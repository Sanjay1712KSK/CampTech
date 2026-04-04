from __future__ import annotations

import logging
import uuid
from datetime import date, timedelta

from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from models.models import ClaimHistory, ModelWeight, UserBehavior

logger = logging.getLogger('gig_insurance_backend.ml_service')

DEFAULT_MODEL_NAME = 'expected_loss_model'
DEFAULT_MODEL_VERSION = 'v1'
DEFAULT_WEIGHTS = {
    'rain_weight': 0.35,
    'traffic_weight': 0.25,
    'aqi_weight': 0.25,
    'wind_weight': 0.15,
    'heat_weight': 0.10,
}


def _round(value: float, places: int = 4) -> float:
    return float(round(float(value), places))


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _normalize(weights: dict[str, float]) -> dict[str, float]:
    total = sum(max(value, 0.001) for value in weights.values())
    if total <= 0:
        return DEFAULT_WEIGHTS.copy()
    return {key: _round(max(value, 0.001) / total) for key, value in weights.items()}


def _trigger_flags(triggers: list[str]) -> dict[str, float]:
    trigger_set = {str(item).upper() for item in triggers}
    return {
        'rain': 1.0 if 'RAIN_TRIGGER' in trigger_set else 0.0,
        'traffic': 1.0 if 'TRAFFIC_TRIGGER' in trigger_set else 0.0,
        'aqi': 1.0 if 'AQI_TRIGGER' in trigger_set else 0.0,
        'heat': 1.0 if 'HEAT_TRIGGER' in trigger_set else 0.0,
        'combined': 1.0 if 'COMBINED_TRIGGER' in trigger_set else 0.0,
    }


def get_or_create_model_weights(
    db: Session,
    model_name: str = DEFAULT_MODEL_NAME,
    version: str = DEFAULT_MODEL_VERSION,
) -> ModelWeight:
    record = (
        db.query(ModelWeight)
        .filter(ModelWeight.model_name == model_name, ModelWeight.version == version, ModelWeight.is_active.is_(True))
        .order_by(ModelWeight.id.desc())
        .first()
    )
    if record is None:
        record = ModelWeight(
            model_name=model_name,
            version=version,
            **DEFAULT_WEIGHTS,
            learning_rate=0.02,
            is_active=True,
            weight_metadata={'source': 'bootstrap'},
        )
        db.add(record)
        db.flush()
    return record


def expected_loss_prediction(risk_score: float, baseline_income: float) -> float:
    return _round(max(risk_score, 0.0) * max(baseline_income, 0.0), 2)


def record_claim_learning(
    db: Session,
    *,
    user_id: int,
    policy_id: int | None,
    risk_snapshot_id: int | None,
    claim_date: date,
    status: str,
    risk_score: float,
    baseline_income: float,
    actual_loss: float,
    approved_payout: float,
    triggers: list[str] | None = None,
    reasons: list[str] | None = None,
    fraud_score: float | None = None,
    review_notes: str | None = None,
) -> ClaimHistory:
    active_triggers = [str(item) for item in (triggers or [])]
    predicted_loss = expected_loss_prediction(risk_score, baseline_income)
    history = ClaimHistory(
        user_id=int(user_id),
        policy_id=policy_id,
        risk_snapshot_id=risk_snapshot_id,
        claim_reference=f'clh_{uuid.uuid4().hex[:12]}',
        claim_date=claim_date,
        status=status,
        predicted_loss=predicted_loss,
        actual_loss=_round(actual_loss, 2),
        claimed_loss=_round(actual_loss, 2),
        approved_payout=_round(approved_payout, 2),
        fraud_score=None if fraud_score is None else _round(fraud_score, 4),
        trigger_snapshot={
            'active_triggers': active_triggers,
            'trigger_flags': _trigger_flags(active_triggers),
            'risk_score': _round(risk_score, 4),
            'baseline_income': _round(baseline_income, 2),
        },
        reasons=[str(item) for item in (reasons or [])],
        review_notes=review_notes,
    )
    db.add(history)
    db.flush()
    logger.info(
        'claim learning recorded user_id=%s predicted_loss=%s actual_loss=%s triggers=%s',
        user_id,
        history.predicted_loss,
        history.actual_loss,
        active_triggers,
    )
    return history


def update_model_weights(
    db: Session,
    *,
    user_id: int | None = None,
    lookback_days: int = 90,
    model_name: str = DEFAULT_MODEL_NAME,
    version: str = DEFAULT_MODEL_VERSION,
) -> dict[str, float]:
    record = get_or_create_model_weights(db, model_name=model_name, version=version)
    cutoff = date.today() - timedelta(days=max(lookback_days, 1))

    query = db.query(ClaimHistory).filter(ClaimHistory.claim_date >= cutoff)
    if user_id is not None:
        query = query.filter(ClaimHistory.user_id == int(user_id))
    histories = query.order_by(ClaimHistory.claim_date.desc(), ClaimHistory.id.desc()).all()

    if not histories:
        return {
            'rain_weight': _round(record.rain_weight),
            'traffic_weight': _round(record.traffic_weight),
            'aqi_weight': _round(record.aqi_weight),
            'wind_weight': _round(record.wind_weight),
            'heat_weight': _round(record.heat_weight),
        }

    weighted_error_total = 0.0
    signal_totals = {'rain': 0.0, 'traffic': 0.0, 'aqi': 0.0, 'wind': 0.0, 'heat': 0.0}
    for item in histories:
        predicted = max(float(item.predicted_loss or 0.0), 0.0)
        actual = max(float(item.actual_loss or 0.0), 0.0)
        denominator = max(max(predicted, actual), 1.0)
        error_ratio = abs(actual - predicted) / denominator
        trigger_snapshot = item.trigger_snapshot or {}
        trigger_flags = trigger_snapshot.get('trigger_flags') or {}
        weighted_error_total += error_ratio
        signal_totals['rain'] += float(trigger_flags.get('rain', 0.0)) * error_ratio
        signal_totals['traffic'] += float(trigger_flags.get('traffic', 0.0)) * error_ratio
        signal_totals['aqi'] += float(trigger_flags.get('aqi', 0.0)) * error_ratio
        signal_totals['heat'] += float(trigger_flags.get('heat', 0.0)) * error_ratio
        wind_signal = max(float(trigger_flags.get('combined', 0.0)), float(trigger_flags.get('rain', 0.0)) * 0.5)
        signal_totals['wind'] += wind_signal * error_ratio

    total_signal = max(weighted_error_total, 0.001)
    learning_rate = float(record.learning_rate or 0.02)
    target = {
        'rain_weight': (signal_totals['rain'] / total_signal) or DEFAULT_WEIGHTS['rain_weight'],
        'traffic_weight': (signal_totals['traffic'] / total_signal) or DEFAULT_WEIGHTS['traffic_weight'],
        'aqi_weight': (signal_totals['aqi'] / total_signal) or DEFAULT_WEIGHTS['aqi_weight'],
        'wind_weight': (signal_totals['wind'] / total_signal) or DEFAULT_WEIGHTS['wind_weight'],
        'heat_weight': (signal_totals['heat'] / total_signal) or DEFAULT_WEIGHTS['heat_weight'],
    }

    blended = _normalize({
        'rain_weight': (1 - learning_rate) * float(record.rain_weight) + (learning_rate * target['rain_weight']),
        'traffic_weight': (1 - learning_rate) * float(record.traffic_weight) + (learning_rate * target['traffic_weight']),
        'aqi_weight': (1 - learning_rate) * float(record.aqi_weight) + (learning_rate * target['aqi_weight']),
        'wind_weight': (1 - learning_rate) * float(record.wind_weight) + (learning_rate * target['wind_weight']),
        'heat_weight': (1 - learning_rate) * float(record.heat_weight) + (learning_rate * target['heat_weight']),
    })

    record.rain_weight = blended['rain_weight']
    record.traffic_weight = blended['traffic_weight']
    record.aqi_weight = blended['aqi_weight']
    record.wind_weight = blended['wind_weight']
    record.heat_weight = blended['heat_weight']
    record.weight_metadata = {
        'lookback_days': lookback_days,
        'sample_count': len(histories),
        'last_update_error': _round(weighted_error_total / len(histories), 4),
        'target_distribution': {key: _round(value, 4) for key, value in target.items()},
    }
    db.flush()

    logger.info('model weights updated from claim history: %s', blended)
    return blended


def update_user_behavior(
    db: Session,
    *,
    user_id: int,
    lookback_days: int = 30,
) -> dict:
    cutoff = date.today() - timedelta(days=max(lookback_days, 1))
    incomes = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id), GigIncome.date >= cutoff)
        .order_by(GigIncome.date.desc())
        .all()
    )
    claims = (
        db.query(ClaimHistory)
        .filter(ClaimHistory.user_id == int(user_id), ClaimHistory.claim_date >= cutoff)
        .order_by(ClaimHistory.claim_date.desc())
        .all()
    )

    if incomes:
        avg_income = _round(sum(float(item.earnings) for item in incomes) / len(incomes), 2)
        avg_hours = _round(sum(float(item.hours_worked) for item in incomes) / len(incomes), 2)
        weekend_ratio = _round(sum(1 for item in incomes if bool(item.is_weekend)) / len(incomes), 4)
        cities: dict[str, int] = {}
        for item in incomes:
            city = (item.city or 'Unknown').strip() or 'Unknown'
            cities[city] = cities.get(city, 0) + 1
        primary_city = max(cities, key=cities.get)
        work_pattern = 'weekend_heavy' if weekend_ratio >= 0.4 else ('steady' if avg_hours >= 7.5 else 'flexible')
    else:
        avg_income = 0.0
        avg_hours = 0.0
        weekend_ratio = 0.0
        primary_city = 'Unknown'
        work_pattern = 'unknown'

    avg_loss = _round(sum(float(item.actual_loss) for item in claims) / len(claims), 2) if claims else 0.0
    claim_frequency = _round(len(claims) / max(lookback_days, 1), 4)

    snapshot = {
        'avg_income': avg_income,
        'avg_loss': avg_loss,
        'avg_hours': avg_hours,
        'work_pattern': work_pattern,
        'primary_city': primary_city,
        'claim_frequency': claim_frequency,
        'weekend_ratio': weekend_ratio,
        'sample_days': lookback_days,
    }

    behavior = UserBehavior(
        user_id=int(user_id),
        event_type='behavior_snapshot',
        event_value=work_pattern,
        confidence_score=_clamp((len(incomes) / max(lookback_days, 1)), 0.1, 1.0),
        behavior_metadata=snapshot,
    )
    db.add(behavior)
    db.flush()
    logger.info('user behavior updated user_id=%s snapshot=%s', user_id, snapshot)
    return snapshot
