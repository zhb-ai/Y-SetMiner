from __future__ import annotations

import unittest
from pathlib import Path

from app.schemas.solve import ConstraintConfig, Entity, Item, Relation, SceneDataset
from app.services.algorithms.sql_unit_hierarchy import _build_item_source_detail, _build_item_source_label
from app.services.algorithms.set_miner import SetMinerService
from app.services.scenes.sql_importer import ParsedSqlDocument, SqlImportService


REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_CASE_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "案例"
SQL_VIEW_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "视图SQL"


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
            any(str(column.get("source_table")) == "js_sales" for column in document.columns),
            "采购同比.sql 应该能够回溯到 js_sales 来源",
        )

    def test_source_table_names_are_normalized_to_lowercase(self) -> None:
        document = self.service._parse_sql_document(
            "mixed_case.sql",
            "SELECT A.ID, b.Name FROM JS_SALES A JOIN js_sales_b b ON A.ID = b.ID",
        )
        dataset = self.service._build_dataset([document], import_warnings=[])

        self.assertEqual(sorted(document.tables), ["js_sales", "js_sales_b"])
        self.assertEqual(sorted(document.joins), ["js_sales_b"])
        self.assertTrue(all((column.get("source_table") or "").islower() for column in document.columns))
        self.assertTrue(all((item.source or "").islower() for item in dataset.items if item.source not in {"unknown", "derived"}))
        self.assertIn("js_sales", dataset.meta["join_graph"])
        self.assertIn("js_sales_b", dataset.meta["join_graph"]["js_sales"])

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

    def test_document_import_warnings_distinguish_expression_lineage_and_constant(self) -> None:
        document = ParsedSqlDocument(
            name="demo.sql",
            content="select round(t1.a + t2.b, 2) as c, 1 as d",
            tables=["t1", "t2"],
            columns=[
                {
                    "name": "c",
                    "source_table": "derived",
                    "column_name": "t1.a, t2.b",
                    "source_tables": "t1, t2",
                    "original_expr": "ROUND(t1.a + t2.b, 2)",
                },
                {
                    "name": "d",
                    "source_table": "derived",
                    "column_name": "d",
                    "source_tables": "",
                    "original_expr": "1",
                },
            ],
            joins=[],
            parser="sqlglot_ast",
        )

        warnings = self.service._build_document_import_warnings(document)

        self.assertTrue(any("已提取依赖来源的表达式字段" in warning for warning in warnings))
        self.assertTrue(any("常量/无法归属的派生字段" in warning for warning in warnings))

    def test_build_item_source_detail_exposes_expression_dependencies(self) -> None:
        dataset = SceneDataset(
            scene="sql",
            entities=[Entity(id="sql_1", name="demo.sql")],
            items=[
                Item(
                    id="derived::库存金额",
                    name="库存金额",
                    group="derived",
                    source="derived",
                    item_type="column",
                    meta={
                        "source_tables": "gl, oh",
                        "column_name": "gl.nabprice, gl.noutmny, gl.noutnum, oh.nonhandnum",
                        "original_expr": "ROUND(oh.nonhandnum * COALESCE(gl.nabprice, gl.noutmny / gl.noutnum), 2)",
                    },
                )
            ],
            relations=[Relation(entity_id="sql_1", item_id="derived::库存金额")],
            constraints=ConstraintConfig(),
        )

        self.assertEqual(_build_item_source_label(dataset, 0), "表达式依赖(gl+oh)")
        detail = _build_item_source_detail(dataset, 0)
        self.assertIn("依赖表: gl, oh", detail)
        self.assertIn("参与列: gl.nabprice, gl.noutmny, gl.noutnum, oh.nonhandnum", detail)
        self.assertIn("原始表达式:", detail)

    def test_subquery_join_tables_appear_in_join_graph(self) -> None:
        sql = """
        SELECT oh.id, gl.amount
        FROM ic_onhandnum oh
        LEFT JOIN (
            SELECT gl1.* FROM ia_generalledger gl1
            WHERE gl1.dr = 0
        ) gl ON oh.pk = gl.cinventoryid
        """
        document = self.service._parse_sql_document("subquery_join.sql", sql)
        dataset = self.service._build_dataset([document], import_warnings=[])
        join_graph = dataset.meta.get("join_graph", {})

        ia_neighbours = set(join_graph.get("ia_generalledger", {}).keys())
        ic_neighbours = set(join_graph.get("ic_onhandnum", {}).keys())
        self.assertIn("ia_generalledger", ic_neighbours | ia_neighbours,
                       "子查询内的 ia_generalledger 应通过穿透出现在 JOIN 图中")

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

    def test_sanitize_vendor_sql_strips_create_materialized_view_preamble(self) -> None:
        mv_sql = (
            "CREATE MATERIALIZED VIEW IF NOT EXISTS MV_TEST\n"
            "COMMENT 'test'\n"
            "DISTRIBUTED BY HASH(id) BUCKETS 32\n"
            "ORDER BY (id)\n"
            "REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)\n"
            "PROPERTIES (\n"
            "    \"enable_spill\" = \"true\"\n"
            ")\n"
            "AS\n"
            "SELECT a.id, b.name FROM t1 a JOIN t2 b ON a.id = b.fk_id"
        )

        result, notes = self.service._sanitize_vendor_sql(mv_sql)

        self.assertTrue(result.strip().startswith("SELECT"))
        self.assertTrue(any("MATERIALIZED VIEW" in note for note in notes))

    def test_sanitize_vendor_sql_strips_create_or_replace_view(self) -> None:
        view_sql = "CREATE OR REPLACE VIEW v_test AS SELECT id FROM t1"

        result, notes = self.service._sanitize_vendor_sql(view_sql)

        self.assertEqual(result.strip(), "SELECT id FROM t1")
        self.assertTrue(any("VIEW" in note for note in notes))

    def test_sanitize_vendor_sql_leaves_plain_select_unchanged(self) -> None:
        plain_sql = "SELECT a.id, b.name FROM t1 a JOIN t2 b ON a.id = b.fk_id"

        result, notes = self.service._sanitize_vendor_sql(plain_sql)

        self.assertEqual(result, plain_sql)
        self.assertFalse(any("VIEW" in note for note in notes))

    def test_materialized_view_file_parsed_as_ast_with_correct_tables(self) -> None:
        raw = (SQL_VIEW_DIR / "01_MV_SALES_DETAIL.sql").read_bytes()
        content = self.service._decode_sql(raw)
        document = self.service._parse_sql_document("01_MV_SALES_DETAIL.sql", content)

        self.assertEqual(document.parser, "sqlglot_ast")
        self.assertTrue(document.columns, "物化视图应提取到字段列表")
        self.assertIn("so_squaredetail", document.tables)
        self.assertIn("bd_invbasdoc", document.tables)
        self.assertTrue(
            any("MATERIALIZED VIEW" in note for note in document.import_notes),
            "应记录物化视图 DDL 剥离提示",
        )

    def test_all_materialized_view_files_parse_successfully(self) -> None:
        view_files = sorted(SQL_VIEW_DIR.glob("*.sql"))
        self.assertTrue(view_files, "视图SQL 目录应包含 .sql 文件")

        for view_file in view_files:
            raw = view_file.read_bytes()
            content = self.service._decode_sql(raw)
            document = self.service._parse_sql_document(view_file.name, content)

            self.assertEqual(
                document.parser,
                "sqlglot_ast",
                f"{view_file.name} 应走 AST 解析而非 regex 回退",
            )
            self.assertTrue(document.columns, f"{view_file.name} 应提取到字段")
            self.assertTrue(document.tables, f"{view_file.name} 应提取到表名")

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

    def _build_hierarchy_dataset(self) -> SceneDataset:
        items = [
            Item(id="a::id", name="id", group="table_a", source="table_a"),
            Item(id="a::name", name="name", group="table_a", source="table_a"),
            Item(id="b::id", name="biz_id", group="table_b", source="table_b"),
            Item(id="b::name", name="biz_name", group="table_b", source="table_b"),
            Item(id="c::owner", name="owner_name", group="table_c", source="table_c"),
            Item(id="d::status", name="status_name", group="table_d", source="table_d"),
        ]
        return SceneDataset(
            scene="sql",
            entities=[
                Entity(id="sql_1", name="sql_1.sql"),
                Entity(id="sql_2", name="sql_2.sql"),
                Entity(id="sql_3", name="sql_3.sql"),
            ],
            items=items,
            relations=[
                Relation(entity_id="sql_1", item_id="a::id"),
                Relation(entity_id="sql_1", item_id="a::name"),
                Relation(entity_id="sql_1", item_id="b::id"),
                Relation(entity_id="sql_1", item_id="b::name"),
                Relation(entity_id="sql_2", item_id="a::id"),
                Relation(entity_id="sql_2", item_id="a::name"),
                Relation(entity_id="sql_2", item_id="b::id"),
                Relation(entity_id="sql_2", item_id="b::name"),
                Relation(entity_id="sql_2", item_id="c::owner"),
                Relation(entity_id="sql_3", item_id="a::id"),
                Relation(entity_id="sql_3", item_id="a::name"),
                Relation(entity_id="sql_3", item_id="b::id"),
                Relation(entity_id="sql_3", item_id="b::name"),
                Relation(entity_id="sql_3", item_id="d::status"),
            ],
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
        )

    def _build_fallback_base_dataset(self) -> SceneDataset:
        items = [
            Item(id="a::id", name="id", group="table_a", source="table_a"),
            Item(id="a::name", name="name", group="table_a", source="table_a"),
            Item(id="b::id", name="biz_id", group="table_b", source="table_b"),
            Item(id="b::name", name="biz_name", group="table_b", source="table_b"),
            Item(id="c::flag", name="c_flag", group="table_c", source="table_c"),
            Item(id="d::flag", name="d_flag", group="table_d", source="table_d"),
            Item(id="e::flag", name="e_flag", group="table_e", source="table_e"),
        ]
        return SceneDataset(
            scene="sql",
            entities=[
                Entity(id="sql_1", name="sql_1.sql"),
                Entity(id="sql_2", name="sql_2.sql"),
                Entity(id="sql_3", name="sql_3.sql"),
                Entity(id="sql_4", name="sql_4.sql"),
            ],
            items=items,
            relations=[
                Relation(entity_id="sql_1", item_id="a::id"),
                Relation(entity_id="sql_1", item_id="a::name"),
                Relation(entity_id="sql_1", item_id="b::id"),
                Relation(entity_id="sql_1", item_id="b::name"),
                Relation(entity_id="sql_1", item_id="c::flag"),
                Relation(entity_id="sql_2", item_id="a::id"),
                Relation(entity_id="sql_2", item_id="a::name"),
                Relation(entity_id="sql_2", item_id="b::id"),
                Relation(entity_id="sql_2", item_id="b::name"),
                Relation(entity_id="sql_2", item_id="d::flag"),
                Relation(entity_id="sql_3", item_id="a::id"),
                Relation(entity_id="sql_3", item_id="a::name"),
                Relation(entity_id="sql_3", item_id="b::id"),
                Relation(entity_id="sql_3", item_id="b::name"),
                Relation(entity_id="sql_3", item_id="e::flag"),
                Relation(entity_id="sql_4", item_id="a::id"),
                Relation(entity_id="sql_4", item_id="a::name"),
                Relation(entity_id="sql_4", item_id="b::id"),
                Relation(entity_id="sql_4", item_id="b::name"),
                Relation(entity_id="sql_4", item_id="c::flag"),
            ],
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
        )

    def _build_same_signature_standalone_dataset(self) -> SceneDataset:
        items = [
            Item(id="a::id", name="id", group="table_a", source="table_a"),
            Item(id="a::name", name="name", group="table_a", source="table_a"),
            Item(id="a::flag", name="flag", group="table_a", source="table_a"),
            Item(id="b::id", name="biz_id", group="table_b", source="table_b"),
            Item(id="b::name", name="biz_name", group="table_b", source="table_b"),
            Item(id="b::flag", name="biz_flag", group="table_b", source="table_b"),
        ]
        return SceneDataset(
            scene="sql",
            entities=[
                Entity(id="sql_1", name="sql_1.sql"),
                Entity(id="sql_2", name="sql_2.sql"),
                Entity(id="sql_3", name="sql_3.sql"),
            ],
            items=items,
            relations=[
                Relation(entity_id="sql_1", item_id="a::id"),
                Relation(entity_id="sql_1", item_id="b::id"),
                Relation(entity_id="sql_2", item_id="a::name"),
                Relation(entity_id="sql_2", item_id="b::name"),
                Relation(entity_id="sql_3", item_id="a::flag"),
                Relation(entity_id="sql_3", item_id="b::flag"),
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

    def test_build_sql_unit_groups_extracts_base_unit_from_shared_sources(self) -> None:
        dataset = self._build_hierarchy_dataset()
        units = [
            {"id": "unit-base", "item_indices": [0, 1, 2, 3], "entity_indices": [0], "score": 4.0},
            {"id": "unit-c", "item_indices": [0, 1, 2, 3, 4], "entity_indices": [1], "score": 5.0},
            {"id": "unit-d", "item_indices": [0, 1, 2, 3, 5], "entity_indices": [2], "score": 5.0},
        ]

        decorated = self.service._decorate_units(dataset, self._matrix(3, 6), units)
        final_units, groups = self.service._build_sql_unit_groups(dataset, self._matrix(3, 6), decorated)

        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]["base_unit"]["name"], "table_a+table_b基础宽表")
        self.assertEqual(groups[0]["base_unit"]["unit_level"], "base")
        self.assertEqual(len(groups[0]["units"]), 2)
        self.assertEqual({unit["name"] for unit in groups[0]["units"]}, {
            "table_a+table_b扩展宽表(+table_c)",
            "table_a+table_b扩展宽表(+table_d)",
        })
        self.assertEqual(
            {unit["unit_level"] for unit in final_units},
            {"base", "extension"},
        )

    def test_solve_response_includes_sql_unit_groups_and_extension_delta(self) -> None:
        dataset = self._build_hierarchy_dataset()
        original_select_units = self.service._select_units
        self.service._select_units = lambda *_args, **_kwargs: [
            {"id": "unit-base", "item_indices": [0, 1, 2, 3], "entity_indices": [0], "score": 4.0},
            {"id": "unit-c", "item_indices": [0, 1, 2, 3, 4], "entity_indices": [1], "score": 5.0},
            {"id": "unit-d", "item_indices": [0, 1, 2, 3, 5], "entity_indices": [2], "score": 5.0},
        ]
        try:
            result = self.service.solve(dataset)
        finally:
            self.service._select_units = original_select_units

        self.assertIsNotNone(result.sql_unit_groups)
        assert result.sql_unit_groups is not None
        self.assertEqual(len(result.sql_unit_groups), 1)
        group = result.sql_unit_groups[0]
        self.assertEqual(group.base_unit.name, "table_a+table_b基础宽表")
        self.assertEqual(group.base_unit.unit_level, "base")
        self.assertEqual(len(group.units), 2)
        self.assertEqual(
            {tuple(unit.extra_source_tables) for unit in group.units},
            {("table_c",), ("table_d",)},
        )
        self.assertTrue(all(unit.base_unit_id == group.base_unit.id for unit in group.units))

    def test_sql_hierarchy_insights_prioritize_base_group_and_filter_unknown_sources(self) -> None:
        dataset = self._build_hierarchy_dataset()
        original_select_units = self.service._select_units
        self.service._select_units = lambda *_args, **_kwargs: [
            {"id": "unit-base", "item_indices": [0, 1, 2, 3], "entity_indices": [0], "score": 4.0},
            {"id": "unit-c", "item_indices": [0, 1, 2, 3, 4], "entity_indices": [1], "score": 5.0},
            {"id": "unit-d", "item_indices": [0, 1, 2, 3, 5], "entity_indices": [2], "score": 5.0},
        ]
        try:
            result = self.service.solve(dataset)
        finally:
            self.service._select_units = original_select_units

        self.assertTrue(result.insights)
        self.assertIn("基础宽表", result.insights[0])
        self.assertTrue(any("扩展宽表" in item for item in result.insights))
        self.assertFalse(any("unknown" in item for item in result.insights))
        self.assertFalse(any("derived" in item for item in result.insights))

    def test_build_sql_unit_groups_prefers_high_support_small_core_base(self) -> None:
        dataset = self._build_fallback_base_dataset()
        units = [
            {"id": "unit-c1", "item_indices": [0, 1, 2, 3, 4], "entity_indices": [0], "score": 5.0},
            {"id": "unit-d", "item_indices": [0, 1, 2, 3, 5], "entity_indices": [1], "score": 5.0},
            {"id": "unit-e", "item_indices": [0, 1, 2, 3, 6], "entity_indices": [2], "score": 5.0},
            {"id": "unit-c2", "item_indices": [0, 1, 2, 3, 4], "entity_indices": [3], "score": 5.0},
        ]

        decorated = self.service._decorate_units(dataset, self._matrix(4, 7), units)
        final_units, groups = self.service._build_sql_unit_groups(dataset, self._matrix(4, 7), decorated)

        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]["base_unit"]["name"], "table_a+table_b基础宽表")
        self.assertEqual(groups[0]["base_unit"]["unit_level"], "base")
        self.assertEqual(len(groups[0]["units"]), 4)
        extension_names = [unit["name"] for unit in groups[0]["units"]]
        self.assertTrue(any(name.startswith("table_a+table_b扩展宽表(+table_c)") for name in extension_names))
        self.assertEqual(len(extension_names), len(set(extension_names)))
        self.assertEqual({unit["unit_level"] for unit in final_units}, {"base", "extension"})

    def test_build_sql_unit_groups_exposes_suggested_fields_by_threshold(self) -> None:
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
                Item(id="b::id", name="biz_id", group="table_b", source="table_b"),
                Item(id="b::name", name="biz_name", group="table_b", source="table_b"),
                Item(id="b::sub", name="sub_class", group="table_b", source="table_b"),
                Item(id="c::flag", name="c_flag", group="table_c", source="table_c"),
                Item(id="d::flag", name="d_flag", group="table_d", source="table_d"),
                Item(id="e::flag", name="e_flag", group="table_e", source="table_e"),
            ],
            relations=[],
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
        )
        dataset.constraints.base_field_threshold = 0.75
        dataset.constraints.suggested_field_threshold = 0.5
        units = [
            {"id": "unit-c1", "item_indices": [0, 1, 2, 3, 4, 5], "entity_indices": [0], "score": 6.0},
            {"id": "unit-d", "item_indices": [0, 1, 2, 3, 4, 6], "entity_indices": [1], "score": 6.0},
            {"id": "unit-e", "item_indices": [0, 1, 2, 3, 7], "entity_indices": [2], "score": 5.0},
            {"id": "unit-c2", "item_indices": [0, 1, 2, 3, 5], "entity_indices": [3], "score": 5.0},
        ]

        decorated = self.service._decorate_units(dataset, self._matrix(4, 8), units)
        _, groups = self.service._build_sql_unit_groups(dataset, self._matrix(4, 8), decorated)

        base_unit = groups[0]["base_unit"]
        self.assertEqual(base_unit["support_unit_count"], 4)
        self.assertEqual(base_unit["base_field_min_hits"], 3)
        self.assertEqual(base_unit["suggested_field_min_hits"], 2)
        self.assertEqual(base_unit["suggested_item_names"], ["sub_class"])
        self.assertEqual(base_unit["suggested_item_sources"], ["table_b"])
        self.assertEqual(base_unit["suggested_item_hits"], [2])

    def test_solve_groups_same_signature_standalone_variants_into_one_family(self) -> None:
        dataset = self._build_same_signature_standalone_dataset()
        original_select_units = self.service._select_units
        self.service._select_units = lambda *_args, **_kwargs: [
            {"id": "unit-1", "item_indices": [0, 3], "entity_indices": [0], "score": 2.0},
            {"id": "unit-2", "item_indices": [1, 4], "entity_indices": [1], "score": 2.0},
            {"id": "unit-3", "item_indices": [2, 5], "entity_indices": [2], "score": 2.0},
        ]
        try:
            result = self.service.solve(dataset)
        finally:
            self.service._select_units = original_select_units

        self.assertIsNotNone(result.sql_unit_groups)
        assert result.sql_unit_groups is not None
        self.assertEqual(len(result.sql_unit_groups), 1)

        family = result.sql_unit_groups[0]
        self.assertEqual(family.group_name, "table_a+table_b组合宽表族")
        self.assertEqual(family.base_unit.name, "table_a+table_b组合宽表1")
        self.assertEqual([unit.name for unit in family.units], [
            "table_a+table_b组合宽表2",
            "table_a+table_b组合宽表3",
        ])
        self.assertTrue(all(unit.unit_level == "standalone" for unit in [family.base_unit, *family.units]))

        summary_map = {metric.label: metric for metric in result.summary}
        self.assertEqual(summary_map["推荐宽表数"].hint, "基础 0 + 扩展 0 + 独立 3")

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

    def test_end_to_end_sql_solve_exposes_hierarchy_metadata(self) -> None:
        result = self._solve_cases(["采购发票.sql", "采购-供应商对比.sql", "采购型号明细.sql"])

        self.assertIsNotNone(result.sql_unit_groups)
        self.assertTrue(result.units)
        self.assertTrue(all(unit.unit_level in {"base", "extension", "standalone"} for unit in result.units))
        self.assertTrue(
            any(
                unit.name.startswith("bd_cubasdoc+po_invoice+po_invoice_b")
                or unit.name.startswith("bd_cubasdoc+bd_invbasdoc+po_invoice+po_invoice_b")
                for unit in result.units
            ),
            "多来源宽表命名应保持字母序稳定前缀",
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

        # derived 不是物理表，不应触发 JOIN 孤立警告（之前是误报）
        self.assertFalse(
            any("'derived'" in warning and "JOIN 图中孤立" in warning for warning in result.warnings),
            "derived 表达式字段不应被当做物理表参与 JOIN 连通性检查",
        )
        self.assertTrue(result.units)
        self.assertTrue(any(unit.sources for unit in result.units))


if __name__ == "__main__":
    unittest.main()
