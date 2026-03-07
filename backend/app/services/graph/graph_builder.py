"""
关系图数据构建模块。

将 SolveResponse + SceneDataset 转换为前端 G6 所需的 { nodes, edges } 格式。

SQL 场景节点类型：
  - table      物理表（蓝色）
  - wide_table 宽表候选（橙色）
  - sql_file   SQL文件（绿色）

SQL 场景边类型：
  - join          表-表 JOIN 关系（标注关联字段）
  - field_belongs 字段属于宽表（字段折叠后不单独展示）
  - covers        宽表覆盖 SQL 文件

ERP 场景节点类型：
  - user       用户（蓝色）
  - role       推荐角色（橙色）
  - permission 权限（灰色，可折叠）

ERP 场景边类型：
  - user_role       用户分配到角色
  - role_permission 角色包含权限
"""
from __future__ import annotations

import re
from typing import Any

from app.schemas.solve import SceneDataset, SolveResponse


def build_sql_graph(dataset: SceneDataset, response: SolveResponse) -> dict[str, Any]:
    """构建 SQL 宽表场景关系图。"""
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    node_ids: set[str] = set()

    def add_node(node: dict[str, Any]) -> None:
        if node["id"] not in node_ids:
            nodes.append(node)
            node_ids.add(node["id"])

    # ── 1. 物理表节点（从 join_graph 提取所有表名）──────────────────────
    join_graph: dict[str, dict[str, list]] = dataset.meta.get("join_graph", {})
    all_join_edges: list[dict] = dataset.meta.get("all_join_edges", [])

    # 也从 item.group 收集物理表
    physical_tables: set[str] = set()
    for item in dataset.items:
        if item.group and item.group != "unknown":
            physical_tables.add(item.group)
    for tbl in join_graph:
        physical_tables.add(tbl)

    for tbl in sorted(physical_tables):
        add_node({
            "id": f"table::{tbl}",
            "label": tbl,
            "node_type": "table",
            "field_count": sum(1 for it in dataset.items if it.group == tbl),
        })

    # ── 2. JOIN 边（表-表）──────────────────────────────────────────────
    seen_join_edges: set[tuple[str, str]] = set()
    for edge_info in all_join_edges:
        l, r = edge_info["left"], edge_info["right"]
        key = (min(l, r), max(l, r))
        if key in seen_join_edges:
            continue
        seen_join_edges.add(key)
        edges.append({
            "id": f"join::{l}::{r}",
            "source": f"table::{l}",
            "target": f"table::{r}",
            "edge_type": "join",
            "label": f"{edge_info['left_col']} = {edge_info['right_col']}",
            "source_sql": edge_info["source"],
        })

    # ── 3. 宽表候选节点 + 覆盖 SQL 文件节点 + 边 ────────────────────────
    item_lookup = {item.id: item for item in dataset.items}
    entity_lookup = {e.id: e.name for e in dataset.entities}

    # 收集宽表级 warning，供前端 tooltip / 详情区直接展示“原因”
    join_warning_by_unit: dict[str, str] = {}
    for w in response.warnings:
        if "孤立" in w and "宽表" in w:
            m = re.search(r"宽表 `([^`]+)`", w)
            if m:
                join_warning_by_unit[m.group(1)] = w

    granularity_warning_by_unit: dict[str, str] = {}
    for w in response.warnings:
        if "粒度" in w and "宽表" in w:
            m = re.search(r"宽表 `([^`]+)`", w)
            if m:
                granularity_warning_by_unit[m.group(1)] = w

    for unit in response.units:
        has_join_warn = unit.name in join_warning_by_unit
        has_gran_warn = unit.name in granularity_warning_by_unit

        add_node({
            "id": f"wide::{unit.id}",
            "label": unit.name,
            "node_type": "wide_table",
            "score": unit.score,
            "field_count": len(unit.item_ids),
            "sources": unit.sources,
            "has_join_warning": has_join_warn,
            "has_granularity_warning": has_gran_warn,
            "join_warning_reason": join_warning_by_unit.get(unit.name, ""),
            "granularity_warning_reason": granularity_warning_by_unit.get(unit.name, ""),
            "rationale": unit.rationale,
        })

        # 字段来源表 → 宽表的归属边
        source_tables_for_unit: set[str] = set()
        for item_id in unit.item_ids:
            item = item_lookup.get(item_id)
            if item and item.group and item.group != "unknown":
                source_tables_for_unit.add(item.group)

        for tbl in source_tables_for_unit:
            edges.append({
                "id": f"field_belongs::{tbl}::{unit.id}",
                "source": f"table::{tbl}",
                "target": f"wide::{unit.id}",
                "edge_type": "field_belongs",
                "label": f"提供字段",
            })

        # 宽表 → SQL 文件覆盖边
        for eid in unit.covered_entity_ids:
            sql_name = entity_lookup.get(eid, eid)
            sql_node_id = f"sql::{eid}"
            add_node({
                "id": sql_node_id,
                "label": sql_name,
                "node_type": "sql_file",
            })
            edges.append({
                "id": f"covers::{unit.id}::{eid}",
                "source": f"wide::{unit.id}",
                "target": sql_node_id,
                "edge_type": "covers",
                "label": "覆盖",
            })

    return {"nodes": nodes, "edges": edges}


def build_erp_graph(dataset: SceneDataset, response: SolveResponse) -> dict[str, Any]:
    """构建 ERP 用户-角色-权限三层关系图。"""
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    node_ids: set[str] = set()

    def add_node(node: dict[str, Any]) -> None:
        if node["id"] not in node_ids:
            nodes.append(node)
            node_ids.add(node["id"])

    item_lookup = {item.id: item for item in dataset.items}
    entity_lookup = {e.id: e for e in dataset.entities}

    # ── 1. 推荐角色节点 ─────────────────────────────────────────────────
    for unit in response.units:
        add_node({
            "id": f"role::{unit.id}",
            "label": unit.name,
            "node_type": "role",
            "score": unit.score,
            "permission_count": len(unit.item_ids),
            "rationale": unit.rationale,
        })

        # ── 2. 权限节点（每个角色包含的权限）───────────────────────────
        for item_id in unit.item_ids:
            item = item_lookup.get(item_id)
            if not item:
                continue
            perm_node_id = f"perm::{item_id}"
            perm_group = item.group or "通用"
            add_node({
                "id": perm_node_id,
                "label": item.name,
                "node_type": "permission",
                "group": perm_group,
                "source": item.source or "",
            })
            edges.append({
                "id": f"role_perm::{unit.id}::{item_id}",
                "source": f"role::{unit.id}",
                "target": perm_node_id,
                "edge_type": "role_permission",
                "label": "包含",
            })

    # ── 3. 用户节点 + 用户→角色分配边 ────────────────────────────────────
    for assignment in response.assignments:
        entity = entity_lookup.get(assignment.entity_id)
        user_name = entity.name if entity else assignment.entity_id
        user_node_id = f"user::{assignment.entity_id}"

        add_node({
            "id": user_node_id,
            "label": user_name,
            "node_type": "user",
            "uncovered_count": len(assignment.uncovered_item_names),
        })

        for unit_id in assignment.unit_ids:
            edges.append({
                "id": f"user_role::{assignment.entity_id}::{unit_id}",
                "source": user_node_id,
                "target": f"role::{unit_id}",
                "edge_type": "user_role",
                "label": "分配",
            })

    return {"nodes": nodes, "edges": edges}
