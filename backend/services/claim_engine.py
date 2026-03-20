import uuid

from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from services.environment_service import get_environment
from services.fraud_engine import validate_claim


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _baseline_value(user_id: int, db: Session) -> float:
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id), GigIncome.disruption_type == 'none')
        .order_by(GigIncome.earnings.desc())
        .limit(5)
        .all()
    )
    if not records:
        return 0.0
    return _round(sum(record.earnings for record in records) / len(records))


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


def process_claim(user_id: int, db: Session, lat: float, lon: float) -> dict:
    environment_data = get_environment(lat, lon)
    today_income = _today_income_payload(user_id, db)
    baseline = _baseline_value(user_id, db)

    fraud_result = validate_claim(
        user_id=user_id,
        db=db,
        environment_data=environment_data,
        today_income=today_income,
    )
    if not fraud_result['is_valid']:
        return {
            'status': 'REJECTED',
            'reasons': fraud_result['reasons'] or ['Claim validation failed'],
            'fraud_score': fraud_result['fraud_score'],
        }

    loss = _round(max(0.0, baseline - float(today_income.get('earnings', 0.0))))
    if loss <= 0:
        return {
            'status': 'REJECTED',
            'reasons': ['No eligible loss detected'],
            'fraud_score': fraud_result['fraud_score'],
        }

    payout = _round(loss * 0.8)
    return {
        'status': 'APPROVED',
        'claim_id': f'claim_{uuid.uuid4()}',
        'loss': loss,
        'payout': payout,
        'fraud_score': fraud_result['fraud_score'],
    }
