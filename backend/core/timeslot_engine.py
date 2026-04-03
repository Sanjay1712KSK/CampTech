from __future__ import annotations

from core.hyperlocal_engine import snapshot_disruption_index


def _level(score: float) -> str:
    if score < 0.33:
        return 'LOW'
    if score < 0.66:
        return 'MEDIUM'
    return 'HIGH'


def compute_time_slot_risk(hourly: list[dict]) -> dict[str, str]:
    slot_map = {
        'morning': range(6, 12),
        'afternoon': range(12, 17),
        'evening': range(17, 22),
        'night': tuple(list(range(22, 24)) + list(range(0, 6))),
    }

    result: dict[str, str] = {}
    for slot_name, hour_range in slot_map.items():
        slot_items = [item for item in hourly if int(item.get('hour', -1)) in hour_range]
        if not slot_items:
            result[slot_name] = 'LOW'
            continue
        score = sum(snapshot_disruption_index(item) for item in slot_items) / len(slot_items)
        result[slot_name] = _level(score)
    return result
