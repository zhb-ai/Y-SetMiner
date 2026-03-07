from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

import numpy as np

from app.schemas.solve import (
    Assignment,
    ConstraintAutoFix,
    ConstraintIssue,
    ErpConstraintReport,
    SceneDataset,
    SolveResponse,
    SolutionUnit,
    SummaryMetric,
)
from app.services.matrix.builder import build_matrix
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

        pattern_groups = self._group_exact_patterns(matrix)
        selected_units = self._select_units(dataset, matrix, pattern_groups, constraint_context=constraint_context)
        assignments = self._build_assignments(bundle, matrix, selected_units)

        n_entities = len(bundle.entity_ids)
        total_required = int(matrix.sum())
        total_granted = sum(
            len(unit["item_ids"]) * len(unit["covered_entity_ids"]) for unit in selected_units
        )
        covered = sum(
            len(unit["item_ids"]) * len(unit["covered_entity_ids"]) for unit in selected_units
        )
        redundancy = max(total_granted - total_required, 0)

        summary = [
            SummaryMetric(
                label="推荐组合数",
                value=str(len(selected_units)),
                hint="ERP 对应角色数，SQL 对应宽表数。",
            ),
            SummaryMetric(
                label="覆盖实体数",
                value=str(n_entities),
                hint="本次参与分析的用户、SQL 或报表数量。",
            ),
            SummaryMetric(
                label="需求覆盖率",
                value="100%",
                hint="当前 MVP 以完全覆盖输入需求为目标。",
            ),
            SummaryMetric(
                label="冗余授权/字段数",
                value=str(redundancy),
                hint="由共享组合带来的附加权限或字段数量。",
            ),
        ]

        scene_title = "ERP 推荐角色方案" if dataset.scene == "erp" else "SQL 推荐宽表方案"
        unit_type = "角色" if dataset.scene == "erp" else "宽表"
        warnings = self._build_warnings(dataset, assignments, selected_units)
        insights = self._build_insights(dataset, selected_units, item_lookup, unit_type)
        constraint_report = self._build_erp_constraint_report(dataset, selected_units) if dataset.scene == "erp" else None

        response = SolveResponse(
            scene=dataset.scene,
            title=scene_title,
            summary=summary,
            units=[
                SolutionUnit(
                    id=unit["id"],
                    name=unit["name"],
                    unit_type=unit_type,
                    item_ids=unit["item_ids"],
                    item_names=unit["item_names"],
                    covered_entity_ids=unit["covered_entity_ids"],
                    covered_entity_names=unit["covered_entity_names"],
                    rationale=unit["rationale"],
                    score=unit["score"],
                    sources=unit["sources"],
                )
                for unit in selected_units
            ],
            assignments=assignments,
            warnings=warnings,
            insights=insights,
            erp_role_diff=None,
            erp_constraint_report=constraint_report,
        )

        if dataset.scene == "erp":
            response.erp_role_diff = self.erp_role_diff_service.build_diff_report(response, current_role_state)

        return response

    def _group_exact_patterns(self, matrix: np.ndarray) -> dict[tuple[int, ...], list[int]]:
        groups: dict[tuple[int, ...], list[int]] = {}
        for row_index, row in enumerate(matrix):
            key = tuple(np.where(row == 1)[0].tolist())
            groups.setdefault(key, []).append(row_index)
        return groups

    def _select_units(
        self,
        dataset: SceneDataset,
        matrix: np.ndarray,
        pattern_groups: dict[tuple[int, ...], list[int]],
        constraint_context: ErpConstraintContext | None = None,
    ) -> list[dict[str, object]]:
        candidate_patterns = sorted(
            [pattern for pattern in pattern_groups if pattern],
            key=lambda pattern: (len(pattern_groups[pattern]) * len(pattern), len(pattern)),
            reverse=True,
        )

        selected_units: list[dict[str, object]] = []
        uncovered = matrix.copy()

        for index, pattern in enumerate(candidate_patterns, start=1):
            item_indices = list(pattern)[: dataset.constraints.max_items_per_unit]
            entity_indices = [
                row_idx for row_idx, row in enumerate(matrix) if all(row[item_idx] == 1 for item_idx in item_indices)
            ]
            if not entity_indices:
                continue

            constraint_meta = self._apply_erp_constraints(item_indices, constraint_context) if constraint_context else {}
            item_indices = constraint_meta.get("item_indices", item_indices)
            gain = int(uncovered[np.ix_(entity_indices, item_indices)].sum())
            if gain == 0:
                continue

            selected_units.append(
                {
                    "id": f"unit-{index}",
                    "item_indices": item_indices,
                    "entity_indices": entity_indices,
                    "score": round(max((gain / max(len(item_indices), 1)) - float(constraint_meta.get("soft_penalty", 0)), 0), 2),
                    **constraint_meta,
                }
            )
            uncovered[np.ix_(entity_indices, item_indices)] = 0

        for row_index, row in enumerate(uncovered):
            remaining_items = np.where(row == 1)[0].tolist()
            if remaining_items:
                constraint_meta = self._apply_erp_constraints(remaining_items[: dataset.constraints.max_items_per_unit], constraint_context) if constraint_context else {}
                selected_units.append(
                    {
                        "id": f"unit-tail-{row_index + 1}",
                        "item_indices": constraint_meta.get("item_indices", remaining_items[: dataset.constraints.max_items_per_unit]),
                        "entity_indices": [row_index],
                        "score": round(max(len(remaining_items) - float(constraint_meta.get("soft_penalty", 0)), 0), 2),
                        **constraint_meta,
                    }
                )

        return self._decorate_units(dataset, matrix, selected_units)

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

        for idx, unit in enumerate(units, start=1):
            item_indices = unit["item_indices"]
            entity_indices = unit["entity_indices"]
            unit_items = [items[item_idx] for item_idx in item_indices]
            groups = Counter(item.group or "通用" for item in unit_items)
            top_group = groups.most_common(1)[0][0]
            top_names = "、".join(item.name for item in unit_items[:2])
            name = f"{top_group}{label_prefix}{idx}"
            sources = sorted({item.source for item in unit_items if item.source})
            rationale = f"覆盖 {len(entity_indices)} 个实体，核心字段/权限为 {top_names}。"
            decorated.append(
                {
                    "id": unit["id"],
                    "name": name,
                    "entity_indices": entity_indices,
                    "item_indices": item_indices,
                    "item_ids": [items[item_idx].id for item_idx in item_indices],
                    "item_names": [items[item_idx].name for item_idx in item_indices],
                    "covered_entity_ids": [entities[e_idx].id for e_idx in entity_indices],
                    "covered_entity_names": [entities[e_idx].name for e_idx in entity_indices],
                    "score": unit["score"],
                    "rationale": rationale,
                    "sources": sources,
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
        if len(units) > max(6, len(dataset.entities)):
            warnings.append("当前组合数量偏多，说明输入需求差异较大，后续可考虑引入 BMF/ILP 精修。")
        if any(assignment.uncovered_item_names for assignment in assignments):
            warnings.append("部分实体仍存在未完全吸收到共享组合中的字段/权限，建议增加补充组合或放宽约束。")
        if dataset.scene == "erp" and any(unit.get("soft_conflict_names") for unit in units):
            warnings.append("当前推荐角色中仍存在 soft SoD 告警组合，请在结果页中进一步审核。")
        if dataset.scene == "sql":
            warnings.append("SQL 场景当前仅基于字段集合做归并，JOIN 可达和粒度校验建议在下一阶段补强。")
        return warnings

    def _build_insights(
        self,
        dataset: SceneDataset,
        units: list[dict[str, object]],
        item_lookup,
        unit_type: str,
    ) -> list[str]:
        if not units:
            return ["当前数据为空，无法形成有效的组合建议。"]

        largest_unit = max(units, key=lambda unit: len(unit["item_ids"]))
        most_reused = max(units, key=lambda unit: len(unit["covered_entity_ids"]))
        sample_sources = [item_lookup[item_id].source for item_id in largest_unit["item_ids"] if item_lookup[item_id].source]
        insights = [
            f"推荐优先落地 `{most_reused['name']}`，它是复用度最高的{unit_type}。",
            f"`{largest_unit['name']}` 包含最多的字段/权限，适合作为核心{unit_type}模板。",
        ]
        if dataset.scene == "sql" and sample_sources:
            insights.append(f"字段来源主要集中在 {', '.join(sorted(set(sample_sources)))}，说明可先围绕该主题域建表。")
        return insights
