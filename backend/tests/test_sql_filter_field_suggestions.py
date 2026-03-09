from __future__ import annotations

import unittest

import numpy as np

from app.schemas.solve import ConstraintConfig, Entity, Item, SceneDataset
from app.services.algorithms.set_miner import SetMinerService
from app.services.scenes.sql_importer import SqlImportService


class SqlFilterFieldSuggestionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.import_service = SqlImportService()
        self.set_miner = SetMinerService()

    def test_parse_sql_document_extracts_filter_fields_outside_select_list(self) -> None:
        document = self.import_service._parse_sql_document(
            "filter_demo.sql",
            "SELECT amount FROM sales WHERE customer_id = 1 AND org_id = 2",
        )

        self.assertEqual([str(column["name"]) for column in document.columns], ["amount"])
        self.assertEqual(
            {str(column["name"]) for column in document.filter_columns},
            {"customer_id", "org_id"},
        )
        self.assertTrue(all(column.get("resolution_kind") == "filter_condition" for column in document.filter_columns))

    def test_build_sql_unit_groups_surfaces_filter_fields_separately(self) -> None:
        dataset = SceneDataset(
            scene="sql",
            entities=[
                Entity(id="sql_1", name="sql_1.sql"),
                Entity(id="sql_2", name="sql_2.sql"),
                Entity(id="sql_3", name="sql_3.sql"),
                Entity(id="sql_4", name="sql_4.sql"),
            ],
            items=[
                Item(id="a::id", name="id", group="table_a", source="table_a"),
                Item(id="a::name", name="name", group="table_a", source="table_a"),
                Item(id="b::name", name="biz_name", group="table_b", source="table_b"),
            ],
            relations=[],
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
            meta={
                "document_filter_fields": {
                    "sql_1.sql": [
                        {"name": "customer_id", "source": "table_a", "source_tables": "table_a", "column_name": "table_a.customer_id"},
                        {"name": "org_id", "source": "table_b", "source_tables": "table_b", "column_name": "table_b.org_id"},
                    ],
                    "sql_2.sql": [
                        {"name": "customer_id", "source": "table_a", "source_tables": "table_a", "column_name": "table_a.customer_id"},
                    ],
                    "sql_3.sql": [
                        {"name": "org_id", "source": "table_b", "source_tables": "table_b", "column_name": "table_b.org_id"},
                    ],
                    "sql_4.sql": [],
                }
            },
        )
        dataset.constraints.base_field_threshold = 0.75
        dataset.constraints.suggested_field_threshold = 0.5

        units = [
            {"id": "unit-1", "item_indices": [0, 1, 2], "entity_indices": [0], "score": 5.0},
            {"id": "unit-2", "item_indices": [0, 1, 2], "entity_indices": [1], "score": 5.0},
            {"id": "unit-3", "item_indices": [0, 1, 2], "entity_indices": [2], "score": 5.0},
            {"id": "unit-4", "item_indices": [0, 1, 2], "entity_indices": [3], "score": 5.0},
        ]

        decorated = self.set_miner._decorate_units(dataset, np.ones((4, 3), dtype=int), units)
        _, groups = self.set_miner._build_sql_unit_groups(dataset, np.ones((4, 3), dtype=int), decorated)

        base_unit = groups[0]["base_unit"]
        self.assertEqual(base_unit["filter_item_names"], ["customer_id", "org_id"])
        self.assertEqual(base_unit["filter_item_sources"], ["table_a", "table_b"])
        self.assertEqual(base_unit["filter_item_hits"], [2, 2])
        self.assertEqual(base_unit["filter_item_support_count"], 4)
        self.assertFalse(any(name in base_unit["item_names"] for name in base_unit["filter_item_names"]))


if __name__ == "__main__":
    unittest.main()
