import logging

import requests

logger = logging.getLogger('gig_insurance_backend.traffic')

import os

TRAFFIC_URL = 'https://api.openrouteservice.org/v2/directions/driving-car'
ORS_API_KEY = os.getenv('ORS_API_KEY', 'your_openrouteservice_api_key')
DEFAULT_TRAFFIC = {
    'traffic_score': 1.0,
    'traffic_level': 'LOW',
}


def get_traffic(lat: float, lon: float) -> dict:
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
        resp = requests.post(TRAFFIC_URL, json=route, headers=headers, timeout=5)
        resp.raise_for_status()
        data = resp.json()

        summary = data.get('routes', [{}])[0].get('summary', {})
        distance = float(summary.get('distance', 1000.0))
        duration = float(summary.get('duration', 60.0))

        distance_km = distance / 1000.0
        avg_speed = 35.0
        free_time = (distance_km / avg_speed) * 3600.0 if avg_speed > 0 else 1.0

        traffic_score = duration / free_time if free_time > 0 else 1.0
        traffic_level = 'LOW'
        if traffic_score >= 1.5:
            traffic_level = 'HIGH'
        elif traffic_score >= 1.2:
            traffic_level = 'MEDIUM'

        result = {
            'traffic_score': float(traffic_score),
            'traffic_level': traffic_level,
        }

        logger.info('traffic computed: %s', result)
        return result

    except Exception as exc:
        logger.exception('traffic fetch error, using fallback: %s', exc)
        return DEFAULT_TRAFFIC.copy()