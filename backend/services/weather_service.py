import logging
from datetime import datetime

import requests

logger = logging.getLogger('gig_insurance_backend.weather')

WEATHER_URL = 'https://api.open-meteo.com/v1/forecast'
DEFAULT_WEATHER = {
    'temperature': 20.0,
    'humidity': 50.0,
    'wind_speed': 5.0,
    'rainfall': 0.0,
    'rain_estimate': 0.0,
    'hourly': [],
}


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def get_weather(lat: float, lon: float) -> dict:
    params = {
        'latitude': lat,
        'longitude': lon,
        'timezone': 'auto',
        'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation',
        'hourly': 'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation',
        'forecast_days': 2,
    }

    try:
        resp = requests.get(WEATHER_URL, params=params, timeout=8)
        resp.raise_for_status()
        data = resp.json()

        current = data.get('current', {})
        hourly = data.get('hourly', {})
        times = hourly.get('time', [])
        temperatures = hourly.get('temperature_2m', [])
        humidities = hourly.get('relative_humidity_2m', [])
        winds = hourly.get('wind_speed_10m', [])
        precipitation = hourly.get('precipitation', [])

        hourly_rows = []
        for index, time_value in enumerate(times[:24]):
            parsed = datetime.fromisoformat(time_value)
            hourly_rows.append({
                'time': time_value,
                'hour': parsed.hour,
                'temperature': _round(temperatures[index] if index < len(temperatures) else current.get('temperature_2m', 20.0)),
                'humidity': _round(humidities[index] if index < len(humidities) else current.get('relative_humidity_2m', 50.0)),
                'wind_speed': _round(winds[index] if index < len(winds) else current.get('wind_speed_10m', 5.0)),
                'rain_estimate': _round(precipitation[index] if index < len(precipitation) else current.get('precipitation', 0.0)),
            })

        result = {
            'temperature': _round(current.get('temperature_2m', DEFAULT_WEATHER['temperature'])),
            'humidity': _round(current.get('relative_humidity_2m', DEFAULT_WEATHER['humidity'])),
            'wind_speed': _round(current.get('wind_speed_10m', DEFAULT_WEATHER['wind_speed'])),
            'rainfall': _round(current.get('precipitation', DEFAULT_WEATHER['rainfall'])),
            'rain_estimate': _round(current.get('precipitation', DEFAULT_WEATHER['rain_estimate'])),
            'hourly': hourly_rows,
        }

        logger.info('weather fetched: %s', result)
        return result
    except Exception as exc:
        logger.exception('weather fetch error, using fallback: %s', exc)
        return DEFAULT_WEATHER.copy()
