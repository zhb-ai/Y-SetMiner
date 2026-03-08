from __future__ import annotations

import unittest

from app.services.scenes.sql_importer import ParsedSqlDocument, SqlImportService


class SqlImporterItemIdentityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SqlImportService()

    def test_derived_items_with_same_name_but_different_lineage_should_not_merge(self) -> None:
        dataset = self.service._build_dataset(
            [
                ParsedSqlDocument(
                    name="js_sales_like.sql",
                    content="select 流水 from js_sales",
                    tables=["js_sales"],
                    columns=[
                        {
                            "name": "流水",
                            "source_table": "js_sales",
                            "column_name": "js_sales.流水",
                            "source_tables": "js_sales",
                            "original_expr": "",
                        }
                    ],
                    joins=[],
                    parser="sqlglot_ast",
                ),
                ParsedSqlDocument(
                    name="story_num_like.sql",
                    content="select sum(xx) as 流水 from story_num",
                    tables=["story_num"],
                    columns=[
                        {
                            "name": "流水",
                            "source_table": "derived",
                            "column_name": "story_num.流水",
                            "source_tables": "story_num",
                            "original_expr": "SUM(story_num.amount)",
                            "resolution_kind": "derived_expression",
                        }
                    ],
                    joins=[],
                    parser="sqlglot_ast",
                ),
                ParsedSqlDocument(
                    name="so_saleinvoice_like.sql",
                    content="select sum(xx) as 流水 from so_saleinvoice",
                    tables=["so_saleinvoice"],
                    columns=[
                        {
                            "name": "流水",
                            "source_table": "derived",
                            "column_name": "so_saleinvoice.流水",
                            "source_tables": "so_saleinvoice",
                            "original_expr": "SUM(so_saleinvoice.noriginalcurmny)",
                            "resolution_kind": "derived_expression",
                        }
                    ],
                    joins=[],
                    parser="sqlglot_ast",
                ),
            ],
            import_warnings=[],
        )

        derived_items = [item for item in dataset.items if item.source == "derived" and item.name == "流水"]

        # 当前实现会把这两个 derived::流水 粗合并成 1 个 item，导致不同事实来源在后续宽表/告警中串台。
        # 期望行为：至少按 lineage(source_tables/original_expr) 区分成两个独立 item。
        self.assertEqual(len(derived_items), 2)
        self.assertEqual(
            sorted(str(item.meta.get("source_tables", "")) for item in derived_items),
            ["so_saleinvoice", "story_num"],
        )
        self.assertTrue(
            any("疑似血缘合并污染" in warning and "流水" in warning for warning in dataset.meta["lineage_merge_risk_warnings"]),
            "同名 derived 字段若来自不同血缘，应给出独立的污染风险提示",
        )


if __name__ == "__main__":
    unittest.main()
