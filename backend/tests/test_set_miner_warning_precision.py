from __future__ import annotations

import unittest

from app.schemas.solve import Entity, Item, Relation, SceneDataset
from app.services.algorithms.set_miner import SetMinerService


class SetMinerWarningPrecisionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SetMinerService()

    def test_expression_warning_lists_only_sqls_that_actually_contain_problem_field(self) -> None:
        dataset = SceneDataset(
            scene="sql",
            entities=[
                Entity(id="sql_1", name="放货结算周期.sql"),
                Entity(id="sql_2", name="放货结算周期-优化.txt"),
            ],
            items=[
                Item(
                    id="derived::金额",
                    name="金额",
                    group="derived",
                    source="derived",
                    meta={
                        "source_tables": "",
                        "column_name": "nheadsummny",
                        "original_expr": "",
                        "resolution_kind": "bare_column",
                    },
                ),
                Item(
                    id="so_sale::单据号",
                    name="单据号",
                    group="so_sale",
                    source="so_sale",
                ),
            ],
            relations=[
                Relation(entity_id="sql_1", item_id="derived::金额"),
                Relation(entity_id="sql_1", item_id="so_sale::单据号"),
                Relation(entity_id="sql_2", item_id="so_sale::单据号"),
            ],
            meta={"join_graph": {}},
        )

        warnings = self.service._check_expression_source_completeness(
            dataset,
            [
                {
                    "name": "so_sale扩展宽表",
                    "item_ids": ["derived::金额", "so_sale::单据号"],
                    "covered_entity_names": ["放货结算周期.sql", "放货结算周期-优化.txt"],
                }
            ],
        )

        self.assertEqual(len(warnings), 1)
        self.assertIn("放货结算周期.sql", warnings[0])
        self.assertNotIn("放货结算周期-优化.txt", warnings[0])
        self.assertIn("裸列写法", warnings[0])


if __name__ == "__main__":
    unittest.main()
