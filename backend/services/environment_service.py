from __future__ import annotations

from copy import deepcopy

from sqlalchemy.orm import Session

from core.environment_engine import build_environment
from services.simulation_input_service import get_simulated_environment_for_user, has_simulated_profile, is_simulation_mode

_OVERRIDE_STATE: dict[str, object] = {
    'override_mode': False,
    'rain': None,
    'traffic': None,
    'aqi': None,
    'scenario': 'reset',
}

_RAIN_LEVELS = {
    'LOW': 0.8,
    'MEDIUM': 4.5,
    'HIGH': 12.0,
}
_TRAFFIC_LEVELS = {
    'LOW': {'traffic_score': 0.95, 'traffic_index': 0.95, 'traffic_level': 'LOW'},
    'MEDIUM': {'traffic_score': 1.25, 'traffic_index': 1.25, 'traffic_level': 'MEDIUM'},
    'HIGH': {'traffic_score': 1.85, 'traffic_index': 1.85, 'traffic_level': 'HIGH'},
}
_AQI_LEVELS = {
    'LOW': {'aqi': 55, 'aqi_index': 55.0, 'pm2_5': 18.0, 'pm10': 28.0},
    'MEDIUM': {'aqi': 105, 'aqi_index': 105.0, 'pm2_5': 46.0, 'pm10': 72.0},
    'HIGH': {'aqi': 165, 'aqi_index': 165.0, 'pm2_5': 92.0, 'pm10': 138.0},
}


def set_environment_override(
    *,
    override_mode: bool,
    rain: str | None = None,
    traffic: str | None = None,
    aqi: str | None = None,
    scenario: str | None = None,
) -> dict:
    if not override_mode or scenario == 'reset':
        _OVERRIDE_STATE.update({
            'override_mode': False,
            'rain': None,
            'traffic': None,
            'aqi': None,
            'scenario': 'reset',
        })
    else:
        _OVERRIDE_STATE.update({
            'override_mode': True,
            'rain': rain,
            'traffic': traffic,
            'aqi': aqi,
            'scenario': scenario or 'custom',
        })
    return get_environment_override()


def get_environment_override() -> dict:
    return {
        'override_mode': bool(_OVERRIDE_STATE.get('override_mode')),
        'scenario': str(_OVERRIDE_STATE.get('scenario') or 'reset'),
        'rain': _OVERRIDE_STATE.get('rain'),
        'traffic': _OVERRIDE_STATE.get('traffic'),
        'aqi': _OVERRIDE_STATE.get('aqi'),
    }


def _apply_override(base: dict) -> dict:
    if not bool(_OVERRIDE_STATE.get('override_mode')):
        return base

    result = deepcopy(base)
    rain_level = _OVERRIDE_STATE.get('rain')
    traffic_level = _OVERRIDE_STATE.get('traffic')
    aqi_level = _OVERRIDE_STATE.get('aqi')

    if rain_level in _RAIN_LEVELS:
        rain_value = float(_RAIN_LEVELS[str(rain_level)])
        result.setdefault('weather', {})
        result['weather']['rainfall'] = rain_value
        result['weather']['rain_estimate'] = rain_value
        result.setdefault('snapshot', {})
        result['snapshot']['rain_estimate'] = rain_value
        for item in result.get('hourly_forecast', [])[:6]:
            item['rain_estimate'] = max(float(item.get('rain_estimate', 0.0) or 0.0), rain_value * 0.7)

    if traffic_level in _TRAFFIC_LEVELS:
        traffic_value = dict(_TRAFFIC_LEVELS[str(traffic_level)])
        result.setdefault('traffic', {})
        result['traffic'].update(traffic_value)
        result.setdefault('snapshot', {})
        result['snapshot']['traffic_index'] = float(traffic_value['traffic_index'])
        for item in result.get('hourly_forecast', [])[:6]:
            item['traffic_index'] = max(float(item.get('traffic_index', 1.0) or 1.0), float(traffic_value['traffic_index']))

    if aqi_level in _AQI_LEVELS:
        aqi_value = dict(_AQI_LEVELS[str(aqi_level)])
        result.setdefault('aqi', {})
        result['aqi'].update(aqi_value)
        result.setdefault('snapshot', {})
        result['snapshot']['aqi'] = float(aqi_value['aqi_index'])
        for item in result.get('hourly_forecast', [])[:6]:
            item['aqi'] = max(float(item.get('aqi', 0.0) or 0.0), float(aqi_value['aqi_index']))

    scenario = str(_OVERRIDE_STATE.get('scenario') or 'custom')
    result['source'] = 'override'
    result['override_mode'] = True
    result['override'] = get_environment_override()
    result['demo_scenario'] = scenario
    if 'hyper_local_analysis' in result and isinstance(result['hyper_local_analysis'], dict):
        result['hyper_local_analysis']['source'] = 'override'
        if scenario == 'rain':
            result['hyper_local_analysis']['insight'] = 'Demo override is amplifying disruption signals to simulate severe working conditions.'
        elif scenario == 'fraud':
            result['hyper_local_analysis']['insight'] = 'Demo override is holding disruption low to test mismatch and fraud handling.'
    return result


def get_environment(lat: float, lon: float, db: Session | None = None, user_id: int | None = None) -> dict:
    if db is not None and user_id is not None and (is_simulation_mode() or has_simulated_profile(db, user_id)):
        result = get_simulated_environment_for_user(db, user_id=user_id, lat=lat, lon=lon)
        result['source'] = 'simulation'
    else:
        result = build_environment(lat=lat, lon=lon, db=db, user_id=user_id)
        result['source'] = 'live'

    result = _apply_override(result)
    result['last_updated'] = result.get('last_updated') or result.get('generated_at')
    result['requested_coordinates'] = {'lat': float(lat), 'lon': float(lon)}
    return result
