from __future__ import annotations

import logging

from core.ml_model import predict_efficiency_score

logger = logging.getLogger('gig_insurance_backend.efficiency_engine')

DEFAULT_DELIVERIES_PER_HOUR = 3.2


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def _rule_based_efficiency(disruption: dict) -> float:
    return _clamp(
        float(disruption.get('delivery_capacity', 1.0))
        * float(disruption.get('working_hours_factor', disruption.get('working_hours', 1.0))),
        0.15,
        1.0,
    )


def calculate_efficiency(snapshot: dict, disruption: dict) -> dict:
    ml_efficiency = predict_efficiency_score(snapshot=snapshot, disruption=disruption)
    efficiency_score = ml_efficiency if ml_efficiency is not None else _rule_based_efficiency(disruption)
    if ml_efficiency is None:
        logger.debug('efficiency fallback used: rule-based')
    else:
        logger.info('efficiency computed via ML hook')

    normal_deliveries_per_hour = DEFAULT_DELIVERIES_PER_HOUR
    estimated_current = normal_deliveries_per_hour * efficiency_score
    drop_ratio = 1.0 - efficiency_score

    return {
        'score': _round(efficiency_score),
        'drop': f'{int(round(drop_ratio * 100))}%',
        'drop_percentage': f'{int(round(drop_ratio * 100))}%',
        'drop_ratio': _round(drop_ratio),
        'normal_deliveries_per_hour': _round(normal_deliveries_per_hour, 2),
        'estimated_current': _round(estimated_current, 2),
        'delivery_capacity': _round(float(disruption.get('delivery_capacity', 1.0))),
        'working_hours_factor': _round(
            float(disruption.get('working_hours_factor', disruption.get('working_hours', 1.0)))
        ),
    }
