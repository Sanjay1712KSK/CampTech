import logging

import requests

logger = logging.getLogger('gig_insurance_backend.weather')

WEATHER_URL = 'https://api.open-meteo.com/v1/forecast'
DEFAULT_WEATHER = {
    'temperature': 20.0,
    'humidity': 50.0,
    'wind_speed': 5.0,
    'rainfall': 0.0,
}


def get_weather(lat: float, lon: float) -> dict:
    params = {
        'latitude': lat,
        'longitude': lon,
        'current_weather': 'true',
        'hourly': 'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation',
    }

    try:
        resp = requests.get(WEATHER_URL, params=params, timeout=5)
        resp.raise_for_status()
        data = resp.json()

        current = data.get('current_weather', {})
        hourly = data.get('hourly', {})
        time_list = hourly.get('time', [])

        # find current hour index
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
        index = 0
        for i, t in enumerate(time_list):
            try:
                t_dt = datetime.fromisoformat(t.replace('Z', '+00:00')).replace(minute=0, second=0, microsecond=0)
                if t_dt == now:
                    index = i
                    break
            except Exception:
                pass

        humidity = hourly.get('relative_humidity_2m', [])
        precipitation = hourly.get('precipitation', [])

        result = {
            'temperature': float(current.get('temperature', DEFAULT_WEATHER['temperature'])),
            'humidity': float(humidity[index] if index < len(humidity) else DEFAULT_WEATHER['humidity']),
            'wind_speed': float(current.get('windspeed', DEFAULT_WEATHER['wind_speed'])),
            'rainfall': float(precipitation[index] if index < len(precipitation) else DEFAULT_WEATHER['rainfall']),
        }

        logger.info('weather fetched: %s', result)
        return result

    except Exception as exc:
        logger.exception('weather fetch error, using fallback: %s', exc)
        return DEFAULT_WEATHER.copy()