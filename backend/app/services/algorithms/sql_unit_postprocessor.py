from __future__ import annotations

from collections import defaultdict


def finalize_sql_unit_groups(
    _units: list[dict[str, object]],
    groups: list[dict[str, object]],
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    """对 SQL 宽表候选做最终整理。

    目标：
    1. 把同来源签名的独立宽表收敛成一个 family，避免顶层出现大量同名组。
    2. 对完全重复的 standalone 候选去重。
    3. 为同 family 下的 standalone 变体重新编号，保证名称唯一且稳定。
    """
    if not groups:
        return units, groups

    preserved_groups: list[dict[str, object]] = []
    standalone_buckets: dict[str, list[dict[str, object]]] = defaultdict(list)

    for group in groups:
        normalized_group = {
            "key": str(group["key"]),
            "group_name": str(group["group_name"]),
            "base_unit": dict(group["base_unit"]),
            "units": [dict(unit) for unit in group.get("units", [])],
        }
        base_unit = normalized_group["base_unit"]
        if str(base_unit.get("unit_level", "standalone")) == "standalone":
            standalone_buckets[_build_family_key(base_unit)].append(normalized_group)
        else:
            preserved_groups.append(normalized_group)

    family_groups: list[dict[str, object]] = []
    for family_key, bucket_groups in standalone_buckets.items():
        family_units = [group["base_unit"] for group in bucket_groups]
        family_units = _deduplicate_units(family_units)
        family_units.sort(key=_unit_priority_key)
        _apply_standalone_family_names(family_key, family_units)

        lead_unit = family_units[0]
        variant_units = family_units[1:]
        family_groups.append(
            {
                "key": family_key if len(family_units) > 1 else str(lead_unit["id"]),
                "group_name": (
                    _build_family_group_name(family_key)
                    if len(family_units) > 1
                    else str(lead_unit["name"])
                ),
                "base_unit": lead_unit,
                "units": variant_units,
            }
        )

    merged_groups = preserved_groups + family_groups
    _ensure_unique_unit_names(merged_groups)
    _refresh_group_names(merged_groups)

    ordered_units: list[dict[str, object]] = []
    for group in merged_groups:
        ordered_units.append(group["base_unit"])
        ordered_units.extend(group["units"])

    ordered_units.sort(key=_final_unit_sort_key)
    merged_groups.sort(key=_final_group_sort_key)
    return ordered_units, merged_groups


def _build_family_key(unit: dict[str, object]) -> str:
    sources = tuple(
        sorted(
            {
                str(source).strip()
                for source in unit.get("sources", [])
                if str(source).strip() and str(source).strip() not in {"unknown", "derived"}
            }
        )
    )
    if sources:
        return "+".join(sources)

    base_name = str(unit.get("base_name") or "").strip()
    if base_name:
        return base_name

    return "通用"


def _build_family_group_name(family_key: str) -> str:
    if family_key == "通用":
        return "通用宽表族"
    if "+" in family_key:
        return f"{family_key}组合宽表族"
    return f"{family_key}宽表族"


def _build_standalone_unit_name(family_key: str, order_no: int) -> str:
    if family_key == "通用":
        return f"通用宽表{order_no}"
    if "+" in family_key:
        return f"{family_key}组合宽表{order_no}"
    return f"{family_key}宽表{order_no}"


def _apply_standalone_family_names(
    family_key: str,
    units: list[dict[str, object]],
) -> None:
    for order_no, unit in enumerate(units, start=1):
        unit["name"] = _build_standalone_unit_name(family_key, order_no)


def _deduplicate_units(units: list[dict[str, object]]) -> list[dict[str, object]]:
    deduped: dict[tuple[object, ...], dict[str, object]] = {}
    for unit in units:
        dedup_key = (
            tuple(str(source) for source in unit.get("sources", [])),
            tuple(str(item_id) for item_id in unit.get("item_ids", [])),
            tuple(str(entity_id) for entity_id in unit.get("covered_entity_ids", [])),
            str(unit.get("unit_level", "standalone")),
        )
        existing = deduped.get(dedup_key)
        if existing is None or _unit_priority_key(unit) < _unit_priority_key(existing):
            deduped[dedup_key] = unit
    return list(deduped.values())


def _ensure_unique_unit_names(groups: list[dict[str, object]]) -> None:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for group in groups:
        buckets[str(group["base_unit"]["name"])].append(group["base_unit"])
        for unit in group["units"]:
            buckets[str(unit["name"])].append(unit)

    for unit_name, bucket in buckets.items():
        if len(bucket) <= 1:
            continue
        bucket.sort(key=_unit_priority_key)
        for idx, unit in enumerate(bucket, start=1):
            unit["name"] = f"{unit_name}（{idx}）"


def _refresh_group_names(groups: list[dict[str, object]]) -> None:
    for group in groups:
        base_unit = group["base_unit"]
        if str(base_unit.get("unit_level", "standalone")) == "standalone" and group["units"]:
            continue
        group["group_name"] = str(base_unit["name"])


def _unit_priority_key(unit: dict[str, object]) -> tuple[float, float, float, str]:
    return (
        -len(unit.get("covered_entity_ids", [])),
        -float(unit.get("score", 0)),
        -len(unit.get("item_ids", [])),
        str(unit.get("id", "")),
    )


def _final_unit_sort_key(unit: dict[str, object]) -> tuple[int, int, float, str]:
    level_order = {"base": 0, "extension": 1, "standalone": 2}
    return (
        level_order.get(str(unit.get("unit_level", "standalone")), 3),
        -len(unit.get("covered_entity_ids", [])),
        -float(unit.get("score", 0)),
        str(unit.get("name", "")),
    )


def _final_group_sort_key(group: dict[str, object]) -> tuple[int, int, str]:
    base_unit = group["base_unit"]
    total_units = 1 + len(group["units"])
    level_order = 0 if str(base_unit.get("unit_level", "standalone")) == "base" else 1
    return (
        level_order,
        -total_units,
        str(group["group_name"]),
    )
