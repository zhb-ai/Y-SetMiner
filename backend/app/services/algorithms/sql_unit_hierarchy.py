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

    for unit_index, unit in enumerate(units):
        source_signature = get_real_unit_sources(dataset, unit)
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
        shared_item_indices = _pick_shared_items_for_subset(
            dataset,
            support_units,
            source_subset,
            item_frequency_threshold=item_frequency_threshold,
        )
        if len(shared_item_indices) < min_shared_items:
            continue

        avg_extra_sources = sum(
            max(len(get_real_unit_sources(dataset, unit)) - len(source_subset), 0)
            for unit in support_units
        ) / len(support_units)
        avg_entity_coverage = sum(len(unit["entity_indices"]) for unit in support_units) / len(support_units)
        score = (
            len(support_units) * 10
            + len(shared_item_indices) * 2
            + avg_entity_coverage
            - avg_extra_sources * 1.5
            - len(source_subset)
        )
        candidates.append(
            SqlBaseCandidate(
                source_subset=source_subset,
                support_unit_ids=[str(unit["id"]) for unit in support_units],
                shared_item_indices=shared_item_indices,
                score=round(score, 4),
            )
        )

    candidates.sort(
        key=lambda candidate: (
            candidate.score,
            len(candidate.support_unit_ids),
            len(candidate.source_subset),
            len(candidate.shared_item_indices),
        ),
        reverse=True,
    )
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
    eligible.sort(
        key=lambda candidate: (
            candidate.score,
            len(candidate.support_unit_ids),
            len(candidate.source_subset),
            len(candidate.shared_item_indices),
        ),
        reverse=True,
    )
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
