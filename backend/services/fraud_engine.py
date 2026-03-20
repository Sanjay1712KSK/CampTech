from sqlalchemy.orm import Session

from models.gig_income import GigIncome


def _round(value: float) -> float:
    return float(round(float(value), 3))


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
    return float(sum(record.earnings for record in records) / len(records))


def validate_claim(user_id: int, db: Session, environment_data: dict, today_income: dict) -> dict:
    baseline = _baseline_value(user_id, db)
    weather = (environment_data or {}).get('weather') or {}
    traffic = (environment_data or {}).get('traffic') or {}

    earnings = float(today_income.get('earnings', 0.0) or 0.0)
    orders_completed = int(today_income.get('orders_completed', 0) or 0)
    disruption = str(today_income.get('disruption_type', 'none') or 'none').lower()

    reasons: list[str] = []
    fraud_score = 0.0
    hard_fail = False

    rainfall = float(weather.get('rainfall', 0.0) or 0.0)
    if rainfall < 1 and disruption == 'rain':
        reasons.append('Weather data does not support a rain-related claim')
        fraud_score += 0.35
        hard_fail = True

    if baseline > 0 and earnings >= baseline * 0.8:
        reasons.append('Income drop is not significant enough for a claim')
        fraud_score += 0.25
        hard_fail = True

    if disruption != 'none' and orders_completed > 0 and baseline > 0 and earnings >= baseline * 0.9:
        reasons.append('Activity looks too healthy for the reported disruption')
        fraud_score += 0.2

    traffic_level = str(traffic.get('traffic_level', 'LOW') or 'LOW').upper()
    if traffic_level == 'LOW' and disruption == 'traffic':
        reasons.append('Traffic data does not support a traffic-related claim')
        fraud_score += 0.35
        hard_fail = True

    if disruption == 'none':
        reasons.append('No disruption detected for today')
        fraud_score += 0.2

    fraud_score = _round(min(fraud_score, 1.0))

    return {
        'is_valid': not hard_fail,
        'fraud_score': fraud_score,
        'reasons': reasons,
    }
