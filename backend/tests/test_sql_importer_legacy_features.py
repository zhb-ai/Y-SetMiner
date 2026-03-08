from __future__ import annotations

import unittest
from pathlib import Path

from app.services.scenes.sql_importer import SqlImportService


REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_CASE_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "案例"


class SqlImporterLegacyFeatureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SqlImportService()

    def _parse_case(self, file_name: str):
        raw = (SQL_CASE_DIR / file_name).read_bytes()
        content = self.service._decode_sql(raw)
        return self.service._parse_sql_document(file_name, content)

    def _edge_pairs(self, document) -> set[frozenset[str]]:
        return {frozenset((edge.left_table, edge.right_table)) for edge in document.join_edges}

    def test_customer_archive_subquery_star_passthrough_resolves_bd_cumandoc_columns(self) -> None:
        document = self._parse_case("客户信息.sql")
        columns_by_name = {str(column["name"]): column for column in document.columns}

        self.assertIn("bd_cumandoc", str(columns_by_name["是否封存"]["source_tables"]))
        self.assertIn("bd_cumandoc", str(columns_by_name["放货账期"]["source_tables"]))

    def test_legacy_where_join_builds_edges_for_realtime_inventory_sql(self) -> None:
        document = self._parse_case("实时-预计出入库.sql")
        join_pairs = self._edge_pairs(document)

        self.assertIn(frozenset(("ic_atp_f", "bd_stordoc")), join_pairs)
        self.assertIn(frozenset(("ic_atp_f", "bd_produce")), join_pairs)


if __name__ == "__main__":
    unittest.main()
