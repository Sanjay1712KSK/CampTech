from sqlalchemy.orm import Session

from services.environment_service import get_environment
from services.gig_service import calculate_baseline_value
from services.risk_engine import calculate_risk


CITY_COORDINATES = {
    'chennai': (13.0827, 80.2707),
    'bengaluru': (12.9716, 77.5946),
    'mumbai': (19.0760, 72.8777),
    'pune': (18.5204, 73.8567),
    'hyderabad': (17.3850, 78.4867),
}


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _baseline_value(user_id: int, db: Session) -> float:
    return calculate_baseline_value(user_id=user_id, db=db)


def baseline_value(user_id: int, db: Session) -> float:
    return _baseline_value(user_id, db)


def _resolve_coordinates(user_id: int, db: Session) -> tuple[float, float]:
    latest = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .first()
    )
    if latest and latest.city:
        coords = CITY_COORDINATES.get(str(latest.city).lower())
        if coords:
            return coords
    return CITY_COORDINATES['chennai']


def resolve_city_from_coordinates(lat: float, lon: float) -> str:
    closest_city = 'Chennai'
    closest_distance = float('inf')
    for city, (city_lat, city_lon) in CITY_COORDINATES.items():
        distance = ((lat - city_lat) ** 2) + ((lon - city_lon) ** 2)
        if distance < closest_distance:
            closest_distance = distance
            closest_city = city.title()
    return closest_city


def calculate_weekly_premium(user_id: int, db: Session) -> dict:
    baseline = _baseline_value(user_id, db)
    lat, lon = _resolve_coordinates(user_id, db)
    environment = get_environment(lat, lon)
    risk_result = calculate_risk(environment)
    risk_score = float(risk_result.get('risk_score', 0.0))

    weekly_income = _round(baseline * 7)
    weekly_premium = _round(weekly_income * risk_score * 0.05)

    return {
        'baseline': baseline,
        'weekly_income': weekly_income,
        'risk_score': _round(risk_score),
        'weekly_premium': weekly_premium,
    }
