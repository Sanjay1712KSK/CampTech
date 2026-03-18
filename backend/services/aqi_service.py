import logging

import requests

logger = logging.getLogger('gig_insurance_backend.aqi')

AQI_URL = 'http://api.openweathermap.org/data/2.5/air_pollution'
OPENWEATHER_KEY = '258d64580bceb19f1efcb0a62fb81af6'
DEFAULT_AQI = {
    'aqi': 2,
    'pm2_5': 10.0,
    'pm10': 20.0,
}


def get_aqi(lat: float, lon: float) -> dict:
    params = {
        'lat': lat,
        'lon': lon,
        'appid': OPENWEATHER_KEY,
    }

    try:
        resp = requests.get(AQI_URL, params=params, timeout=5)
        resp.raise_for_status()
        data = resp.json()

        first = data.get('list', [{}])[0]
        aqi_code = int(first.get('main', {}).get('aqi', DEFAULT_AQI['aqi']))
        components = first.get('components', {})

        result = {
            'aqi': aqi_code,
            'pm2_5': float(components.get('pm2_5', DEFAULT_AQI['pm2_5'])),
            'pm10': float(components.get('pm10', DEFAULT_AQI['pm10'])),
        }

        logger.info('aqi fetched: %s', result)
        return result

    except Exception as exc:
        logger.exception('aqi fetch error, using fallback: %s', exc)
        return DEFAULT_AQI.copy()