from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


SceneType = Literal["erp", "sql"]
UnitLevel = Literal["base", "extension", "standalone"]


class Entity(BaseModel):
    id: str
    name: str
    meta: dict[str, Any] = Field(default_factory=dict)


class Item(BaseModel):
    id: str
    name: str
    group: str | None = None
    item_type: str | None = None
    source: str | None = None
    meta: dict[str, Any] = Field(default_factory=dict)


class Relation(BaseModel):
    entity_id: str
    item_id: str


class ConstraintConfig(BaseModel):
    max_items_per_unit: int = 10
    max_units_per_entity: int = 3
    similarity_threshold: float = 0.6
    min_shared_items: int = 2


class SceneDataset(BaseModel):
    scene: SceneType
    entities: list[Entity]
    items: list[Item]
    relations: list[Relation]
    constraints: ConstraintConfig = Field(default_factory=ConstraintConfig)
    meta: dict[str, Any] = Field(default_factory=dict)


class SolveRequest(BaseModel):
    scene: SceneType
    dataset: SceneDataset | None = None


class ImportPreviewResponse(BaseModel):
    scene: SceneType
    entity_count: int
    item_count: int
    relation_count: int
    sample_entities: list[str]
    sample_items: list[str]
    detected_columns: dict[str, str]
    warnings: list[str]


class SceneInfo(BaseModel):
    key: SceneType
    name: str
    description: str
    goal: str
    default_unit_name: str


class SummaryMetric(BaseModel):
    label: str
    value: str
    hint: str | None = None


class SolutionUnit(BaseModel):
    id: str
    name: str
    unit_type: str
    item_ids: list[str]
    item_names: list[str]
    item_display_names: list[str] = Field(default_factory=list)
    item_exprs: list[str] = Field(default_factory=list)  # 对应 item_names 的原始表达式，无则为空字符串
    covered_entity_ids: list[str]
    covered_entity_names: list[str]
    rationale: str
    score: float
    sources: list[str] = Field(default_factory=list)
    unit_level: UnitLevel = "standalone"
    base_unit_id: str | None = None
    extra_source_tables: list[str] = Field(default_factory=list)
    extra_item_names: list[str] = Field(default_factory=list)


class SqlUnitGroup(BaseModel):
    key: str
    group_name: str
    base_unit: SolutionUnit
    units: list[SolutionUnit] = Field(default_factory=list)


class Assignment(BaseModel):
    entity_id: str
    entity_name: str
    unit_ids: list[str]
    unit_names: list[str]
    uncovered_item_names: list[str] = Field(default_factory=list)


class ConstraintIssue(BaseModel):
    scope: Literal["input", "recommended", "current"]
    severity: Literal["hard", "soft", "warning"]
    issue_type: str
    target_name: str
    permission_names: list[str] = Field(default_factory=list)
    detail: str


class ConstraintAutoFix(BaseModel):
    target_name: str
    fix_type: str
    added_permission_names: list[str] = Field(default_factory=list)
    detail: str


class ErpConstraintReport(BaseModel):
    autofixes: list[ConstraintAutoFix]
    issues: list[ConstraintIssue]
    summary: list[SummaryMetric]


class CurrentRoleSummary(BaseModel):
    role_id: str
    role_name: str
    permission_names: list[str]
    permission_count: int
    user_names: list[str] = Field(default_factory=list)
    user_count: int = 0


class RoleComparison(BaseModel):
    recommended_unit_name: str
    current_role_name: str | None = None
    overlap_rate: float
    matched_permissions: list[str]
    recommended_only_permissions: list[str]
    current_only_permissions: list[str]
    action: str


class RoleCombinationMapping(BaseModel):
    recommended_unit_name: str
    current_role_names: list[str]
    coverage_rate: float
    matched_permissions: list[str]
    missing_permissions: list[str]
    extra_permissions: list[str]
    action: str


class CurrentRoleMergeSuggestion(BaseModel):
    role_names: list[str]
    overlap_rate: float
    shared_permissions: list[str]
    action: str


class RoleDiffReport(BaseModel):
    current_roles: list[CurrentRoleSummary]
    comparisons: list[RoleComparison]
    combination_mappings: list[RoleCombinationMapping]
    merge_suggestions: list[CurrentRoleMergeSuggestion]
    current_role_constraint_issues: list[ConstraintIssue]
    current_role_actions: list[str]
    current_roles_to_retire: list[str]
    summary: list[SummaryMetric]


class SolveResponse(BaseModel):
    scene: SceneType
    title: str
    summary: list[SummaryMetric]
    units: list[SolutionUnit]
    assignments: list[Assignment]
    warnings: list[str]
    insights: list[str]
    sql_unit_groups: list[SqlUnitGroup] | None = None
    erp_role_diff: RoleDiffReport | None = None
    erp_constraint_report: ErpConstraintReport | None = None
    graph: dict[str, Any] | None = None  # { nodes: [...], edges: [...] }
