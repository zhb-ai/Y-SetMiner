from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from itertools import combinations
from math import ceil

from app.schemas.solve import SceneDataset


@dataclass
class SqlBaseCandidate:
    source_subset: tuple[str, ...]
    support_unit_ids: list[str]
    shared_item_indices: list[int]
    score: float
    exact_match_unit_ids: list[str]
    extension_unit_ids: list[str]
    extension_signatures: list[tuple[str, ...]]
    suggested_item_indices: list[int]
    suggested_item_hits: list[int]
    support_unit_count: int
    base_field_min_hits: int
    suggested_field_min_hits: int


def get_real_unit_sources(dataset: SceneDataset, unit: dict[str, object]) -> tuple[str, ...]:
    sources = {
        str(dataset.items[item_idx].source)
        for item_idx in unit["item_indices"]
        if dataset.items[item_idx].source and dataset.items[item_idx].source not in {"unknown", "derived"}
    }
    return tuple(sorted(sources))


def get_real_unit_source_counter(dataset: SceneDataset, unit: dict[str, object]) -> Counter[str]:
    return Counter(get_real_unit_sources(dataset, unit))


def mine_sql_base_candidates(
    dataset: SceneDataset,
    units: list[dict[str, object]],
    *,
    min_support: int = 3,
    min_subset_size: int = 2,
    min_shared_items: int = 4,
    item_frequency_threshold: float = 0.6,
    suggested_item_frequency_threshold: float = 0.45,
) -> list[SqlBaseCandidate]:
    subset_support: dict[tuple[str, ...], list[int]] = defaultdict(list)
    unit_source_signatures = [get_real_unit_sources(dataset, unit) for unit in units]

    for unit_index, unit in enumerate(units):
        source_signature = unit_source_signatures[unit_index]
        if len(source_signature) < min_subset_size:
            continue
        for subset_size in range(min_subset_size, len(source_signature) + 1):
            for subset in combinations(source_signature, subset_size):
                subset_support[subset].append(unit_index)

    candidates: list[SqlBaseCandidate] = []
    for source_subset, support_indices in subset_support.items():
        if len(support_indices) < min_support:
            continue

        support_units = [units[idx] for idx in support_indices]
        exact_match_unit_ids = [
            str(units[idx]["id"])
            for idx in support_indices
            if unit_source_signatures[idx] == source_subset
        ]
        extension_unit_ids = [
            str(units[idx]["id"])
            for idx in support_indices
            if unit_source_signatures[idx] != source_subset
        ]
        extension_signatures = sorted(
            {
                tuple(sorted(set(unit_source_signatures[idx]) - set(source_subset)))
                for idx in support_indices
                if unit_source_signatures[idx] != source_subset
            }
        )
        item_frequency, support_count = _build_subset_item_frequency(
            dataset,
            support_units,
            source_subset,
        )
        base_field_min_hits = max(2, ceil(support_count * item_frequency_threshold))
        suggested_field_min_hits = max(2, ceil(support_count * suggested_item_frequency_threshold))
        shared_item_indices = _select_item_indices_by_hits(item_frequency, base_field_min_hits)
        required_shared_items = _get_min_shared_items_for_subset(len(source_subset), min_shared_items)
        if len(shared_item_indices) < required_shared_items:
            continue
        suggested_candidates = [
            (item_idx, hits)
            for item_idx, hits in item_frequency.items()
            if suggested_field_min_hits <= hits < base_field_min_hits
        ]
        suggested_candidates.sort(key=lambda item: (-item[1], item[0]))
        suggested_item_indices = [item_idx for item_idx, _ in suggested_candidates]
        suggested_item_hits = [hits for _, hits in suggested_candidates]

        avg_extra_sources = sum(
            max(len(unit_source_signatures[idx]) - len(source_subset), 0)
            for idx in support_indices
        ) / len(support_units)
        avg_entity_coverage = sum(len(unit["entity_indices"]) for unit in support_units) / len(support_units)
        extension_diversity = len(extension_signatures)
        extension_support = len(extension_unit_ids)
        score = (
            len(support_units) * 10
            + extension_support * 5
            + extension_diversity * 4
            + len(exact_match_unit_ids) * 2
            + len(shared_item_indices) * 2
            + avg_entity_coverage
            - avg_extra_sources * 1.5
            - len(source_subset) * 0.5
        )
        candidates.append(
            SqlBaseCandidate(
                source_subset=source_subset,
                support_unit_ids=[str(unit["id"]) for unit in support_units],
                shared_item_indices=shared_item_indices,
                score=round(score, 4),
                exact_match_unit_ids=exact_match_unit_ids,
                extension_unit_ids=extension_unit_ids,
                extension_signatures=extension_signatures,
                suggested_item_indices=suggested_item_indices,
                suggested_item_hits=suggested_item_hits,
                support_unit_count=support_count,
                base_field_min_hits=base_field_min_hits,
                suggested_field_min_hits=suggested_field_min_hits,
            )
        )

    candidates.sort(key=_candidate_priority_key)
    return candidates


def choose_base_candidate_for_unit(
    dataset: SceneDataset,
    unit: dict[str, object],
    candidates: list[SqlBaseCandidate],
) -> SqlBaseCandidate | None:
    source_set = set(get_real_unit_sources(dataset, unit))
    eligible = [candidate for candidate in candidates if set(candidate.source_subset).issubset(source_set)]
    if not eligible:
        return None
    eligible.sort(key=_candidate_priority_key)
    return eligible[0]


def build_extension_delta(
    dataset: SceneDataset,
    unit: dict[str, object],
    base_candidate: SqlBaseCandidate,
) -> tuple[list[str], list[str], list[str], list[str]]:
    base_sources = set(base_candidate.source_subset)
    extra_source_tables = sorted(set(get_real_unit_sources(dataset, unit)) - base_sources)
    base_items = set(base_candidate.shared_item_indices)
    extra_item_indices = [
        item_idx
        for item_idx in unit["item_indices"]
        if item_idx not in base_items
    ]
    extra_item_names = [
        dataset.items[item_idx].name
        for item_idx in extra_item_indices
    ]
    extra_item_sources = [
        _build_item_source_label(dataset, item_idx)
        for item_idx in extra_item_indices
    ]
    extra_item_source_details = [
        _build_item_source_detail(dataset, item_idx)
        for item_idx in extra_item_indices
    ]
    return extra_source_tables, extra_item_names, extra_item_sources, extra_item_source_details


def _build_subset_item_frequency(
    dataset: SceneDataset,
    support_units: list[dict[str, object]],
    source_subset: tuple[str, ...],
) -> tuple[Counter[int], int]:
    source_filter = set(source_subset)
    item_frequency: Counter[int] = Counter()
    for unit in support_units:
        unit_subset_items = {
            item_idx
            for item_idx in unit["item_indices"]
            if dataset.items[item_idx].source in source_filter
        }
        item_frequency.update(unit_subset_items)
    return item_frequency, len(support_units)


def _select_item_indices_by_hits(item_frequency: Counter[int], min_hits: int) -> list[int]:
    selected = [item_idx for item_idx, freq in item_frequency.items() if freq >= min_hits]
    selected.sort(key=lambda item_idx: (-item_frequency[item_idx], item_idx))
    return selected


def _get_min_shared_items_for_subset(subset_size: int, default_min_shared_items: int) -> int:
    if subset_size <= 2:
        return min(default_min_shared_items, 2)
    if subset_size == 3:
        return min(default_min_shared_items, 3)
    return default_min_shared_items


def _candidate_priority_key(candidate: SqlBaseCandidate) -> tuple[int, int, int, float, int]:
    return (
        -len(candidate.support_unit_ids),
        -len(candidate.extension_unit_ids),
        len(candidate.source_subset),
        -candidate.score,
        -len(candidate.shared_item_indices),
    )


def _build_item_source_label(dataset: SceneDataset, item_idx: int) -> str:
    item = dataset.items[item_idx]
    source = str(item.source or "").strip()
    original_expr = str(item.meta.get("original_expr", "")).strip()
    source_tables = _split_item_meta_list(item.meta.get("source_tables", ""))
    if source == "derived":
        if source_tables:
            return f"表达式依赖({'+'.join(source_tables)})"
        if original_expr:
            return "表达式/常量"
    return source or "unknown"


def _build_item_source_detail(dataset: SceneDataset, item_idx: int) -> str:
    item = dataset.items[item_idx]
    source = str(item.source or "").strip()
    source_tables = _split_item_meta_list(item.meta.get("source_tables", ""))
    source_columns = str(item.meta.get("column_name", "")).strip()
    original_expr = str(item.meta.get("original_expr", "")).strip()

    if source != "derived":
        return original_expr

    details: list[str] = []
    if source_tables:
        details.append(f"依赖表: {', '.join(source_tables)}")
    if source_columns:
        details.append(f"参与列: {source_columns}")
    if original_expr:
        details.append(f"原始表达式: {original_expr}")
    return "\n".join(details)


def _split_item_meta_list(value: object) -> list[str]:
    return [part.strip() for part in str(value).split(",") if part.strip()]
