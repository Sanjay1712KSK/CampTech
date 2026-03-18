import logging

from datetime import datetime

from services.weather_service import get_weather
from services.aqi_service import get_aqi
from services.traffic_service import get_traffic

logger = logging.getLogger('gig_insurance_backend.environment')

# very simple cache map: (lat,lon)->(expiry_timestamp,data)
_cache = {}
CACHE_TTL_SECONDS = 10 * 60


def _is_weekend(dt: datetime) -> bool:
    return dt.weekday() >= 5


def get_environment(lat: float, lon: float) -> dict:
    key = (round(lat, 6), round(lon, 6))
    now_ts = datetime.utcnow().timestamp()
    cached = _cache.get(key)
    if cached and cached[0] > now_ts:
        logger.info('environment cache hit for %s', key)
        return cached[1]

    weather = get_weather(lat, lon)
    aqi = get_aqi(lat, lon)
    traffic = get_traffic(lat, lon)

    now = datetime.utcnow()
    context = {
        'hour': now.hour,
        'day_type': 'weekend' if _is_weekend(now) else 'weekday',
    }

    result = {
        'weather': weather,
        'aqi': aqi,
        'traffic': traffic,
        'context': context,
    }

    _cache[key] = (now_ts + CACHE_TTL_SECONDS, result)
    logger.info('environment response cached for %s', key)
    return result