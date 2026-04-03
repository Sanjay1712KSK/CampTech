from __future__ import annotations

from core.hyperlocal_engine import snapshot_disruption_index


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def compute_predictive_risk(hourly: list[dict]) -> dict:
    upcoming = hourly[:6]
    if not upcoming:
        return {
            'next_6hr': 0.0,
            'next_6hr_risk': 0.0,
            'trend': 'stable',
        }

    scores = [snapshot_disruption_index(item) for item in upcoming]
    first_half = sum(scores[:3]) / max(len(scores[:3]), 1)
    second_half = sum(scores[3:]) / max(len(scores[3:]), 1)
    trend = 'stable'
    if second_half > first_half + 0.05:
        trend = 'increasing'
    elif second_half < first_half - 0.05:
        trend = 'decreasing'

    next_score = _round(sum(scores) / len(scores))
    return {
        'next_6hr': next_score,
        'next_6hr_risk': next_score,
        'trend': trend,
    }
