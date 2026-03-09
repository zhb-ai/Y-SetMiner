from __future__ import annotations

import asyncio
import io
import unittest

from fastapi import UploadFile

from app.services.scenes.sql_importer import SqlImportService
from app.services.scenes.sql_object_preprocessor import SqlObjectPreprocessor


class SqlObjectPreprocessorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.preprocessor = SqlObjectPreprocessor()
        self.service = SqlImportService()

    def test_parse_uploads_expand_view_materialized_view_and_wide_table_recursively(self) -> None:
        files = [
            UploadFile(
                filename="view.sql",
                file=io.BytesIO(
                    b"CREATE VIEW v_sales_base AS "
                    b"SELECT order_id, customer_id, amount FROM ods_sales"
                ),
            ),
            UploadFile(
                filename="mv.sql",
                file=io.BytesIO(
                    b"CREATE MATERIALIZED VIEW mv_sales_summary AS "
                    b"SELECT customer_id, SUM(amount) AS total_amount "
                    b"FROM v_sales_base GROUP BY customer_id"
                ),
            ),
            UploadFile(
                filename="wide.sql",
                file=io.BytesIO(
                    b"CREATE TABLE dws_sales_wide AS "
                    b"SELECT customer_id, total_amount FROM mv_sales_summary"
                ),
            ),
            UploadFile(
                filename="report.sql",
                file=io.BytesIO(
                    b"SELECT w.customer_id, w.total_amount FROM dws_sales_wide w"
                ),
            ),
        ]

        documents, warnings, summary = asyncio.run(self.service._parse_uploads(files))
        report_document = next(document for document in documents if document.name == "report.sql")

        self.assertIn("ods_sales", report_document.tables)
        self.assertNotIn("dws_sales_wide", report_document.tables)
        self.assertNotIn("mv_sales_summary", report_document.tables)
        self.assertNotIn("v_sales_base", report_document.tables)
        self.assertTrue(any("report.sql" in warning and "展开对象引用" in warning for warning in warnings))
        self.assertIsNotNone(summary)
        assert summary is not None
        self.assertEqual(len(summary.detected_objects), 3)
        report_trace = next(item for item in summary.expanded_documents if item.file_name == "report.sql")
        self.assertEqual(report_trace.expanded_objects, ["dws_sales_wide"])
        self.assertEqual(report_trace.max_depth, 2)

    def test_preprocessor_keeps_local_cte_shadowing_without_expansion(self) -> None:
        processed_documents, warnings, summary = self.preprocessor.preprocess_documents(
            [
                ("view.sql", "CREATE VIEW v_sales AS SELECT id FROM ods_sales"),
                (
                    "report.sql",
                    "WITH v_sales AS (SELECT 1 AS id) SELECT id FROM v_sales",
                ),
            ]
        )
        report_sql = dict(processed_documents)["report.sql"].lower()

        self.assertIn("with v_sales as", report_sql)
        self.assertNotIn("ods_sales", report_sql)
        self.assertFalse(any("report.sql" in warning and "展开对象引用" in warning for warning in warnings))
        self.assertIsNotNone(summary)
        assert summary is not None
        report_trace = next(item for item in summary.expanded_documents if item.file_name == "report.sql")
        self.assertEqual(report_trace.expanded_objects, [])

    def test_preprocessor_reports_cycle_and_stops_recursive_expansion(self) -> None:
        processed_documents, warnings, summary = self.preprocessor.preprocess_documents(
            [
                ("view_a.sql", "CREATE VIEW view_a AS SELECT * FROM view_b"),
                ("view_b.sql", "CREATE VIEW view_b AS SELECT * FROM view_a"),
                ("report.sql", "SELECT * FROM view_a"),
            ]
        )
        report_sql = dict(processed_documents)["report.sql"].lower()

        self.assertIn("view_a", report_sql)
        self.assertTrue(any("循环依赖" in warning for warning in warnings))
        self.assertIsNotNone(summary)
        assert summary is not None
        self.assertTrue(summary.cycles)

    def test_sanitize_vendor_sql_strips_ctas_preamble(self) -> None:
        sql = "CREATE TABLE dws_demo AS SELECT id, amount FROM ods_sales"

        result, notes = self.service._sanitize_vendor_sql(sql)

        self.assertEqual(result.strip(), "SELECT id, amount FROM ods_sales")
        self.assertTrue(any("CREATE TABLE AS SELECT" in note for note in notes))

    def test_preview_uploads_returns_structured_preprocess_summary(self) -> None:
        files = [
            UploadFile(
                filename="view.sql",
                file=io.BytesIO(b"CREATE VIEW v_sales AS SELECT id, amount FROM ods_sales"),
            ),
            UploadFile(
                filename="report.sql",
                file=io.BytesIO(b"SELECT id, amount FROM v_sales"),
            ),
        ]

        preview = asyncio.run(self.service.preview_uploads(files))

        self.assertIsNotNone(preview.preprocess_summary)
        assert preview.preprocess_summary is not None
        self.assertEqual(preview.preprocess_summary.detected_objects[0].name, "v_sales")
        report_trace = next(item for item in preview.preprocess_summary.expanded_documents if item.file_name == "report.sql")
        self.assertEqual(report_trace.expanded_objects, ["v_sales"])
        self.assertEqual(report_trace.max_depth, 1)


if __name__ == "__main__":
    unittest.main()
