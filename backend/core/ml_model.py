from __future__ import annotations

import json
import logging
import os

logger = logging.getLogger('gig_insurance_backend.ml_model')

DEFAULT_COEFFICIENTS = {
    'intercept': 0.98,
    'rain_estimate': -0.020,
    'traffic_index': -0.180,
    'aqi': -0.0012,
    'wind_speed': -0.006,
    'temperature': -0.010,
}


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _load_coefficients() -> dict[str, float]:
    raw = os.getenv('RISK_ML_COEFFICIENTS', '').strip()
    if not raw:
        return DEFAULT_COEFFICIENTS.copy()
    try:
        parsed = json.loads(raw)
        if not isinstance(parsed, dict):
            raise ValueError('RISK_ML_COEFFICIENTS must decode to an object')
        coefficients = DEFAULT_COEFFICIENTS.copy()
        for key in coefficients:
            if key in parsed:
                coefficients[key] = float(parsed[key])
        return coefficients
    except Exception as exc:
        logger.warning('invalid RISK_ML_COEFFICIENTS, falling back to defaults: %s', exc)
        return DEFAULT_COEFFICIENTS.copy()


def predict_efficiency_score(snapshot: dict, disruption: dict) -> float | None:
    enabled = os.getenv('RISK_ML_ENABLED', '').strip().lower() in {'1', 'true', 'yes'}
    if not enabled:
        return None

    try:
        coefficients = _load_coefficients()
        score = float(coefficients['intercept'])
        score += coefficients['rain_estimate'] * float(snapshot.get('rain_estimate', 0.0) or 0.0)
        score += coefficients['traffic_index'] * max(float(snapshot.get('traffic_index', 1.0) or 1.0) - 1.0, 0.0)
        score += coefficients['aqi'] * float(snapshot.get('aqi', 50.0) or 50.0)
        score += coefficients['wind_speed'] * float(snapshot.get('wind_speed', 0.0) or 0.0)
        score += coefficients['temperature'] * max(float(snapshot.get('temperature', 30.0) or 30.0) - 30.0, 0.0)
        score *= float(disruption.get('delivery_capacity', 1.0) or 1.0) ** 0.35
        score *= float(disruption.get('working_hours_factor', 1.0) or 1.0) ** 0.35
        return _clamp(score, 0.15, 1.0)
    except Exception as exc:
        logger.warning('ML efficiency prediction failed, falling back to rule-based logic: %s', exc)
        return None
