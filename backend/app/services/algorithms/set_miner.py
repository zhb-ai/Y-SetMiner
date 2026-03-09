from __future__ import annotations

from collections import Counter, deque
from dataclasses import dataclass
from itertools import combinations

import numpy as np

from app.schemas.solve import (
    Assignment,
    ConstraintAutoFix,
    ConstraintIssue,
    ErpConstraintReport,
    SceneDataset,
    SqlUnitGroup,
    SolveResponse,
    SolutionUnit,
    SummaryMetric,
)
from app.services.graph.graph_builder import build_erp_graph, build_sql_graph
from app.services.matrix.builder import build_matrix
from app.services.algorithms.sql_unit_hierarchy import (
    build_extension_delta,
    build_filter_field_suggestions,
    get_real_unit_source_counter,
    get_real_unit_sources,
    _build_item_source_detail,
    mine_sql_base_candidates,
    _build_item_source_label,
    _split_item_meta_list,
)
from app.services.scenes.erp_importer import CurrentRoleState
from app.services.scenes.erp_role_diff import ErpRoleDiffService


@dataclass
class ErpConstraintContext:
    item_index_by_id: dict[str, int]
    parent_map: dict[int, int]
    hard_groups: dict[str, set[int]]
    soft_groups: dict[str, set[int]]
    item_frequency: np.ndarray


class SetMinerService:
    def __init__(self) -> None:
        self.erp_role_diff_service = ErpRoleDiffService()

    def solve(self, dataset: SceneDataset, current_role_state: CurrentRoleState | None = None) -> SolveResponse:
        bundle = build_matrix(dataset)
        matrix = bundle.matrix
        item_lookup = {item.id: item for item in dataset.items}
        constraint_context = self._build_erp_constraint_context(dataset, matrix) if dataset.scene == "erp" else None

        selected_units = self._select_units(dataset, matrix, {}, constraint_context=constraint_context)
        selected_units = self._decorate_units(dataset, matrix, selected_units)
        sql_unit_groups = None
        if dataset.scene == "sql":
            selected_units, sql_unit_groups = self._build_sql_unit_groups(dataset, matrix, selected_units)

        assignments = self._build_assignments(bundle, matrix, selected_units)

        n_entities = len(bundle.entity_ids)
        total_required = int(matrix.sum())
        total_granted = sum(
            len(unit["item_ids"]) * len(unit["covered_entity_ids"]) for unit in selected_units
        )
        redundancy = max(total_granted - total_required, 0)

        item_term = "权限" if dataset.scene == "erp" else "字段"

        if dataset.scene == "sql" and sql_unit_groups:
            summary = self._build_sql_summary_metrics(
                matrix, n_entities, total_required, redundancy, selected_units, sql_unit_groups,
            )
        else:
            summary = [
                SummaryMetric(
                    label="推荐组合数",
                    value=str(len(selected_units)),
                    hint="ERP 对应角色数。",
                ),
                SummaryMetric(
                    label="覆盖实体数",
                    value=str(n_entities),
                    hint="本次参与分析的用户数量。",
                ),
                SummaryMetric(
                    label="需求覆盖率",
                    value="100%",
                    hint="当前以完全覆盖输入需求为目标。",
                ),
                SummaryMetric(
                    label=f"冗余{item_term}数",
                    value=str(redundancy),
                    hint=f"由共享组合带来的附加{item_term}数量。",
                ),
            ]

        scene_title = "ERP 推荐角色方案" if dataset.scene == "erp" else "SQL 推荐宽表方案"
        unit_type = "角色" if dataset.scene == "erp" else "宽表"
        warnings = self._build_warnings(dataset, assignments, selected_units)
        insights = self._build_insights(dataset, selected_units, item_lookup, unit_type, sql_unit_groups)
        constraint_report = self._build_erp_constraint_report(dataset, selected_units) if dataset.scene == "erp" else None

        response = SolveResponse(
            scene=dataset.scene,
            title=scene_title,
            summary=summary,
            units=[self._to_solution_unit_model(unit, unit_type) for unit in selected_units],
            assignments=assignments,
            warnings=warnings,
            insights=insights,
            sql_unit_groups=[
                SqlUnitGroup(
                    key=group["key"],
                    group_name=group["group_name"],
                    base_unit=self._to_solution_unit_model(group["base_unit"], unit_type),
                    units=[self._to_solution_unit_model(unit, unit_type) for unit in group["units"]],
                )
                for group in sql_unit_groups
            ]
            if sql_unit_groups
            else None,
            erp_role_diff=None,
            erp_constraint_report=constraint_report,
        )

        if dataset.scene == "erp":
            response.erp_role_diff = self.erp_role_diff_service.build_diff_report(response, current_role_state)

        # 构建关系图（附加在 response 中，前端按需展示）
        try:
            if dataset.scene == "sql":
                response.graph = build_sql_graph(dataset, response)
            else:
                response.graph = build_erp_graph(dataset, response)
        except Exception:
            response.graph = None  # 图构建失败不影响主流程

        return response

    def _compute_jaccard_association(self, matrix: np.ndarray) -> np.ndarray:
        """计算字段/权限之间的 Jaccard 关联矩阵。"""
        n, m = matrix.shape
        assoc = np.zeros((m, m))
        for j in range(m):
            for l in range(j + 1, m):
                col_j = matrix[:, j].astype(bool)
                col_l = matrix[:, l].astype(bool)
                intersection = int(np.sum(col_j & col_l))
                union = int(np.sum(col_j | col_l))
                sim = intersection / union if union > 0 else 0.0
                assoc[j, l] = assoc[l, j] = sim
        return assoc

    def _generate_asso_candidates(self, assoc: np.ndarray, matrix: np.ndarray, tau: float) -> list[np.ndarray]:
        """基于 Jaccard 关联矩阵生成候选基向量（字段组），并加入每个实体的完整字段集合。"""
        m = assoc.shape[0]
        seen: dict[tuple, np.ndarray] = {}

        # 方法1：关联矩阵行二值化——找高度共现的字段组
        for j in range(m):
            candidate = (assoc[j] >= tau).astype(np.int8)
            candidate[j] = 1
            if int(candidate.sum()) >= 2:
                key = tuple(candidate.tolist())
                seen[key] = candidate

        # 方法2：每个实体的完整字段集合也纳入候选
        for row in matrix:
            candidate = row.astype(np.int8)
            if int(candidate.sum()) >= 1:
                key = tuple(candidate.tolist())
                seen[key] = candidate

        return list(seen.values())

    def _select_units(
        self,
        dataset: SceneDataset,
        matrix: np.ndarray,
        pattern_groups: dict[tuple[int, ...], list[int]],  # 保留签名兼容性，此参数不再使用
        constraint_context: ErpConstraintContext | None = None,
    ) -> list[dict[str, object]]:
        n, m = matrix.shape
        max_items = dataset.constraints.max_items_per_unit

        # 动态调整关联阈值：字段越少阈值越低，保证能形成有意义的候选组
        tau = 0.3 if m <= 20 else (0.4 if m <= 50 else 0.5)
        assoc = self._compute_jaccard_association(matrix)
        candidates = self._generate_asso_candidates(assoc, matrix, tau)

        selected_units: list[dict[str, object]] = []
        residual = matrix.copy().astype(np.int8)
        unit_index = 0

        for _ in range(max(n, m) * 2):  # 上界保护，防止死循环
            if residual.sum() == 0:
                break

            best_gain = 0
            best_item_vec: np.ndarray | None = None
            best_entity_indices: list[int] = []

            for candidate in candidates:
                # 截断至最大字段数：选取与候选中字段关联度最高的 top-max_items 项
                item_positions = np.where(candidate == 1)[0]
                if len(item_positions) > max_items:
                    # 保留关联度最强的 max_items 个字段
                    freq = matrix[:, item_positions].sum(axis=0)
                    top_pos = item_positions[np.argsort(-freq)[:max_items]]
                    truncated = np.zeros(m, dtype=np.int8)
                    truncated[top_pos] = 1
                else:
                    truncated = candidate

                item_positions_trunc = np.where(truncated == 1)[0]
                if len(item_positions_trunc) == 0:
                    continue

                # 判断哪些实体与该候选有足够重叠（覆盖率 > 0.5 或完全包含）
                sub_residual = residual[:, item_positions_trunc]  # shape (n, k)
                sub_original = matrix[:, item_positions_trunc]
                k = len(item_positions_trunc)

                # 实体必须在原始矩阵中拥有该候选的大部分字段（至少 50%）
                entity_has = (sub_original.sum(axis=1) / k) >= 0.5
                entity_indices = np.where(entity_has)[0].tolist()
                if not entity_indices:
                    continue

                gain = int(residual[np.ix_(entity_indices, item_positions_trunc.tolist())].sum())
                if gain > best_gain:
                    best_gain = gain
                    best_item_vec = truncated
                    best_entity_indices = entity_indices

            if best_gain == 0 or best_item_vec is None:
                break

            unit_index += 1
            item_indices = np.where(best_item_vec == 1)[0].tolist()

            constraint_meta = self._apply_erp_constraints(item_indices, constraint_context) if constraint_context else {}
            final_item_indices = constraint_meta.get("item_indices", item_indices)

            selected_units.append(
                {
                    "id": f"unit-{unit_index}",
                    "item_indices": final_item_indices,
                    "entity_indices": best_entity_indices,
                    "score": round(
                        max(
                            (best_gain / max(len(final_item_indices), 1))
                            - float(constraint_meta.get("soft_penalty", 0)),
                            0,
                        ),
                        2,
                    ),
                    **constraint_meta,
                }
            )
            residual[np.ix_(best_entity_indices, final_item_indices)] = 0

        # 尾部补齐：把剩余未覆盖的字段合并到已有的最相似宽表，实在无法合并才新建
        for row_index in range(n):
            remaining = np.where(residual[row_index] == 1)[0].tolist()
            if not remaining:
                continue

            # 尝试把剩余字段并入已有宽表（找字段集合重叠最多的宽表）
            best_unit_idx = -1
            best_overlap = 0
            for u_idx, unit in enumerate(selected_units):
                overlap = len(set(unit["item_indices"]) & set(remaining))
                if overlap > best_overlap:
                    best_overlap = overlap
                    best_unit_idx = u_idx

            if best_unit_idx >= 0 and best_overlap > 0:
                merged = sorted(set(selected_units[best_unit_idx]["item_indices"]) | set(remaining))
                if len(merged) <= max_items:
                    selected_units[best_unit_idx]["item_indices"] = merged
                    if row_index not in selected_units[best_unit_idx]["entity_indices"]:
                        selected_units[best_unit_idx]["entity_indices"].append(row_index)
                    residual[row_index, remaining] = 0
                    continue

            # 无法合并时新建补充宽表
            unit_index += 1
            constraint_meta = (
                self._apply_erp_constraints(remaining[:max_items], constraint_context)
                if constraint_context
                else {}
            )
            selected_units.append(
                {
                    "id": f"unit-tail-{unit_index}",
                    "item_indices": constraint_meta.get("item_indices", remaining[:max_items]),
                    "entity_indices": [row_index],
                    "score": round(
                        max(len(remaining) - float(constraint_meta.get("soft_penalty", 0)), 0), 2
                    ),
                    **constraint_meta,
                }
            )

        if dataset.scene == "sql":
            selected_units = self._merge_similar_sql_units(dataset, matrix, selected_units)

        return selected_units

    def _get_unit_source_counter(
        self,
        dataset: SceneDataset,
        unit: dict[str, object],
    ) -> Counter[str]:
        return get_real_unit_source_counter(dataset, unit)

    def _get_unit_source_signature(
        self,
        dataset: SceneDataset,
        unit: dict[str, object],
    ) -> tuple[str, ...]:
        return get_real_unit_sources(dataset, unit)

    def _build_sql_unit_name(
        self,
        dataset: SceneDataset,
        unit: dict[str, object],
        index: int | None = None,
    ) -> str:
        unit_level = unit.get("unit_level")
        base_name = str(unit.get("base_name") or "")
        if unit_level == "base" and base_name:
            return f"{base_name}基础宽表"
        if unit_level == "extension" and base_name:
            extra_sources = list(unit.get("extra_source_tables", []))
            if extra_sources:
                return f"{base_name}扩展宽表(+{'+'.join(extra_sources)})"
            return f"{base_name}扩展宽表(+字段扩展)"

        source_signature = self._get_unit_source_signature(dataset, unit)
        if not source_signature:
            return f"通用宽表{index or 1}"

        canonical_name = "+".join(source_signature)
        if len(source_signature) == 1:
            return f"{canonical_name}宽表{index or 1}"
        return f"{canonical_name}组合宽表{index or 1}"

    def _should_merge_sql_units(
        self,
        dataset: SceneDataset,
        left_unit: dict[str, object],
        right_unit: dict[str, object],
    ) -> bool:
        left_sources = self._get_unit_source_signature(dataset, left_unit)
        right_sources = self._get_unit_source_signature(dataset, right_unit)

        # 来源集合不同，说明语义层级通常已经不同，不做硬合并。
        if left_sources != right_sources:
            return False

        left_items = set(left_unit["item_indices"])
        right_items = set(right_unit["item_indices"])
        if not left_items or not right_items:
            return False

        item_overlap = len(left_items & right_items) / max(len(left_items | right_items), 1)
        if item_overlap < 0.35:
            return False

        left_entities = set(left_unit["entity_indices"])
        right_entities = set(right_unit["entity_indices"])
        entity_overlap = len(left_entities & right_entities) / max(len(left_entities | right_entities), 1)

        # 实体完全不同但字段又不算足够接近时，也不合并。
        return entity_overlap > 0 or item_overlap >= 0.6

    def _merge_similar_sql_units(
        self,
        dataset: SceneDataset,
        matrix: np.ndarray,
        units: list[dict[str, object]],
    ) -> list[dict[str, object]]:
        """保守合并高度相似的 SQL 宽表，避免同名族宽表过度碎片化。"""
        if not units:
            return units

        # 先按来源集合粗分组，防止把“产品维表”与“销售事实宽表”合并到一起。
        buckets: dict[tuple[str, ...], list[dict[str, object]]] = {}
        for unit in units:
            buckets.setdefault(self._get_unit_source_signature(dataset, unit), []).append(unit)

        merged_units: list[dict[str, object]] = []
        for bucket_units in buckets.values():
            working_units = [
                {
                    **unit,
                    "item_indices": sorted(set(unit["item_indices"])),
                    "entity_indices": sorted(set(unit["entity_indices"])),
                }
                for unit in bucket_units
            ]

            changed = True
            while changed and len(working_units) > 1:
                changed = False
                for left_idx in range(len(working_units)):
                    if changed:
                        break
                    for right_idx in range(left_idx + 1, len(working_units)):
                        left_unit = working_units[left_idx]
                        right_unit = working_units[right_idx]
                        if not self._should_merge_sql_units(dataset, left_unit, right_unit):
                            continue

                        merged_items = sorted(set(left_unit["item_indices"]) | set(right_unit["item_indices"]))
                        merged_entities = sorted(set(left_unit["entity_indices"]) | set(right_unit["entity_indices"]))
                        gain = int(matrix[np.ix_(merged_entities, merged_items)].sum())
                        working_units[left_idx] = {
                            "id": f"{left_unit['id']}__{right_unit['id']}",
                            "item_indices": merged_items,
                            "entity_indices": merged_entities,
                            "score": round(gain / max(len(merged_items), 1), 2),
                        }
                        del working_units[right_idx]
                        changed = True
                        break

            merged_units.extend(working_units)

        return merged_units

    def _decorate_units(
        self,
        dataset: SceneDataset,
        matrix: np.ndarray,
        units: list[dict[str, object]],
    ) -> list[dict[str, object]]:
        decorated: list[dict[str, object]] = []
        items = dataset.items
        entities = dataset.entities
        label_prefix = "角色" if dataset.scene == "erp" else "宽表"
        item_term = "权限" if dataset.scene == "erp" else "字段"

        for idx, unit in enumerate(units, start=1):
            item_indices = unit["item_indices"]
            entity_indices = unit["entity_indices"]
            unit_items = [items[item_idx] for item_idx in item_indices]
            top_names = "、".join(item.name for item in unit_items[:2])
            sources = sorted(
                {
                    item.source
                    for item in unit_items
                    if item.source and item.source != "unknown"
                }
            )
            if dataset.scene == "sql":
                name = self._build_sql_unit_name(dataset, unit, idx)
            else:
                groups = Counter(
                    item.group
                    for item in unit_items
                    if item.group and item.group != "unknown"
                )
                if groups:
                    top_group = groups.most_common(1)[0][0]
                else:
                    fallback_groups = Counter(item.group or "通用" for item in unit_items)
                    top_group = fallback_groups.most_common(1)[0][0]
                name = f"{top_group}{label_prefix}{idx}"
            rationale = f"覆盖 {len(entity_indices)} 个实体，核心{item_term}为 {top_names}。"
            decorated.append(
                {
                    "id": unit["id"],
                    "name": name,
                    "entity_indices": entity_indices,
                    "item_indices": item_indices,
                    "item_ids": [items[item_idx].id for item_idx in item_indices],
                    "item_names": [items[item_idx].name for item_idx in item_indices],
                    "item_display_names": [items[item_idx].name for item_idx in item_indices],
                    "item_exprs": [items[item_idx].meta.get("original_expr", "") for item_idx in item_indices],
                    "item_sources": [_build_item_source_label(dataset, item_idx) for item_idx in item_indices],
                    "item_source_details": [_build_item_source_detail(dataset, item_idx) for item_idx in item_indices],
                    "covered_entity_ids": [entities[e_idx].id for e_idx in entity_indices],
                    "covered_entity_names": [entities[e_idx].name for e_idx in entity_indices],
                    "score": unit["score"],
                    "rationale": rationale,
                    "sources": sources,
                    "base_name": unit.get("base_name"),
                    "unit_level": unit.get("unit_level", "standalone"),
                    "base_unit_id": unit.get("base_unit_id"),
                    "extra_source_tables": list(unit.get("extra_source_tables", [])),
                    "extra_item_names": list(unit.get("extra_item_names", [])),
                    "extra_item_sources": list(unit.get("extra_item_sources", [])),
                    "extra_item_source_details": list(unit.get("extra_item_source_details", [])),
                    "suggested_item_names": list(unit.get("suggested_item_names", [])),
                    "suggested_item_sources": list(unit.get("suggested_item_sources", [])),
                    "suggested_item_source_details": list(unit.get("suggested_item_source_details", [])),
                    "suggested_item_hits": list(unit.get("suggested_item_hits", [])),
                    "filter_item_names": list(unit.get("filter_item_names", [])),
                    "filter_item_sources": list(unit.get("filter_item_sources", [])),
                    "filter_item_source_details": list(unit.get("filter_item_source_details", [])),
                    "filter_item_hits": list(unit.get("filter_item_hits", [])),
                    "filter_item_support_count": unit.get("filter_item_support_count"),
                    "support_unit_count": unit.get("support_unit_count"),
                    "base_field_min_hits": unit.get("base_field_min_hits"),
                    "suggested_field_min_hits": unit.get("suggested_field_min_hits"),
                    "added_parent_names": [items[item_idx].name for item_idx in unit.get("added_parent_indices", [])],
                    "hard_removed_names": [items[item_idx].name for item_idx in unit.get("hard_removed_indices", [])],
                    "soft_conflict_names": [
                        [items[item_idx].name for item_idx in group]
                        for group in unit.get("soft_conflict_groups", [])
                    ],
                }
            )

        decorated.sort(
            key=lambda unit: (len(unit["covered_entity_ids"]), unit["score"], len(unit["item_ids"])),
            reverse=True,
        )
        return decorated

    def _to_solution_unit_model(self, unit: dict[str, object], unit_type: str) -> SolutionUnit:
        return SolutionUnit(
            id=unit["id"],
            name=unit["name"],
            unit_type=unit_type,
            item_ids=unit["item_ids"],
            item_names=unit["item_names"],
            item_display_names=unit["item_display_names"],
            item_exprs=unit["item_exprs"],
            item_sources=unit.get("item_sources", []),
            item_source_details=unit.get("item_source_details", []),
            covered_entity_ids=unit["covered_entity_ids"],
            covered_entity_names=unit["covered_entity_names"],
            rationale=unit["rationale"],
            score=unit["score"],
            sources=unit["sources"],
            unit_level=unit.get("unit_level", "standalone"),
            base_unit_id=unit.get("base_unit_id"),
            extra_source_tables=list(unit.get("extra_source_tables", [])),
            extra_item_names=list(unit.get("extra_item_names", [])),
            extra_item_sources=list(unit.get("extra_item_sources", [])),
            extra_item_source_details=list(unit.get("extra_item_source_details", [])),
            suggested_item_names=list(unit.get("suggested_item_names", [])),
            suggested_item_sources=list(unit.get("suggested_item_sources", [])),
            suggested_item_source_details=list(unit.get("suggested_item_source_details", [])),
            suggested_item_hits=list(unit.get("suggested_item_hits", [])),
            filter_item_names=list(unit.get("filter_item_names", [])),
            filter_item_sources=list(unit.get("filter_item_sources", [])),
            filter_item_source_details=list(unit.get("filter_item_source_details", [])),
            filter_item_hits=list(unit.get("filter_item_hits", [])),
            filter_item_support_count=unit.get("filter_item_support_count"),
            support_unit_count=unit.get("support_unit_count"),
            base_field_min_hits=unit.get("base_field_min_hits"),
            suggested_field_min_hits=unit.get("suggested_field_min_hits"),
        )

    def _build_unit_filter_field_payload(
        self,
        dataset: SceneDataset,
        entity_names: list[str],
        *,
        allowed_sources: tuple[str, ...] | None = None,
        excluded_pairs: set[tuple[str, str]] | None = None,
        min_hits: int = 1,
    ) -> dict[str, object]:
        names, sources, details, hits, support_count = build_filter_field_suggestions(
            dataset,
            entity_names,
            allowed_sources=allowed_sources,
            excluded_fields=excluded_pairs,
            min_hits=min_hits,
        )
        return {
            "filter_item_names": names,
            "filter_item_sources": sources,
            "filter_item_source_details": details,
            "filter_item_hits": hits,
            "filter_item_support_count": support_count if names else None,
        }

    @staticmethod
    def _build_sql_summary_metrics(
        matrix: np.ndarray,
        n_entities: int,
        total_required: int,
        redundancy: int,
        selected_units: list[dict],
        sql_unit_groups: list[dict],
    ) -> list[SummaryMetric]:
        base_covered: set[tuple[int, int]] = set()
        n_base = 0
        n_extension = 0
        n_standalone = 0
        for group in sql_unit_groups:
            base = group["base_unit"]
            level = base.get("unit_level", "standalone")
            if level == "base":
                n_base += 1
                for ei in base["entity_indices"]:
                    for ii in base["item_indices"]:
                        if matrix[ei, ii] == 1:
                            base_covered.add((ei, ii))
            elif level == "standalone":
                n_standalone += 1
            n_extension += len(group["units"])

        base_coverage_pct = round(len(base_covered) / max(total_required, 1) * 100)

        effective_count = sum(
            1 for unit in selected_units if len(unit.get("covered_entity_ids", [])) >= 2
        )

        col_usage = (matrix > 0).sum(axis=0)
        used_items = int((col_usage >= 1).sum())
        standalone_items = int((col_usage == 1).sum())
        standalone_pct = round(standalone_items / max(used_items, 1) * 100)

        total_units = n_base + n_extension + n_standalone
        composition = f"基础 {n_base} + 扩展 {n_extension} + 独立 {n_standalone}"

        return [
            SummaryMetric(
                label="推荐宽表数",
                value=str(total_units),
                hint=composition,
            ),
            SummaryMetric(
                label="覆盖 SQL 数",
                value=str(n_entities),
                hint="本次参与分析的 SQL 文件数量。",
            ),
            SummaryMetric(
                label="基础宽表覆盖率",
                value=f"{base_coverage_pct}%",
                hint=(
                    f"仅靠 {n_base} 张基础宽表即可覆盖 {base_coverage_pct}% 的字段需求，"
                    + ("复用价值高，扩展宽表仅作补充。" if base_coverage_pct >= 60
                       else "覆盖率偏低，仍需扩展或独立宽表补充剩余需求。" if base_coverage_pct >= 30
                       else "覆盖率较低，业务 SQL 间共性不足，建议检查 SQL 是否可进一步规范化。")
                ),
            ),
            SummaryMetric(
                label="有效宽表数",
                value=f"{effective_count}/{total_units}",
                hint="覆盖 ≥ 2 个 SQL 的宽表，覆盖越多复用价值越高。",
            ),
            SummaryMetric(
                label="独立需求占比",
                value=f"{standalone_pct}%",
                hint=f"{standalone_items}/{used_items} 个字段仅被 1 个 SQL 使用，共性较低。",
            ),
            SummaryMetric(
                label="冗余字段数",
                value=str(redundancy),
                hint="由共享组合带来的附加字段数量。",
            ),
        ]

    def _build_sql_unit_groups(
        self,
        dataset: SceneDataset,
        matrix: np.ndarray,
        units: list[dict[str, object]],
    ) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
        if not units:
            return units, []

        candidates = mine_sql_base_candidates(
            dataset,
            units,
            min_shared_items=dataset.constraints.min_shared_items,
            item_frequency_threshold=dataset.constraints.base_field_threshold,
            suggested_item_frequency_threshold=dataset.constraints.suggested_field_threshold,
        )
        if not candidates:
            standalone_units = []
            standalone_groups = []
            for unit in units:
                updated = {
                    **unit,
                    "unit_level": "standalone",
                    "base_unit_id": None,
                    "extra_source_tables": [],
                    "extra_item_names": [],
                    "extra_item_sources": [],
                    "extra_item_source_details": [],
                    "suggested_item_names": [],
                    "suggested_item_sources": [],
                    "suggested_item_source_details": [],
                    "suggested_item_hits": [],
                    "support_unit_count": None,
                    "base_field_min_hits": None,
                    "suggested_field_min_hits": None,
                }
                updated.update(
                    self._build_unit_filter_field_payload(
                        dataset,
                        list(updated["covered_entity_names"]),
                        excluded_pairs={
                            (str(name), str(source))
                            for name, source in zip(updated["item_display_names"], updated["item_sources"])
                        },
                    )
                )
                standalone_units.append(updated)
                standalone_groups.append(
                    {
                        "key": updated["id"],
                        "group_name": updated["name"],
                        "base_unit": updated,
                        "units": [],
                    }
                )
            return standalone_units, standalone_groups

        decorated_by_id = {str(unit["id"]): {**unit} for unit in units}
        raw_by_id = {str(unit["id"]): unit for unit in units}
        groups: list[dict[str, object]] = []
        assigned_unit_ids: set[str] = set()

        for candidate in candidates:
            member_ids = [
                member_id
                for member_id in candidate.support_unit_ids
                if member_id not in assigned_unit_ids
            ]
            if len(member_ids) < 2:
                continue

            exact_match_ids = [
                member_id
                for member_id in member_ids
                if self._get_unit_source_signature(dataset, raw_by_id[member_id]) == candidate.source_subset
            ]
            extension_member_ids = [member_id for member_id in member_ids if member_id not in exact_match_ids]
            if not extension_member_ids and len(exact_match_ids) < 3:
                continue

            base_name = "+".join(candidate.source_subset)
            support_entity_names = sorted(
                {
                    entity_name
                    for member_id in member_ids
                    for entity_name in decorated_by_id[member_id]["covered_entity_names"]
                }
            )
            base_unit_id = None
            base_unit = None

            for member_id in exact_match_ids:
                raw_unit = raw_by_id[member_id]
                if self._get_unit_source_signature(dataset, raw_unit) != candidate.source_subset:
                    continue
                extra_sources, extra_items, extra_item_sources, extra_item_source_details = build_extension_delta(
                    dataset, raw_unit, candidate
                )
                if extra_sources or extra_items:
                    continue

                updated = {
                    **decorated_by_id[member_id],
                    "base_name": base_name,
                    "unit_level": "base",
                    "base_unit_id": member_id,
                    "extra_source_tables": [],
                    "extra_item_names": [],
                    "extra_item_sources": [],
                    "extra_item_source_details": [],
                    "suggested_item_names": [dataset.items[item_idx].name for item_idx in candidate.suggested_item_indices],
                    "suggested_item_sources": [_build_item_source_label(dataset, item_idx) for item_idx in candidate.suggested_item_indices],
                    "suggested_item_source_details": [
                        _build_item_source_detail(dataset, item_idx) for item_idx in candidate.suggested_item_indices
                    ],
                    "suggested_item_hits": list(candidate.suggested_item_hits),
                    "support_unit_count": candidate.support_unit_count,
                    "base_field_min_hits": candidate.base_field_min_hits,
                    "suggested_field_min_hits": candidate.suggested_field_min_hits,
                }
                updated.update(
                    self._build_unit_filter_field_payload(
                        dataset,
                        support_entity_names,
                        allowed_sources=candidate.source_subset,
                        excluded_pairs={
                            *[(str(name), str(source)) for name, source in zip(updated["item_display_names"], updated["item_sources"])],
                            *[(str(name), str(source)) for name, source in zip(updated["suggested_item_names"], updated["suggested_item_sources"])],
                        },
                        min_hits=candidate.suggested_field_min_hits,
                    )
                )
                updated["name"] = self._build_sql_unit_name(dataset, updated)
                decorated_by_id[member_id] = updated
                base_unit_id = member_id
                base_unit = updated
                assigned_unit_ids.add(member_id)
                break

            if base_unit is None:
                support_units = [raw_by_id[member_id] for member_id in member_ids]
                synthetic_base = {
                    "id": f"sql-base::{base_name}",
                    "item_indices": candidate.shared_item_indices,
                    "entity_indices": sorted(
                        {
                            entity_index
                            for unit in support_units
                            for entity_index in unit["entity_indices"]
                        }
                    ),
                    "score": round(
                        sum(float(unit["score"]) for unit in support_units) / max(len(support_units), 1),
                        2,
                    ),
                    "base_name": base_name,
                    "unit_level": "base",
                    "base_unit_id": None,
                    "extra_source_tables": [],
                    "extra_item_names": [],
                    "extra_item_sources": [],
                    "extra_item_source_details": [],
                    "suggested_item_names": [dataset.items[item_idx].name for item_idx in candidate.suggested_item_indices],
                    "suggested_item_sources": [_build_item_source_label(dataset, item_idx) for item_idx in candidate.suggested_item_indices],
                    "suggested_item_source_details": [
                        _build_item_source_detail(dataset, item_idx) for item_idx in candidate.suggested_item_indices
                    ],
                    "suggested_item_hits": list(candidate.suggested_item_hits),
                    "support_unit_count": candidate.support_unit_count,
                    "base_field_min_hits": candidate.base_field_min_hits,
                    "suggested_field_min_hits": candidate.suggested_field_min_hits,
                }
                base_unit = self._decorate_units(dataset, matrix, [synthetic_base])[0]
                base_unit.update(
                    self._build_unit_filter_field_payload(
                        dataset,
                        support_entity_names,
                        allowed_sources=candidate.source_subset,
                        excluded_pairs={
                            *[(str(name), str(source)) for name, source in zip(base_unit["item_display_names"], base_unit["item_sources"])],
                            *[(str(name), str(source)) for name, source in zip(base_unit["suggested_item_names"], base_unit["suggested_item_sources"])],
                        },
                        min_hits=candidate.suggested_field_min_hits,
                    )
                )
                base_unit_id = str(base_unit["id"])

            extension_units: list[dict[str, object]] = []
            for member_id in member_ids:
                if member_id == base_unit_id:
                    continue
                raw_unit = raw_by_id[member_id]
                extra_sources, extra_items, extra_item_sources, extra_item_source_details = build_extension_delta(
                    dataset, raw_unit, candidate
                )
                updated = {
                    **decorated_by_id[member_id],
                    "base_name": base_name,
                    "unit_level": "extension",
                    "base_unit_id": base_unit_id,
                    "extra_source_tables": extra_sources,
                    "extra_item_names": extra_items,
                    "extra_item_sources": extra_item_sources,
                    "extra_item_source_details": extra_item_source_details,
                    "suggested_item_names": [],
                    "suggested_item_sources": [],
                    "suggested_item_source_details": [],
                    "suggested_item_hits": [],
                    "support_unit_count": None,
                    "base_field_min_hits": None,
                    "suggested_field_min_hits": None,
                }
                updated.update(
                    self._build_unit_filter_field_payload(
                        dataset,
                        list(updated["covered_entity_names"]),
                        excluded_pairs={
                            (str(name), str(source))
                            for name, source in zip(updated["item_display_names"], updated["item_sources"])
                        },
                    )
                )
                updated["name"] = self._build_sql_unit_name(dataset, updated)
                decorated_by_id[member_id] = updated
                extension_units.append(updated)
                assigned_unit_ids.add(member_id)

            groups.append(
                {
                    "key": base_name,
                    "group_name": base_unit["name"],
                    "base_unit": base_unit,
                    "units": sorted(
                        extension_units,
                        key=lambda unit: (
                            len(unit.get("extra_source_tables", [])),
                            len(unit["covered_entity_ids"]),
                            unit["score"],
                        ),
                        reverse=True,
                    ),
                }
            )

        for unit_id, unit in decorated_by_id.items():
            if unit_id in assigned_unit_ids:
                continue
            standalone_unit = {
                **unit,
                "unit_level": "standalone",
                "base_unit_id": None,
                "extra_source_tables": [],
                "extra_item_names": [],
                "extra_item_sources": [],
                "extra_item_source_details": [],
                "suggested_item_names": [],
                "suggested_item_sources": [],
                "suggested_item_source_details": [],
                "suggested_item_hits": [],
                "support_unit_count": None,
                "base_field_min_hits": None,
                "suggested_field_min_hits": None,
            }
            standalone_unit.update(
                self._build_unit_filter_field_payload(
                    dataset,
                    list(standalone_unit["covered_entity_names"]),
                    excluded_pairs={
                        (str(name), str(source))
                        for name, source in zip(standalone_unit["item_display_names"], standalone_unit["item_sources"])
                    },
                )
            )
            standalone_unit["name"] = self._build_sql_unit_name(dataset, standalone_unit)
            decorated_by_id[unit_id] = standalone_unit
            groups.append(
                {
                    "key": unit_id,
                    "group_name": standalone_unit["name"],
                    "base_unit": standalone_unit,
                    "units": [],
                }
            )

        ordered_units = list(decorated_by_id.values())
        ordered_units.sort(
            key=lambda unit: (
                {"base": 0, "extension": 1, "standalone": 2}.get(unit.get("unit_level", "standalone"), 3),
                -len(unit["covered_entity_ids"]),
                -float(unit["score"]),
                unit["name"],
            )
        )
        groups.sort(
            key=lambda group: (
                0 if group["base_unit"].get("unit_level") == "base" else 1,
                -(1 + len(group["units"])),
                group["group_name"],
            )
        )
        return ordered_units, groups

    def _build_assignments(
        self,
        bundle,
        matrix: np.ndarray,
        units: list[dict[str, object]],
    ) -> list[Assignment]:
        assignments: list[Assignment] = []
        for row_idx, entity_name in enumerate(bundle.entity_names):
            entity_need = set(np.where(matrix[row_idx] == 1)[0].tolist())
            matched_units = []
            covered_items: set[int] = set()
            for unit in units:
                if row_idx not in unit["entity_indices"]:
                    continue
                unit_item_indices = set(unit["item_indices"])
                if unit_item_indices.issubset(entity_need):
                    matched_units.append(unit)
                    covered_items |= unit_item_indices
                if len(matched_units) >= 3 or covered_items == entity_need:
                    break

            if not matched_units:
                for unit in units:
                    unit_item_indices = set(unit["item_indices"])
                    if unit_item_indices & entity_need:
                        matched_units.append(unit)
                        covered_items |= unit_item_indices
                    if len(matched_units) >= 3 or covered_items == entity_need:
                        break

            uncovered_names = [bundle.item_names[item_idx] for item_idx in sorted(entity_need - covered_items)]
            assignments.append(
                Assignment(
                    entity_id=bundle.entity_ids[row_idx],
                    entity_name=entity_name,
                    unit_ids=[unit["id"] for unit in matched_units],
                    unit_names=[unit["name"] for unit in matched_units],
                    uncovered_item_names=uncovered_names,
                )
            )
        return assignments

    def _build_erp_constraint_context(self, dataset: SceneDataset, matrix: np.ndarray) -> ErpConstraintContext:
        item_index_by_id = {item.id: idx for idx, item in enumerate(dataset.items)}
        parent_map: dict[int, int] = {}
        hard_groups: dict[str, set[int]] = {}
        soft_groups: dict[str, set[int]] = {}

        for idx, item in enumerate(dataset.items):
            parent_permission_id = item.meta.get("parent_permission_id")
            if isinstance(parent_permission_id, str) and parent_permission_id in item_index_by_id:
                parent_map[idx] = item_index_by_id[parent_permission_id]

            conflict_code = item.meta.get("sod_conflict_code")
            conflict_level = item.meta.get("sod_conflict_level")
            if isinstance(conflict_code, str) and conflict_code:
                if conflict_level == "hard":
                    hard_groups.setdefault(conflict_code, set()).add(idx)
                elif conflict_level == "soft":
                    soft_groups.setdefault(conflict_code, set()).add(idx)

        return ErpConstraintContext(
            item_index_by_id=item_index_by_id,
            parent_map=parent_map,
            hard_groups=hard_groups,
            soft_groups=soft_groups,
            item_frequency=matrix.sum(axis=0),
        )

    def _apply_erp_constraints(
        self,
        item_indices: list[int],
        constraint_context: ErpConstraintContext | None,
    ) -> dict[str, object]:
        if constraint_context is None:
            return {"item_indices": item_indices}

        working = set(item_indices)
        added_parent_indices: list[int] = []
        hard_removed_indices: list[int] = []
        soft_conflict_groups: list[list[int]] = []

        queue = list(working)
        while queue:
            item_idx = queue.pop()
            parent_idx = constraint_context.parent_map.get(item_idx)
            if parent_idx is not None and parent_idx not in working:
                working.add(parent_idx)
                added_parent_indices.append(parent_idx)
                queue.append(parent_idx)

        for group_indices in constraint_context.hard_groups.values():
            selected = sorted(working & group_indices)
            if len(selected) > 1:
                selected.sort(
                    key=lambda idx: (
                        -int(constraint_context.item_frequency[idx]),
                        idx,
                    )
                )
                keep = selected[0]
                for idx in selected[1:]:
                    if idx in working:
                        working.remove(idx)
                        hard_removed_indices.append(idx)
                if keep not in working:
                    working.add(keep)

        for group_indices in constraint_context.soft_groups.values():
            selected = sorted(working & group_indices)
            if len(selected) > 1:
                soft_conflict_groups.append(selected)

        return {
            "item_indices": sorted(working),
            "added_parent_indices": sorted(set(added_parent_indices)),
            "hard_removed_indices": sorted(set(hard_removed_indices)),
            "soft_conflict_groups": soft_conflict_groups,
            "soft_penalty": len(soft_conflict_groups) * 0.5,
        }

    def _build_erp_constraint_report(
        self,
        dataset: SceneDataset,
        units: list[dict[str, object]],
    ) -> ErpConstraintReport:
        autofixes: list[ConstraintAutoFix] = []
        issues: list[ConstraintIssue] = []

        for record in dataset.meta.get("auto_added_parent_relations", []):
            child_name = next((item.name for item in dataset.items if item.id == record["permission_id"]), record["permission_id"])
            parent_name = next((item.name for item in dataset.items if item.id == record["parent_permission_id"]), record["parent_permission_id"])
            autofixes.append(
                ConstraintAutoFix(
                    target_name=record["entity_id"],
                    fix_type="input_parent_completion",
                    added_permission_names=[parent_name],
                    detail=f"用户拥有子权限 `{child_name}` 但缺少父菜单，系统已自动补齐 `{parent_name}`。",
                )
            )

        for unit in units:
            if unit.get("added_parent_names"):
                autofixes.append(
                    ConstraintAutoFix(
                        target_name=str(unit["name"]),
                        fix_type="role_parent_completion",
                        added_permission_names=list(unit["added_parent_names"]),
                        detail="推荐角色因按钮依赖自动补齐了父菜单权限。",
                    )
                )
            if unit.get("hard_removed_names"):
                issues.append(
                    ConstraintIssue(
                        scope="recommended",
                        severity="hard",
                        issue_type="hard_sod_removed",
                        target_name=str(unit["name"]),
                        permission_names=list(unit["hard_removed_names"]),
                        detail="这些权限因命中 hard SoD 冲突，已从推荐角色中移除。",
                    )
                )
            for group in unit.get("soft_conflict_names", []):
                issues.append(
                    ConstraintIssue(
                        scope="recommended",
                        severity="soft",
                        issue_type="soft_sod_warning",
                        target_name=str(unit["name"]),
                        permission_names=list(group),
                        detail="这些权限属于 soft SoD 冲突组，当前被保留但会降低推荐优先级。",
                    )
                )

        summary = [
            SummaryMetric(label="输入自动补齐数", value=str(sum(1 for item in autofixes if item.fix_type == "input_parent_completion")), hint="输入用户权限中因按钮缺少父菜单而自动补齐的次数。"),
            SummaryMetric(label="角色父菜单补齐数", value=str(sum(1 for item in autofixes if item.fix_type == "role_parent_completion")), hint="推荐角色中自动补齐父菜单的次数。"),
            SummaryMetric(label="硬冲突移除数", value=str(sum(1 for item in issues if item.issue_type == "hard_sod_removed")), hint="推荐角色中因 hard SoD 被移除的权限组数量。"),
            SummaryMetric(label="软冲突告警数", value=str(sum(1 for item in issues if item.issue_type == "soft_sod_warning")), hint="推荐角色中保留但需要关注的 soft SoD 告警数量。"),
        ]

        return ErpConstraintReport(
            autofixes=autofixes,
            issues=issues,
            summary=summary,
        )

    def _build_warnings(
        self,
        dataset: SceneDataset,
        assignments: list[Assignment],
        units: list[dict[str, object]],
    ) -> list[str]:
        warnings: list[str] = []
        item_term = "权限" if dataset.scene == "erp" else "字段"
        if len(units) > max(6, len(dataset.entities)):
            warnings.append("当前组合数量偏多，说明输入需求差异较大，后续可考虑引入 BMF/ILP 精修。")
        if any(assignment.uncovered_item_names for assignment in assignments):
            warnings.append(f"部分实体仍存在未完全吸收到共享组合中的{item_term}，建议增加补充组合或放宽约束。")
        if dataset.scene == "erp" and any(unit.get("soft_conflict_names") for unit in units):
            warnings.append("当前推荐角色中仍存在 soft SoD 告警组合，请在结果页中进一步审核。")
        if dataset.scene == "sql":
            warnings.extend(dataset.meta.get("import_warnings", []))
            warnings.extend(dataset.meta.get("lineage_merge_risk_warnings", []))
            warnings.extend(self._check_join_reachability(dataset, units))
            warnings.extend(self._check_expression_source_completeness(dataset, units))
            warnings.extend(self._check_granularity_conflicts(dataset, units))
        return warnings

    # ─── JOIN 可达性检查 ────────────────────────────────────────────────

    def _check_join_reachability(
        self,
        dataset: SceneDataset,
        units: list[dict[str, object]],
    ) -> list[str]:
        """对每个宽表候选，检查其来源物理表是否在全局 JOIN 图中互相可达。

        可达：从来源表集合中任意一张出发，能通过 JOIN 边遍历到其余所有表（连通分量为 1）。
        不可达：来源表形成多个孤立连通分量 → 报告哪些表孤立，字段来自哪里。
        """
        join_graph: dict[str, dict[str, list]] = dataset.meta.get("join_graph", {})
        if not join_graph:
            return []

        warnings: list[str] = []
        items = dataset.items
        item_lookup = {item.id: item for item in items}

        for unit in units:
            unit_name = str(unit["name"])
            item_ids: list[str] = list(unit["item_ids"])
            covered_sql_names: list[str] = list(unit.get("covered_entity_names", []))

            source_tables = self._collect_unit_physical_sources(item_ids, item_lookup)

            if len(source_tables) <= 1:
                continue

            components = self._find_connected_components(source_tables, join_graph)
            if len(components) > 1:
                isolated_tables = [t for comp in components[1:] for t in comp]
                isolated_fields = [
                    item_lookup[iid].name
                    for iid in item_ids
                    if item_lookup.get(iid) and self._item_touches_tables(item_lookup[iid], set(isolated_tables))
                ][:5]
                field_hint = "、".join(isolated_fields) if isolated_fields else "（字段未知）"
                warnings.append(
                    f"⚠ 宽表 `{unit_name}` 来源表 {sorted(source_tables)} 中，"
                    f"{isolated_tables} 在 JOIN 图中孤立，"
                    f"字段 {field_hint} 等无法通过已知 JOIN 条件与主表关联。"
                    f"涉及 SQL：{self._format_sql_name_hint(covered_sql_names)}。"
                    f"建议检查是否缺少 JOIN 条件或添加桥接表。"
                )

        return warnings

    def _check_expression_source_completeness(
        self,
        dataset: SceneDataset,
        units: list[dict[str, object]],
    ) -> list[str]:
        warnings: list[str] = []
        item_lookup = {item.id: item for item in dataset.items}
        entity_name_by_id = {entity.id: entity.name for entity in dataset.entities}
        entity_names_by_item_id = self._build_entity_names_by_item_id(dataset, entity_name_by_id)

        for unit in units:
            unit_name = str(unit["name"])
            item_ids: list[str] = list(unit["item_ids"])
            covered_sql_names: list[str] = list(unit.get("covered_entity_names", []))

            unresolved_item_ids = [
                item_id
                for item_id in item_ids
                if item_id in item_lookup and self._is_unresolved_derived_item(item_lookup[item_id])
            ]
            bare_column_item_ids = [
                item_id for item_id in unresolved_item_ids if self._get_item_resolution_kind(item_lookup[item_id]) == "bare_column"
            ]
            unresolved_expr_item_ids = [
                item_id for item_id in unresolved_item_ids if item_id not in bare_column_item_ids
            ]

            if not bare_column_item_ids and not unresolved_expr_item_ids:
                continue

            if bare_column_item_ids:
                bare_field_hint = "、".join(item_lookup[item_id].name for item_id in bare_column_item_ids[:5])
                bare_sql_names = sorted(
                    {
                        entity_name
                        for item_id in bare_column_item_ids
                        for entity_name in entity_names_by_item_id.get(item_id, [])
                        if entity_name
                    }
                )
                warnings.append(
                    f"⚠ 宽表 `{unit_name}` 中的字段 {bare_field_hint} 等使用了裸列写法，当前无法稳定确定底层来源表。"
                    f"涉及 SQL：{self._format_sql_name_hint(bare_sql_names or covered_sql_names)}。"
                    "建议改为显式表前缀写法，例如 `hl.nheadsummny`。"
                )

            if unresolved_expr_item_ids:
                unresolved_expr_fields = [item_lookup[item_id].name for item_id in unresolved_expr_item_ids[:5]]
                relevant_sql_names = sorted(
                    {
                        entity_name
                        for item_id in unresolved_expr_item_ids
                        for entity_name in entity_names_by_item_id.get(item_id, [])
                        if entity_name
                    }
                )
                field_hint = "、".join(unresolved_expr_fields)
                warnings.append(
                    f"⚠ 宽表 `{unit_name}` 中的表达式字段 {field_hint} 等未能解析出底层来源表。"
                    f"涉及 SQL：{self._format_sql_name_hint(relevant_sql_names or covered_sql_names)}。"
                    "这类字段不会参与 JOIN 孤立判断，建议补充显式别名或拆解子查询以完善血缘。"
                )

        return warnings

    def _collect_unit_physical_sources(
        self,
        item_ids: list[str],
        item_lookup: dict[str, object],
    ) -> set[str]:
        source_tables: set[str] = set()
        for item_id in item_ids:
            item = item_lookup.get(item_id)
            if not item:
                continue
            source_tables.update(self._get_item_physical_sources(item))
        return source_tables

    def _get_item_physical_sources(self, item: object) -> set[str]:
        direct_source = self._normalize_source_name(getattr(item, "group", None) or getattr(item, "source", None))
        if direct_source and direct_source not in {"unknown", "derived"}:
            return {direct_source}

        meta = getattr(item, "meta", {}) or {}
        meta_sources = {
            source_name
            for source_name in (
                self._normalize_source_name(part)
                for part in _split_item_meta_list(meta.get("source_tables", ""))
            )
            if source_name and source_name not in {"unknown", "derived"}
        }
        return meta_sources

    def _item_touches_tables(self, item: object, tables: set[str]) -> bool:
        return bool(self._get_item_physical_sources(item) & tables)

    def _is_unresolved_derived_item(self, item: object) -> bool:
        source_name = self._normalize_source_name(getattr(item, "group", None) or getattr(item, "source", None))
        return source_name == "derived" and not self._get_item_physical_sources(item)

    def _get_item_resolution_kind(self, item: object) -> str:
        meta = getattr(item, "meta", {}) or {}
        return self._normalize_source_name(meta.get("resolution_kind", ""))

    def _format_sql_name_hint(self, sql_names: list[str]) -> str:
        if not sql_names:
            return "（未知）"
        sql_hint = "、".join(sql_names[:5])
        if len(sql_names) > 5:
            sql_hint += f" 等 {len(sql_names)} 个文件"
        return sql_hint

    def _normalize_source_name(self, value: object) -> str:
        return str(value or "").strip().lower()

    def _build_entity_names_by_item_id(
        self,
        dataset: SceneDataset,
        entity_name_by_id: dict[str, str],
    ) -> dict[str, set[str]]:
        entity_names_by_item_id: dict[str, set[str]] = {}
        for relation in dataset.relations:
            entity_name = entity_name_by_id.get(relation.entity_id, "")
            if not entity_name:
                continue
            entity_names_by_item_id.setdefault(relation.item_id, set()).add(entity_name)
        return entity_names_by_item_id

    def _find_connected_components(
        self,
        nodes: set[str],
        graph: dict[str, dict[str, list]],
    ) -> list[list[str]]:
        """基于全局 JOIN 图找出来源表的连通分量，允许经过桥接表。"""
        remaining = set(nodes)
        components: list[list[str]] = []
        while remaining:
            start = min(remaining)
            reachable = self._find_reachable_tables(start, graph)
            component = sorted(node for node in remaining if node in reachable)
            components.append(component or [start])
            remaining -= set(component or [start])
        components.sort(key=lambda component: (-len(component), component))
        return components

    def _find_reachable_tables(
        self,
        start: str,
        graph: dict[str, dict[str, list]],
    ) -> set[str]:
        visited: set[str] = {start}
        queue: deque[str] = deque([start])
        while queue:
            current = queue.popleft()
            for neighbor in graph.get(current, {}):
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        return visited

    # ─── 粒度冲突检查 ───────────────────────────────────────────────────

    def _check_granularity_conflicts(
        self,
        dataset: SceneDataset,
        units: list[dict[str, object]],
    ) -> list[str]:
        """对每个宽表候选，检查其来源 SQL 的粒度键是否兼容。

        兼容定义：来源 SQL 的粒度键集合存在非空交集（共享维度）或其中一方是子集（可汇总）。
        冲突：所有来源 SQL 的粒度键集合两两不相交 → 说明字段来自不同统计粒度，合并后可能产生笛卡尔积或数据误读。
        """
        granularity_map: dict[str, list[str]] = dataset.meta.get("granularity_map", {})
        if not granularity_map:
            return []

        warnings: list[str] = []
        items = dataset.items
        item_lookup = {item.id: item for item in items}
        entities = {e.id: e.name for e in dataset.entities}

        for unit in units:
            unit_name = str(unit["name"])
            covered_entity_ids: list[str] = list(unit["covered_entity_ids"])

            # 找到该宽表覆盖的 SQL 文件名（entity.name）
            covered_sql_names = [entities.get(eid, "") for eid in covered_entity_ids]

            # 获取每个 SQL 的粒度键
            unit_granularities: dict[str, list[str]] = {}
            for sql_name in covered_sql_names:
                if sql_name in granularity_map:
                    unit_granularities[sql_name] = granularity_map[sql_name]

            if len(unit_granularities) < 2:
                continue  # 少于2个有粒度信息的 SQL，无法比较

            # 检查所有 SQL 粒度键是否有交集
            sets = [set(keys) for keys in unit_granularities.values()]
            conflict_pairs: list[str] = []
            sql_names = list(unit_granularities.keys())
            for i, j in combinations(range(len(sql_names)), 2):
                if not (sets[i] & sets[j]):  # 交集为空 → 粒度不兼容
                    conflict_pairs.append(
                        f"{sql_names[i]}({', '.join(sorted(sets[i]))}) vs "
                        f"{sql_names[j]}({', '.join(sorted(sets[j]))})"
                    )

            if conflict_pairs:
                warnings.append(
                    f"⚠ 宽表 `{unit_name}` 合并了来自不同粒度的 SQL：{'; '.join(conflict_pairs[:3])}。"
                    f"建议拆分宽表或统一到相同的 GROUP BY 粒度后再合并。"
                )

        return warnings

    def _build_insights(
        self,
        dataset: SceneDataset,
        units: list[dict[str, object]],
        item_lookup,
        unit_type: str,
        sql_unit_groups: list[dict[str, object]] | None = None,
    ) -> list[str]:
        if not units:
            return ["当前数据为空，无法形成有效的组合建议。"]

        if dataset.scene == "sql" and sql_unit_groups:
            return self._build_sql_hierarchy_insights(sql_unit_groups)

        largest_unit = max(units, key=lambda unit: len(unit["item_ids"]))
        most_reused = max(units, key=lambda unit: len(unit["covered_entity_ids"]))
        sample_sources = [item_lookup[item_id].source for item_id in largest_unit["item_ids"] if item_lookup[item_id].source]
        item_term = "权限" if dataset.scene == "erp" else "字段"
        insights = [
            f"推荐优先落地 `{most_reused['name']}`，它是复用度最高的{unit_type}。",
            f"`{largest_unit['name']}` 包含最多的{item_term}，适合作为核心{unit_type}模板。",
        ]
        if dataset.scene == "sql" and sample_sources:
            insights.append(f"字段来源主要集中在 {', '.join(sorted(set(sample_sources)))}，说明可先围绕该主题域建表。")
        return insights

    def _build_sql_hierarchy_insights(self, sql_unit_groups: list[dict[str, object]]) -> list[str]:
        if not sql_unit_groups:
            return ["当前数据为空，无法形成有效的组合建议。"]

        base_groups = [group for group in sql_unit_groups if group["base_unit"].get("unit_level") == "base"]
        standalone_groups = [group for group in sql_unit_groups if group["base_unit"].get("unit_level") == "standalone"]

        if not base_groups:
            fallback_group = max(
                sql_unit_groups,
                key=lambda group: (
                    len(group["base_unit"]["covered_entity_ids"]),
                    group["base_unit"]["score"],
                    len(group["base_unit"]["item_ids"]),
                ),
            )
            fallback_unit = fallback_group["base_unit"]
            sources = [source for source in fallback_unit.get("sources", []) if source not in {"unknown", "derived"}]
            insights = [
                f"推荐优先落地 `{fallback_unit['name']}`，它是当前复用度最高的候选宽表。",
                f"`{fallback_unit['name']}` 当前承载的字段最完整，可作为首批主题宽表模板。",
            ]
            if sources:
                insights.append(f"高频来源主要集中在 {', '.join(sources[:6])}，建议先围绕该主题域建表。")
            return insights

        primary_group = max(
            base_groups,
            key=lambda group: (
                len(group["base_unit"]["covered_entity_ids"]) + len(group["units"]),
                len(group["units"]),
                group["base_unit"]["score"],
            ),
        )
        primary_base = primary_group["base_unit"]
        primary_extensions = primary_group["units"]
        primary_sources = [
            source
            for source in primary_base.get("sources", [])
            if source and source not in {"unknown", "derived"}
        ]

        insights = [
            f"推荐优先落地 `{primary_base['name']}`，它是复用度最高的公共底座宽表。",
        ]

        if primary_extensions:
            extension_labels = []
            for unit in primary_extensions[:3]:
                extra_sources = unit.get("extra_source_tables", [])
                if extra_sources:
                    extension_labels.append("+" + "+".join(extra_sources))
                elif unit.get("extra_item_names"):
                    extension_labels.append("字段扩展")
            if extension_labels:
                insights.append(
                    f"建议在 `{primary_base['name']}` 之上继续挂接 {', '.join(extension_labels)} 等扩展宽表，避免把不同主题字段全部压进同一张大宽表。"
                )
            else:
                insights.append(
                    f"`{primary_base['name']}` 下已经形成多个主题扩展，建议按基础宽表 + 扩展宽表的层次结构落地。"
                )
        else:
            insights.append(
                f"`{primary_base['name']}` 当前已经可以独立承载主要复用字段，适合作为首批基础宽表模板。"
            )

        if primary_sources:
            insights.append(
                f"高频核心来源主要集中在 {', '.join(primary_sources[:6])}，建议优先围绕这组基础来源建设公共底座。"
            )

        if standalone_groups:
            standalone_count = len(standalone_groups)
            standalone_examples = [group["base_unit"]["name"] for group in standalone_groups[:2]]
            insights.append(
                f"另有 {standalone_count} 个独立专题宽表暂未形成稳定公共底座，例如 `{standalone_examples[0]}`"
                + (f"、`{standalone_examples[1]}`" if len(standalone_examples) > 1 else "")
                + "，建议按专题单独落地。"
            )

        return insights[:4]
