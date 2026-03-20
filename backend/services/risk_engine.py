import logging
from datetime import datetime, timezone

logger = logging.getLogger('gig_insurance_backend.risk_engine')


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _to_float(value, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return float(default)


def _to_int(value, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return int(default)


def _aqi_bucket_to_index(aqi_value: int) -> int:
    # Current environment service returns OpenWeather AQI buckets 1..5.
    if 1 <= aqi_value <= 5:
        return {
            1: 25,
            2: 75,
            3: 150,
            4: 250,
            5: 350,
        }[aqi_value]
    return aqi_value


def _calculate_weather_risk(weather: dict) -> float:
    rainfall = _to_float(weather.get('rainfall'), 0.0)
    wind_speed = _to_float(weather.get('wind_speed'), 0.0)
    temperature = _to_float(weather.get('temperature'), 25.0)

    risk = 0.0
    if rainfall > 5:
        risk = 0.9
    elif 1 <= rainfall <= 5:
        risk = 0.6

    if wind_speed > 10:
        risk += 0.2

    if temperature < 10 or temperature > 40:
        risk += 0.2

    return round(_clamp(risk), 3)


def _calculate_aqi_risk(aqi_payload: dict) -> float:
    aqi_value = _aqi_bucket_to_index(_to_int(aqi_payload.get('aqi'), 50))

    if aqi_value <= 50:
        risk = 0.1
    elif aqi_value <= 100:
        risk = 0.3
    elif aqi_value <= 200:
        risk = 0.6
    elif aqi_value <= 300:
        risk = 0.8
    else:
        risk = 1.0

    return round(risk, 3)


def _calculate_traffic_risk(traffic_payload: dict) -> float:
    level = str(traffic_payload.get('traffic_level', 'LOW')).upper()
    if level == 'HIGH':
        return 0.8
    if level == 'MEDIUM':
        return 0.5
    return 0.2


def _calculate_time_risk(context: dict) -> float:
    current_utc_hour = datetime.now(timezone.utc).hour
    hour = _to_int(context.get('hour'), current_utc_hour) % 24

    if hour >= 20 or hour < 6:
        return 0.7
    if 8 <= hour <= 11 or 17 <= hour <= 21:
        return 0.6
    return 0.3


def _risk_level(score: float) -> str:
    if score < 0.4:
        return 'LOW'
    if score <= 0.7:
        return 'MEDIUM'
    return 'HIGH'


def _recommendation(level: str) -> str:
    if level == 'HIGH':
        return 'Avoid delivery if possible'
    if level == 'MEDIUM':
        return 'Be cautious'
    return 'Safe to deliver'


def calculate_risk(environment_data: dict) -> dict:
    payload = environment_data or {}
    weather = payload.get('weather') or {}
    aqi = payload.get('aqi') or {}
    traffic = payload.get('traffic') or {}
    context = payload.get('context') or {}

    weather_risk = _calculate_weather_risk(weather)
    aqi_risk = _calculate_aqi_risk(aqi)
    traffic_risk = _calculate_traffic_risk(traffic)
    time_risk = _calculate_time_risk(context)

    risk_score = round(
        (0.35 * weather_risk)
        + (0.25 * aqi_risk)
        + (0.25 * traffic_risk)
        + (0.15 * time_risk),
        3,
    )
    risk_score = _clamp(risk_score)
    risk_level = _risk_level(risk_score)

    result = {
        'risk_score': round(risk_score, 3),
        'risk_level': risk_level,
        'risk_factors': {
            'weather_risk': weather_risk,
            'aqi_risk': aqi_risk,
            'traffic_risk': traffic_risk,
            'time_risk': time_risk,
        },
        'recommendation': _recommendation(risk_level),
    }

    logger.info('risk calculated: %s', result)
    return result
