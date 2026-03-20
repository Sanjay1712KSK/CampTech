from sqlalchemy.orm import Session

from models.gig_income import GigIncome
from services.policy_service import get_claimable_policy
from services.premium_engine import baseline_value


def _round(value: float) -> float:
    return float(round(float(value), 3))


def _claim_week_records(user_id: int, db: Session) -> list[GigIncome]:
    policy = get_claimable_policy(int(user_id), db)
    query = db.query(GigIncome).filter(GigIncome.user_id == int(user_id))
    if policy is not None:
        query = query.filter(
            GigIncome.date >= policy.start_date,
            GigIncome.date <= policy.end_date,
        )
    return query.order_by(GigIncome.date.asc(), GigIncome.created_at.asc()).all()


def _majority_city(records: list[GigIncome]) -> tuple[str | None, float]:
    if not records:
        return None, 0.0
    counts: dict[str, int] = {}
    for record in records:
        city = (record.city or '').strip()
        if not city:
            continue
        counts[city] = counts.get(city, 0) + 1
    if not counts:
        return None, 0.0
    city, count = max(counts.items(), key=lambda item: item[1])
    return city, count / len(records)


def _dominant_disruption(records: list[GigIncome], fallback: str) -> str:
    counts: dict[str, int] = {}
    for record in records:
        disruption = str(record.disruption_type or 'none').lower()
        if disruption == 'none':
            continue
        counts[disruption] = counts.get(disruption, 0) + 1
    if not counts:
        return fallback
    return max(counts.items(), key=lambda item: item[1])[0]


def _disruption_counts(records: list[GigIncome]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for record in records:
        disruption = str(record.disruption_type or 'none').lower()
        if disruption == 'none':
            continue
        counts[disruption] = counts.get(disruption, 0) + 1
    return counts


def validate_claim(user_id: int, db: Session, environment_data: dict, today_income: dict) -> dict:
    baseline = baseline_value(user_id, db)
    weather = (environment_data or {}).get('weather') or {}
    traffic = (environment_data or {}).get('traffic') or {}
    environment_city = (
        (environment_data or {}).get('city')
        or ((environment_data or {}).get('context') or {}).get('city')
        or ''
    )

    week_records = _claim_week_records(user_id, db)
    claim_day = week_records[-1] if week_records else None
    earnings = (
        float(claim_day.earnings)
        if claim_day is not None
        else float(today_income.get('earnings', 0.0) or 0.0)
    )
    orders_completed = (
        int(claim_day.orders_completed)
        if claim_day is not None
        else int(today_income.get('orders_completed', 0) or 0)
    )
    disruption = _dominant_disruption(
        week_records,
        str(today_income.get('disruption_type', 'none') or 'none').lower(),
    )
    disruption_counts = _disruption_counts(week_records)
    actual_week_income = sum(float(record.earnings) for record in week_records)
    avg_week_income = actual_week_income / len(week_records) if week_records else earnings
    disruption_days = sum(1 for record in week_records if record.disruption_type != 'none')
    majority_city, city_ratio = _majority_city(week_records)

    reasons: list[str] = []
    location_check = 0.0
    income_check = 0.0
    weather_check = 0.0
    activity_check = 0.0

    rainfall = float(weather.get('rainfall', 0.0) or 0.0)
    if rainfall < 1 and disruption == 'rain':
        reasons.append('Weather data does not support a rain-related claim')
        weather_check = 1.0

    if majority_city and environment_city and majority_city.lower() != str(environment_city).lower():
        reasons.append('Current claim location does not match the worker city pattern')
        location_check = 1.0
        if city_ratio < 0.8:
            reasons.append('Claim-week city pattern is inconsistent and needs manual review')
            location_check = 1.0
    elif city_ratio < 0.8:
        reasons.append('User work history is not city-consistent enough for this policy')
        location_check = 0.8

    expected_week_income = baseline * 7
    weekly_loss = max(0.0, expected_week_income - actual_week_income)
    if baseline <= 0 or weekly_loss <= baseline * 0.5:
        reasons.append('Weekly income drop is too small for a valid claim')
        income_check = 1.0

    traffic_level = str(traffic.get('traffic_level', 'LOW') or 'LOW').upper()
    if traffic_level == 'LOW' and disruption == 'traffic':
        reasons.append('Traffic data does not support a traffic-related claim')
        weather_check = max(weather_check, 1.0)

    if disruption_days >= 5 and actual_week_income >= expected_week_income * 0.9:
        reasons.append('Weekly disruption pattern does not match the reported loss')
        activity_check = max(activity_check, 0.8)

    if len(disruption_counts) > 1:
        reasons.append('Claim-week disruption pattern is inconsistent across multiple causes')
        activity_check = max(activity_check, 0.8)

    if orders_completed > 0 and baseline > 0 and earnings >= baseline * 0.85:
        reasons.append('Daily activity looks too healthy for the reported disruption')
        activity_check = max(activity_check, 1.0)

    if disruption == 'none':
        reasons.append('No disruption detected for the current claim window')
        activity_check = max(activity_check, 0.8)

    fraud_score = _round(
        min(
            1.0,
            (0.3 * location_check)
            + (0.3 * income_check)
            + (0.2 * weather_check)
            + (0.2 * activity_check),
        )
    )

    return {
        'is_valid': fraud_score < 0.45,
        'fraud_score': fraud_score,
        'reasons': reasons,
        'signals': {
            'location_check': location_check,
            'income_check': income_check,
            'weather_check': weather_check,
            'activity_check': activity_check,
            'majority_city': majority_city,
            'environment_city': environment_city or None,
            'weekly_loss': _round(weekly_loss),
            'actual_week_income': _round(actual_week_income),
            'disruption_days': disruption_days,
        },
    }
