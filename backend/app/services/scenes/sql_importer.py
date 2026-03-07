from __future__ import annotations

import re
from collections import defaultdict, deque
from dataclasses import dataclass, field
from itertools import combinations

from fastapi import HTTPException, UploadFile
from sqlglot import exp, parse_one

from app.schemas.solve import ConstraintConfig, Entity, ImportPreviewResponse, Item, Relation, SceneDataset

SUPPORTED_SQL_SUFFIXES = (".sql", ".txt")


@dataclass
class JoinEdge:
    """两张表之间一条等值 JOIN 条件，来源于某个 SQL 的 ON 子句。"""
    left_table: str
    right_table: str
    left_col: str
    right_col: str
    sql_source: str


@dataclass
class ParsedSqlDocument:
    name: str
    content: str
    tables: list[str]
    columns: list[dict[str, str | None]]
    joins: list[str]
    parser: str
    join_edges: list[JoinEdge] = field(default_factory=list)
    granularity_keys: list[str] = field(default_factory=list)  # GROUP BY 列，推断粒度键
    alias_to_table: dict[str, str] = field(default_factory=dict)  # {别名/短名 -> 真实物理表名}


@dataclass
class ResolvedField:
    field_name: str
    primary_source: str | None
    source_tables: list[str]
    source_columns: list[str]
    original_expr: str = ""  # 原始 SQL 表达式，当 field_name 是简化占位名时使用


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
            raise HTTPException(status_code=400, detail="请至少上传一个 .sql 或 .txt 文件。")

        documents: list[ParsedSqlDocument] = []
        parse_errors: list[str] = []
        for upload in files:
            filename = upload.filename or ""
            if not filename.lower().endswith(SUPPORTED_SQL_SUFFIXES):
                raise HTTPException(status_code=400, detail=f"文件 `{filename}` 不是 .sql 或 .txt 格式。")

            raw = await upload.read()
            content = self._decode_sql(raw)
            try:
                documents.append(self._parse_sql_document(filename, content))
            except Exception as exc:
                parse_errors.append(f"{filename}: {exc}")

        if not documents:
            detail = "未解析到有效的 SQL 文件。"
            if parse_errors:
                detail += " 解析错误：" + "；".join(parse_errors)
            raise HTTPException(status_code=400, detail=detail)
        return documents

    def _decode_sql(self, raw: bytes) -> str:
        for encoding in ("utf-8-sig", "utf-8", "gbk", "gb2312"):
            try:
                return raw.decode(encoding)
            except UnicodeDecodeError:
                continue
        raise HTTPException(status_code=400, detail="SQL 文件编码无法识别，请保存为 UTF-8 或 GBK。")

    def _sanitize_vendor_sql(self, sql: str) -> str:
        """处理 ERP/BI 平台特有的非标准语法，使 sqlglot 和正则解析器能正常处理。

        覆盖场景：
        - NC 用友 / Superset：#变量名# 动态参数占位符 → 替换为合法字符串字面量 'NC_PARAM'
        - Oracle DB Link 跨库引用：TABLE@dblink → TABLE（去掉 @dblink 部分）
        - 裸中文列别名（不带引号）：col 中文 → col（去掉中文别名，保留字段表达式）
        - 末尾多余分号
        """
        # 1. NC/用友 动态参数 #varname# → 'NC_PARAM'
        sql = re.sub(r"#[^#\s]+#", "'NC_PARAM'", sql)

        # 2. Oracle DB Link：table@dblink 或 schema.table@dblink → 去掉 @dblink
        sql = re.sub(r"(@\w+)", "", sql)

        # 3. 裸中文别名：紧跟在字段表达式后面的中文词（无逗号/关键字分隔）
        #    例：cu.custname 客户  →  cu.custname
        #    注意：不能破坏 CASE WHEN 里的中文字符串字面量（已用引号包裹，不匹配）
        sql = re.sub(r"(?<=[)\w])\s+([\u4e00-\u9fff][\u4e00-\u9fff\w（）()]*)", " ", sql)

        return sql

    def _parse_sql_document(self, filename: str, content: str) -> ParsedSqlDocument:
        cleaned = self._remove_comments(content)
        cleaned = self._sanitize_vendor_sql(cleaned)
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
        join_edges = self._collect_join_edges(expression, cte_map, filename)
        granularity_keys = self._infer_granularity_keys(expression, cte_map)
        # 收集全文所有 SELECT 层的别名→真实表名映射
        alias_to_table: dict[str, str] = {}
        for select_expr in expression.find_all(exp.Select):
            amap = self._build_alias_map(select_expr, cte_map)
            for alias, info in amap.items():
                if info.get("type") == "table":
                    alias_to_table[alias] = str(info["table"])
        columns = [
            {
                "name": field.field_name,
                "source_table": field.primary_source,
                "column_name": ", ".join(field.source_columns) if field.source_columns else field.field_name,
                "source_tables": ", ".join(field.source_tables),
                "original_expr": field.original_expr,
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
            join_edges=join_edges,
            granularity_keys=granularity_keys,
            alias_to_table=alias_to_table,
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

        segment = select_match.group(1).strip()

        # SELECT * → 尝试找内层子查询的字段列表
        if segment.strip() == '*':
            inner_match = re.search(r"\(\s*select\b(.*?)\bfrom\b", sql, flags=re.I | re.S)
            if inner_match:
                segment = inner_match.group(1).strip()
            else:
                return []
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
                # 无别名的复杂表达式（CASE WHEN / 聚合等）：提取出现的列名拼短名
                col_refs = re.findall(r"\b([A-Za-z_]\w*)\b", cleaned)
                _skip = {"as","sum","count","avg","min","max","case","when","then","else","end","nvl","coalesce","distinct","and","or","not","is","null","in","like"}
                meaningful = [c for c in col_refs if c.lower() not in _skip][:2]
                field_name = "_".join(meaningful) + "_expr" if meaningful else "derived_expr"

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

    def _collect_join_edges(
        self,
        expression: exp.Expression,
        cte_map: dict[str, exp.Expression],
        sql_source: str,
    ) -> list[JoinEdge]:
        """从 AST 的所有 JOIN ... ON 子句提取等值条件，构建 JOIN 边列表。

        支持：
        - 直接等值：ON a.id = b.fk_id
        - USING(col)：转为 (left_table.col, right_table.col)
        - 忽略 CTE 名（只关注真实物理表之间的关系）
        """
        edges: list[JoinEdge] = []
        # 对每个 SELECT 层独立处理，避免子查询 JOIN 影响外层语义
        for select_expr in expression.find_all(exp.Select):
            from_expr = select_expr.args.get("from_")
            if from_expr is None:
                continue
            left_source = from_expr.this
            left_table = self._resolve_table_name(left_source, cte_map)

            for join in select_expr.args.get("joins", []):
                right_source = join.this
                right_table = self._resolve_table_name(right_source, cte_map)
                if not left_table or not right_table:
                    continue

                on_expr = join.args.get("on")
                using_expr = join.args.get("using")

                if on_expr:
                    # 递归提取所有等值 EQ 条件
                    for eq in on_expr.find_all(exp.EQ):
                        left_col = self._extract_col_from_eq_side(eq.left)
                        right_col = self._extract_col_from_eq_side(eq.right)
                        if left_col and right_col:
                            # 根据列的表限定符决定方向
                            l_tbl = eq.left.table if isinstance(eq.left, exp.Column) else ""
                            r_tbl = eq.right.table if isinstance(eq.right, exp.Column) else ""
                            # 解析别名到真实表名
                            alias_map = self._build_alias_map(select_expr, cte_map)
                            l_real = self._alias_to_table(l_tbl, alias_map, cte_map)
                            r_real = self._alias_to_table(r_tbl, alias_map, cte_map)
                            if l_real and r_real and l_real != r_real:
                                edges.append(JoinEdge(
                                    left_table=l_real,
                                    right_table=r_real,
                                    left_col=left_col,
                                    right_col=right_col,
                                    sql_source=sql_source,
                                ))
                elif using_expr:
                    # USING(col) → left_table.col = right_table.col
                    for col in using_expr.find_all(exp.Column):
                        col_name = col.name
                        if col_name and left_table and right_table:
                            edges.append(JoinEdge(
                                left_table=left_table,
                                right_table=right_table,
                                left_col=col_name,
                                right_col=col_name,
                                sql_source=sql_source,
                            ))
        return edges

    def _resolve_table_name(self, source: exp.Expression | None, cte_map: dict[str, exp.Expression]) -> str:
        """从 FROM/JOIN 的 source 节点解析出真实表名（跳过 CTE 和子查询）。"""
        if source is None:
            return ""
        if isinstance(source, exp.Table):
            name = source.name
            if name and name not in cte_map:
                return name
        return ""

    def _extract_col_from_eq_side(self, node: exp.Expression) -> str:
        """从等值条件的一侧提取列名（支持 table.col 和裸 col）。"""
        if isinstance(node, exp.Column):
            return node.name
        return ""

    def _alias_to_table(
        self,
        alias: str,
        alias_map: dict[str, dict[str, object]],
        cte_map: dict[str, exp.Expression],
    ) -> str:
        """把表别名解析成真实物理表名，CTE 返回空（不计入物理 JOIN 图）。"""
        if not alias:
            return ""
        info = alias_map.get(alias)
        if info is None:
            return alias
        if info["type"] == "table":
            return str(info["table"])
        # CTE 或子查询，不计入物理表 JOIN 图
        return ""

    def _infer_granularity_keys(
        self,
        expression: exp.Expression,
        cte_map: dict[str, exp.Expression],
    ) -> list[str]:
        """从 SQL 推断粒度键：优先取最外层 GROUP BY 的列；无 GROUP BY 则取 FROM 主表的猜测主键。

        规则：
        1. 最外层 SELECT 有 GROUP BY → GROUP BY 的列名作为粒度键
        2. 没有 GROUP BY → 找 SELECT 列表里符合主键特征的列（_id 结尾、pk_ 开头）
        3. 都没有 → 空列表（行粒度，粒度键未知）
        """
        select_expressions = list(expression.find_all(exp.Select))
        if not select_expressions:
            return []
        outermost = select_expressions[0]

        # 1. GROUP BY
        group_by = outermost.args.get("group")
        if group_by:
            keys = []
            for col in group_by.find_all(exp.Column):
                keys.append(col.name)
            if keys:
                return keys

        # 2. 从 SELECT 列推断主键列
        pk_pattern = re.compile(r"^(pk_|.*_id$|.*_key$|.*_code$)", re.I)
        pk_cols = []
        for proj in outermost.expressions:
            name = proj.alias_or_name
            if name and pk_pattern.match(name):
                pk_cols.append(name)
        return pk_cols[:3]  # 最多保留3个，避免噪音

    def _collect_resolved_fields(
        self,
        expression: exp.Expression,
        cte_map: dict[str, exp.Expression],
    ) -> list[ResolvedField]:
        select_expressions = list(expression.find_all(exp.Select))
        if not select_expressions:
            return []

        outermost_select = select_expressions[0]

        # 如果最外层是 SELECT *，尝试穿透到内层子查询/CTE 获取真实字段
        projections = outermost_select.expressions
        if len(projections) == 1 and isinstance(projections[0], exp.Star):
            inner_select = self._unwrap_star_select(outermost_select, cte_map, select_expressions)
            if inner_select is not None:
                outermost_select = inner_select

        alias_map = self._build_alias_map(outermost_select, cte_map)
        resolved_fields: list[ResolvedField] = []
        seen: set[str] = set()

        for projection in outermost_select.expressions:
            # 跳过 SELECT * 本身（穿透失败时的兜底）
            if isinstance(projection, exp.Star):
                continue
            field = self._resolve_projection(projection, alias_map, cte_map)
            # 过滤掉无效字段名（空字符串、纯符号如 "." "," 等）
            if not field.field_name or not re.search(r"[A-Za-z0-9_\u4e00-\u9fff]", field.field_name):
                continue
            dedupe_key = f"{field.primary_source or 'derived'}::{field.field_name}"
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            resolved_fields.append(field)

        return resolved_fields

    def _unwrap_star_select(
        self,
        outer_select: exp.Select,
        cte_map: dict[str, exp.Expression],
        all_selects: list[exp.Select],
    ) -> exp.Select | None:
        """SELECT * FROM (subquery) 或 SELECT * FROM cte 时，返回内层真实 SELECT。"""
        from_expr = outer_select.args.get("from_")
        if from_expr is None:
            return None

        source = from_expr.this
        # SELECT * FROM (子查询)
        if isinstance(source, exp.Subquery):
            inner = source.this
            if isinstance(inner, exp.Select):
                return inner
            # 子查询本身可能还有嵌套，取第一个 Select
            inner_selects = list(inner.find_all(exp.Select))
            return inner_selects[0] if inner_selects else None

        # SELECT * FROM cte_name
        if isinstance(source, exp.Table):
            name = source.name
            if name and name in cte_map:
                cte_expr = cte_map[name]
                if isinstance(cte_expr, exp.Select):
                    return cte_expr
                inner_selects = list(cte_expr.find_all(exp.Select))
                return inner_selects[0] if inner_selects else None

        # 找下一层 Select（最外层之后的第一个）
        if len(all_selects) > 1:
            return all_selects[1]

        return None

    def _build_alias_map(self, select_expr: exp.Select, cte_map: dict[str, exp.Expression]) -> dict[str, dict[str, object]]:
        alias_map: dict[str, dict[str, object]] = {}
        from_expr = select_expr.args.get("from_")
        if from_expr is None:
            return alias_map

        for source in [from_expr.this, *[join.this for join in select_expr.args.get("joins", [])]]:
            if source is None:
                continue
            if isinstance(source, exp.Table):
                alias = source.alias_or_name or source.name
                if source.name in cte_map:
                    # 不覆盖已有映射：同名别名以先出现的为准
                    if alias not in alias_map:
                        alias_map[alias] = {
                            "type": "cte",
                            "expression": cte_map[source.name],
                        }
                else:
                    if alias not in alias_map:
                        alias_map[alias] = {
                            "type": "table",
                            "table": source.name,  # 纯表名，不含别名部分
                        }
            elif isinstance(source, exp.Subquery):
                alias = source.alias_or_name
                if alias and alias not in alias_map:
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
        # 原始 SQL 表达式（用于 Tooltip 展示）
        raw_expr = projection.sql(dialect="")

        # 优先取显式别名；若无别名且是复杂表达式（含函数/运算符），用简化占位名
        alias = projection.alias_or_name
        if alias:
            field_name = alias
            original_expr = ""  # 有别名时，别名即为可读名，不需要额外展示原始表达式
        elif isinstance(projection, exp.Column):
            # 普通列引用，直接用列名
            col_name = projection.name
            # projection.name 在极少数情况下可能返回空（如解析出空列节点），此时用 raw_expr 兜底
            # 但 raw_expr 可能是 "table.col" 这样的带限定符形式，取最后一段
            if col_name:
                field_name = col_name
            elif raw_expr and "." in raw_expr:
                field_name = raw_expr.split(".")[-1].strip()
            else:
                field_name = raw_expr.strip()
            original_expr = ""
        else:
            # CASE WHEN / 聚合函数 / 运算表达式 等无别名情况
            col_names = [c.name for c in projection.find_all(exp.Column) if c.name][:2]
            if col_names:
                field_name = "_".join(col_names) + "_expr"
            else:
                field_name = "derived_expr"
            original_expr = raw_expr  # 记录原始表达式供前端 Tooltip

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
            original_expr=original_expr,
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

        # 聚合所有文档的别名→真实表名映射（后出现的覆盖先出现的，以最完整的为准）
        global_alias_to_table: dict[str, str] = {}
        for doc in documents:
            global_alias_to_table.update(doc.alias_to_table)
        # regex fallback 路径也可能用别名作为 source_table，一并兜底处理

        item_map: dict[str, Item] = {}
        relations: list[Relation] = []
        for idx, document in enumerate(documents):
            entity_id = f"sql_{idx + 1}"
            for column in document.columns:
                raw_source = column["source_table"] or "unknown"
                # 别名 → 真实表名，使用文档级优先、全局次之
                real_source = (
                    document.alias_to_table.get(raw_source)
                    or global_alias_to_table.get(raw_source)
                    or raw_source
                )
                item_id = f"{real_source}::{column['name']}"
                if item_id not in item_map:
                    item_map[item_id] = Item(
                        id=item_id,
                        name=str(column["name"]),
                        group=real_source,
                        source=real_source,
                        item_type="column",
                        meta={
                            "source_tables": str(column.get("source_tables", "")),
                            "column_name": str(column.get("column_name", "")),
                            "original_expr": str(column.get("original_expr", "")),
                        },
                    )
                relations.append(Relation(entity_id=entity_id, item_id=item_id))

        # 构建全局 JOIN 图（所有文件的 join_edges 合并）
        join_graph = self._build_join_graph(documents)

        # 粒度信息：每个 SQL 文件的粒度键
        granularity_map = {
            doc.name: doc.granularity_keys
            for doc in documents
            if doc.granularity_keys
        }

        return SceneDataset(
            scene="sql",
            entities=entities,
            items=list(item_map.values()),
            relations=relations,
            constraints=ConstraintConfig(max_items_per_unit=20, max_units_per_entity=3),
            meta={
                "join_graph": join_graph,              # {table: {neighbor: [edge_info, ...]}}
                "granularity_map": granularity_map,    # {sql_name: [key_cols]}
                "alias_to_table": global_alias_to_table,  # 供前端/图展示使用
                "all_join_edges": [                    # 原始边列表，供连通性检查
                    {
                        "left": e.left_table,
                        "right": e.right_table,
                        "left_col": e.left_col,
                        "right_col": e.right_col,
                        "source": e.sql_source,
                    }
                    for doc in documents for e in doc.join_edges
                ],
            },
        )

    def _build_join_graph(
        self, documents: list[ParsedSqlDocument]
    ) -> dict[str, dict[str, list[dict[str, str]]]]:
        """构建全局无向 JOIN 邻接图：{table -> {neighbor_table -> [edge_list]}}。"""
        graph: dict[str, dict[str, list[dict[str, str]]]] = defaultdict(lambda: defaultdict(list))
        for doc in documents:
            for edge in doc.join_edges:
                edge_info = {
                    "left_col": edge.left_col,
                    "right_col": edge.right_col,
                    "source": edge.sql_source,
                }
                graph[edge.left_table][edge.right_table].append(edge_info)
                graph[edge.right_table][edge.left_table].append(edge_info)
        # 转为普通 dict 方便序列化
        return {t: dict(neighbors) for t, neighbors in graph.items()}

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
