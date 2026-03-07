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
        shared_item_indices = _pick_shared_items_for_subset(
            dataset,
            support_units,
            source_subset,
            item_frequency_threshold=item_frequency_threshold,
        )
        required_shared_items = _get_min_shared_items_for_subset(len(source_subset), min_shared_items)
        if len(shared_item_indices) < required_shared_items:
            continue

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
) -> tuple[list[str], list[str]]:
    base_sources = set(base_candidate.source_subset)
    extra_source_tables = sorted(set(get_real_unit_sources(dataset, unit)) - base_sources)
    base_items = set(base_candidate.shared_item_indices)
    extra_item_names = [
        dataset.items[item_idx].name
        for item_idx in unit["item_indices"]
        if item_idx not in base_items
    ]
    return extra_source_tables, extra_item_names


def _pick_shared_items_for_subset(
    dataset: SceneDataset,
    support_units: list[dict[str, object]],
    source_subset: tuple[str, ...],
    *,
    item_frequency_threshold: float,
) -> list[int]:
    source_filter = set(source_subset)
    item_frequency: Counter[int] = Counter()
    for unit in support_units:
        unit_subset_items = {
            item_idx
            for item_idx in unit["item_indices"]
            if dataset.items[item_idx].source in source_filter
        }
        item_frequency.update(unit_subset_items)

    support_count = len(support_units)
    min_hits = max(2, ceil(support_count * item_frequency_threshold))
    selected = [
        item_idx
        for item_idx, freq in item_frequency.items()
        if freq >= min_hits
    ]
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
