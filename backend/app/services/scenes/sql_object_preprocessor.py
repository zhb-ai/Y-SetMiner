from __future__ import annotations

import re
from dataclasses import dataclass

from sqlglot import exp, parse_one


@dataclass(frozen=True)
class ExpandableSqlObject:
    name: str
    object_type: str
    definition_sql: str
    source_file: str


@dataclass(frozen=True)
class ExpandedDocumentTrace:
    file_name: str
    expanded_objects: list[str]
    max_depth: int
    is_definition_file: bool
    definition_object_name: str | None = None
    definition_object_type: str | None = None


@dataclass(frozen=True)
class SqlPreprocessSummary:
    detected_objects: list[ExpandableSqlObject]
    expanded_documents: list[ExpandedDocumentTrace]
    cycles: list[list[str]]


class SqlObjectPreprocessor:
    """跨文件收集并展开可内联 SQL 对象定义。"""

    _VIEW_PATTERN = re.compile(
        r"^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(?:(?P<materialized>MATERIALIZED)\s+)?VIEW\s+"
        r"(?:IF\s+NOT\s+EXISTS\s+)?(?P<name>[`\"\[\]\w\.]+).*?\bAS\b\s*"
        r"(?P<select>(?:WITH|SELECT)\b[\s\S]*)$",
        re.I,
    )
    _CTAS_PATTERN = re.compile(
        r"^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?P<name>[`\"\[\]\w\.]+).*?\bAS\b\s*"
        r"(?P<select>(?:WITH|SELECT)\b[\s\S]*)$",
        re.I,
    )

    def preprocess_documents(
        self,
        documents: list[tuple[str, str]],
    ) -> tuple[list[tuple[str, str]], list[str], SqlPreprocessSummary | None]:
        objects, detected_objects = self.collect_objects(documents)
        if not objects:
            return documents, [], None

        processed_documents: list[tuple[str, str]] = []
        notes: list[str] = []
        definition_cache: dict[str, tuple[str, int]] = {}
        warned_cycles: set[tuple[str, ...]] = set()
        expanded_documents: list[ExpandedDocumentTrace] = []

        for file_name, content in documents:
            extracted = self.extract_object_definition(file_name, content)
            base_sql = extracted.definition_sql if extracted else content
            expanded_sql, expanded_objects, max_depth = self._expand_sql_text(
                base_sql,
                objects,
                definition_cache,
                stack=[],
                warned_cycles=warned_cycles,
            )
            processed_documents.append((file_name, expanded_sql))
            expanded_documents.append(
                ExpandedDocumentTrace(
                    file_name=file_name,
                    expanded_objects=sorted(expanded_objects),
                    max_depth=max_depth,
                    is_definition_file=extracted is not None,
                    definition_object_name=extracted.name.lower() if extracted else None,
                    definition_object_type=extracted.object_type if extracted else None,
                )
            )
            if extracted:
                notes.append(
                    f"[预处理] `{file_name}` 已识别为可展开对象定义（{self._label_object_type(extracted.object_type)}），"
                    "后续分析将基于其底层查询。"
                )
            if expanded_objects:
                notes.append(
                    f"[预处理] `{file_name}` 已展开对象引用：{', '.join(sorted(expanded_objects))}；最大展开层级 {max_depth} 层。"
                )

        cycle_list = [list(cycle) for cycle in sorted(warned_cycles)]
        for cycle in sorted(warned_cycles):
            notes.append(
                f"[预处理] 检测到对象循环依赖：{' -> '.join(cycle)}，已停止继续展开并保留当前引用。"
            )

        summary = SqlPreprocessSummary(
            detected_objects=detected_objects,
            expanded_documents=expanded_documents,
            cycles=cycle_list,
        )
        return processed_documents, notes, summary

    def collect_objects(
        self,
        documents: list[tuple[str, str]],
    ) -> tuple[dict[str, ExpandableSqlObject], list[ExpandableSqlObject]]:
        objects: dict[str, ExpandableSqlObject] = {}
        detected_objects_by_name: dict[str, ExpandableSqlObject] = {}
        for file_name, content in documents:
            extracted = self.extract_object_definition(file_name, content)
            if extracted is None:
                continue

            normalized_name = self._normalize_identifier(extracted.name)
            short_name = self._short_name(normalized_name)
            objects[normalized_name] = extracted
            objects.setdefault(short_name, extracted)
            detected_objects_by_name[normalized_name] = extracted
        detected_objects = sorted(
            detected_objects_by_name.values(),
            key=lambda item: (item.object_type, self._normalize_identifier(item.name), item.source_file.lower()),
        )
        return objects, detected_objects

    def extract_object_definition(self, file_name: str, content: str) -> ExpandableSqlObject | None:
        prepared = self._prepare_sql(content)
        for pattern, object_type in (
            (self._VIEW_PATTERN, "materialized_view"),
            (self._VIEW_PATTERN, "view"),
            (self._CTAS_PATTERN, "wide_table"),
        ):
            match = pattern.match(prepared)
            if match is None:
                continue

            materialized = bool(match.groupdict().get("materialized"))
            resolved_type = "materialized_view" if materialized else object_type
            if object_type == "view" and materialized:
                continue
            if object_type == "materialized_view" and not materialized:
                continue

            return ExpandableSqlObject(
                name=self._clean_identifier(match.group("name")),
                object_type=resolved_type,
                definition_sql=match.group("select").strip().rstrip(";"),
                source_file=file_name,
            )
        return None

    def _expand_sql_text(
        self,
        sql: str,
        objects: dict[str, ExpandableSqlObject],
        definition_cache: dict[str, tuple[str, int]],
        *,
        stack: list[str],
        warned_cycles: set[tuple[str, ...]],
    ) -> tuple[str, set[str], int]:
        try:
            expression = parse_one(sql, error_level="raise")
        except Exception:
            return sql, set(), max(len(stack), 0)

        cte_names = {
            self._normalize_identifier(cte.alias_or_name)
            for cte in expression.find_all(exp.CTE)
            if cte.alias_or_name
        }
        expanded_objects: set[str] = set()
        max_depth = len(stack)

        def replace_table(node: exp.Expression) -> exp.Expression:
            nonlocal max_depth
            if not isinstance(node, exp.Table):
                return node

            resolved = self._resolve_object_for_table(node, objects)
            if resolved is None:
                return node

            object_key, sql_object = resolved
            if self._short_name(object_key) in cte_names or object_key in cte_names:
                return node

            expanded_sql, nested_depth = self._expand_object_definition(
                object_key,
                objects,
                definition_cache,
                stack=stack,
                warned_cycles=warned_cycles,
            )
            max_depth = max(max_depth, nested_depth)
            try:
                subquery_expression = parse_one(expanded_sql, error_level="raise")
            except Exception:
                return node

            alias_name = self._normalize_identifier(node.alias_or_name or sql_object.name) or "src"
            expanded_objects.add(sql_object.name.lower())
            return exp.Subquery(
                this=subquery_expression,
                alias=exp.TableAlias(this=exp.to_identifier(self._short_name(alias_name))),
            )

        transformed = expression.transform(replace_table)
        return transformed.sql(dialect=""), expanded_objects, max_depth

    def _expand_object_definition(
        self,
        object_key: str,
        objects: dict[str, ExpandableSqlObject],
        definition_cache: dict[str, tuple[str, int]],
        *,
        stack: list[str],
        warned_cycles: set[tuple[str, ...]],
    ) -> tuple[str, int]:
        if object_key in definition_cache:
            cached_sql, cached_depth = definition_cache[object_key]
            return cached_sql, max(cached_depth, len(stack) + 1)

        if object_key in stack:
            cycle = tuple(stack + [object_key])
            warned_cycles.add(cycle)
            return objects[object_key].definition_sql, len(stack)

        sql_object = objects[object_key]
        expanded_sql, _, nested_depth = self._expand_sql_text(
            sql_object.definition_sql,
            objects,
            definition_cache,
            stack=stack + [object_key],
            warned_cycles=warned_cycles,
        )
        definition_cache[object_key] = (expanded_sql, nested_depth)
        return expanded_sql, nested_depth

    def _resolve_object_for_table(
        self,
        table: exp.Table,
        objects: dict[str, ExpandableSqlObject],
    ) -> tuple[str, ExpandableSqlObject] | None:
        candidates = []
        if table.catalog and table.db:
            candidates.append(
                self._normalize_identifier(f"{table.catalog}.{table.db}.{table.name}")
            )
        if table.db:
            candidates.append(self._normalize_identifier(f"{table.db}.{table.name}"))
        candidates.append(self._normalize_identifier(table.name))

        for candidate in candidates:
            if candidate in objects:
                return candidate, objects[candidate]

        short_name = self._short_name(self._normalize_identifier(table.name))
        if short_name in objects:
            return short_name, objects[short_name]
        return None

    def _prepare_sql(self, sql: str) -> str:
        no_comments = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
        no_comments = re.sub(r"--.*?$", " ", no_comments, flags=re.M)
        translation_map = str.maketrans({
            "（": "(",
            "）": ")",
            "，": ",",
            "；": ";",
        })
        return no_comments.translate(translation_map).strip()

    def _normalize_identifier(self, value: str | None) -> str:
        if value is None:
            return ""
        return self._clean_identifier(value).lower()

    def _clean_identifier(self, value: str) -> str:
        cleaned = str(value).strip()
        parts = [part.strip("`\"[]") for part in cleaned.split(".") if part.strip()]
        return ".".join(parts)

    def _short_name(self, value: str) -> str:
        normalized = self._normalize_identifier(value)
        return normalized.split(".")[-1] if normalized else ""

    def _label_object_type(self, object_type: str) -> str:
        labels = {
            "view": "视图",
            "materialized_view": "物化视图",
            "wide_table": "宽表/CTAS",
        }
        return labels.get(object_type, object_type)
