import logging

from sqlalchemy.orm import Session

CITY_COORDINATES = {
    'chennai': (13.0827, 80.2707),
    'bengaluru': (12.9716, 77.5946),
    'mumbai': (19.0760, 72.8777),
    'pune': (18.5204, 73.8567),
    'hyderabad': (17.3850, 78.4867),
}

from services.environment_service import get_environment
from services.gig_service import calculate_baseline_value
from services.risk_engine import calculate_risk

logger = logging.getLogger('gig_insurance_backend.premium')


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _baseline_value(user_id: int, db: Session) -> float:
    return calculate_baseline_value(user_id=user_id, db=db)


def baseline_value(user_id: int, db: Session) -> float:
    return _baseline_value(user_id, db)


def resolve_city_from_coordinates(lat: float, lon: float) -> str:
    closest_city = 'Chennai'
    closest_distance = float('inf')
    for city, (city_lat, city_lon) in CITY_COORDINATES.items():
        distance = ((lat - city_lat) ** 2) + ((lon - city_lon) ** 2)
        if distance < closest_distance:
            closest_distance = distance
            closest_city = city.title()
    return closest_city


def _build_explanation(risk: dict) -> str:
    reasons = [str(item) for item in (risk.get('reasons') or []) if str(item).strip()]
    if reasons:
        lead = reasons[:2]
        return f"Pricing is based on {' and '.join(lead).lower()}"
    severity = str(risk.get('trigger_severity', 'MEDIUM')).lower()
    return f'Pricing is based on {severity} disruption conditions from the live risk engine'


def calculate_weekly_premium(user_id: int, lat: float, lon: float, db: Session) -> dict:
    baseline = _baseline_value(user_id, db)
    environment = get_environment(lat, lon, db=db, user_id=user_id)
    risk_result = calculate_risk(environment, user_id=user_id, db=db)
    risk_score = float(risk_result.get('risk_score', 0.0))
    active_triggers = [str(item) for item in (risk_result.get('active_triggers') or [])]
    trigger_severity = str(risk_result.get('trigger_severity', 'MEDIUM') or 'MEDIUM').upper()

    weekly_income = _round(baseline * 7)
    weekly_premium = weekly_income * risk_score * 0.07
    if trigger_severity == 'HIGH':
        weekly_premium *= 1.15
    if 'COMBINED_TRIGGER' in active_triggers:
        weekly_premium *= 1.10
    weekly_premium = _round(weekly_premium)
    coverage = _round(weekly_income * 0.8)

    linked_risk = {
        'risk_score': _round(risk_score),
        'expected_income_loss': risk_result.get('expected_income_loss', '0%'),
        'trigger_severity': trigger_severity,
        'active_triggers': active_triggers,
        'reasons': risk_result.get('reasons', []),
    }

    response = {
        'baseline': _round(baseline),
        'weekly_income': weekly_income,
        'weekly_premium': weekly_premium,
        'coverage': coverage,
        'risk_score': _round(risk_score),
        'risk': linked_risk,
        'explanation': _build_explanation(linked_risk),
    }

    logger.info(
        'premium calculated user_id=%s lat=%s lon=%s premium=%s risk_score=%s severity=%s',
        user_id,
        lat,
        lon,
        weekly_premium,
        linked_risk['risk_score'],
        trigger_severity,
    )

    return response
