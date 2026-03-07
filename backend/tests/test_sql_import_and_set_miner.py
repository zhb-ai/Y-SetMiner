from __future__ import annotations

import unittest
from pathlib import Path

from app.schemas.solve import ConstraintConfig, Entity, Item, Relation, SceneDataset
from app.services.algorithms.set_miner import SetMinerService
from app.services.scenes.sql_importer import ParsedSqlDocument, SqlImportService


REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_CASE_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "案例"


class SqlImportServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SqlImportService()

    def _parse_case(self, file_name: str):
        raw = (SQL_CASE_DIR / file_name).read_bytes()
        content = self.service._decode_sql(raw)
        return self.service._parse_sql_document(file_name, content)

    def test_procurement_invoice_sql_resolves_all_column_sources(self) -> None:
        document = self._parse_case("采购发票.sql")

        self.assertEqual(document.parser, "sqlglot_ast")
        self.assertTrue(document.columns)
        self.assertFalse(
            [column for column in document.columns if not column.get("source_table")],
            "采购发票.sql 仍然存在未解析来源表的字段",
        )

        source_tables = {str(column["source_table"]) for column in document.columns}
        self.assertIn("po_invoice_b", source_tables)
        self.assertIn("bd_cubasdoc", source_tables)
        self.assertIn("bd_invbasdoc", source_tables)

    def test_procurement_model_detail_sql_resolves_nested_sources_without_unknown(self) -> None:
        document = self._parse_case("采购型号明细.sql")

        self.assertEqual(document.parser, "sqlglot_ast")
        self.assertFalse(
            [column for column in document.columns if not column.get("source_table")],
            "采购型号明细.sql 仍然存在 unknown 来源",
        )
        self.assertFalse(
            [column for column in document.columns if str(column.get("name", "")).endswith("_expr")],
            "采购型号明细.sql 不应再退化出大量 *_expr 字段",
        )

        source_tables = {str(column["source_table"]) for column in document.columns}
        self.assertIn("bd_invbasdoc", source_tables)
        self.assertIn("so_squaredetail", source_tables)

    def test_procurement_tongbi_sql_resolves_star_passthrough_sources(self) -> None:
        document = self._parse_case("采购同比.sql")

        self.assertEqual(document.parser, "sqlglot_ast")
        self.assertFalse(
            [column for column in document.columns if not column.get("source_table")],
            "采购同比.sql 的星号透传字段来源未被正确解析",
        )
        self.assertTrue(
            any(str(column.get("source_table")) == "JS_SALES" for column in document.columns),
            "采购同比.sql 应该能够回溯到 JS_SALES 来源",
        )

    def test_sanitize_vendor_sql_reports_fullwidth_punctuation_fix(self) -> None:
        normalized, notes = self.service._sanitize_vendor_sql("select * from （select 1）；")

        self.assertEqual(normalized, "select * from (select 1);")
        self.assertTrue(any("全角括号或标点" in note for note in notes))

    def test_count_only_sql_should_be_excluded_from_import(self) -> None:
        document = self._parse_case("更改.sql")

        self.assertEqual(
            self.service._get_document_exclusion_reason(document),
            "仅包含聚合/常量结果，无法形成可复用宽表字段，已跳过该文件。",
        )

    def test_document_import_warnings_mark_derived_fields(self) -> None:
        document = ParsedSqlDocument(
            name="demo.sql",
            content="select 1 as a",
            tables=[],
            columns=[
                {
                    "name": "a",
                    "source_table": "derived",
                    "column_name": "a",
                    "source_tables": "",
                    "original_expr": "1",
                }
            ],
            joins=[],
            parser="sqlglot_ast",
        )

        warnings = self.service._build_document_import_warnings(document)

        self.assertTrue(any("derived" in warning for warning in warnings))

    def test_fullwidth_parenthesis_sql_no_longer_produces_weird_sources(self) -> None:
        document = self._parse_case("兼容新备货-分仓.sql")

        weird_sources = {
            str(column.get("source_table"))
            for column in document.columns
            if str(column.get("source_table") or "") in {"(", ")", "-", "（", "）"}
        }

        self.assertFalse(weird_sources, "兼容新备货-分仓.sql 不应再解析出括号/横线来源")

    def test_export_sqls_resolve_main_fact_and_dimension_sources(self) -> None:
        product_doc = self._parse_case("产品部&法务部绩效导出.sql")
        nj_doc = self._parse_case("南京分公司绩效导出.sql")

        self.assertFalse(
            [column for column in product_doc.columns if not column.get("source_table")],
            "产品部&法务部绩效导出.sql 仍存在空来源字段",
        )
        self.assertIn(
            "w_tencent_product_achievement",
            {str(column.get("source_table")) for column in product_doc.columns},
        )
        self.assertIn(
            "yafo_employe_station",
            {str(column.get("source_table")) for column in product_doc.columns},
        )

        self.assertFalse(
            [column for column in nj_doc.columns if not column.get("source_table")],
            "南京分公司绩效导出.sql 仍存在空来源字段",
        )
        self.assertIn(
            "financial_nc_assessment_department_achievement",
            {str(column.get("source_table")) for column in nj_doc.columns},
        )

    def test_documents_with_high_unresolved_ratio_should_be_excluded(self) -> None:
        document = ParsedSqlDocument(
            name="bad.sql",
            content="select a, b, c",
            tables=[],
            columns=[
                {"name": "a", "source_table": None, "column_name": "a", "source_tables": "", "original_expr": ""},
                {"name": "b", "source_table": None, "column_name": "b", "source_tables": "", "original_expr": ""},
                {"name": "c", "source_table": None, "column_name": "c", "source_tables": "", "original_expr": ""},
                {"name": "d", "source_table": "t1", "column_name": "t1.d", "source_tables": "t1", "original_expr": ""},
                {"name": "e", "source_table": "t1", "column_name": "t1.e", "source_tables": "t1", "original_expr": ""},
            ],
            joins=[],
            parser="sqlglot_ast",
        )

        self.assertEqual(
            self.service._get_document_exclusion_reason(document),
            "字段来源不确定比例过高，已跳过该文件。",
        )


class SetMinerServiceSqlUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = SetMinerService()

    def _build_dataset(self, items: list[Item]) -> SceneDataset:
        return SceneDataset(
            scene="sql",
            entities=[
                Entity(id="sql_1", name="sql_1.sql"),
                Entity(id="sql_2", name="sql_2.sql"),
                Entity(id="sql_3", name="sql_3.sql"),
            ],
            items=items,
            relations=[
                Relation(entity_id="sql_1", item_id=items[0].id),
                Relation(entity_id="sql_2", item_id=items[min(1, len(items) - 1)].id),
                Relation(entity_id="sql_3", item_id=items[min(2, len(items) - 1)].id),
            ],
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
        )

    def test_sql_unit_name_uses_combination_name_for_multi_source_unit(self) -> None:
        dataset = self._build_dataset(
            [
                Item(id="a::id", name="id", group="so_saleinvoice", source="so_saleinvoice"),
                Item(id="a::name", name="name", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="b::amount", name="amount", group="bd_invbasdoc", source="bd_invbasdoc"),
            ]
        )
        unit = {
            "item_indices": [0, 1, 2],
            "entity_indices": [0, 1],
        }

        name = self.service._build_sql_unit_name(dataset, unit, 1)

        self.assertEqual(name, "bd_invbasdoc+so_saleinvoice组合宽表1")

    def test_sql_unit_name_is_stable_when_item_order_changes(self) -> None:
        dataset = self._build_dataset(
            [
                Item(id="a::id", name="id", group="so_saleinvoice", source="so_saleinvoice"),
                Item(id="b::id", name="id", group="bd_cubasdoc", source="bd_cubasdoc"),
                Item(id="c::id", name="id", group="bd_cumandoc", source="bd_cumandoc"),
            ]
        )

        left_name = self.service._build_sql_unit_name(
            dataset,
            {"item_indices": [0, 1, 2], "entity_indices": [0]},
            7,
        )
        right_name = self.service._build_sql_unit_name(
            dataset,
            {"item_indices": [2, 0, 1], "entity_indices": [1]},
            7,
        )

        self.assertEqual(left_name, "bd_cubasdoc+bd_cumandoc+so_saleinvoice组合宽表7")
        self.assertEqual(left_name, right_name)

    def test_merge_rule_does_not_merge_units_with_different_source_signatures(self) -> None:
        dataset = self._build_dataset(
            [
                Item(id="inv::id", name="id", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="inv::name", name="name", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="sale::amount", name="amount", group="so_saleinvoice", source="so_saleinvoice"),
                Item(id="sale::month", name="month", group="so_saleinvoice", source="so_saleinvoice"),
            ]
        )
        units = [
            {
                "id": "unit-a",
                "item_indices": [0, 1],
                "entity_indices": [0, 1],
                "score": 1.0,
            },
            {
                "id": "unit-b",
                "item_indices": [0, 2, 3],
                "entity_indices": [1, 2],
                "score": 1.0,
            },
        ]

        merged = self.service._merge_similar_sql_units(dataset, matrix=self._matrix(3, 4), units=units)

        self.assertEqual(len(merged), 2)

    def test_merge_rule_merges_highly_overlapping_units_with_same_sources(self) -> None:
        dataset = self._build_dataset(
            [
                Item(id="inv::id", name="id", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="inv::name", name="name", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="inv::category", name="category", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="inv::brand", name="brand", group="bd_invbasdoc", source="bd_invbasdoc"),
            ]
        )
        units = [
            {
                "id": "unit-a",
                "item_indices": [0, 1, 2],
                "entity_indices": [0, 1],
                "score": 1.0,
            },
            {
                "id": "unit-b",
                "item_indices": [1, 2, 3],
                "entity_indices": [1, 2],
                "score": 1.0,
            },
        ]

        merged = self.service._merge_similar_sql_units(dataset, matrix=self._matrix(3, 4), units=units)

        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["item_indices"], [0, 1, 2, 3])
        self.assertEqual(merged[0]["entity_indices"], [0, 1, 2])

    def test_build_warnings_includes_import_warnings_for_sql_scene(self) -> None:
        dataset = SceneDataset(
            scene="sql",
            entities=[Entity(id="sql_1", name="demo.sql")],
            items=[Item(id="i1", name="id", group="t1", source="t1")],
            relations=[Relation(entity_id="sql_1", item_id="i1")],
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
            meta={"import_warnings": ["[警告] `demo.sql` 仍有 1 个字段来源未确定，分析结果可能存在偏差。"]},
        )

        warnings = self.service._build_warnings(dataset, assignments=[], units=[])

        self.assertTrue(any("demo.sql" in item for item in warnings))

    @staticmethod
    def _matrix(rows: int, cols: int):
        import numpy as np

        return np.ones((rows, cols), dtype=int)


class SqlSolveEndToEndTests(unittest.TestCase):
    def setUp(self) -> None:
        self.import_service = SqlImportService()
        self.set_miner = SetMinerService()

    def _solve_cases(self, file_names: list[str]):
        documents = []
        for file_name in file_names:
            raw = (SQL_CASE_DIR / file_name).read_bytes()
            content = self.import_service._decode_sql(raw)
            document = self.import_service._parse_sql_document(file_name, content)
            documents.append(document)
        dataset = self.import_service._build_dataset(documents, import_warnings=[])
        return self.set_miner.solve(dataset)

    def test_end_to_end_sql_solve_keeps_stable_combination_names(self) -> None:
        result = self._solve_cases(["采购发票.sql", "采购-供应商对比.sql", "采购型号明细.sql"])

        unit_names = [unit.name for unit in result.units]
        self.assertIn("bd_cubasdoc+po_invoice+po_invoice_b组合宽表2", unit_names)
        self.assertIn("bd_cubasdoc+bd_invbasdoc+po_invoice+po_invoice_b组合宽表3", unit_names)
        self.assertTrue(
            any(name.startswith("bd_invbasdoc+bd_stordoc+derived+so_saleinvoice+so_saleinvoice_b+so_squaredetail+v_zlw_cust组合宽表") for name in unit_names),
            "多来源组合宽表命名应保持稳定且按来源字母序排列",
        )

        procurement_compare_assignment = next(
            assignment for assignment in result.assignments if assignment.entity_name == "采购-供应商对比.sql"
        )
        self.assertTrue(procurement_compare_assignment.unit_names)
        self.assertTrue(
            any("bd_cubasdoc+po_invoice+po_invoice_b组合宽表" in unit_name for unit_name in procurement_compare_assignment.unit_names)
        )

    def test_end_to_end_sql_solve_surfaces_join_risk_warning(self) -> None:
        result = self._solve_cases(["采购型号明细.sql"])

        self.assertTrue(
            any("JOIN 图中孤立" in warning for warning in result.warnings),
            "复杂多来源 SQL 应在最终结果中暴露 JOIN 可达性风险",
        )
        self.assertTrue(result.units)
        self.assertTrue(any(unit.sources for unit in result.units))


if __name__ == "__main__":
    unittest.main()
