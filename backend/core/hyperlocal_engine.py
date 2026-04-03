from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from models.environment_snapshot import EnvironmentSnapshot
from models.gig_income import GigIncome

LOCAL_BUCKET_DECIMALS = 2


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _bucket(value: float) -> float:
    return round(float(value), LOCAL_BUCKET_DECIMALS)


def snapshot_disruption_index(snapshot: dict) -> float:
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


def compute_hyper_local_risk(
    snapshot: dict,
    db: Session | None = None,
    lat: float | None = None,
    lon: float | None = None,
    user_id: int | None = None,
) -> dict:
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
            .limit(240)
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

    baseline_index = max(snapshot_disruption_index(history_baseline), 0.05)
    current_index = snapshot_disruption_index(snapshot)
    hyper_local_risk = _round(max(current_index / baseline_index, 0.2), 3)
    delta_pct = int(round((hyper_local_risk - 1.0) * 100))

    if source == 'synthetic_current':
        insight = 'Insufficient local history; using current conditions as the baseline'
    elif hyper_local_risk > 1.05:
        insight = f'{delta_pct}% higher disruption than recent average'
    elif hyper_local_risk < 0.95:
        insight = f'{abs(delta_pct)}% lower disruption than recent average'
    else:
        insight = 'Conditions are close to the recent local average'

    return {
        'hyper_local_risk': hyper_local_risk,
        'insight': insight,
        'baseline_snapshot': history_baseline,
        'source': source,
    }
