import logging
import os

import requests

logger = logging.getLogger('gig_insurance_backend.traffic')

TRAFFIC_URL = 'https://api.openrouteservice.org/v2/directions/driving-car'
ORS_API_KEY = os.getenv('ORS_API_KEY', '')
DEFAULT_TRAFFIC = {
    'traffic_score': 1.0,
    'traffic_index': 1.0,
    'traffic_level': 'LOW',
    'route_duration_seconds': 720.0,
    'free_flow_duration_seconds': 720.0,
}


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def get_traffic(lat: float, lon: float) -> dict:
    if not ORS_API_KEY:
        logger.warning('ORS_API_KEY missing, using fallback traffic response')
        return DEFAULT_TRAFFIC.copy()

    headers = {
        'Authorization': ORS_API_KEY,
        'Content-Type': 'application/json',
    }

    route = {
        'coordinates': [
            [lon, lat],
            [lon + 0.02, lat + 0.02],
        ]
    }

    try:
        resp = requests.post(TRAFFIC_URL, json=route, headers=headers, timeout=8)
        resp.raise_for_status()
        data = resp.json()
        summary = data.get('routes', [{}])[0].get('summary', {})
        distance = float(summary.get('distance', 1000.0))
        duration = float(summary.get('duration', 720.0))

        distance_km = distance / 1000.0
        free_flow_speed_kph = 35.0
        free_flow_duration = (distance_km / free_flow_speed_kph) * 3600.0 if distance_km > 0 else duration
        traffic_index = duration / max(free_flow_duration, 1.0)

        traffic_level = 'LOW'
        if traffic_index >= 1.5:
            traffic_level = 'HIGH'
        elif traffic_index >= 1.2:
            traffic_level = 'MEDIUM'

        result = {
            'traffic_score': _round(traffic_index),
            'traffic_index': _round(traffic_index),
            'traffic_level': traffic_level,
            'route_duration_seconds': _round(duration),
            'free_flow_duration_seconds': _round(free_flow_duration),
        }
        logger.info('traffic computed: %s', result)
        return result
    except Exception as exc:
        logger.warning('traffic fetch error, using fallback: %s', exc)
        return DEFAULT_TRAFFIC.copy()
