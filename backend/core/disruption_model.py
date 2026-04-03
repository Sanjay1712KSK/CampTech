from __future__ import annotations


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def calculate_disruption(snapshot: dict) -> dict:
    rain_estimate = float(snapshot.get('rain_estimate', 0.0) or 0.0)
    traffic_index = float(snapshot.get('traffic_index', 1.0) or 1.0)
    aqi = float(snapshot.get('aqi', 50.0) or 50.0)
    temperature = float(snapshot.get('temperature', 30.0) or 30.0)
    wind_speed = float(snapshot.get('wind_speed', 5.0) or 5.0)

    rain_penalty = _clamp(rain_estimate / 12.0, 0.0, 0.7)
    traffic_penalty = _clamp((traffic_index - 1.0) / 1.2, 0.0, 0.65)
    aqi_penalty = _clamp((aqi - 50.0) / 250.0, 0.0, 0.55)
    heat_penalty = _clamp((temperature - 32.0) / 12.0, 0.0, 0.45)
    wind_penalty = _clamp((wind_speed - 12.0) / 20.0, 0.0, 0.25)

    delivery_capacity = _clamp(1.0 - ((0.55 * rain_penalty) + (0.45 * traffic_penalty)), 0.2, 1.0)
    working_hours_factor = _clamp(1.0 - ((0.45 * aqi_penalty) + (0.4 * heat_penalty) + (0.15 * wind_penalty)), 0.3, 1.0)

    return {
        'delivery_capacity': _round(delivery_capacity),
        'working_hours': _round(working_hours_factor),
        'working_hours_factor': _round(working_hours_factor),
        'factor_breakdown': {
            'rain_penalty': _round(rain_penalty),
            'traffic_penalty': _round(traffic_penalty),
            'aqi_penalty': _round(aqi_penalty),
            'heat_penalty': _round(heat_penalty),
            'wind_penalty': _round(wind_penalty),
        },
    }


def calculate_delivery_efficiency(snapshot: dict, disruption: dict) -> dict:
    from core.efficiency_engine import calculate_efficiency

    return calculate_efficiency(snapshot=snapshot, disruption=disruption)
