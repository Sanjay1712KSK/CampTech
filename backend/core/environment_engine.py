from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from models.environment_snapshot import EnvironmentSnapshot
from models.gig_income import GigIncome
from services.aqi_service import get_aqi
from services.traffic_service import get_traffic
from services.weather_service import get_weather

logger = logging.getLogger('gig_insurance_backend.environment_engine')

_cache: dict[tuple[float, float], tuple[float, dict]] = {}
CACHE_TTL_SECONDS = 10 * 60
LOCAL_BUCKET_DECIMALS = 2


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


def _snapshot_disruption_index(snapshot: dict) -> float:
    rain_factor = _clamp(float(snapshot.get('rain_estimate', 0.0)) / 12.0)
    traffic_factor = _clamp((float(snapshot.get('traffic_index', 1.0)) - 1.0) / 1.2)
    aqi_factor = _clamp((float(snapshot.get('aqi', 50.0)) - 50.0) / 250.0)
    heat_factor = _clamp((float(snapshot.get('temperature', 30.0)) - 32.0) / 12.0)
    return _round((0.35 * rain_factor) + (0.3 * traffic_factor) + (0.2 * aqi_factor) + (0.15 * heat_factor))


def _gig_history_baseline(db: Session | None, user_id: int | None) -> dict | None:
    if db is None or user_id is None:
        return None
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .limit(10)
        .all()
    )
    if not records:
        return None
    total = len(records)
    return {
        'temperature': _round(sum(float(row.temperature) for row in records) / total),
        'wind_speed': _round(sum(float(row.wind_speed) for row in records) / total),
        'humidity': _round(sum(float(row.humidity) for row in records) / total),
        'rain_estimate': _round(sum(float(row.rainfall) for row in records) / total),
        'aqi': _round(sum(float(row.aqi_level) * 50.0 for row in records) / total),
        'traffic_index': _round(sum(float(row.traffic_score) for row in records) / total),
    }


def compute_hyper_local_risk(snapshot: dict, db: Session | None = None, lat: float | None = None, lon: float | None = None, user_id: int | None = None) -> dict:
    history_baseline = None
    source = 'synthetic_current'

    if db is not None and lat is not None and lon is not None:
        cutoff = _utcnow() - timedelta(days=10)
        records = (
            db.query(EnvironmentSnapshot)
            .filter(
                EnvironmentSnapshot.bucket_lat == _bucket(lat),
                EnvironmentSnapshot.bucket_lon == _bucket(lon),
                EnvironmentSnapshot.observed_at >= cutoff,
            )
            .order_by(EnvironmentSnapshot.observed_at.desc())
            .limit(120)
            .all()
        )
        if records:
            total = len(records)
            history_baseline = {
                'temperature': _round(sum(float(row.temperature) for row in records) / total),
                'wind_speed': _round(sum(float(row.wind_speed) for row in records) / total),
                'humidity': _round(sum(float(row.humidity) for row in records) / total),
                'rain_estimate': _round(sum(float(row.rain_estimate) for row in records) / total),
                'aqi': _round(sum(float(row.aqi) for row in records) / total),
                'traffic_index': _round(sum(float(row.traffic_index) for row in records) / total),
            }
            source = 'environment_snapshots'

    if history_baseline is None:
        history_baseline = _gig_history_baseline(db, user_id)
        if history_baseline is not None:
            source = 'gig_history'

    if history_baseline is None:
        history_baseline = snapshot.copy()

    baseline_index = max(_snapshot_disruption_index(history_baseline), 0.05)
    current_index = _snapshot_disruption_index(snapshot)
    hyper_local_risk = _round(max(current_index / baseline_index, 0.2), 3)
    disruption_delta = int(round(max(hyper_local_risk - 1.0, 0.0) * 100))

    if source == 'synthetic_current':
        insight = 'Insufficient local history; using current conditions as the baseline'
    elif hyper_local_risk > 1.05:
        insight = f'{disruption_delta}% higher disruption than recent average'
    elif hyper_local_risk < 0.95:
        insight = f'{abs(disruption_delta)}% lower disruption than recent average'
    else:
        insight = 'Conditions are close to the recent local average'

    return {
        'hyper_local_risk': hyper_local_risk,
        'insight': insight,
        'baseline_snapshot': history_baseline,
        'source': source,
    }


def compute_time_slot_risk(hourly: list[dict]) -> dict:
    slot_map = {
        'morning': range(6, 12),
        'afternoon': range(12, 17),
        'evening': range(17, 22),
        'night': tuple(list(range(22, 24)) + list(range(0, 6))),
    }

    def _slot_score(items: list[dict]) -> float:
        if not items:
            return 0.0
        total = 0.0
        for item in items:
            total += _snapshot_disruption_index({
                'temperature': item.get('temperature', 0.0),
                'wind_speed': item.get('wind_speed', 0.0),
                'humidity': item.get('humidity', 0.0),
                'rain_estimate': item.get('rain_estimate', 0.0),
                'aqi': item.get('aqi', 50.0),
                'traffic_index': item.get('traffic_index', 1.0),
            })
        return total / len(items)

    def _level(score: float) -> str:
        if score < 0.33:
            return 'LOW'
        if score < 0.66:
            return 'MEDIUM'
        return 'HIGH'

    result = {}
    for slot_name, hour_range in slot_map.items():
        slot_items = [item for item in hourly if int(item.get('hour', -1)) in hour_range]
        result[slot_name] = _level(_slot_score(slot_items))
    return result


def compute_predictive_risk(hourly: list[dict]) -> dict:
    upcoming = hourly[:6]
    if not upcoming:
        return {
            'next_6hr_risk': 0.0,
            'trend': 'stable',
        }

    scores = [
        _snapshot_disruption_index({
            'temperature': item.get('temperature', 0.0),
            'wind_speed': item.get('wind_speed', 0.0),
            'humidity': item.get('humidity', 0.0),
            'rain_estimate': item.get('rain_estimate', 0.0),
            'aqi': item.get('aqi', 50.0),
            'traffic_index': item.get('traffic_index', 1.0),
        })
        for item in upcoming
    ]
    first_half = sum(scores[:3]) / max(len(scores[:3]), 1)
    second_half = sum(scores[3:]) / max(len(scores[3:]), 1)
    trend = 'stable'
    if second_half > first_half + 0.05:
        trend = 'increasing'
    elif second_half < first_half - 0.05:
        trend = 'decreasing'

    return {
        'next_6hr_risk': _round(sum(scores) / len(scores)),
        'trend': trend,
    }


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

    payload = {
        'weather': weather,
        'aqi': aqi,
        'traffic': traffic,
        'context': {
            'hour': now.hour,
            'day_type': 'weekend' if _is_weekend(now) else 'weekday',
        },
        'snapshot': snapshot,
        'time_slot_risk': compute_time_slot_risk(hourly_forecast),
        'predictive_risk': compute_predictive_risk(hourly_forecast),
        'hourly_forecast': hourly_forecast,
    }
    _cache[key] = (now_ts + CACHE_TTL_SECONDS, payload)

    if db is not None:
        _save_snapshot(db, lat, lon, snapshot)
        payload['hyper_local_analysis'] = compute_hyper_local_risk(snapshot, db=db, lat=lat, lon=lon, user_id=user_id)
    else:
        payload['hyper_local_analysis'] = compute_hyper_local_risk(snapshot, db=None, lat=lat, lon=lon, user_id=user_id)

    logger.info('environment built for (%s, %s)', lat, lon)
    return payload
