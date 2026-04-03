from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from core.hyperlocal_engine import LOCAL_BUCKET_DECIMALS, compute_hyper_local_risk
from core.predictive_engine import compute_predictive_risk
from core.timeslot_engine import compute_time_slot_risk
from models.environment_snapshot import EnvironmentSnapshot
from services.aqi_service import get_aqi
from services.traffic_service import get_traffic
from services.weather_service import get_weather

logger = logging.getLogger('gig_insurance_backend.environment_engine')

_cache: dict[tuple[float, float], tuple[float, dict]] = {}
CACHE_TTL_SECONDS = 10 * 60


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def _bucket(value: float) -> float:
    return round(float(value), LOCAL_BUCKET_DECIMALS)


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _is_weekend(dt: datetime) -> bool:
    return dt.weekday() >= 5


def _snapshot_from_sources(weather: dict, aqi: dict, traffic: dict) -> dict:
    traffic_index = float(traffic.get('traffic_index', traffic.get('traffic_score', 1.0)) or 1.0)
    aqi_value = float(aqi.get('aqi_index', aqi.get('aqi', 50.0)) or 50.0)
    rain_estimate = float(weather.get('rain_estimate', weather.get('rainfall', 0.0)) or 0.0)
    return {
        'temperature': _round(float(weather.get('temperature', 0.0) or 0.0)),
        'wind_speed': _round(float(weather.get('wind_speed', 0.0) or 0.0)),
        'humidity': _round(float(weather.get('humidity', 0.0) or 0.0)),
        'rain_estimate': _round(rain_estimate),
        'aqi': _round(aqi_value),
        'traffic_index': _round(traffic_index),
    }


def _save_snapshot(db: Session | None, lat: float, lon: float, snapshot: dict) -> None:
    if db is None:
        return
    record = EnvironmentSnapshot(
        bucket_lat=_bucket(lat),
        bucket_lon=_bucket(lon),
        temperature=float(snapshot['temperature']),
        wind_speed=float(snapshot['wind_speed']),
        humidity=float(snapshot['humidity']),
        rain_estimate=float(snapshot['rain_estimate']),
        aqi=float(snapshot['aqi']),
        traffic_index=float(snapshot['traffic_index']),
        observed_at=_utcnow(),
    )
    db.add(record)
    db.commit()


def build_environment(lat: float, lon: float, db: Session | None = None, user_id: int | None = None) -> dict:
    key = (round(lat, 4), round(lon, 4))
    now_ts = _utcnow().timestamp()
    cached = _cache.get(key)
    if cached and cached[0] > now_ts:
        cached_payload = dict(cached[1])
        if db is not None:
            _save_snapshot(db, lat, lon, cached_payload['snapshot'])
            cached_payload['hyper_local_analysis'] = compute_hyper_local_risk(
                cached_payload['snapshot'],
                db=db,
                lat=lat,
                lon=lon,
                user_id=user_id,
            )
        return cached_payload

    weather = get_weather(lat, lon)
    aqi = get_aqi(lat, lon)
    traffic = get_traffic(lat, lon)
    now = _utcnow()
    snapshot = _snapshot_from_sources(weather, aqi, traffic)

    hourly_weather = weather.get('hourly', [])
    hourly_forecast = []
    for item in hourly_weather[:24]:
        hourly_forecast.append({
            'time': item.get('time'),
            'hour': int(item.get('hour', 0)),
            'temperature': item.get('temperature', snapshot['temperature']),
            'wind_speed': item.get('wind_speed', snapshot['wind_speed']),
            'humidity': item.get('humidity', snapshot['humidity']),
            'rain_estimate': item.get('rain_estimate', snapshot['rain_estimate']),
            'aqi': float(aqi.get('aqi_index', aqi.get('aqi', snapshot['aqi']))),
            'traffic_index': float(traffic.get('traffic_index', traffic.get('traffic_score', snapshot['traffic_index']))),
        })

    hyper_local_analysis = compute_hyper_local_risk(
        snapshot,
        db=db,
        lat=lat,
        lon=lon,
        user_id=user_id,
    )

    payload = {
        'weather': weather,
        'aqi': aqi,
        'traffic': traffic,
        'context': {
            'hour': now.hour,
            'day_type': 'weekend' if _is_weekend(now) else 'weekday',
        },
        'snapshot': snapshot,
        'hyper_local_risk': float(hyper_local_analysis.get('hyper_local_risk', 1.0) or 1.0),
        'hyper_local_analysis': hyper_local_analysis,
        'time_slot_risk': compute_time_slot_risk(hourly_forecast),
        'predictive_risk': compute_predictive_risk(hourly_forecast),
        'hourly_forecast': hourly_forecast,
    }
    _cache[key] = (now_ts + CACHE_TTL_SECONDS, payload)
    if db is not None:
        _save_snapshot(db, lat, lon, snapshot)

    logger.info('environment built for (%s, %s)', lat, lon)
    return payload
