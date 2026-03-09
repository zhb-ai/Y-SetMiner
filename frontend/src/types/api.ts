export type SceneKey = 'erp' | 'sql'

export interface SceneInfo {
  key: SceneKey
  name: string
  description: string
  goal: string
  default_unit_name: string
}

export interface SummaryMetric {
  label: string
  value: string
  hint?: string | null
}

export interface ImportPreviewResponse {
  scene: SceneKey
  entity_count: number
  item_count: number
  relation_count: number
  sample_entities: string[]
  sample_items: string[]
  detected_columns: Record<string, string>
  warnings: string[]
  preprocess_summary?: {
    detected_objects: Array<{
      name: string
      object_type: string
      source_file: string
    }>
    expanded_documents: Array<{
      file_name: string
      expanded_objects: string[]
      max_depth: number
      is_definition_file: boolean
      definition_object_name?: string | null
      definition_object_type?: string | null
    }>
    cycles: string[][]
  } | null
}

export interface SolutionUnit {
  id: string
  name: string
  unit_type: string
  item_ids: string[]
  item_names: string[]
  item_display_names: string[]
  item_exprs: string[]
  item_sources: string[]
  item_source_details: string[]
  covered_entity_ids: string[]
  covered_entity_names: string[]
  rationale: string
  score: number
  sources: string[]
  unit_level: 'base' | 'extension' | 'standalone'
  base_unit_id?: string | null
  extra_source_tables: string[]
  extra_item_names: string[]
  extra_item_sources: string[]
  extra_item_source_details: string[]
  suggested_item_names: string[]
  suggested_item_sources: string[]
  suggested_item_source_details: string[]
  suggested_item_hits: number[]
  filter_item_names: string[]
  filter_item_sources: string[]
  filter_item_source_details: string[]
  filter_item_hits: number[]
  filter_item_support_count?: number | null
  support_unit_count?: number | null
  base_field_min_hits?: number | null
  suggested_field_min_hits?: number | null
}

export interface SqlUnitGroup {
  key: string
  group_name: string
  base_unit: SolutionUnit
  units: SolutionUnit[]
}

export interface Assignment {
  entity_id: string
  entity_name: string
  unit_ids: string[]
  unit_names: string[]
  uncovered_item_names: string[]
}

export interface ConstraintIssue {
  scope: 'input' | 'recommended' | 'current'
  severity: 'hard' | 'soft' | 'warning'
  issue_type: string
  target_name: string
  permission_names: string[]
  detail: string
}

export interface ConstraintAutoFix {
  target_name: string
  fix_type: string
  added_permission_names: string[]
  detail: string
}

export interface ErpConstraintReport {
  autofixes: ConstraintAutoFix[]
  issues: ConstraintIssue[]
  summary: SummaryMetric[]
}

export interface CurrentRoleSummary {
  role_id: string
  role_name: string
  permission_names: string[]
  permission_count: number
  user_names: string[]
  user_count: number
}

export interface RoleComparison {
  recommended_unit_name: string
  current_role_name?: string | null
  overlap_rate: number
  matched_permissions: string[]
  recommended_only_permissions: string[]
  current_only_permissions: string[]
  action: string
}

export interface RoleCombinationMapping {
  recommended_unit_name: string
  current_role_names: string[]
  coverage_rate: number
  matched_permissions: string[]
  missing_permissions: string[]
  extra_permissions: string[]
  action: string
}

export interface CurrentRoleMergeSuggestion {
  role_names: string[]
  overlap_rate: number
  shared_permissions: string[]
  action: string
}

export interface RoleDiffReport {
  current_roles: CurrentRoleSummary[]
  comparisons: RoleComparison[]
  combination_mappings: RoleCombinationMapping[]
  merge_suggestions: CurrentRoleMergeSuggestion[]
  current_role_constraint_issues: ConstraintIssue[]
  current_role_actions: string[]
  current_roles_to_retire: string[]
  summary: SummaryMetric[]
}

export interface SolveResponse {
  scene: SceneKey
  title: string
  summary: SummaryMetric[]
  units: SolutionUnit[]
  assignments: Assignment[]
  warnings: string[]
  insights: string[]
  sql_unit_groups?: SqlUnitGroup[] | null
  erp_role_diff?: RoleDiffReport | null
  erp_constraint_report?: ErpConstraintReport | null
  graph?: {
    nodes: Array<{
      id: string
      label: string
      node_type: string
      [key: string]: unknown
    }>
    edges: Array<{
      id: string
      source: string
      target: string
      edge_type: string
      label?: string
      [key: string]: unknown
    }>
  } | null
}
