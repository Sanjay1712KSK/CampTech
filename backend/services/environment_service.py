from sqlalchemy.orm import Session

from core.environment_engine import build_environment
from services.simulation_input_service import get_simulated_environment_for_user, has_simulated_profile, is_simulation_mode


_OVERRIDE_LEVELS = ('LOW', 'MEDIUM', 'HIGH')
_override_state = {
    'override_mode': False,
    'fraud_mode': False,
    'rain': 'LOW',
    'traffic': 'LOW',
    'aqi': 'LOW',
    'version': 0,
}


def set_environment_override(
    *,
    override_mode: bool,
    rain: str | None = None,
    traffic: str | None = None,
    aqi: str | None = None,
    fraud_mode: bool = False,
) -> dict:
    _override_state['override_mode'] = bool(override_mode)
    _override_state['fraud_mode'] = bool(fraud_mode)
    if rain in _OVERRIDE_LEVELS:
        _override_state['rain'] = rain
    if traffic in _OVERRIDE_LEVELS:
        _override_state['traffic'] = traffic
    if aqi in _OVERRIDE_LEVELS:
        _override_state['aqi'] = aqi
    _override_state['version'] = int(_override_state['version']) + 1
    return get_environment_override_state()


def get_environment_override_state() -> dict:
    return {
        'override_mode': bool(_override_state['override_mode']),
        'fraud_mode': bool(_override_state['fraud_mode']),
        'version': int(_override_state['version']),
        'levels': {
            'rain': str(_override_state['rain']),
            'traffic': str(_override_state['traffic']),
            'aqi': str(_override_state['aqi']),
        },
    }


def _apply_environment_override(result: dict) -> dict:
    if not bool(_override_state['override_mode']):
        return result

    rain_level = str(_override_state['rain'])
    traffic_level = str(_override_state['traffic'])
    aqi_level = str(_override_state['aqi'])

    rain_values = {
        'LOW': 0.3,
        'MEDIUM': 4.8,
        'HIGH': 12.5,
    }
    traffic_values = {
        'LOW': (0.9, 'LOW'),
        'MEDIUM': (1.2, 'MEDIUM'),
        'HIGH': (1.65, 'HIGH'),
    }
    aqi_values = {
        'LOW': (48, 1.0, 14.0, 22.0),
        'MEDIUM': (108, 2.0, 40.0, 68.0),
        'HIGH': (176, 4.0, 92.0, 134.0),
    }

    weather = dict(result.get('weather') or {})
    traffic = dict(result.get('traffic') or {})
    aqi = dict(result.get('aqi') or {})
    snapshot = dict(result.get('snapshot') or {})

    rainfall = rain_values[rain_level]
    traffic_index, traffic_level_text = traffic_values[traffic_level]
    aqi_score, aqi_index, pm25, pm10 = aqi_values[aqi_level]

    weather['rainfall'] = rainfall
    weather['rain_estimate'] = rainfall
    traffic['traffic_score'] = traffic_index
    traffic['traffic_index'] = traffic_index
    traffic['traffic_level'] = traffic_level_text
    aqi['aqi'] = int(aqi_score)
    aqi['aqi_index'] = float(aqi_index)
    aqi['pm2_5'] = float(pm25)
    aqi['pm10'] = float(pm10)

    snapshot['rain_estimate'] = rainfall
    snapshot['traffic_index'] = traffic_index
    snapshot['aqi'] = float(aqi_score)

    result['weather'] = weather
    result['traffic'] = traffic
    result['aqi'] = aqi
    result['snapshot'] = snapshot
    result['source'] = 'override'
    result['override'] = get_environment_override_state()
    return result


def get_environment(lat: float, lon: float, db: Session | None = None, user_id: int | None = None) -> dict:
    if db is not None and user_id is not None and (is_simulation_mode() or has_simulated_profile(db, user_id)):
        result = get_simulated_environment_for_user(db, user_id=user_id, lat=lat, lon=lon)
        result['source'] = 'simulation'
    else:
        result = build_environment(lat=lat, lon=lon, db=db, user_id=user_id)
        result['source'] = 'live'

    result = _apply_environment_override(result)
    result['last_updated'] = result.get('last_updated') or result.get('generated_at')
    result['requested_coordinates'] = {'lat': float(lat), 'lon': float(lon)}
    return result
