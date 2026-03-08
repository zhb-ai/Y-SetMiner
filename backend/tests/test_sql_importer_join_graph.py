from __future__ import annotations

import unittest
from pathlib import Path

from app.services.scenes.sql_importer import SqlImportService


REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_CASE_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "案例"
SQL_VIEW_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "视图SQL"


class SqlImporterJoinGraphTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SqlImportService()

    def _parse_case(self, file_name: str):
        raw = (SQL_CASE_DIR / file_name).read_bytes()
        content = self.service._decode_sql(raw)
        return self.service._parse_sql_document(file_name, content)

    def _parse_view(self, file_name: str):
        raw = (SQL_VIEW_DIR / file_name).read_bytes()
        content = self.service._decode_sql(raw)
        return self.service._parse_sql_document(file_name, content)

    def _edge_pairs(self, document) -> set[frozenset[str]]:
        return {frozenset((edge.left_table, edge.right_table)) for edge in document.join_edges}

    def test_transfer_sql_subquery_keeps_to_bill_bridge_edge(self) -> None:
        document = self._parse_case("NC仓库调拨表.sql")
        join_pairs = self._edge_pairs(document)

        self.assertIn(
            frozenset(("to_bill_b", "to_bill")),
            join_pairs,
            "子查询中的 to_bill 应通过 to_bill_b 被纳入 JOIN 图",
        )

    def test_customer_info_sql_keeps_department_and_salesperson_bridge_edges(self) -> None:
        document = self._parse_case("客户信息.sql")
        join_pairs = self._edge_pairs(document)

        self.assertIn(frozenset(("bd_cumandoc", "bd_deptdoc")), join_pairs)
        self.assertIn(frozenset(("bd_cumandoc", "bd_psndoc")), join_pairs)

    def test_inventory_snapshot_view_keeps_onhand_to_ledger_edge(self) -> None:
        document = self._parse_view("02_MV_INVENTORY_SNAPSHOT.sql")
        join_pairs = self._edge_pairs(document)

        self.assertIn(
            frozenset(("ic_onhandnum", "ia_generalledger")),
            join_pairs,
            "库存快照视图应保留现存量到总账的直接 JOIN 边",
        )

    def test_payable_sql_keeps_join_edge_when_on_clause_uses_bare_column(self) -> None:
        document = self._parse_case("供应商预付明细.sql")
        join_pairs = self._edge_pairs(document)

        self.assertIn(
            frozenset(("arap_djfb", "bd_cubasdoc")),
            join_pairs,
            "gm.pk_cubasdoc = hbbm 这类一侧裸列的 ON 条件应建立 arap_djfb -> bd_cubasdoc 关系",
        )

    def test_payable_sql_keeps_correlated_scalar_subquery_edge_for_customer_view(self) -> None:
        document = self._parse_case("应付-数据底表.sql")
        join_pairs = self._edge_pairs(document)

        self.assertIn(
            frozenset(("arap_djfb", "v_zlw_cust")),
            join_pairs,
            "标量子查询 where pk_cubasdoc = hbbm 应建立 arap_djfb -> v_zlw_cust 关系",
        )


if __name__ == "__main__":
    unittest.main()
