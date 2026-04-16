from __future__ import annotations

from collections import Counter
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from models.bank_account import BankTransaction
from models.fraud_log import FraudLog
from models.models import ClaimHistory, ModelWeight, RiskSnapshot, UserBehavior

PREDICTION_MODEL_NAME = 'prediction_engine'
PREDICTION_MODEL_VERSION = 'v1'
DEFAULT_PREDICTION_CONFIG = {
    'recent_risk_weight': 0.5,
    'environment_factor_weight': 0.3,
    'historical_avg_weight': 0.2,
    'claims_trend_boost': 0.2,
}


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float | None, places: int = 2) -> float:
    return float(round(float(value or 0.0), places))


def _clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def _average(values: list[float]) -> float:
    cleaned = [float(item) for item in values]
    if not cleaned:
        return 0.0
    return sum(cleaned) / len(cleaned)


def _normalize_weight_triplet(config: dict[str, float]) -> dict[str, float]:
    recent = max(float(config.get('recent_risk_weight', 0.0)), 0.05)
    environment = max(float(config.get('environment_factor_weight', 0.0)), 0.05)
    historical = max(float(config.get('historical_avg_weight', 0.0)), 0.05)
    total = recent + environment + historical
    return {
        'recent_risk_weight': recent / total,
        'environment_factor_weight': environment / total,
        'historical_avg_weight': historical / total,
        'claims_trend_boost': _clamp(float(config.get('claims_trend_boost', DEFAULT_PREDICTION_CONFIG['claims_trend_boost'])), 0.05, 0.5),
    }


def _prediction_record(db: Session) -> ModelWeight:
    record = (
        db.query(ModelWeight)
        .filter(
            ModelWeight.model_name == PREDICTION_MODEL_NAME,
            ModelWeight.version == PREDICTION_MODEL_VERSION,
            ModelWeight.is_active.is_(True),
        )
        .order_by(ModelWeight.id.desc())
        .first()
    )
    if record is None:
        record = ModelWeight(
            model_name=PREDICTION_MODEL_NAME,
            version=PREDICTION_MODEL_VERSION,
            learning_rate=0.03,
            is_active=True,
            weight_metadata=DEFAULT_PREDICTION_CONFIG.copy(),
        )
        db.add(record)
        db.flush()
    elif not isinstance(record.weight_metadata, dict):
        record.weight_metadata = DEFAULT_PREDICTION_CONFIG.copy()
        db.flush()
    return record


def get_prediction_config(db: Session) -> dict[str, float]:
    record = _prediction_record(db)
    base = DEFAULT_PREDICTION_CONFIG.copy()
    base.update({key: float(value) for key, value in (record.weight_metadata or {}).items() if key in base})
    normalized = _normalize_weight_triplet(base)
    if normalized != (record.weight_metadata or {}):
        record.weight_metadata = normalized
        db.flush()
    return normalized


def _environment_factor_from_context(context: dict | None) -> float:
    source = context or {}
    snapshot = source.get('snapshot') if isinstance(source, dict) else {}
    snapshot = snapshot if isinstance(snapshot, dict) else {}
    traffic = source.get('traffic') if isinstance(source, dict) else {}
    traffic = traffic if isinstance(traffic, dict) else {}

    rainfall = _clamp(float(snapshot.get('rain_estimate', 0.0) or 0.0) / 15.0)
    aqi = _clamp(float(snapshot.get('aqi', 0.0) or 0.0) / 180.0)
    traffic_index = float(snapshot.get('traffic_index', traffic.get('traffic_score', 1.0)) or 1.0)
    traffic_factor = _clamp(max(traffic_index - 1.0, 0.0) / 0.8)
    return _round((0.4 * rainfall) + (0.3 * aqi) + (0.3 * traffic_factor), 4)


def _risk_label(score: float) -> str:
    if score >= 0.7:
        return 'HIGH'
    if score >= 0.4:
        return 'MEDIUM'
    return 'LOW'


def _risk_trend(avg_recent: float, avg_previous: float) -> str:
    if avg_recent > avg_previous + 0.03:
        return 'increasing'
    if avg_recent < avg_previous - 0.03:
        return 'decreasing'
    return 'stable'


def _recent_risk_snapshots(
    db: Session,
    *,
    hours: int,
    user_id: int | None = None,
) -> list[RiskSnapshot]:
    query = db.query(RiskSnapshot).filter(RiskSnapshot.created_at >= _utcnow() - timedelta(hours=max(hours, 1)))
    if user_id is not None:
        query = query.filter(RiskSnapshot.user_id == int(user_id))
    return query.order_by(RiskSnapshot.created_at.asc(), RiskSnapshot.id.asc()).all()


def _historical_risk_average(
    db: Session,
    *,
    days: int = 14,
    user_id: int | None = None,
) -> float:
    query = db.query(RiskSnapshot).filter(RiskSnapshot.created_at >= _utcnow() - timedelta(days=max(days, 1)))
    if user_id is not None:
        query = query.filter(RiskSnapshot.user_id == int(user_id))
    snapshots = query.all()
    return _average([float(item.risk_score or 0.0) for item in snapshots])


def _top_environment_pressure(snapshots: list[RiskSnapshot]) -> tuple[str, float]:
    pressure_counter: Counter[str] = Counter()
    pressure_weight = {'rain': 0.0, 'traffic': 0.0, 'aqi': 0.0}
    for snapshot in snapshots:
        context = snapshot.environment_context or {}
        factor = _environment_factor_from_context(context)
        raw = context.get('snapshot') if isinstance(context, dict) else {}
        raw = raw if isinstance(raw, dict) else {}
        rainfall = float(raw.get('rain_estimate', 0.0) or 0.0)
        aqi = float(raw.get('aqi', 0.0) or 0.0)
        traffic_index = float(raw.get('traffic_index', 1.0) or 1.0)
        if rainfall >= 5.0:
            pressure_counter['rain'] += 1
            pressure_weight['rain'] += factor
        if aqi >= 100:
            pressure_counter['aqi'] += 1
            pressure_weight['aqi'] += factor
        if traffic_index >= 1.25:
            pressure_counter['traffic'] += 1
            pressure_weight['traffic'] += factor
    if not pressure_counter:
        return ('conditions', 0.0)
    dominant = max(pressure_counter, key=lambda key: (pressure_counter[key], pressure_weight[key]))
    return (dominant, pressure_weight.get(dominant, 0.0))


def _fraud_trend(db: Session) -> tuple[float, float, str]:
    now = _utcnow()
    last_7_start = now - timedelta(days=7)
    prev_7_start = now - timedelta(days=14)

    recent_claims = db.query(ClaimHistory).filter(ClaimHistory.created_at >= last_7_start).count()
    previous_claims = db.query(ClaimHistory).filter(
        ClaimHistory.created_at >= prev_7_start,
        ClaimHistory.created_at < last_7_start,
    ).count()

    recent_fraud = db.query(FraudLog).filter(FraudLog.created_at >= last_7_start).count()
    previous_fraud = db.query(FraudLog).filter(
        FraudLog.created_at >= prev_7_start,
        FraudLog.created_at < last_7_start,
    ).count()

    recent_rate = (recent_fraud / recent_claims) if recent_claims else 0.0
    previous_rate = (previous_fraud / previous_claims) if previous_claims else 0.0
    if recent_rate > previous_rate + 0.03:
        trend = 'increasing'
    elif recent_rate < previous_rate - 0.03:
        trend = 'decreasing'
    else:
        trend = 'stable'
    return (_round(recent_rate, 4), _round(previous_rate, 4), trend)


def generate_predictions(db: Session, *, user_id: int | None = None) -> dict:
    config = get_prediction_config(db)
    recent_snapshots = _recent_risk_snapshots(db, hours=6, user_id=user_id)
    previous_snapshots = (
        db.query(RiskSnapshot)
        .filter(
            RiskSnapshot.created_at >= _utcnow() - timedelta(hours=12),
            RiskSnapshot.created_at < _utcnow() - timedelta(hours=6),
        )
    )
    if user_id is not None:
        previous_snapshots = previous_snapshots.filter(RiskSnapshot.user_id == int(user_id))
    previous_snapshots = previous_snapshots.order_by(RiskSnapshot.created_at.asc(), RiskSnapshot.id.asc()).all()

    avg_risk_last_6hrs = _average([float(item.risk_score or 0.0) for item in recent_snapshots])
    avg_risk_previous_6hrs = _average([float(item.risk_score or 0.0) for item in previous_snapshots])
    risk_trend = _risk_trend(avg_risk_last_6hrs, avg_risk_previous_6hrs)

    environment_factor = _average([
        _environment_factor_from_context(item.environment_context or {})
        for item in recent_snapshots
    ])
    historical_avg = _historical_risk_average(db, days=14, user_id=user_id)
    predicted_risk_score = (
        config['recent_risk_weight'] * avg_risk_last_6hrs
        + config['environment_factor_weight'] * environment_factor
        + config['historical_avg_weight'] * historical_avg
    )
    predicted_risk_score = _clamp(predicted_risk_score)
    next_6hr_risk = _risk_label(predicted_risk_score)

    now = _utcnow()
    claims_last_7_days = (
        db.query(ClaimHistory)
        .filter(ClaimHistory.created_at >= now - timedelta(days=7))
    )
    if user_id is not None:
        claims_last_7_days = claims_last_7_days.filter(ClaimHistory.user_id == int(user_id))
    claims_last_7_days = claims_last_7_days.all()
    base_predicted_claims = _average([1.0 for _ in claims_last_7_days]) * 7 if claims_last_7_days else 0.0
    predicted_claims = base_predicted_claims
    if risk_trend == 'increasing':
        predicted_claims *= 1 + config['claims_trend_boost']
    elif risk_trend == 'decreasing':
        predicted_claims *= max(0.5, 1 - (config['claims_trend_boost'] * 0.6))
    predicted_claims = int(round(max(predicted_claims, 0.0)))

    payout_query = (
        db.query(BankTransaction)
        .filter(
            BankTransaction.created_at >= now - timedelta(days=7),
            BankTransaction.transaction_type.in_(['CLAIM_PAYOUT', 'MANUAL_CLAIM_PAYOUT']),
            BankTransaction.status == 'SUCCESS',
        )
    )
    if user_id is not None:
        payout_query = payout_query.filter(BankTransaction.user_id == int(user_id))
    payout_rows = payout_query.all()
    total_payout_last_7_days = sum(float(item.amount or 0.0) for item in payout_rows)
    claims_count_last_7_days = max(len(claims_last_7_days), 1)
    avg_payout = total_payout_last_7_days / claims_count_last_7_days if claims_last_7_days else 0.0
    expected_payout = _round(predicted_claims * avg_payout)

    fraud_rate_recent, fraud_rate_previous, fraud_trend = _fraud_trend(db)
    dominant_pressure, dominant_weight = _top_environment_pressure(recent_snapshots)
    insights: list[str] = []
    if dominant_pressure == 'rain' and dominant_weight > 0:
        insights.append('Heavy rainfall trend may increase claims in the next cycle')
    elif dominant_pressure == 'traffic' and dominant_weight > 0:
        insights.append('Traffic congestion is the strongest current pressure on claim frequency')
    elif dominant_pressure == 'aqi' and dominant_weight > 0:
        insights.append('Poor air quality conditions may reduce safe work hours and raise claim pressure')

    if risk_trend == 'increasing':
        insights.append('Rising risk levels indicate higher payouts may be needed soon')
    elif risk_trend == 'decreasing':
        insights.append('Risk levels are softening, which may reduce claim intensity next week')
    else:
        insights.append('Risk conditions are stable, so claim volume should stay close to the recent average')

    if fraud_trend == 'increasing':
        insights.append('Fraud activity slightly increased this week and should be monitored closely')

    if not insights:
        insights.append('Current platform conditions remain stable with no major prediction alerts')

    return {
        'next_6hr_risk': next_6hr_risk,
        'predicted_risk_score': _round(predicted_risk_score, 4),
        'risk_trend': risk_trend,
        'predicted_claims': int(predicted_claims),
        'next_week_claims': int(predicted_claims),
        'expected_payout': expected_payout,
        'insights': insights,
        'insight': insights[0],
        'fraud_rate': fraud_rate_recent,
        'fraud_trend': fraud_trend,
        'prediction_weights': {
            'recent_risk_weight': _round(config['recent_risk_weight'], 4),
            'environment_factor_weight': _round(config['environment_factor_weight'], 4),
            'historical_avg_weight': _round(config['historical_avg_weight'], 4),
            'claims_trend_boost': _round(config['claims_trend_boost'], 4),
        },
        'forecast_basis': {
            'avg_risk_last_6hrs': _round(avg_risk_last_6hrs, 4),
            'avg_risk_previous_6hrs': _round(avg_risk_previous_6hrs, 4),
            'environment_factor': _round(environment_factor, 4),
            'historical_avg': _round(historical_avg, 4),
            'fraud_rate_previous': fraud_rate_previous,
        },
    }


def build_worker_prediction_message(db: Session, *, user_id: int) -> dict:
    prediction = generate_predictions(db, user_id=user_id)
    if prediction['risk_trend'] == 'increasing':
        message = 'If current conditions continue, your risk may increase over the next few hours.'
    elif prediction['risk_trend'] == 'decreasing':
        message = 'Current conditions look easier than earlier today, so your risk may ease soon.'
    else:
        message = 'Current conditions look steady, so your risk is likely to stay near the present level.'
    return {
        'next_6hr_risk': prediction['next_6hr_risk'],
        'risk_trend': prediction['risk_trend'],
        'predicted_risk_score': prediction['predicted_risk_score'],
        'message': message,
        'insights': prediction['insights'],
    }


def record_prediction_feedback(
    db: Session,
    *,
    user_id: int,
    predicted_claims: int,
    actual_claims: int,
    predicted_payout: float,
    actual_payout: float,
    predicted_risk_score: float | None = None,
    actual_risk_score: float | None = None,
) -> UserBehavior:
    behavior = UserBehavior(
        user_id=int(user_id),
        event_type='prediction_feedback',
        event_value='claim_outcome',
        confidence_score=1.0,
        behavior_metadata={
            'predicted_claims': int(predicted_claims),
            'actual_claims': int(actual_claims),
            'predicted_payout': _round(predicted_payout),
            'actual_payout': _round(actual_payout),
            'predicted_risk_score': _round(predicted_risk_score, 4) if predicted_risk_score is not None else None,
            'actual_risk_score': _round(actual_risk_score, 4) if actual_risk_score is not None else None,
            'recorded_at': _utcnow().isoformat(),
        },
    )
    db.add(behavior)
    db.flush()
    return behavior


def update_prediction_weights(db: Session, *, lookback_events: int = 20) -> dict[str, float]:
    record = _prediction_record(db)
    config = get_prediction_config(db)
    feedback_rows = (
        db.query(UserBehavior)
        .filter(UserBehavior.event_type == 'prediction_feedback')
        .order_by(UserBehavior.observed_at.desc(), UserBehavior.id.desc())
        .limit(max(lookback_events, 1))
        .all()
    )
    if not feedback_rows:
        return config

    claim_bias_values: list[float] = []
    payout_bias_values: list[float] = []
    risk_bias_values: list[float] = []
    for row in feedback_rows:
        meta = row.behavior_metadata or {}
        predicted_claims = max(int(meta.get('predicted_claims', 0) or 0), 1)
        actual_claims = int(meta.get('actual_claims', 0) or 0)
        predicted_payout = max(float(meta.get('predicted_payout', 0.0) or 0.0), 1.0)
        actual_payout = float(meta.get('actual_payout', 0.0) or 0.0)
        claim_bias_values.append((actual_claims - predicted_claims) / predicted_claims)
        payout_bias_values.append((actual_payout - predicted_payout) / predicted_payout)

        predicted_risk = meta.get('predicted_risk_score')
        actual_risk = meta.get('actual_risk_score')
        if predicted_risk is not None and actual_risk is not None:
            denominator = max(float(predicted_risk), 0.1)
            risk_bias_values.append((float(actual_risk) - float(predicted_risk)) / denominator)

    claim_bias = _average(claim_bias_values)
    payout_bias = _average(payout_bias_values)
    risk_bias = _average(risk_bias_values)
    learning_rate = _clamp(float(record.learning_rate or 0.03), 0.01, 0.15)

    adjusted = {
        'recent_risk_weight': float(config['recent_risk_weight']) + (learning_rate * (0.6 * risk_bias + 0.3 * claim_bias)),
        'environment_factor_weight': float(config['environment_factor_weight']) + (learning_rate * (0.5 * payout_bias + 0.2 * risk_bias)),
        'historical_avg_weight': float(config['historical_avg_weight']) - (learning_rate * (0.4 * claim_bias + 0.3 * payout_bias)),
        'claims_trend_boost': float(config['claims_trend_boost']) + (learning_rate * 0.5 * claim_bias),
    }
    normalized = _normalize_weight_triplet(adjusted)
    record.weight_metadata = {
        **normalized,
        'last_learning': {
            'claim_bias': _round(claim_bias, 4),
            'payout_bias': _round(payout_bias, 4),
            'risk_bias': _round(risk_bias, 4),
            'feedback_samples': len(feedback_rows),
        },
    }
    db.flush()
    return normalized


def record_claim_prediction_feedback(
    db: Session,
    *,
    user_id: int,
    actual_payout: float,
    actual_claims: int = 1,
    actual_risk_score: float | None = None,
) -> dict:
    snapshot = generate_predictions(db, user_id=user_id)
    per_claim_payout_prediction = (
        float(snapshot['expected_payout']) / max(int(snapshot['predicted_claims']), 1)
        if int(snapshot['predicted_claims']) > 0
        else 0.0
    )
    record_prediction_feedback(
        db,
        user_id=user_id,
        predicted_claims=max(int(snapshot['predicted_claims']), 1),
        actual_claims=max(int(actual_claims), 0),
        predicted_payout=per_claim_payout_prediction,
        actual_payout=float(actual_payout or 0.0),
        predicted_risk_score=float(snapshot['predicted_risk_score']),
        actual_risk_score=actual_risk_score,
    )
    updated = update_prediction_weights(db)
    return {
        'prediction': snapshot,
        'updated_weights': {
            'recent_risk_weight': _round(updated['recent_risk_weight'], 4),
            'environment_factor_weight': _round(updated['environment_factor_weight'], 4),
            'historical_avg_weight': _round(updated['historical_avg_weight'], 4),
            'claims_trend_boost': _round(updated['claims_trend_boost'], 4),
        },
    }
