from __future__ import annotations

import unittest
from pathlib import Path

from app.services.scenes.sql_importer import SqlImportService


REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_CASE_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "案例"


class SqlImporterLineageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SqlImportService()

    def _parse_case(self, file_name: str):
        raw = (SQL_CASE_DIR / file_name).read_bytes()
        content = self.service._decode_sql(raw)
        return self.service._parse_sql_document(file_name, content)

    def test_payable_scalar_subqueries_resolve_real_customer_sources_instead_of_join_alias(self) -> None:
        document = self._parse_case("应付-数据底表.sql")
        columns_by_name = {str(column["name"]): column for column in document.columns}

        customer_key = columns_by_name["客户主键"]
        customer_name = columns_by_name["客户名称"]
        salesman = columns_by_name["业务员"]
        department = columns_by_name["部门"]
        market = columns_by_name["市场部"]

        self.assertIn("bd_cubasdoc", str(customer_key["source_tables"]))
        self.assertIn("bd_cubasdoc", str(customer_name["source_tables"]))
        self.assertNotIn("gm", str(customer_key["source_tables"]))
        self.assertNotIn("gm", str(customer_name["source_tables"]))

        self.assertIn("v_zlw_cust", str(salesman["source_tables"]))
        self.assertIn("v_zlw_cust", str(department["source_tables"]))
        self.assertIn("v_zlw_cust", str(market["source_tables"]))
        self.assertNotIn("gm", str(salesman["source_tables"]))
        self.assertNotIn("gm", str(department["source_tables"]))
        self.assertNotIn("gm", str(market["source_tables"]))


if __name__ == "__main__":
    unittest.main()
