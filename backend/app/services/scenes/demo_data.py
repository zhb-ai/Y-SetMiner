from __future__ import annotations

from app.schemas.solve import ConstraintConfig, Entity, Item, Relation, SceneDataset, SceneInfo


SCENES = [
    SceneInfo(
        key="erp",
        name="ERP 权限优化",
        description="根据用户实际所需权限，推荐最少重叠的角色集合与用户分配方案。",
        goal="回答应该创建多少个角色，以及每个角色有哪些权限。",
        default_unit_name="角色",
    ),
    SceneInfo(
        key="sql",
        name="SQL 宽表优化",
        description="根据 SQL 或报表需求中重复出现的字段组合，推荐中间表或宽表设计方案。",
        goal="回答应该创建哪些宽表，以及每张表包含哪些字段。",
        default_unit_name="宽表",
    ),
]


def get_demo_dataset(scene: str) -> SceneDataset:
    if scene == "erp":
        return _erp_demo()
    return _sql_demo()


def _erp_demo() -> SceneDataset:
    entities = [
        Entity(id="u1", name="销售专员A"),
        Entity(id="u2", name="销售专员B"),
        Entity(id="u3", name="销售主管"),
        Entity(id="u4", name="客服专员"),
        Entity(id="u5", name="财务专员"),
    ]
    items = [
        Item(id="p1", name="订单查询", group="订单", item_type="menu"),
        Item(id="p2", name="订单创建", group="订单", item_type="button"),
        Item(id="p3", name="订单审核", group="订单", item_type="button"),
        Item(id="p4", name="客户查看", group="客户", item_type="menu"),
        Item(id="p5", name="客户编辑", group="客户", item_type="button"),
        Item(id="p6", name="退款处理", group="售后", item_type="button"),
        Item(id="p7", name="收款查看", group="财务", item_type="menu"),
        Item(id="p8", name="发票管理", group="财务", item_type="button"),
    ]
    relations = [
        Relation(entity_id="u1", item_id="p1"),
        Relation(entity_id="u1", item_id="p2"),
        Relation(entity_id="u1", item_id="p4"),
        Relation(entity_id="u2", item_id="p1"),
        Relation(entity_id="u2", item_id="p2"),
        Relation(entity_id="u2", item_id="p4"),
        Relation(entity_id="u3", item_id="p1"),
        Relation(entity_id="u3", item_id="p2"),
        Relation(entity_id="u3", item_id="p3"),
        Relation(entity_id="u3", item_id="p4"),
        Relation(entity_id="u3", item_id="p5"),
        Relation(entity_id="u4", item_id="p1"),
        Relation(entity_id="u4", item_id="p4"),
        Relation(entity_id="u4", item_id="p6"),
        Relation(entity_id="u5", item_id="p7"),
        Relation(entity_id="u5", item_id="p8"),
    ]
    return SceneDataset(
        scene="erp",
        entities=entities,
        items=items,
        relations=relations,
        constraints=ConstraintConfig(max_items_per_unit=4, max_units_per_entity=3),
    )


def _sql_demo() -> SceneDataset:
    entities = [
        Entity(id="q1", name="销售日报"),
        Entity(id="q2", name="销售月报"),
        Entity(id="q3", name="客户成交分析"),
        Entity(id="q4", name="退款统计"),
        Entity(id="q5", name="发票报表"),
    ]
    items = [
        Item(id="c1", name="order_id", group="订单", source="t_order"),
        Item(id="c2", name="order_date", group="订单", source="t_order"),
        Item(id="c3", name="customer_id", group="客户", source="t_order"),
        Item(id="c4", name="customer_name", group="客户", source="t_customer"),
        Item(id="c5", name="amount", group="订单", source="t_order"),
        Item(id="c6", name="refund_amount", group="售后", source="t_refund"),
        Item(id="c7", name="invoice_no", group="财务", source="t_invoice"),
        Item(id="c8", name="invoice_amount", group="财务", source="t_invoice"),
    ]
    relations = [
        Relation(entity_id="q1", item_id="c1"),
        Relation(entity_id="q1", item_id="c2"),
        Relation(entity_id="q1", item_id="c3"),
        Relation(entity_id="q1", item_id="c4"),
        Relation(entity_id="q1", item_id="c5"),
        Relation(entity_id="q2", item_id="c2"),
        Relation(entity_id="q2", item_id="c3"),
        Relation(entity_id="q2", item_id="c4"),
        Relation(entity_id="q2", item_id="c5"),
        Relation(entity_id="q3", item_id="c3"),
        Relation(entity_id="q3", item_id="c4"),
        Relation(entity_id="q3", item_id="c5"),
        Relation(entity_id="q4", item_id="c1"),
        Relation(entity_id="q4", item_id="c2"),
        Relation(entity_id="q4", item_id="c6"),
        Relation(entity_id="q5", item_id="c1"),
        Relation(entity_id="q5", item_id="c2"),
        Relation(entity_id="q5", item_id="c7"),
        Relation(entity_id="q5", item_id="c8"),
    ]
    return SceneDataset(
        scene="sql",
        entities=entities,
        items=items,
        relations=relations,
        constraints=ConstraintConfig(max_items_per_unit=5, max_units_per_entity=3),
    )
