from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.fraud_log import FraudLog
from models.gig_income import GigIncome
from models.models import ClaimHistory
from models.profile import Profile
from models.user_model import User
from services.blockchain_service import log_claim, record_payout
from services.environment_service import get_environment
from services.fraud_intelligence_engine import evaluate_fraud_intelligence, update_user_location_state
from services.ml_service import (
    expected_loss_prediction,
    get_latest_user_behavior,
    record_claim_learning,
    update_model_weights,
    update_user_behavior,
    user_allows_model_training,
)
from services.payout_service import process_payout
from services.policy_service import create_claim_record, get_claimable_policy
from services.premium_engine import CITY_COORDINATES, baseline_value, calculate_weekly_premium
from services.risk_engine import calculate_risk


def _utcnow_iso() -> str:
    return datetime.now(UTC).replace(tzinfo=None).isoformat()


def _round(value: float | None, places: int = 2) -> float:
    return float(round(float(value or 0.0), places))


def _user_or_404(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    return user


def _resolve_coordinates(user: User, db: Session, lat: float | None = None, lon: float | None = None) -> tuple[float, float]:
    if lat is not None and lon is not None:
        return float(lat), float(lon)
    if user.last_known_lat is not None and user.last_known_lon is not None:
        return float(user.last_known_lat), float(user.last_known_lon)
    profile = db.query(Profile).filter(Profile.user_id == int(user.id)).first()
    city_key = str((profile.city if profile and profile.city else user.active_city) or 'Chennai').strip().lower()
    coords = CITY_COORDINATES.get(city_key, CITY_COORDINATES['chennai'])
    return float(coords[0]), float(coords[1])


def _current_gig_snapshot(db: Session, user_id: int) -> dict:
    current = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .first()
    )
    if current is None:
        return {
            'date': date.today(),
            'deliveries_per_hour': 0.0,
            'orders_completed': 0,
            'hours_worked': 0.0,
            'earnings': 0.0,
            'platform': 'swiggy',
            'disruption_type': 'none',
            'expected_orders': 0,
        }
    hours = max(float(current.hours_worked or 0.0), 1.0)
    return {
        'date': current.date,
        'deliveries_per_hour': _round(float(current.orders_completed or 0) / hours, 3),
        'orders_completed': int(current.orders_completed or 0),
        'hours_worked': float(current.hours_worked or 0.0),
        'earnings': float(current.earnings or 0.0),
        'platform': current.platform,
        'disruption_type': current.disruption_type,
        'expected_orders': int(current.expected_orders or 0),
    }


def _historical_baseline(db: Session, user_id: int) -> dict:
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .limit(30)
        .all()
    )
    if not records:
        return {
            'avg_earnings': 0.0,
            'avg_deliveries_per_hour': 0.0,
            'sample_size': 0,
        }
    baseline_income = baseline_value(user_id, db)
    deliveries_per_hour = []
    for item in records:
        hours = max(float(item.hours_worked or 0.0), 1.0)
        deliveries_per_hour.append(float(item.orders_completed or 0) / hours)
    return {
        'avg_earnings': _round(baseline_income),
        'avg_deliveries_per_hour': _round(sum(deliveries_per_hour) / len(deliveries_per_hour), 3),
        'sample_size': len(records),
    }


def _detect_triggers(*, environment_data: dict, risk_data: dict, gig_data: dict, baseline: dict) -> dict:
    snapshot = (environment_data or {}).get('snapshot') or {}
    traffic = (environment_data or {}).get('traffic') or {}
    active_triggers = [str(item).upper() for item in (risk_data.get('active_triggers') or [])]

    rainfall = float(snapshot.get('rain_estimate', 0.0) or 0.0)
    traffic_index = float(snapshot.get('traffic_index', traffic.get('traffic_score', 1.0)) or 1.0)
    aqi = float(snapshot.get('aqi', 0.0) or 0.0)
    current_dph = float(gig_data.get('deliveries_per_hour', 0.0) or 0.0)
    baseline_dph = max(float(baseline.get('avg_deliveries_per_hour', 0.0) or 0.0), 0.01)
    delivery_drop = max(baseline_dph - current_dph, 0.0) / baseline_dph

    triggered = []
    strength_parts = []
    if rainfall > 5.0 or 'RAIN_TRIGGER' in active_triggers:
        triggered.append('rain')
        strength_parts.append(min(rainfall / 15.0, 1.0))
    if traffic_index > 1.25 or 'TRAFFIC_TRIGGER' in active_triggers:
        triggered.append('traffic')
        strength_parts.append(min(max(traffic_index - 1.0, 0.0) / 0.8, 1.0))
    if aqi > 100 or 'AQI_TRIGGER' in active_triggers:
        triggered.append('aqi')
        strength_parts.append(min(aqi / 180.0, 1.0))
    if delivery_drop > 0.3:
        triggered.append('delivery_drop')
        strength_parts.append(min(delivery_drop / 0.7, 1.0))

    trigger_detected = bool(triggered)
    trigger_strength = _round(sum(strength_parts) / len(strength_parts), 3) if strength_parts else 0.0
    primary_trigger = triggered[0] if triggered else None
    return {
        'trigger_detected': trigger_detected,
        'triggers': triggered,
        'primary_trigger': primary_trigger,
        'trigger_strength': trigger_strength,
        'rainfall': _round(rainfall, 2),
        'traffic_index': _round(traffic_index, 3),
        'aqi': _round(aqi, 2),
        'delivery_drop': _round(delivery_drop, 3),
    }


def _loss_estimation(*, baseline: dict, gig_data: dict) -> dict:
    baseline_income = max(float(baseline.get('avg_earnings', 0.0) or 0.0), 0.0)
    actual_income = max(float(gig_data.get('earnings', 0.0) or 0.0), 0.0)
    loss = max(baseline_income - actual_income, 0.0)
    loss_percentage = (loss / baseline_income) if baseline_income > 0 else 0.0
    return {
        'baseline_income': _round(baseline_income),
        'actual_income': _round(actual_income),
        'loss': _round(loss),
        'loss_percentage': _round(loss_percentage, 4),
    }


def _confidence_score(*, trigger_data: dict, loss_data: dict, baseline: dict, environment_data: dict, risk_data: dict) -> dict:
    trigger_strength = float(trigger_data.get('trigger_strength', 0.0) or 0.0)
    loss_magnitude = min(float(loss_data.get('loss_percentage', 0.0) or 0.0) / 0.8, 1.0)
    data_reliability = min(max(float(baseline.get('sample_size', 0) or 0) / 14.0, 0.0), 1.0)
    environment_consistency = 1.0 if risk_data.get('active_triggers') else (0.7 if environment_data.get('source') == 'live' else 0.55)
    score = _round((0.35 * trigger_strength) + (0.3 * loss_magnitude) + (0.15 * data_reliability) + (0.2 * environment_consistency), 3)
    if score >= 0.75:
        label = 'HIGH'
    elif score >= 0.5:
        label = 'MEDIUM'
    else:
        label = 'LOW'
    return {
        'score': score,
        'label': label,
    }


def _explanation(*, trigger_data: dict, loss_data: dict, timestamp: str) -> str:
    triggers = trigger_data.get('triggers') or []
    trigger_label = ', '.join(str(item).replace('_', ' ') for item in triggers) if triggers else 'no active disruption'
    loss_pct = int(round(float(loss_data.get('loss_percentage', 0.0) or 0.0) * 100))
    return f"Claim triggered due to {trigger_label} and a {loss_pct}% drop in earnings compared to the normal baseline during the current monitoring window at {timestamp}."


def auto_process_claim(
    *,
    user_id: int,
    db: Session,
    lat: float | None = None,
    lon: float | None = None,
) -> dict:
    user = _user_or_404(db, user_id)
    lat, lon = _resolve_coordinates(user, db, lat=lat, lon=lon)
    gig_data = _current_gig_snapshot(db, user_id)
    baseline = _historical_baseline(db, user_id)
    environment_data = get_environment(lat, lon, db=db, user_id=user_id)
    environment_data['city'] = str(environment_data.get('city') or environment_data.get('resolved_city') or user.active_city or 'Chennai')
    risk_data = calculate_risk(environment_data, user_id=user_id, db=db, today_income=gig_data)
    premium_data = calculate_weekly_premium(
        user_id=user_id,
        lat=lat,
        lon=lon,
        db=db,
        environment_data=environment_data,
        risk_result=risk_data,
        persist_snapshots=True,
    )
    policy = get_claimable_policy(user_id, db)

    trigger_data = _detect_triggers(environment_data=environment_data, risk_data=risk_data, gig_data=gig_data, baseline=baseline)
    loss_data = _loss_estimation(baseline=baseline, gig_data=gig_data)
    confidence = _confidence_score(
        trigger_data=trigger_data,
        loss_data=loss_data,
        baseline=baseline,
        environment_data=environment_data,
        risk_data=risk_data,
    )

    eligible = bool(
        trigger_data['trigger_detected']
        and float(loss_data['loss_percentage']) > 0.2
        and policy is not None
        and bool(policy.premium_paid)
        and bool(premium_data.get('eligible'))
    )
    timestamp = _utcnow_iso()
    explanation = _explanation(trigger_data=trigger_data, loss_data=loss_data, timestamp=timestamp)

    if not eligible:
        return {
            'claim_triggered': False,
            'status': 'NO_CLAIM',
            'loss': float(loss_data['loss']),
            'confidence': confidence['label'],
            'fraud': None,
            'payout': None,
            'explanation': explanation if trigger_data['trigger_detected'] else 'No automatic claim was triggered because disruption thresholds were not met.',
            'trigger': trigger_data['primary_trigger'],
            'timestamp': timestamp,
        }

    predicted_loss = expected_loss_prediction(float(risk_data.get('risk_score', 0.0) or 0.0), float(loss_data['baseline_income']))
    location_status = update_user_location_state(user, lat=lat, lon=lon, city=environment_data.get('city'), db=db)

    provisional_claim = create_claim_record(
        user_id=user_id,
        db=db,
        week=policy.start_date.strftime('%G-W%V'),
        loss=float(loss_data['loss']),
        payout=0.0,
        fraud_score=0.0,
        status='PROCESSING',
        reasons=[explanation],
    )
    claim_id = f'claim_{provisional_claim.id}'

    fraud = evaluate_fraud_intelligence(
        db=db,
        user=user,
        claim_id=claim_id,
        device_id=user.current_device_id,
        device_metadata={},
        location_logs=None,
        login_history=None,
        claim_data={
            'actual_income': float(loss_data['actual_income']),
            'baseline_income': float(loss_data['baseline_income']),
            'predicted_loss': predicted_loss,
            'actual_loss': float(loss_data['loss']),
            'lat': lat,
            'lon': lon,
            'city': environment_data.get('city'),
            'claim_reason': trigger_data['primary_trigger'],
        },
        risk_data=risk_data,
        environment_data=environment_data,
        past_claims=None,
        user_behavior_profile=get_latest_user_behavior(db, user_id=user_id),
        gig_data=gig_data,
    )

    if fraud['decision'] == 'FLAGGED':
        final_status = 'UNDER_REVIEW'
    elif fraud['decision'] == 'REJECTED':
        final_status = 'REJECTED'
    else:
        final_status = 'APPROVED'

    payout = None
    payout_chain = None
    payout_amount = 0.0
    if final_status == 'APPROVED':
        payout_amount = min(float(loss_data['loss']), float(premium_data.get('coverage', loss_data['loss']) or loss_data['loss']))
        payout = process_payout(
            db=db,
            user_id=user_id,
            claim_id=claim_id,
            amount=payout_amount,
            claim_status='APPROVED',
            fraud_decision='APPROVED',
            fraud_score=float(fraud.get('fraud_score', 0.0)),
        )
        if payout.get('status') == 'SUCCESS':
            payout_chain = record_payout(claim_id=claim_id, amount=float(payout.get('amount_paid', 0.0)), user_id=user_id, db=db)

    provisional_claim.loss = _round(loss_data['loss'])
    provisional_claim.payout = _round(float(payout.get('amount_paid', 0.0)) if payout else 0.0)
    provisional_claim.fraud_score = float(round(float(fraud.get('fraud_score', 0.0)), 3))
    provisional_claim.status = final_status
    provisional_claim.reasons_json = __import__('json').dumps([explanation, fraud['explanation']])

    blockchain = log_claim(
        claim_id,
        {
            'user_id': user_id,
            'claim_id': claim_id,
            'trigger': trigger_data['primary_trigger'],
            'loss': float(loss_data['loss']),
            'loss_percentage': float(loss_data['loss_percentage']),
            'status': final_status,
            'confidence': confidence['label'],
        },
        db=db,
    )

    learning_record = record_claim_learning(
        db,
        user_id=user_id,
        policy_id=policy.id,
        risk_snapshot_id=premium_data.get('risk_snapshot_id'),
        claim_date=policy.end_date,
        status=final_status,
        risk_score=float(risk_data.get('risk_score', 0.0) or 0.0),
        baseline_income=float(loss_data['baseline_income']),
        actual_loss=float(loss_data['loss']) if final_status == 'APPROVED' else 0.0,
        approved_payout=float(payout.get('amount_paid', 0.0)) if payout else 0.0,
        triggers=[str(item) for item in (risk_data.get('active_triggers') or [])],
        reasons=[explanation, fraud['explanation']],
        fraud_score=float(fraud.get('fraud_score', 0.0)),
        review_notes=fraud['explanation'],
    )

    fraud_log = FraudLog(
        user_id=int(user_id),
        claim_history_id=learning_record.id,
        claim_reference=claim_id,
        fraud_score=float(fraud.get('fraud_score', 0.0)),
        decision='FLAGGED' if final_status == 'UNDER_REVIEW' else final_status,
        confidence=str(fraud.get('confidence', 'LOW')),
        city=str(environment_data.get('city') or ''),
        fraud_types=fraud.get('fraud_types') or [],
        explanation=str(fraud.get('explanation', '')),
        signals=fraud.get('signals') or {},
    )
    db.add(fraud_log)

    if user_allows_model_training(db, user_id=user_id):
        update_model_weights(db, user_id=user_id)
        update_user_behavior(db, user_id=user_id)

    db.commit()

    return {
        'claim_triggered': True,
        'status': final_status,
        'loss': float(loss_data['loss']),
        'confidence': confidence['label'],
        'fraud': fraud,
        'payout': payout,
        'explanation': explanation,
        'trigger': trigger_data['primary_trigger'],
        'timestamp': timestamp,
        'claim_id': claim_id,
        'trigger_details': trigger_data,
        'loss_percentage': float(loss_data['loss_percentage']),
        'location_status': location_status,
        'blockchain': {
            'claim': blockchain,
            'payout': payout_chain,
        },
    }
