from datetime import date

from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from services.environment_service import get_environment
from services.fraud_engine import validate_claim
from services.policy_service import create_claim_record, get_latest_policy
from services.premium_engine import baseline_value, resolve_city_from_coordinates


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

    policy = get_latest_policy(user_id, db)
    if policy is None or not policy.premium_paid:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=date.today().strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=1.0,
            status='REJECTED',
            reasons=['No paid policy found for this user'],
        )
        return {
            'status': 'REJECTED',
            'claim_id': f'claim_{claim.id}',
            'reasons': ['No paid policy found for this user'],
            'fraud_score': 1.0,
        }

    if date.today() <= policy.end_date:
        return {
            'status': 'REJECTED',
            'reasons': ['Claim available after policy period ends'],
            'fraud_score': 0.0,
        }

    environment_data = get_environment(lat, lon)
    environment_data['city'] = resolve_city_from_coordinates(lat, lon)
    today_income = _today_income_payload(user_id, db)
    baseline = baseline_value(user_id, db)
    week_records = _week_records(user_id, db, policy.start_date, policy.end_date)
    actual_week_income = sum(record.earnings for record in week_records)

    fraud_result = validate_claim(
        user_id=user_id,
        db=db,
        environment_data=environment_data,
        today_income=today_income,
    )
    if not fraud_result['is_valid']:
        claim = create_claim_record(
            user_id=user_id,
            db=db,
            week=policy.start_date.strftime('%G-W%V'),
            loss=0.0,
            payout=0.0,
            fraud_score=fraud_result['fraud_score'],
            status='REJECTED',
            reasons=fraud_result['reasons'] or ['Claim validation failed'],
        )
        return {
            'status': 'REJECTED',
            'claim_id': f'claim_{claim.id}',
            'reasons': fraud_result['reasons'] or ['Claim validation failed'],
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
    return {
        'status': 'APPROVED',
        'claim_id': f'claim_{claim.id}',
        'weekly_loss': weekly_loss,
        'loss': weekly_loss,
        'payout': payout,
        'fraud_score': fraud_result['fraud_score'],
    }
