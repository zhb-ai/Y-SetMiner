from __future__ import annotations

from itertools import combinations

from app.schemas.solve import (
    ConstraintIssue,
    CurrentRoleMergeSuggestion,
    CurrentRoleSummary,
    RoleCombinationMapping,
    RoleComparison,
    RoleDiffReport,
    SolveResponse,
    SummaryMetric,
)
from app.services.scenes.erp_importer import CurrentRoleState


class ErpRoleDiffService:
    def build_diff_report(
        self,
        result: SolveResponse,
        current_state: CurrentRoleState | None,
    ) -> RoleDiffReport | None:
        if current_state is None:
            return None

        current_roles = []
        comparisons = []
        combination_mappings = []
        merge_suggestions = []
        current_role_constraint_issues: list[ConstraintIssue] = []
        matched_current_role_ids: set[str] = set()
        combo_matched_role_ids: set[str] = set()

        for role in current_state.roles:
            permission_names = sorted({str(item["permission_name"]) for item in role["permissions"]})
            current_roles.append(
                CurrentRoleSummary(
                    role_id=str(role["role_id"]),
                    role_name=str(role["role_name"]),
                    permission_names=permission_names,
                    permission_count=len(permission_names),
                    user_names=[str(name) for name in role.get("user_names", [])],
                    user_count=int(role.get("user_count", 0)),
                )
            )
            current_role_constraint_issues.extend(self._build_current_role_constraint_issues(role))

        for unit in result.units:
            recommended_perm_set = set(unit.item_names)
            best_match = None
            best_overlap = 0.0

            for role in current_roles:
                current_perm_set = set(role.permission_names)
                overlap = self._jaccard(recommended_perm_set, current_perm_set)
                if overlap > best_overlap:
                    best_overlap = overlap
                    best_match = role

            if best_match is not None and best_overlap > 0:
                matched_current_role_ids.add(best_match.role_id)
                current_perm_set = set(best_match.permission_names)
                action = self._decide_action(best_overlap, recommended_perm_set, current_perm_set)
                comparisons.append(
                    RoleComparison(
                        recommended_unit_name=unit.name,
                        current_role_name=best_match.role_name,
                        overlap_rate=round(best_overlap, 3),
                        matched_permissions=sorted(recommended_perm_set & current_perm_set),
                        recommended_only_permissions=sorted(recommended_perm_set - current_perm_set),
                        current_only_permissions=sorted(current_perm_set - recommended_perm_set),
                        action=action,
                    )
                )
            else:
                comparisons.append(
                    RoleComparison(
                        recommended_unit_name=unit.name,
                        current_role_name=None,
                        overlap_rate=0.0,
                        matched_permissions=[],
                        recommended_only_permissions=sorted(recommended_perm_set),
                        current_only_permissions=[],
                        action="建议新增该推荐角色，现状中没有相近角色。",
                    )
                )

            best_combo = self._find_best_combination(recommended_perm_set, current_roles)
            if best_combo is not None:
                combo_roles, coverage_rate, matched_permissions, missing_permissions, extra_permissions = best_combo
                combo_matched_role_ids.update(role.role_id for role in combo_roles)
                combination_mappings.append(
                    RoleCombinationMapping(
                        recommended_unit_name=unit.name,
                        current_role_names=[role.role_name for role in combo_roles],
                        coverage_rate=round(coverage_rate, 3),
                        matched_permissions=matched_permissions,
                        missing_permissions=missing_permissions,
                        extra_permissions=extra_permissions,
                        action=self._decide_combo_action(coverage_rate, missing_permissions, extra_permissions),
                    )
                )

        for left_role, right_role in combinations(current_roles, 2):
            left_set = set(left_role.permission_names)
            right_set = set(right_role.permission_names)
            overlap = self._jaccard(left_set, right_set)
            shared_permissions = sorted(left_set & right_set)
            if overlap >= 0.6 and shared_permissions:
                merge_suggestions.append(
                    CurrentRoleMergeSuggestion(
                        role_names=[left_role.role_name, right_role.role_name],
                        overlap_rate=round(overlap, 3),
                        shared_permissions=shared_permissions,
                        action="两个现状角色权限高度重叠，建议评估是否合并或抽取公共基础角色。",
                    )
                )

        current_role_actions = []
        current_roles_to_retire = []
        for role in current_roles:
            if role.role_id not in matched_current_role_ids and role.role_id not in combo_matched_role_ids:
                current_roles_to_retire.append(role.role_name)
                current_role_actions.append(f"现状角色 `{role.role_name}` 与推荐方案重叠较低，建议评估是否保留、拆分或下线。")

        summary = [
            SummaryMetric(label="现状角色数", value=str(len(current_roles)), hint="从现状角色文件中识别到的角色数量。"),
            SummaryMetric(label="推荐角色数", value=str(len(result.units)), hint="本次算法推荐的新角色数量。"),
            SummaryMetric(
                label="可直接映射角色数",
                value=str(sum(1 for item in comparisons if item.current_role_name)),
                hint="存在显著相似现状角色的推荐角色数量。",
            ),
            SummaryMetric(
                label="建议新增角色数",
                value=str(sum(1 for item in comparisons if item.current_role_name is None)),
                hint="现状角色体系中找不到高重叠映射的推荐角色数量。",
            ),
            SummaryMetric(
                label="可组合映射角色数",
                value=str(sum(1 for item in combination_mappings if item.coverage_rate >= 0.8)),
                hint="可以通过多个现状角色组合覆盖的推荐角色数量。",
            ),
            SummaryMetric(
                label="建议下线现状角色数",
                value=str(len(current_roles_to_retire)),
                hint="与推荐方案重叠很低的现状角色数量。",
            ),
        ]

        return RoleDiffReport(
            current_roles=current_roles,
            comparisons=comparisons,
            combination_mappings=combination_mappings,
            merge_suggestions=merge_suggestions,
            current_role_constraint_issues=current_role_constraint_issues,
            current_role_actions=current_role_actions,
            current_roles_to_retire=current_roles_to_retire,
            summary=summary,
        )

    def _jaccard(self, left: set[str], right: set[str]) -> float:
        if not left and not right:
            return 1.0
        union = left | right
        if not union:
            return 0.0
        return len(left & right) / len(union)

    def _decide_action(self, overlap: float, recommended_perm_set: set[str], current_perm_set: set[str]) -> str:
        if overlap >= 0.85:
            return "建议直接映射为现状角色的优化版本，差异较小。"
        if overlap >= 0.5:
            if len(recommended_perm_set) > len(current_perm_set):
                return "建议在现状角色基础上补充权限后替换。"
            return "建议从现状角色中裁剪冗余权限后替换。"
        return "现状角色与推荐角色只有部分重合，建议拆分后重组。"

    def _find_best_combination(
        self,
        recommended_perm_set: set[str],
        current_roles: list[CurrentRoleSummary],
    ) -> tuple[list[CurrentRoleSummary], float, list[str], list[str], list[str]] | None:
        best_result = None
        best_score = -1.0

        max_group_size = min(2, len(current_roles))
        for group_size in range(2, max_group_size + 1):
            for role_group in combinations(current_roles, group_size):
                combined_permissions = set()
                for role in role_group:
                    combined_permissions |= set(role.permission_names)

                matched_permissions = sorted(recommended_perm_set & combined_permissions)
                missing_permissions = sorted(recommended_perm_set - combined_permissions)
                extra_permissions = sorted(combined_permissions - recommended_perm_set)
                coverage_rate = len(matched_permissions) / max(len(recommended_perm_set), 1)
                score = coverage_rate - len(extra_permissions) * 0.05

                if score > best_score and coverage_rate > 0:
                    best_score = score
                    best_result = (
                        list(role_group),
                        coverage_rate,
                        matched_permissions,
                        missing_permissions,
                        extra_permissions,
                    )

        return best_result

    def _decide_combo_action(
        self,
        coverage_rate: float,
        missing_permissions: list[str],
        extra_permissions: list[str],
    ) -> str:
        if coverage_rate >= 0.95 and not extra_permissions:
            return "推荐角色基本可以由现状角色组合直接替代，建议以组合映射过渡。"
        if coverage_rate >= 0.8:
            return "推荐角色可以由多个现状角色组合近似覆盖，建议合并并补齐少量差异权限。"
        if missing_permissions:
            return "现状角色组合仍无法完整覆盖推荐角色，建议新建角色或重构现状角色。"
        return "建议结合业务规则进一步人工确认该组合映射。"

    def _build_current_role_constraint_issues(self, role: dict[str, object]) -> list[ConstraintIssue]:
        issues: list[ConstraintIssue] = []
        permissions = role["permissions"]
        permission_names_by_id = {
            str(permission["permission_id"]): str(permission["permission_name"])
            for permission in permissions
        }
        role_name = str(role["role_name"])

        for permission in permissions:
            parent_permission_id = permission.get("parent_permission_id")
            permission_name = str(permission["permission_name"])
            if parent_permission_id and str(parent_permission_id) not in permission_names_by_id:
                issues.append(
                    ConstraintIssue(
                        scope="current",
                        severity="warning",
                        issue_type="missing_parent_permission",
                        target_name=role_name,
                        permission_names=[permission_name, str(parent_permission_id)],
                        detail=f"现状角色中的 `{permission_name}` 缺少父菜单 `{parent_permission_id}`。",
                    )
                )

        hard_groups: dict[str, list[str]] = {}
        soft_groups: dict[str, list[str]] = {}
        for permission in permissions:
            conflict_code = permission.get("sod_conflict_code")
            conflict_level = permission.get("sod_conflict_level")
            permission_name = str(permission["permission_name"])
            if conflict_code and conflict_level == "hard":
                hard_groups.setdefault(str(conflict_code), []).append(permission_name)
            elif conflict_code and conflict_level == "soft":
                soft_groups.setdefault(str(conflict_code), []).append(permission_name)

        for conflict_permissions in hard_groups.values():
            if len(conflict_permissions) > 1:
                issues.append(
                    ConstraintIssue(
                        scope="current",
                        severity="hard",
                        issue_type="hard_sod_conflict",
                        target_name=role_name,
                        permission_names=sorted(conflict_permissions),
                        detail="现状角色命中了 hard SoD 冲突，不建议保留该权限组合。",
                    )
                )

        for conflict_permissions in soft_groups.values():
            if len(conflict_permissions) > 1:
                issues.append(
                    ConstraintIssue(
                        scope="current",
                        severity="soft",
                        issue_type="soft_sod_conflict",
                        target_name=role_name,
                        permission_names=sorted(conflict_permissions),
                        detail="现状角色命中了 soft SoD 冲突，建议人工评审是否拆分。",
                    )
                )

        return issues
