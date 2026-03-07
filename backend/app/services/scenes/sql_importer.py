from __future__ import annotations

import re
from dataclasses import dataclass
from itertools import combinations

from fastapi import HTTPException, UploadFile
from sqlglot import exp, parse_one

from app.schemas.solve import ConstraintConfig, Entity, ImportPreviewResponse, Item, Relation, SceneDataset

SUPPORTED_SQL_SUFFIXES = (".sql",)


@dataclass
class ParsedSqlDocument:
    name: str
    content: str
    tables: list[str]
    columns: list[dict[str, str | None]]
    joins: list[str]
    parser: str


@dataclass
class ResolvedField:
    field_name: str
    primary_source: str | None
    source_tables: list[str]
    source_columns: list[str]


class SqlImportService:
    async def preview_uploads(self, files: list[UploadFile]) -> ImportPreviewResponse:
        documents = await self._parse_uploads(files)
        dataset = self._build_dataset(documents)
        warnings = self._build_warnings(documents, dataset)
        return ImportPreviewResponse(
            scene="sql",
            entity_count=len(dataset.entities),
            item_count=len(dataset.items),
            relation_count=len(dataset.relations),
            sample_entities=[entity.name for entity in dataset.entities[:5]],
            sample_items=[item.name for item in dataset.items[:8]],
            detected_columns={
                "import_mode": "batch_sql_files",
                "file_count": str(len(documents)),
                "parser": ", ".join(sorted({document.parser for document in documents})),
            },
            warnings=warnings,
        )

    async def solve_uploads(self, files: list[UploadFile]) -> SceneDataset:
        documents = await self._parse_uploads(files)
        return self._build_dataset(documents)

    async def _parse_uploads(self, files: list[UploadFile]) -> list[ParsedSqlDocument]:
        if not files:
            raise HTTPException(status_code=400, detail="请至少上传一个 .sql 文件。")

        documents: list[ParsedSqlDocument] = []
        for upload in files:
            filename = upload.filename or ""
            if not filename.lower().endswith(SUPPORTED_SQL_SUFFIXES):
                raise HTTPException(status_code=400, detail=f"文件 `{filename}` 不是 .sql 格式。")

            raw = await upload.read()
            content = self._decode_sql(raw)
            documents.append(self._parse_sql_document(filename, content))

        if not documents:
            raise HTTPException(status_code=400, detail="未解析到有效的 SQL 文件。")
        return documents

    def _decode_sql(self, raw: bytes) -> str:
        for encoding in ("utf-8-sig", "utf-8", "gbk", "gb2312"):
            try:
                return raw.decode(encoding)
            except UnicodeDecodeError:
                continue
        raise HTTPException(status_code=400, detail="SQL 文件编码无法识别，请保存为 UTF-8 或 GBK。")

    def _parse_sql_document(self, filename: str, content: str) -> ParsedSqlDocument:
        cleaned = self._remove_comments(content)
        normalized = " ".join(cleaned.split()).strip().rstrip(";")

        try:
            expression = parse_one(normalized, error_level="raise")
            return self._parse_with_ast(filename, content, expression)
        except Exception:
            alias_map, joins = self._extract_tables_and_aliases(normalized)
            columns = self._extract_columns_by_regex(normalized, alias_map)
            tables = sorted(set(alias_map.values()))
            return ParsedSqlDocument(
                name=filename,
                content=content,
                tables=tables,
                columns=columns,
                joins=joins,
                parser="regex_fallback",
            )

    def _parse_with_ast(self, filename: str, content: str, expression: exp.Expression) -> ParsedSqlDocument:
        cte_map = self._build_cte_map(expression)
        tables = sorted(self._collect_base_tables(expression, cte_map))
        joins = sorted(self._collect_join_tables(expression, cte_map))
        resolved_fields = self._collect_resolved_fields(expression, cte_map)
        columns = [
            {
                "name": field.field_name,
                "source_table": field.primary_source,
                "column_name": ", ".join(field.source_columns) if field.source_columns else field.field_name,
                "source_tables": ", ".join(field.source_tables),
            }
            for field in resolved_fields
        ]
        return ParsedSqlDocument(
            name=filename,
            content=content,
            tables=tables,
            columns=columns,
            joins=joins,
            parser="sqlglot_ast",
        )

    def _remove_comments(self, sql: str) -> str:
        sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
        sql = re.sub(r"--.*?$", " ", sql, flags=re.M)
        return sql

    def _extract_tables_and_aliases(self, sql: str) -> tuple[dict[str, str], list[str]]:
        pattern = re.compile(
            r"\b(from|join)\s+([`\"\[\]\w\.]+)(?:\s+(?:as\s+)?([A-Za-z_]\w*))?",
            flags=re.I,
        )
        alias_map: dict[str, str] = {}
        joins: list[str] = []
        for match in pattern.finditer(sql):
            keyword, raw_table, alias = match.groups()
            table = raw_table.strip("`[]\"")
            if table.startswith("("):
                continue
            alias_key = alias or table.split(".")[-1]
            alias_map[alias_key] = table
            if keyword.lower() == "join":
                joins.append(table)
        return alias_map, joins

    def _extract_columns_by_regex(self, sql: str, alias_map: dict[str, str]) -> list[dict[str, str | None]]:
        select_match = re.search(r"\bselect\b(.*?)\bfrom\b", sql, flags=re.I | re.S)
        if not select_match:
            return []

        segment = select_match.group(1)
        expressions = self._split_select_expressions(segment)
        columns: list[dict[str, str | None]] = []
        seen: set[str] = set()

        for expression in expressions:
            cleaned = expression.strip()
            if not cleaned:
                continue

            source_table = None
            source_column = None
            qualified_matches = re.findall(r"([A-Za-z_]\w*)\.([A-Za-z_]\w*)", cleaned)
            if qualified_matches:
                alias, column = qualified_matches[-1]
                source_table = alias_map.get(alias, alias)
                source_column = column
            else:
                bare_matches = re.findall(r"\b([A-Za-z_]\w*)\b", cleaned)
                if bare_matches:
                    candidate = bare_matches[-1]
                    if candidate.lower() not in {"as", "sum", "count", "avg", "min", "max", "distinct", "case", "when", "then", "else", "end"}:
                        source_column = candidate

            output_alias_match = re.search(r"\bas\s+([A-Za-z_]\w*)$", cleaned, flags=re.I)
            if output_alias_match:
                field_name = output_alias_match.group(1)
            elif source_table and source_column:
                field_name = f"{source_table}.{source_column}"
            elif source_column:
                field_name = source_column
            else:
                field_name = re.sub(r"\s+", " ", cleaned)[:80]

            dedupe_key = f"{source_table or 'unknown'}::{field_name}"
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            columns.append(
                {
                    "name": field_name,
                    "source_table": source_table,
                    "column_name": source_column or field_name,
                    "source_tables": source_table or "",
                }
            )

        return columns

    def _split_select_expressions(self, segment: str) -> list[str]:
        parts: list[str] = []
        current: list[str] = []
        depth = 0
        for char in segment:
            if char == "(":
                depth += 1
            elif char == ")":
                depth = max(depth - 1, 0)
            elif char == "," and depth == 0:
                parts.append("".join(current))
                current = []
                continue
            current.append(char)
        if current:
            parts.append("".join(current))
        return parts

    def _build_cte_map(self, expression: exp.Expression) -> dict[str, exp.Expression]:
        cte_map: dict[str, exp.Expression] = {}
        with_clause = expression.args.get("with")
        if not with_clause:
            return cte_map

        for cte in with_clause.find_all(exp.CTE):
            alias = cte.alias_or_name
            if alias:
                cte_map[alias] = cte.this
        return cte_map

    def _collect_base_tables(self, expression: exp.Expression, cte_map: dict[str, exp.Expression]) -> set[str]:
        tables: set[str] = set()
        for table in expression.find_all(exp.Table):
            table_name = table.name
            if not table_name or table_name in cte_map:
                continue
            tables.add(table.sql(dialect=""))
        return tables

    def _collect_join_tables(self, expression: exp.Expression, cte_map: dict[str, exp.Expression]) -> set[str]:
        join_tables: set[str] = set()
        for join in expression.find_all(exp.Join):
            table = join.this
            if isinstance(table, exp.Table):
                table_name = table.name
                if table_name and table_name not in cte_map:
                    join_tables.add(table.sql(dialect=""))
        return join_tables

    def _collect_resolved_fields(
        self,
        expression: exp.Expression,
        cte_map: dict[str, exp.Expression],
    ) -> list[ResolvedField]:
        select_expressions = list(expression.find_all(exp.Select))
        if not select_expressions:
            return []

        outermost_select = select_expressions[0]
        alias_map = self._build_alias_map(outermost_select, cte_map)
        resolved_fields: list[ResolvedField] = []
        seen: set[str] = set()

        for projection in outermost_select.expressions:
            field = self._resolve_projection(projection, alias_map, cte_map)
            dedupe_key = f"{field.primary_source or 'derived'}::{field.field_name}"
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            resolved_fields.append(field)

        return resolved_fields

    def _build_alias_map(self, select_expr: exp.Select, cte_map: dict[str, exp.Expression]) -> dict[str, dict[str, object]]:
        alias_map: dict[str, dict[str, object]] = {}
        from_expr = select_expr.args.get("from")
        if from_expr is None:
            return alias_map

        for source in [from_expr.this, *[join.this for join in select_expr.args.get("joins", [])]]:
            if source is None:
                continue
            if isinstance(source, exp.Table):
                alias = source.alias_or_name or source.name
                table_name = source.sql(dialect="")
                if source.name in cte_map:
                    alias_map[alias] = {
                        "type": "cte",
                        "expression": cte_map[source.name],
                    }
                else:
                    alias_map[alias] = {
                        "type": "table",
                        "table": table_name,
                    }
            elif isinstance(source, exp.Subquery):
                alias = source.alias_or_name
                if alias:
                    alias_map[alias] = {
                        "type": "subquery",
                        "expression": source.this,
                    }
        return alias_map

    def _resolve_projection(
        self,
        projection: exp.Expression,
        alias_map: dict[str, dict[str, object]],
        cte_map: dict[str, exp.Expression],
    ) -> ResolvedField:
        field_name = projection.alias_or_name or projection.sql(dialect="")
        lineage_tables: set[str] = set()
        lineage_columns: set[str] = set()

        for column in projection.find_all(exp.Column):
            resolved = self._resolve_column(column, alias_map, cte_map)
            lineage_tables.update(resolved["tables"])
            lineage_columns.update(resolved["columns"])

        primary_source = None
        if len(lineage_tables) == 1:
            primary_source = next(iter(lineage_tables))
        elif len(lineage_tables) > 1:
            primary_source = "derived"

        return ResolvedField(
            field_name=field_name,
            primary_source=primary_source,
            source_tables=sorted(lineage_tables),
            source_columns=sorted(lineage_columns),
        )

    def _resolve_column(
        self,
        column: exp.Column,
        alias_map: dict[str, dict[str, object]],
        cte_map: dict[str, exp.Expression],
    ) -> dict[str, set[str]]:
        table_alias = column.table
        column_name = column.name

        if table_alias and table_alias in alias_map:
            alias_info = alias_map[table_alias]
            if alias_info["type"] == "table":
                table_name = str(alias_info["table"])
                return {
                    "tables": {table_name},
                    "columns": {f"{table_name}.{column_name}"},
                }
            if alias_info["type"] in {"cte", "subquery"}:
                return self._resolve_from_nested_query(
                    alias_info["expression"],
                    column_name,
                    cte_map,
                )

        if table_alias:
            return {"tables": {table_alias}, "columns": {f"{table_alias}.{column_name}"}}

        base_tables = {
            str(info["table"])
            for info in alias_map.values()
            if info["type"] == "table"
        }
        if len(base_tables) == 1:
            base_table = next(iter(base_tables))
            return {"tables": {base_table}, "columns": {f"{base_table}.{column_name}"}}

        return {"tables": set(), "columns": {column_name}}

    def _resolve_from_nested_query(
        self,
        nested_expression: exp.Expression,
        requested_name: str,
        cte_map: dict[str, exp.Expression],
    ) -> dict[str, set[str]]:
        select_expr = nested_expression.find(exp.Select)
        if select_expr is None:
            return {"tables": set(), "columns": {requested_name}}

        nested_alias_map = self._build_alias_map(select_expr, cte_map)
        for projection in select_expr.expressions:
            alias = projection.alias_or_name or projection.sql(dialect="")
            if alias == requested_name:
                resolved = self._resolve_projection(projection, nested_alias_map, cte_map)
                return {
                    "tables": set(resolved.source_tables),
                    "columns": set(resolved.source_columns or [requested_name]),
                }

        return {"tables": set(), "columns": {requested_name}}

    def _build_dataset(self, documents: list[ParsedSqlDocument]) -> SceneDataset:
        entities = [Entity(id=f"sql_{idx + 1}", name=document.name) for idx, document in enumerate(documents)]

        item_map: dict[str, Item] = {}
        relations: list[Relation] = []
        for idx, document in enumerate(documents):
            entity_id = f"sql_{idx + 1}"
            for column in document.columns:
                source_table = column["source_table"] or "unknown"
                item_id = f"{source_table}::{column['name']}"
                if item_id not in item_map:
                    item_map[item_id] = Item(
                        id=item_id,
                        name=str(column["name"]),
                        group=source_table,
                        source=source_table,
                        item_type="column",
                        meta={
                            "source_tables": str(column.get("source_tables", "")),
                            "column_name": str(column.get("column_name", "")),
                        },
                    )
                relations.append(Relation(entity_id=entity_id, item_id=item_id))

        return SceneDataset(
            scene="sql",
            entities=entities,
            items=list(item_map.values()),
            relations=relations,
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
        )

    def _build_warnings(self, documents: list[ParsedSqlDocument], dataset: SceneDataset) -> list[str]:
        warnings: list[str] = []
        if any(not document.columns for document in documents):
            warnings.append("部分 SQL 未提取到字段，可能存在复杂子查询、方言函数或动态 SQL。")
        if any(len(document.tables) > 4 for document in documents):
            warnings.append("部分 SQL 涉及较多源表，建议后续补充 JOIN 深度和粒度校验。")
        if len(dataset.items) == 0:
            warnings.append("当前未构造出有效字段矩阵，建议检查 SQL 内容是否为标准 SELECT 查询。")
        if any(document.parser == "regex_fallback" for document in documents):
            warnings.append("部分 SQL 走了正则回退解析，说明存在当前 AST 解析未完全覆盖的方言或语法。")
        warnings.append("当前 SQL 解析已优先支持 CTE、子查询、复杂字段表达式与别名链，极端方言仍建议补充人工校验。")
        return warnings
