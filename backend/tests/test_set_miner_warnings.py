from __future__ import annotations

import unittest
from pathlib import Path

from app.schemas.solve import Entity, Item, Relation, SceneDataset
from app.services.algorithms.set_miner import SetMinerService
from app.services.scenes.sql_importer import SqlImportService


REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_CASE_DIR = REPO_ROOT / "NC_SQL" / "starrocks_ai" / "案例"


class SetMinerWarningTests(unittest.TestCase):
    def setUp(self) -> None:
        self.import_service = SqlImportService()
        self.set_miner = SetMinerService()

    def _parse_case(self, file_name: str):
        raw = (SQL_CASE_DIR / file_name).read_bytes()
        content = self.import_service._decode_sql(raw)
        return self.import_service._parse_sql_document(file_name, content)

    def _solve_cases(self, file_names: list[str]):
        documents = [self._parse_case(file_name) for file_name in file_names]
        dataset = self.import_service._build_dataset(documents, import_warnings=[])
        return self.set_miner.solve(dataset)

    def _build_warning_dataset(
        self,
        join_graph: dict[str, dict[str, list]],
        items: list[Item],
        *,
        sql_name: str = "demo.sql",
    ) -> SceneDataset:
        entity = Entity(id="sql::1", name=sql_name)
        relations = [Relation(entity_id=entity.id, item_id=item.id) for item in items]
        return SceneDataset(
            scene="sql",
            entities=[entity],
            items=items,
            relations=relations,
            meta={"join_graph": join_graph},
        )

    def test_bridge_path_prevents_bd_psndoc_false_positive(self) -> None:
        document = self._parse_case("客户信息.sql")
        parsed_dataset = self.import_service._build_dataset([document], import_warnings=[])
        dataset = self._build_warning_dataset(
            parsed_dataset.meta["join_graph"],
            [
                Item(id="dept", name="部门", group="bd_deptdoc", source="bd_deptdoc"),
                Item(id="psn", name="业务员", group="bd_psndoc", source="bd_psndoc"),
            ],
            sql_name="客户信息.sql",
        )

        warnings = self.set_miner._check_join_reachability(
            dataset,
            [
                {
                    "name": "bd_deptdoc+bd_psndoc组合宽表1",
                    "item_ids": ["dept", "psn"],
                    "covered_entity_names": ["客户信息.sql"],
                }
            ],
        )

        self.assertFalse(
            warnings,
            "bd_deptdoc 与 bd_psndoc 可通过 bd_cumandoc 桥接，不应误报孤立",
        )

    def test_bridge_path_prevents_to_bill_false_positive(self) -> None:
        document = self._parse_case("NC仓库调拨表.sql")
        parsed_dataset = self.import_service._build_dataset([document], import_warnings=[])
        dataset = self._build_warning_dataset(
            parsed_dataset.meta["join_graph"],
            [
                Item(id="store", name="调入仓库", group="bd_stordoc", source="bd_stordoc"),
                Item(id="product", name="产品名称", group="bd_invbasdoc", source="bd_invbasdoc"),
                Item(id="date", name="the_date", group="to_bill", source="to_bill"),
            ],
            sql_name="NC仓库调拨表.sql",
        )

        warnings = self.set_miner._check_join_reachability(
            dataset,
            [
                {
                    "name": "bd_stordoc+to_bill扩展宽表(+bd_invbasdoc)",
                    "item_ids": ["store", "product", "date"],
                    "covered_entity_names": ["NC仓库调拨表.sql"],
                }
            ],
        )

        self.assertFalse(
            warnings,
            "to_bill 可通过 to_bill_b 桥接到 bd_stordoc / bd_invbasdoc，不应误报孤立",
        )

    def test_derived_lineage_tables_participate_in_join_reachability(self) -> None:
        dataset = self._build_warning_dataset(
            {
                "bd_invbasdoc": {"so_saleinvoice": [{}]},
                "so_saleinvoice": {"bd_invbasdoc": [{}]},
            },
            [
                Item(
                    id="rank",
                    name="排名",
                    group="derived",
                    source="derived",
                    meta={
                        "source_tables": "bd_invbasdoc, so_saleinvoice",
                        "column_name": "bd_invbasdoc.invcode, so_saleinvoice.csaleid",
                        "original_expr": "ROW_NUMBER() OVER (...)",
                    },
                )
            ],
        )

        warnings = self.set_miner._check_join_reachability(
            dataset,
            [
                {
                    "name": "derived扩展宽表",
                    "item_ids": ["rank"],
                    "covered_entity_names": ["demo.sql"],
                }
            ],
        )

        self.assertFalse(
            warnings,
            "带血缘的 derived 字段应按其物理来源表参与连通性判断，而不是被忽略或误报",
        )
        self.assertFalse(
            self.set_miner._check_expression_source_completeness(
                dataset,
                [
                    {
                        "name": "derived扩展宽表",
                        "item_ids": ["rank"],
                        "covered_entity_names": ["demo.sql"],
                    }
                ],
            ),
            "已解析出来源表的表达式字段不应再报血缘不完整",
        )

    def test_unresolved_derived_fields_emit_separate_warning_with_sql_names(self) -> None:
        dataset = self._build_warning_dataset(
            {},
            [
                Item(
                    id="rank",
                    name="排名",
                    group="derived",
                    source="derived",
                    meta={
                        "source_tables": "",
                        "column_name": "",
                        "original_expr": "1",
                    },
                )
            ],
            sql_name="NC仓库出货表.sql",
        )

        warnings = self.set_miner._check_expression_source_completeness(
            dataset,
            [
                {
                    "name": "字段扩展宽表",
                    "item_ids": ["rank"],
                    "covered_entity_names": ["NC仓库出货表.sql"],
                }
            ],
        )

        self.assertEqual(len(warnings), 1)
        self.assertIn("表达式字段 排名", warnings[0])
        self.assertIn("NC仓库出货表.sql", warnings[0])
        self.assertIn("不会参与 JOIN 孤立判断", warnings[0])

    def test_payable_cases_do_not_report_gm_as_isolated_table(self) -> None:
        result = self._solve_cases(
            ["供应商预付明细.sql", "应付-数据底表.sql", "应付预提.sql", "原装-供应商预提.sql"]
        )

        self.assertFalse(
            any("['gm'] 在 JOIN 图中孤立" in warning for warning in result.warnings),
            "gm 是外层 JOIN 别名，不应被当作真实孤立表出现在最终告警中",
        )


if __name__ == "__main__":
    unittest.main()
