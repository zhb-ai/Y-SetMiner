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
    SolveResponse,
    SolutionUnit,
    SummaryMetric,
)
from app.services.graph.graph_builder import build_erp_graph, build_sql_graph
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

        selected_units = self._select_units(dataset, matrix, {}, constraint_context=constraint_context)
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

        item_term = "权限" if dataset.scene == "erp" else "字段"

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
                label=f"冗余{item_term}数",
                value=str(redundancy),
                hint=f"由共享组合带来的附加{item_term}数量。",
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
                    item_display_names=unit["item_display_names"],
                    item_exprs=unit["item_exprs"],
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
        item_term = "权限" if dataset.scene == "erp" else "字段"

        for idx, unit in enumerate(units, start=1):
            item_indices = unit["item_indices"]
            entity_indices = unit["entity_indices"]
            unit_items = [items[item_idx] for item_idx in item_indices]
            groups = Counter(item.group or "通用" for item in unit_items)
            top_group = groups.most_common(1)[0][0]
            top_names = "、".join(item.name for item in unit_items[:2])
            name = f"{top_group}{label_prefix}{idx}"
            sources = sorted({item.source for item in unit_items if item.source})
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
        item_term = "权限" if dataset.scene == "erp" else "字段"
        if len(units) > max(6, len(dataset.entities)):
            warnings.append("当前组合数量偏多，说明输入需求差异较大，后续可考虑引入 BMF/ILP 精修。")
        if any(assignment.uncovered_item_names for assignment in assignments):
            warnings.append(f"部分实体仍存在未完全吸收到共享组合中的{item_term}，建议增加补充组合或放宽约束。")
        if dataset.scene == "erp" and any(unit.get("soft_conflict_names") for unit in units):
            warnings.append("当前推荐角色中仍存在 soft SoD 告警组合，请在结果页中进一步审核。")
        if dataset.scene == "sql":
            warnings.extend(self._check_join_reachability(dataset, units))
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

            # 收集该宽表中所有字段的来源物理表
            source_tables: set[str] = set()
            for item_id in item_ids:
                item = item_lookup.get(item_id)
                if item and item.group and item.group != "unknown":
                    source_tables.add(item.group)

            if len(source_tables) <= 1:
                continue  # 单表宽表，无需检查

            # BFS 连通性检查
            components = self._find_connected_components(source_tables, join_graph)
            if len(components) > 1:
                isolated_tables = [t for comp in components[1:] for t in comp]
                # 找到孤立表对应的字段
                isolated_fields = [
                    item_lookup[iid].name
                    for iid in item_ids
                    if item_lookup.get(iid) and item_lookup[iid].group in isolated_tables
                ][:5]
                field_hint = "、".join(isolated_fields) if isolated_fields else "（字段未知）"
                warnings.append(
                    f"⚠ 宽表 `{unit_name}` 来源表 {sorted(source_tables)} 中，"
                    f"{isolated_tables} 在 JOIN 图中孤立，"
                    f"字段 {field_hint} 等无法通过已知 JOIN 条件与主表关联。"
                    f"建议检查是否缺少 JOIN 条件或添加桥接表。"
                )

        return warnings

    def _find_connected_components(
        self,
        nodes: set[str],
        graph: dict[str, dict[str, list]],
    ) -> list[list[str]]:
        """BFS 找出节点集合在图中的所有连通分量。"""
        visited: set[str] = set()
        components: list[list[str]] = []
        node_list = sorted(nodes)
        for start in node_list:
            if start in visited:
                continue
            component: list[str] = []
            queue: deque[str] = deque([start])
            visited.add(start)
            while queue:
                cur = queue.popleft()
                component.append(cur)
                for neighbor in graph.get(cur, {}):
                    if neighbor in nodes and neighbor not in visited:
                        visited.add(neighbor)
                        queue.append(neighbor)
            components.append(component)
        return components

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
    ) -> list[str]:
        if not units:
            return ["当前数据为空，无法形成有效的组合建议。"]

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
