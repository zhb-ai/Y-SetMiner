from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO

import pandas as pd
from fastapi import HTTPException, UploadFile

from app.schemas.solve import ConstraintConfig, Entity, ImportPreviewResponse, Item, Relation, SceneDataset

REQUIRED_ALIASES = {
    "user_id": ["user_id", "用户id", "用户ID", "账号", "工号", "用户编码"],
    "user_name": ["user_name", "用户名", "姓名", "用户名称", "员工姓名"],
    "permission_id": ["permission_id", "权限id", "权限ID", "权限编码", "perm_id"],
    "permission_name": ["permission_name", "权限名称", "权限名", "perm_name"],
}

OPTIONAL_ALIASES = {
    "permission_group": ["permission_group", "权限组", "模块", "菜单组", "业务域"],
    "permission_type": ["permission_type", "权限类型", "类型", "type"],
    "permission_level": ["permission_level", "权限层级", "层级", "level"],
    "parent_permission_id": ["parent_permission_id", "父权限id", "父权限ID", "上级权限id", "上级权限ID", "parent_id"],
    "sod_conflict_code": ["sod_conflict_code", "职责分离冲突组", "冲突组", "sod组", "冲突编码"],
    "sod_conflict_level": ["sod_conflict_level", "职责分离级别", "冲突级别", "sod级别"],
    "permission_path": ["permission_path", "权限路径", "菜单路径", "path"],
}

CURRENT_ROLE_REQUIRED_ALIASES = {
    "role_id": ["role_id", "角色id", "角色ID", "角色编码"],
    "role_name": ["role_name", "角色名", "角色名称"],
    "permission_id": REQUIRED_ALIASES["permission_id"],
    "permission_name": REQUIRED_ALIASES["permission_name"],
}

CURRENT_USER_ROLE_REQUIRED_ALIASES = {
    "user_id": REQUIRED_ALIASES["user_id"],
    "user_name": REQUIRED_ALIASES["user_name"],
    "role_id": CURRENT_ROLE_REQUIRED_ALIASES["role_id"],
    "role_name": CURRENT_ROLE_REQUIRED_ALIASES["role_name"],
}

SUPPORTED_SUFFIXES = (".csv", ".xlsx", ".xls")


@dataclass
class ParsedErpData:
    dataframe: pd.DataFrame
    detected_columns: dict[str, str]


@dataclass
class CurrentRoleState:
    roles: list[dict[str, object]]


class ErpImportService:
    async def preview_upload(self, upload: UploadFile) -> ImportPreviewResponse:
        parsed = await self._parse_upload(upload)
        dataset = self._build_dataset(parsed)
        return ImportPreviewResponse(
            scene="erp",
            entity_count=len(dataset.entities),
            item_count=len(dataset.items),
            relation_count=len(dataset.relations),
            sample_entities=[entity.name for entity in dataset.entities[:5]],
            sample_items=[item.name for item in dataset.items[:5]],
            detected_columns=parsed.detected_columns,
            warnings=self._build_warnings(parsed.dataframe, dataset),
        )

    async def solve_upload(self, upload: UploadFile) -> SceneDataset:
        parsed = await self._parse_upload(upload)
        return self._build_dataset(parsed)

    async def parse_current_roles(
        self,
        current_role_permissions_file: UploadFile | None,
        current_user_roles_file: UploadFile | None = None,
    ) -> CurrentRoleState | None:
        if current_role_permissions_file is None:
            return None

        role_permissions = await self._parse_generic_upload(
            current_role_permissions_file,
            CURRENT_ROLE_REQUIRED_ALIASES,
            OPTIONAL_ALIASES,
            dedupe_subset=["role_id", "permission_id"],
            empty_message="现状角色权限文件中没有可用的角色-权限关系数据。",
        )

        role_to_users: dict[str, list[tuple[str, str]]] = {}
        if current_user_roles_file is not None:
            user_roles = await self._parse_generic_upload(
                current_user_roles_file,
                CURRENT_USER_ROLE_REQUIRED_ALIASES,
                {},
                dedupe_subset=["user_id", "role_id"],
                empty_message="现状用户角色文件中没有可用的用户-角色关系数据。",
            )
            for row in user_roles.dataframe[["role_id", "user_id", "user_name"]].itertuples(index=False):
                role_to_users.setdefault(row.role_id, []).append((str(row.user_id), str(row.user_name)))

        roles: list[dict[str, object]] = []
        aggregate_columns: dict[str, str] = {"role_name": "first", "permission_name": "first"}
        for column in OPTIONAL_ALIASES:
            if column in role_permissions.dataframe.columns:
                aggregate_columns[column] = "first"

        for role_id, role_frame in role_permissions.dataframe.groupby("role_id", as_index=False):
            role_name = str(role_frame["role_name"].iloc[0])
            permission_columns = ["permission_id", "permission_name", *[column for column in OPTIONAL_ALIASES if column in role_frame.columns]]
            permissions = role_frame[permission_columns].drop_duplicates().to_dict("records")
            users = role_to_users.get(role_id, [])
            roles.append(
                {
                    "role_id": str(role_id),
                    "role_name": role_name,
                    "permissions": permissions,
                    "user_names": [user_name for _, user_name in users],
                    "user_count": len(users),
                }
            )

        return CurrentRoleState(roles=roles)

    async def _parse_upload(self, upload: UploadFile) -> ParsedErpData:
        return await self._parse_generic_upload(
            upload,
            REQUIRED_ALIASES,
            OPTIONAL_ALIASES,
            dedupe_subset=["user_id", "permission_id"],
            empty_message="上传文件没有可用的用户-权限关系数据。",
        )

    async def _parse_generic_upload(
        self,
        upload: UploadFile,
        required_aliases: dict[str, list[str]],
        optional_aliases: dict[str, list[str]],
        dedupe_subset: list[str],
        empty_message: str,
    ) -> ParsedErpData:
        filename = upload.filename or ""
        if not filename.lower().endswith(SUPPORTED_SUFFIXES):
            raise HTTPException(status_code=400, detail="仅支持上传 csv、xlsx、xls 文件。")

        content = await upload.read()
        dataframe = self._read_dataframe(filename, content)
        dataframe.columns = [str(column).strip() for column in dataframe.columns]

        detected_columns: dict[str, str] = {}
        for logical_name, aliases in required_aliases.items():
            matched = next((column for column in dataframe.columns if column in aliases), None)
            if matched is None:
                raise HTTPException(
                    status_code=400,
                    detail=f"缺少必要列 `{logical_name}`，可接受别名包括: {', '.join(aliases)}",
                )
            detected_columns[logical_name] = matched

        for logical_name, aliases in optional_aliases.items():
            matched = next((column for column in dataframe.columns if column in aliases), None)
            if matched is not None:
                detected_columns[logical_name] = matched

        normalized = dataframe.rename(columns={value: key for key, value in detected_columns.items()}).copy()
        for key in required_aliases:
            normalized[key] = normalized[key].astype(str).str.strip()
        for key in optional_aliases:
            if key in normalized.columns:
                normalized[key] = normalized[key].apply(self._clean_optional_value)
        if "permission_level" in normalized.columns:
            normalized["permission_level"] = normalized["permission_level"].apply(
                lambda value: self._derive_permission_level(value, None)
            )
        if "permission_type" in normalized.columns and "permission_level" not in normalized.columns:
            normalized["permission_type"] = normalized["permission_type"].apply(self._clean_optional_value)
        if "sod_conflict_level" in normalized.columns:
            normalized["sod_conflict_level"] = normalized["sod_conflict_level"].apply(self._normalize_sod_level)

        non_empty_filter = True
        for key in required_aliases:
            non_empty_filter = non_empty_filter & (normalized[key] != "")

        normalized = normalized[non_empty_filter].drop_duplicates(subset=dedupe_subset)
        if normalized.empty:
            raise HTTPException(status_code=400, detail=empty_message)

        return ParsedErpData(dataframe=normalized, detected_columns=detected_columns)

    def _read_dataframe(self, filename: str, content: bytes) -> pd.DataFrame:
        if filename.lower().endswith(".csv"):
            for encoding in ("utf-8-sig", "utf-8", "gbk", "gb2312"):
                try:
                    return pd.read_csv(BytesIO(content), encoding=encoding)
                except UnicodeDecodeError:
                    continue
            raise HTTPException(status_code=400, detail="CSV 编码无法识别，请保存为 UTF-8 或 GBK。")

        try:
            return pd.read_excel(BytesIO(content))
        except Exception as exc:  # pragma: no cover
            raise HTTPException(status_code=400, detail=f"Excel 解析失败: {exc}") from exc

    def _build_dataset(self, parsed: ParsedErpData) -> SceneDataset:
        dataframe = parsed.dataframe

        entities = [
            Entity(id=row.user_id, name=row.user_name)
            for row in dataframe[["user_id", "user_name"]].drop_duplicates().itertuples(index=False)
        ]

        aggregate_columns: dict[str, str] = {"permission_name": "first"}
        for column in OPTIONAL_ALIASES:
            if column in dataframe.columns:
                aggregate_columns[column] = "first"

        item_rows = (
            dataframe.groupby("permission_id", as_index=False)
            .agg(aggregate_columns)
        )

        permission_meta_by_id: dict[str, dict[str, object]] = {}
        items = []
        for row in item_rows.itertuples(index=False):
            permission_level = self._derive_permission_level(
                getattr(row, "permission_level", None),
                getattr(row, "permission_type", None),
            )
            meta = {
                "parent_permission_id": self._clean_optional_value(getattr(row, "parent_permission_id", None)),
                "permission_level": permission_level,
                "sod_conflict_code": self._clean_optional_value(getattr(row, "sod_conflict_code", None)),
                "sod_conflict_level": self._normalize_sod_level(getattr(row, "sod_conflict_level", None)),
                "permission_path": self._clean_optional_value(getattr(row, "permission_path", None)),
            }
            permission_meta_by_id[str(row.permission_id)] = meta
            items.append(
                Item(
                    id=row.permission_id,
                    name=str(row.permission_name),
                    group=getattr(row, "permission_group", None),
                    item_type=getattr(row, "permission_type", None),
                    meta=meta,
                )
            )

        relation_pairs = {
            (str(row.user_id), str(row.permission_id))
            for row in dataframe[["user_id", "permission_id"]].itertuples(index=False)
        }

        auto_added_parent_relations: list[dict[str, str]] = []
        for entity_id, permission_id in list(relation_pairs):
            parent_permission_id = permission_meta_by_id.get(permission_id, {}).get("parent_permission_id")
            if parent_permission_id and (entity_id, str(parent_permission_id)) not in relation_pairs:
                relation_pairs.add((entity_id, str(parent_permission_id)))
                auto_added_parent_relations.append(
                    {
                        "entity_id": entity_id,
                        "permission_id": permission_id,
                        "parent_permission_id": str(parent_permission_id),
                    }
                )

        relations = [
            Relation(entity_id=entity_id, item_id=permission_id)
            for entity_id, permission_id in sorted(relation_pairs)
        ]

        return SceneDataset(
            scene="erp",
            entities=entities,
            items=items,
            relations=relations,
            constraints=ConstraintConfig(max_items_per_unit=12, max_units_per_entity=4),
            meta={
                "auto_added_parent_relations": auto_added_parent_relations,
            },
        )

    def _build_warnings(self, dataframe: pd.DataFrame, dataset: SceneDataset) -> list[str]:
        warnings: list[str] = []
        if "permission_group" not in dataframe.columns:
            warnings.append("未提供权限分组列，系统会仅按权限共现关系自动命名角色。")
        if "permission_type" not in dataframe.columns:
            warnings.append("未提供权限类型列，当前不会区分菜单、按钮、接口权限。")
        if "parent_permission_id" not in dataframe.columns:
            warnings.append("未提供父权限列，当前不会校验按钮是否依赖父菜单。")
        if "sod_conflict_code" not in dataframe.columns:
            warnings.append("未提供职责分离冲突组列，当前不会进行 SoD 冲突控制。")
        if dataset.meta.get("auto_added_parent_relations"):
            warnings.append(f"已根据父权限关系自动补齐 {len(dataset.meta['auto_added_parent_relations'])} 条用户父菜单依赖。")
        if len(dataset.entities) < 3:
            warnings.append("用户数量较少，算法结果更适合做辅助参考。")
        if len(dataset.items) > 200:
            warnings.append("权限数量较多，后续建议接入 BMF/ILP 精修以减少角色重叠。")
        return warnings

    def _derive_permission_level(self, level_value: object, type_value: object) -> str | None:
        level = self._clean_optional_value(level_value)
        if level:
            return level.lower()
        type_text = self._clean_optional_value(type_value)
        if type_text:
            lowered = type_text.lower()
            if lowered in {"menu", "button", "api"}:
                return lowered
        return None

    def _normalize_sod_level(self, value: object) -> str | None:
        text = self._clean_optional_value(value)
        if text is None:
            return None
        lowered = text.lower()
        if lowered in {"hard", "soft"}:
            return lowered
        return None

    def _clean_optional_value(self, value: object) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        if text == "" or text.lower() == "nan":
            return None
        return text
