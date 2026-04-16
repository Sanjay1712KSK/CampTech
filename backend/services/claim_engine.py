from __future__ import annotations

from datetime import date

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from models.fraud_log import FraudLog
from models.models import ClaimHistory, PremiumSnapshot
from models.profile import Profile
from models.user_model import User
from services.blockchain_service import log_claim, record_payout, store_on_blockchain
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
from services.policy_service import create_claim_record, get_claimable_policy
from services.payout_service import execute_instant_payout
from services.premium_engine import baseline_value, calculate_weekly_premium, resolve_city_from_coordinates
from services.risk_engine import calculate_risk


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _user_or_404(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    return user


def _today_income_payload(user_id: int, db: Session) -> dict:
    record = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .first()
    )
    if not record:
        return {
            'earnings': 0.0,
            'orders_completed': 0,
            'hours_worked': 0.0,
            'disruption_type': 'none',
            'platform': 'swiggy',
            'efficiency_score': 0.0,
        }
    return {
        'earnings': float(record.earnings),
        'orders_completed': int(record.orders_completed),
        'hours_worked': float(record.hours_worked),
        'disruption_type': record.disruption_type,
        'platform': record.platform,
        'efficiency_score': float(record.efficiency_score or 0.0),
    }


def _claim_city(user_id: int, db: Session, environment_data: dict, lat: float, lon: float) -> str:
    simulation_meta = (environment_data or {}).get('simulation_meta') or {}
    if simulation_meta:
        profile = db.query(Profile).filter(Profile.user_id == int(user_id)).first()
        if profile and profile.city:
            return str(profile.city)
    return resolve_city_from_coordinates(lat, lon)


def check_user_eligibility(user_id: int, db: Session) -> dict:
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc())
        .all()
    )
    if len(records) < 7:
        return {'eligible': False, 'reason': 'At least 7 days of gig data is required'}

    baseline = baseline_value(user_id, db)
    if baseline <= 0:
        return {'eligible': False, 'reason': 'Valid baseline income is required'}

    return {'eligible': True, 'reason': ''}


def _reject_response(*, claim_id: str, reason: str, fraud: dict | None = None, blockchain: dict | None = None) -> dict:
    fraud = fraud or {
        'fraud_score': 1.0,
        'fraud_types': ['SYSTEM_REJECT'],
        'decision': 'REJECTED',
        'confidence': 'HIGH',
        'explanation': reason,
    }
    return {
        'claim_status': 'REJECTED',
        'status': 'REJECTED',
        'reason': reason,
        'loss': 0.0,
        'weekly_loss': 0.0,
        'payout': 0.0,
        'predicted_loss': None,
        'fraud_score': float(fraud.get('fraud_score', 1.0)),
        'confidence': fraud.get('confidence'),
        'fraud': fraud,
        'transaction': None,
        'blockchain': blockchain,
        'claim_id': claim_id,
        'reasons': [reason],
    }


def process_claim(
    user_id: int,
    db: Session,
    lat: float,
    lon: float,
    *,
    device_id: str | None = None,
    device_metadata: dict | None = None,
    location_logs: list[dict] | None = None,
    claim_reason: str | None = None,
) -> dict:
    user = _user_or_404(db, user_id)
    eligibility = check_user_eligibility(user_id, db)
    if not eligibility['eligible']:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=date.today().strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=1.0,
            status='REJECTED',
            reasons=[eligibility['reason']],
        )
        blockchain = log_claim(f'claim_{claim.id}', {'user_id': user_id, 'status': 'REJECTED', 'reason': eligibility['reason']}, db=db)
        db.commit()
        return _reject_response(claim_id=f'claim_{claim.id}', reason=eligibility['reason'], blockchain=blockchain)

    policy = get_claimable_policy(user_id, db)
    if policy is None or not policy.premium_paid:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=date.today().strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=1.0,
            status='REJECTED',
            reasons=['No completed policy week is available to claim yet'],
        )
        blockchain = log_claim(f'claim_{claim.id}', {'user_id': user_id, 'status': 'REJECTED', 'reason': 'No completed policy week is available to claim yet'}, db=db)
        db.commit()
        return _reject_response(
            claim_id=f'claim_{claim.id}',
            reason='No completed policy week is available to claim yet',
            blockchain=blockchain,
        )

    settled_claim = (
        db.query(ClaimHistory)
        .filter(
            ClaimHistory.user_id == int(user_id),
            ClaimHistory.policy_id == policy.id,
            ClaimHistory.status == 'APPROVED',
            ClaimHistory.approved_payout > 0,
        )
        .order_by(ClaimHistory.claim_date.desc(), ClaimHistory.id.desc())
        .first()
    )
    if settled_claim is not None:
        blockchain = log_claim(
            settled_claim.claim_reference,
            {'user_id': user_id, 'status': 'REJECTED', 'reason': 'Previous completed week was already claimed and paid'},
            db=db,
        )
        db.commit()
        return _reject_response(
            claim_id=settled_claim.claim_reference,
            reason='Previous completed week was already claimed and paid',
            blockchain=blockchain,
        )

    environment_data = get_environment(lat, lon, db=db, user_id=user_id)
    environment_data['city'] = _claim_city(user_id, db, environment_data, lat, lon)
    today_income = _today_income_payload(user_id, db)
    risk_result = calculate_risk(environment_data, user_id=user_id, db=db, today_income=today_income)
    premium_result = calculate_weekly_premium(
        user_id=user_id,
        lat=lat,
        lon=lon,
        db=db,
        environment_data=environment_data,
        risk_result=risk_result,
        persist_snapshots=True,
    )

    expected_income = _round(baseline_value(user_id, db))
    actual_income = _round(float(today_income.get('earnings', 0.0) or 0.0))
    actual_loss = _round(max(0.0, expected_income - actual_income))
    predicted_loss = expected_loss_prediction(float(risk_result.get('risk_score', 0.0) or 0.0), expected_income)

    location_status = update_user_location_state(
        user,
        lat=lat,
        lon=lon,
        city=environment_data.get('city'),
        db=db,
    )
    fraud = evaluate_fraud_intelligence(
        db=db,
        user=user,
        claim_id=None,
        device_id=device_id,
        device_metadata=device_metadata,
        location_logs=location_logs,
        login_history=None,
        claim_data={
            'actual_income': actual_income,
            'baseline_income': expected_income,
            'predicted_loss': predicted_loss,
            'actual_loss': actual_loss,
            'lat': lat,
            'lon': lon,
            'city': environment_data.get('city'),
            'claim_reason': claim_reason or today_income.get('disruption_type'),
        },
        risk_data=risk_result,
        environment_data=environment_data,
        past_claims=None,
        user_behavior_profile=get_latest_user_behavior(db, user_id=user_id),
        gig_data=today_income,
    )

    latest_premium_snapshot = None
    if premium_result.get('premium_snapshot_id'):
        latest_premium_snapshot = (
            db.query(PremiumSnapshot)
            .filter(PremiumSnapshot.id == int(premium_result['premium_snapshot_id']))
            .first()
        )
        if latest_premium_snapshot is not None and latest_premium_snapshot.policy_id is None:
            latest_premium_snapshot.policy_id = policy.id

    claim_status = fraud['decision']
    reasons = [fraud['explanation']]
    if not risk_result.get('active_triggers'):
        claim_status = 'REJECTED'
        reasons.insert(0, 'No active disruption triggers were detected')
    elif actual_loss <= 0:
        claim_status = 'REJECTED'
        reasons.insert(0, 'No eligible income loss detected')

    payout_amount = 0.0
    transaction = None
    payout_chain = None
    if claim_status == 'APPROVED':
        payout_amount = min(
            _round(actual_loss * 0.8),
            _round(float(premium_result.get('coverage', actual_loss) or actual_loss)),
        )

    claim = create_claim_record(
        user_id=user_id,
        db=db,
        week=policy.start_date.strftime('%G-W%V'),
        loss=actual_loss if claim_status == 'APPROVED' else 0.0,
        payout=payout_amount if claim_status == 'APPROVED' else 0.0,
        fraud_score=float(fraud.get('fraud_score', 0.0)),
        status=claim_status,
        reasons=reasons,
    )

    blockchain = log_claim(
        f'claim_{claim.id}',
        {
            'user_id': user_id,
            'claim_id': f'claim_{claim.id}',
            'policy_id': policy.id,
            'status': claim_status,
            'predicted_loss': predicted_loss,
            'actual_loss': actual_loss,
            'fraud': fraud,
        },
        db=db,
    )

    if claim_status == 'APPROVED':
        transaction = execute_instant_payout(
            db=db,
            user_id=user_id,
            amount=payout_amount,
            claim_id=f'claim_{claim.id}',
            metadata={'policy_id': policy.id, 'fraud_score': fraud['fraud_score']},
        )
        payout_chain = record_payout(f'claim_{claim.id}', payout_amount, user_id=user_id, db=db)

    learning_record = record_claim_learning(
        db,
        user_id=user_id,
        policy_id=policy.id,
        risk_snapshot_id=premium_result.get('risk_snapshot_id'),
        claim_date=policy.end_date,
        status=claim_status,
        risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
        baseline_income=expected_income,
        actual_loss=actual_loss if claim_status == 'APPROVED' else 0.0,
        approved_payout=payout_amount if claim_status == 'APPROVED' else 0.0,
        triggers=[str(item) for item in (risk_result.get('active_triggers') or [])],
        reasons=reasons,
        fraud_score=float(fraud.get('fraud_score', 0.0)),
        review_notes=fraud['explanation'],
    )

    fraud_log = FraudLog(
        user_id=int(user_id),
        claim_history_id=learning_record.id,
        claim_reference=f'claim_{claim.id}',
        fraud_score=float(fraud.get('fraud_score', 0.0)),
        decision=str(fraud.get('decision', claim_status)),
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
    if fraud_log.id is None:
        db.refresh(fraud_log)

    return {
        'claim_status': claim_status,
        'status': claim_status,
        'reason': reasons[0] if reasons else None,
        'expected_income': expected_income,
        'actual_income': actual_income,
        'weekly_loss': actual_loss,
        'loss': actual_loss,
        'payout': payout_amount,
        'predicted_loss': predicted_loss,
        'fraud_score': float(fraud.get('fraud_score', 0.0)),
        'confidence': fraud.get('confidence'),
        'fraud': fraud,
        'transaction': transaction,
        'blockchain': {
            'claim': blockchain,
            'payout': payout_chain,
        },
        'policy': {
            'policy_id': policy.id,
            'start_date': policy.start_date.isoformat(),
            'end_date': policy.end_date.isoformat(),
            'premium_paid': bool(policy.premium_paid),
        },
        'environment': environment_data,
        'risk': risk_result,
        'premium': premium_result,
        'gig': today_income,
        'location_status': location_status,
        'claim_id': f'claim_{claim.id}',
        'fraud_log_id': fraud_log.id,
        'reasons': reasons,
    }
