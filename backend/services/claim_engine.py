from datetime import date

from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from services.environment_service import get_environment
from services.fraud_engine import validate_claim
from services.ml_service import record_claim_learning, update_model_weights, update_user_behavior
from services.policy_service import create_claim_record, get_claimable_policy
from services.premium_engine import baseline_value, resolve_city_from_coordinates
from services.risk_engine import calculate_risk


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _week_records(user_id: int, db: Session, start_date: date, end_date: date) -> list[GigIncome]:
    return (
        db.query(GigIncome)
        .filter(
            GigIncome.user_id == int(user_id),
            GigIncome.date >= start_date,
            GigIncome.date <= end_date,
        )
        .order_by(GigIncome.date.asc())
        .all()
    )


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
        }
    return {
        'earnings': float(record.earnings),
        'orders_completed': int(record.orders_completed),
        'hours_worked': float(record.hours_worked),
        'disruption_type': record.disruption_type,
        'platform': record.platform,
    }


def check_user_eligibility(user_id: int, db: Session) -> dict:
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc())
        .all()
    )
    if len(records) < 7:
        return {'eligible': False, 'reason': 'At least 7 days of gig data is required'}

    city_counts: dict[str, int] = {}
    for record in records:
        city = (record.city or '').strip()
        if city:
            city_counts[city] = city_counts.get(city, 0) + 1

    if not city_counts:
        return {'eligible': False, 'reason': 'City history is unavailable'}

    dominant_ratio = max(city_counts.values()) / len(records)
    if dominant_ratio < 0.8:
        return {'eligible': False, 'reason': 'User must work at least 80% of the time in the same city'}

    baseline = baseline_value(user_id, db)
    if baseline <= 0:
        return {'eligible': False, 'reason': 'Valid baseline income is required'}

    return {'eligible': True, 'reason': ''}


def process_claim(user_id: int, db: Session, lat: float, lon: float) -> dict:
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
        return {
            'status': 'REJECTED',
            'claim_id': f'claim_{claim.id}',
            'reasons': [eligibility['reason']],
            'fraud_score': 1.0,
        }

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
        return {
            'status': 'REJECTED',
            'claim_id': f'claim_{claim.id}',
            'reasons': ['No completed policy week is available to claim yet'],
            'fraud_score': 1.0,
        }

    environment_data = get_environment(lat, lon, db=db, user_id=user_id)
    environment_data['city'] = resolve_city_from_coordinates(lat, lon)
    today_income = _today_income_payload(user_id, db)
    baseline = baseline_value(user_id, db)
    risk_result = calculate_risk(environment_data, user_id=user_id, db=db, today_income=today_income)
    week_records = _week_records(user_id, db, policy.start_date, policy.end_date)
    actual_week_income = sum(record.earnings for record in week_records)
    active_triggers = [str(item) for item in (risk_result.get('active_triggers') or [])]
    claim_date = policy.end_date

    fraud_result = validate_claim(
        user_id=user_id,
        db=db,
        environment_data=environment_data,
        today_income=today_income,
    )
    if not fraud_result['is_valid']:
        borderline_review = 0.45 <= float(fraud_result['fraud_score']) < 0.65
        status = 'NEEDS_REVIEW' if borderline_review else 'REJECTED'
        reasons = fraud_result['reasons'] or ['Claim validation failed']
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=policy.start_date.strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=fraud_result['fraud_score'],
            status=status,
            reasons=reasons,
        )
        record_claim_learning(
            db,
            user_id=user_id,
            policy_id=policy.id,
            risk_snapshot_id=None,
            claim_date=claim_date,
            status=status,
            risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
            baseline_income=baseline * 7,
            actual_loss=0.0,
            approved_payout=0.0,
            triggers=active_triggers,
            reasons=reasons,
            fraud_score=float(fraud_result['fraud_score']),
            review_notes='Fraud validation blocked approval',
        )
        update_model_weights(db, user_id=user_id)
        update_user_behavior(db, user_id=user_id)
        db.commit()
        return {
            'status': status,
            'claim_id': f'claim_{claim.id}',
            'reasons': reasons,
            'fraud_score': fraud_result['fraud_score'],
        }

    weekly_loss = _round(max(0.0, (baseline * 7) - actual_week_income))
    if weekly_loss <= 0:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=policy.start_date.strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=fraud_result['fraud_score'],
            status='REJECTED',
            reasons=['No eligible weekly loss detected'],
        )
        record_claim_learning(
            db,
            user_id=user_id,
            policy_id=policy.id,
            risk_snapshot_id=None,
            claim_date=claim_date,
            status='REJECTED',
            risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
            baseline_income=baseline * 7,
            actual_loss=0.0,
            approved_payout=0.0,
            triggers=active_triggers,
            reasons=['No eligible weekly loss detected'],
            fraud_score=float(fraud_result['fraud_score']),
            review_notes='Actual loss was zero after completed policy period',
        )
        update_model_weights(db, user_id=user_id)
        update_user_behavior(db, user_id=user_id)
        db.commit()
        return {
            'status': 'REJECTED',
            'claim_id': f'claim_{claim.id}',
            'reasons': ['No eligible weekly loss detected'],
            'fraud_score': fraud_result['fraud_score'],
        }

    payout = _round(weekly_loss * 0.8)
    claim = create_claim_record(
        user_id=user_id,
        db=db,
        week=policy.start_date.strftime('%G-W%V'),
        loss=weekly_loss,
        payout=payout,
        fraud_score=fraud_result['fraud_score'],
        status='APPROVED',
        reasons=[],
    )
    record_claim_learning(
        db,
        user_id=user_id,
        policy_id=policy.id,
        risk_snapshot_id=None,
        claim_date=claim_date,
        status='APPROVED',
        risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
        baseline_income=baseline * 7,
        actual_loss=weekly_loss,
        approved_payout=payout,
        triggers=active_triggers,
        reasons=[],
        fraud_score=float(fraud_result['fraud_score']),
        review_notes='Approved claim used for adaptive learning',
    )
    update_model_weights(db, user_id=user_id)
    update_user_behavior(db, user_id=user_id)
    db.commit()
    return {
        'status': 'APPROVED',
        'claim_id': f'claim_{claim.id}',
        'weekly_loss': weekly_loss,
        'loss': weekly_loss,
        'payout': payout,
        'fraud_score': fraud_result['fraud_score'],
    }
