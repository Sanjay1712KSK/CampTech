import logging
import os

import requests

logger = logging.getLogger('gig_insurance_backend.aqi')

AQI_URL = 'https://api.openweathermap.org/data/2.5/air_pollution'
OPENWEATHER_KEY = os.getenv('OPENWEATHER_API_KEY', '')
DEFAULT_AQI = {
    'aqi': 2,
    'aqi_index': 75.0,
    'pm2_5': 10.0,
    'pm10': 20.0,
}


def _aqi_bucket_to_index(aqi_bucket: int) -> float:
    mapping = {
        1: 25.0,
        2: 75.0,
        3: 150.0,
        4: 250.0,
        5: 350.0,
    }
    return float(mapping.get(int(aqi_bucket), 75.0))


def get_aqi(lat: float, lon: float) -> dict:
    if not OPENWEATHER_KEY:
        logger.warning('OPENWEATHER_API_KEY missing, using fallback AQI response')
        return DEFAULT_AQI.copy()

    params = {
        'lat': lat,
        'lon': lon,
        'appid': OPENWEATHER_KEY,
    }

    try:
        resp = requests.get(AQI_URL, params=params, timeout=8)
        resp.raise_for_status()
        data = resp.json()
        first = data.get('list', [{}])[0]
        aqi_bucket = int(first.get('main', {}).get('aqi', DEFAULT_AQI['aqi']))
        components = first.get('components', {})

        result = {
            'aqi': aqi_bucket,
            'aqi_index': _aqi_bucket_to_index(aqi_bucket),
            'pm2_5': float(components.get('pm2_5', DEFAULT_AQI['pm2_5'])),
            'pm10': float(components.get('pm10', DEFAULT_AQI['pm10'])),
        }
        logger.info('aqi fetched: %s', result)
        return result
    except Exception as exc:
        logger.exception('aqi fetch error, using fallback: %s', exc)
        return DEFAULT_AQI.copy()
