import logging
import random
from datetime import date, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from database.db import SessionLocal
from models.gig_account import GigAccount
from models.gig_income import GigIncome
from models.profile import Profile
from models.user_model import User

logger = logging.getLogger('gig_insurance_backend.gig')

PLATFORM_LABELS = {
    'swiggy': 'Swiggy',
    'zomato': 'Zomato',
    'blinkit': 'Blinkit',
    'porter': 'Porter',
    'uber': 'Uber',
}
PLATFORMS = list(PLATFORM_LABELS.keys())
CITIES = ['Chennai', 'Bengaluru', 'Pune', 'Mumbai', 'Hyderabad']


def _round(value: float, places: int = 2) -> float:
    return float(round(float(value), places))


def _clamp(value: float, min_value: float, max_value: float) -> float:
    return max(min_value, min(max_value, value))


def _is_holiday(target_date: date) -> bool:
    return target_date.day in (15, 26)


def _normalize_platform(platform: str | None) -> str:
    normalized = (platform or '').strip().lower()
    if normalized not in PLATFORM_LABELS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Platform must be one of swiggy, zomato, blinkit, porter, or uber',
        )
    return normalized


def _ensure_user_exists(session: Session, user_id: int) -> None:
    exists = session.query(User).filter(User.id == int(user_id)).first()
    if exists is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')


def _resolve_city(session: Session, user_id: int) -> str:
    profile = session.query(Profile).filter(Profile.user_id == int(user_id)).first()
    if profile and profile.city:
        return profile.city

    latest_income = (
        session.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .first()
    )
    if latest_income and latest_income.city:
        return latest_income.city

    return random.choice(CITIES)


def _select_platform(session: Session, user_id: int, platform: str | None) -> str:
    if platform:
        return _normalize_platform(platform)

    latest_account = (
        session.query(GigAccount)
        .filter(GigAccount.user_id == int(user_id))
        .order_by(GigAccount.created_at.desc(), GigAccount.id.desc())
        .first()
    )
    if latest_account:
        return latest_account.platform

    latest_income = (
        session.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .first()
    )
    if latest_income and latest_income.platform:
        return latest_income.platform

    return random.choice(PLATFORMS)


def _generate_environment(disruption_type: str) -> dict:
    if disruption_type == 'rain':
        rainfall = _round(random.uniform(6, 18))
        humidity = _round(random.uniform(78, 95))
        weather_condition = random.choice(['rain', 'heavy_rain'])
        traffic_level = 'HIGH'
        traffic_score = _round(random.uniform(1.4, 2.0), 3)
        temperature = _round(random.uniform(24, 30))
        wind_speed = _round(random.uniform(12, 24))
        aqi_level = random.randint(2, 4)
    elif disruption_type == 'traffic':
        rainfall = _round(random.uniform(0, 3))
        humidity = _round(random.uniform(45, 75))
        weather_condition = random.choice(['clear', 'cloudy'])
        traffic_level = 'HIGH'
        traffic_score = _round(random.uniform(1.5, 2.1), 3)
        temperature = _round(random.uniform(29, 36))
        wind_speed = _round(random.uniform(6, 14))
        aqi_level = random.randint(2, 4)
    elif disruption_type == 'low_demand':
        rainfall = _round(random.uniform(0, 2))
        humidity = _round(random.uniform(35, 65))
        weather_condition = random.choice(['clear', 'cloudy'])
        traffic_level = random.choice(['LOW', 'MEDIUM'])
        traffic_score = _round(random.uniform(0.9, 1.3), 3)
        temperature = _round(random.uniform(27, 35))
        wind_speed = _round(random.uniform(5, 12))
        aqi_level = random.randint(1, 3)
    else:
        rainfall = _round(random.uniform(0, 1.5))
        humidity = _round(random.uniform(40, 70))
        weather_condition = random.choice(['clear', 'cloudy'])
        traffic_level = random.choice(['LOW', 'MEDIUM'])
        traffic_score = _round(random.uniform(0.8, 1.2), 3)
        temperature = _round(random.uniform(28, 34))
        wind_speed = _round(random.uniform(5, 12))
        aqi_level = random.randint(1, 3)

    return {
        'weather_condition': weather_condition,
        'temperature': temperature,
        'humidity': humidity,
        'rainfall': rainfall,
        'wind_speed': wind_speed,
        'aqi_level': aqi_level,
        'pm2_5': _round(random.uniform(18, 65)),
        'pm10': _round(random.uniform(35, 95)),
        'traffic_level': traffic_level,
        'traffic_score': traffic_score,
    }


def _risk_score(temperature: float, rainfall: float, traffic_score: float, loss_amount: float, expected_income: float) -> float:
    score = 0.0
    score += 0.25 * _clamp(rainfall / 20.0, 0.0, 1.0)
    score += 0.25 * _clamp((traffic_score - 1.0) / 1.5, 0.0, 1.0)
    score += 0.2 * _clamp((temperature - 30.0) / 12.0, 0.0, 1.0)
    score += 0.3 * _clamp(loss_amount / max(expected_income, 1.0), 0.0, 1.0)
    return _round(_clamp(score, 0.0, 1.0), 3)


def _build_day_record(user_id: int, target_date: date, platform: str, city: str) -> dict:
    weekend = target_date.weekday() >= 5
    base_income = float(random.randint(500, 1200))
    weekend_boost = float(random.randint(100, 300)) if weekend else 0.0
    expected_income = base_income + weekend_boost

    disruption_type = 'none'
    if random.random() < 0.2:
        disruption_type = random.choice(['rain', 'traffic', 'low_demand'])

    reduction_ratio = random.uniform(0.3, 0.7) if disruption_type != 'none' else 0.0
    income = _round(expected_income * (1.0 - reduction_ratio))
    hours = random.uniform(6.0, 10.0)
    if disruption_type != 'none':
        hours = max(6.0, hours - random.uniform(0.0, 1.2))
    hours = _round(hours)

    orders_completed = max(6, int(round(income / random.uniform(45.0, 70.0))))
    earnings_per_order = _round(income / max(orders_completed, 1))
    earnings_per_hour = _round(income / max(hours, 1.0))
    environment = _generate_environment(disruption_type)
    peak_hours = _round(min(hours, random.uniform(3.0, 5.5)))
    off_peak_hours = _round(max(0.0, hours - peak_hours))
    loss_amount = _round(max(0.0, expected_income - income))

    return {
        'date': target_date,
        'user_id': int(user_id),
        'orders_completed': orders_completed,
        'hours_worked': hours,
        'earnings': income,
        'earnings_per_order': earnings_per_order,
        'platform': platform,
        'disruption_type': disruption_type,
        'weather_condition': environment['weather_condition'],
        'temperature': environment['temperature'],
        'humidity': environment['humidity'],
        'rainfall': environment['rainfall'],
        'wind_speed': environment['wind_speed'],
        'aqi_level': environment['aqi_level'],
        'pm2_5': environment['pm2_5'],
        'pm10': environment['pm10'],
        'traffic_level': environment['traffic_level'],
        'traffic_score': environment['traffic_score'],
        'peak_hours_active': peak_hours,
        'off_peak_hours': off_peak_hours,
        'expected_orders': max(orders_completed, int(round(expected_income / 55.0))),
        'order_acceptance_rate': _round(random.uniform(0.88, 0.99), 3),
        'order_completion_rate': _round(random.uniform(0.9, 0.99), 3),
        'distance_travelled_km': _round(random.uniform(35.0, 80.0)),
        'avg_delivery_time_mins': _round(random.uniform(18.0, 42.0)),
        'earnings_per_hour': earnings_per_hour,
        'efficiency_score': _round(orders_completed / max(hours, 1.0)),
        'loss_amount': loss_amount,
        'earnings_variance': _round(income - expected_income),
        'risk_score': _risk_score(
            temperature=environment['temperature'],
            rainfall=environment['rainfall'],
            traffic_score=environment['traffic_score'],
            loss_amount=loss_amount,
            expected_income=expected_income,
        ),
        'is_weekend': weekend,
        'is_holiday': _is_holiday(target_date),
        'city': city,
    }


def _serialize_income_record(record: GigIncome) -> dict:
    return {
        'id': record.id,
        'user_id': record.user_id,
        'date': record.date,
        'income': _round(record.earnings),
        'hours': _round(record.hours_worked),
        'earnings': _round(record.earnings),
        'orders_completed': int(record.orders_completed),
        'hours_worked': _round(record.hours_worked),
        'earnings_per_order': _round(record.earnings_per_order),
        'platform': record.platform,
        'disruption_type': record.disruption_type,
        'weather_condition': record.weather_condition,
        'temperature': _round(record.temperature),
        'humidity': _round(record.humidity),
        'rainfall': _round(record.rainfall),
        'wind_speed': _round(record.wind_speed),
        'aqi_level': int(record.aqi_level),
        'pm2_5': _round(record.pm2_5),
        'pm10': _round(record.pm10),
        'traffic_level': record.traffic_level,
        'traffic_score': _round(record.traffic_score, 3),
        'peak_hours_active': _round(record.peak_hours_active),
        'off_peak_hours': _round(record.off_peak_hours),
        'expected_orders': int(record.expected_orders),
        'order_acceptance_rate': _round(record.order_acceptance_rate, 3),
        'order_completion_rate': _round(record.order_completion_rate, 3),
        'distance_travelled_km': _round(record.distance_travelled_km),
        'avg_delivery_time_mins': _round(record.avg_delivery_time_mins),
        'earnings_per_hour': _round(record.earnings_per_hour),
        'efficiency_score': _round(record.efficiency_score),
        'loss_amount': _round(record.loss_amount),
        'earnings_variance': _round(record.earnings_variance),
        'risk_score': _round(record.risk_score, 3),
        'is_weekend': bool(record.is_weekend),
        'is_holiday': bool(record.is_holiday),
        'city': record.city,
    }


def _upsert_income_history(session: Session, user_id: int, days: int, platform: str, city: str) -> list[dict]:
    start_date = date.today() - timedelta(days=days - 1)
    existing = (
        session.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id), GigIncome.date >= start_date)
        .all()
    )
    existing_by_date = {record.date: record for record in existing}
    generated = []

    for offset in range(days):
        target_date = start_date + timedelta(days=offset)
        payload = _build_day_record(user_id=user_id, target_date=target_date, platform=platform, city=city)
        current = existing_by_date.get(target_date)
        if current is None:
            session.add(GigIncome(**payload))
        else:
            for field, value in payload.items():
                if hasattr(current, field):
                    setattr(current, field, value)
        generated.append(payload)

    return generated


def _recent_records(session: Session, user_id: int, days: int = 30) -> list[GigIncome]:
    start_date = date.today() - timedelta(days=max(days - 1, 0))
    return (
        session.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id), GigIncome.date >= start_date)
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .all()
    )


def calculate_baseline_value(user_id: int, db: Session) -> float:
    records = _recent_records(db, user_id=user_id, days=30)
    if not records:
        return 0.0
    top_days = sorted(records, key=lambda record: float(record.earnings), reverse=True)[:10]
    return _round(sum(record.earnings for record in top_days) / len(top_days))


def connect_gig_account(user_id: int, platform: str, worker_id: str, db: Session) -> dict:
    user_id = int(user_id)
    normalized_platform = _normalize_platform(platform)
    normalized_worker_id = worker_id.strip().upper()
    if not normalized_worker_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='worker_id is required')

    _ensure_user_exists(db, user_id)

    duplicate = (
        db.query(GigAccount)
        .filter(GigAccount.user_id == user_id, GigAccount.platform == normalized_platform)
        .first()
    )
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f'{PLATFORM_LABELS[normalized_platform]} account already connected',
        )

    worker_in_use = (
        db.query(GigAccount)
        .filter(GigAccount.platform == normalized_platform, GigAccount.worker_id == normalized_worker_id)
        .first()
    )
    if worker_in_use is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f'Worker ID already linked to another {PLATFORM_LABELS[normalized_platform]} account',
        )

    city = _resolve_city(db, user_id)
    db.add(GigAccount(user_id=user_id, platform=normalized_platform, worker_id=normalized_worker_id))
    generated = _upsert_income_history(db, user_id=user_id, days=30, platform=normalized_platform, city=city)

    avg_income = _round(sum(item['earnings'] for item in generated) / max(len(generated), 1))
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)
    profile.platform = normalized_platform
    profile.city = city
    profile.avg_income = avg_income

    db.commit()
    logger.info('connected gig account user_id=%s platform=%s worker_id=%s', user_id, normalized_platform, normalized_worker_id)
    return {
        'message': f'{PLATFORM_LABELS[normalized_platform]} account connected successfully',
        'income_generated': True,
        'status': 'CONNECTED',
        'user_id': user_id,
        'platform': normalized_platform,
        'worker_id': normalized_worker_id,
        'partner_id': normalized_worker_id,
        'generated': len(generated),
    }


def generate_data(user_id: int, days: int = 30, platform: str | None = None, db: Session | None = None) -> list[dict]:
    if days < 1:
        raise ValueError('days must be >= 1')
    if days > 90:
        raise ValueError('days must be <= 90')

    session = db or SessionLocal()
    owns_session = db is None
    try:
        user_id = int(user_id)
        _ensure_user_exists(session, user_id)
        normalized_platform = _select_platform(session, user_id=user_id, platform=platform)
        city = _resolve_city(session, user_id)
        generated = _upsert_income_history(session, user_id=user_id, days=days, platform=normalized_platform, city=city)
        session.commit()
        return generated
    finally:
        if owns_session:
            session.close()


def income_history(user_id: int, db: Session | None = None) -> list[dict]:
    session = db or SessionLocal()
    owns_session = db is None
    try:
        _ensure_user_exists(session, user_id)
        records = (
            session.query(GigIncome)
            .filter(GigIncome.user_id == int(user_id))
            .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
            .all()
        )
        return [_serialize_income_record(record) for record in records]
    finally:
        if owns_session:
            session.close()


def debug_all_records(db: Session | None = None) -> list[dict]:
    session = db or SessionLocal()
    owns_session = db is None
    try:
        records = session.query(GigIncome).order_by(GigIncome.user_id, GigIncome.date.desc()).all()
        return [_serialize_income_record(record) for record in records]
    finally:
        if owns_session:
            session.close()


def baseline_income(user_id: int, db: Session | None = None) -> dict:
    session = db or SessionLocal()
    owns_session = db is None
    try:
        _ensure_user_exists(session, user_id)
        baseline = calculate_baseline_value(user_id=int(user_id), db=session)
        return {'baseline_income': baseline, 'baseline_daily_income': baseline}
    finally:
        if owns_session:
            session.close()


def today_income(user_id: int, db: Session | None = None) -> dict:
    session = db or SessionLocal()
    owns_session = db is None
    try:
        _ensure_user_exists(session, user_id)
        record = (
            session.query(GigIncome)
            .filter(GigIncome.user_id == int(user_id), GigIncome.date == date.today())
            .order_by(GigIncome.created_at.desc())
            .first()
        )
        if record is None:
            platform = _select_platform(session, user_id=int(user_id), platform=None)
            return {
                'date': date.today(),
                'income': 0.0,
                'hours': 0.0,
                'earnings': 0.0,
                'orders_completed': 0,
                'hours_worked': 0.0,
                'disruption_type': 'none',
                'platform': platform,
            }

        return {
            'date': record.date,
            'income': _round(record.earnings),
            'hours': _round(record.hours_worked),
            'earnings': _round(record.earnings),
            'orders_completed': int(record.orders_completed),
            'hours_worked': _round(record.hours_worked),
            'disruption_type': record.disruption_type,
            'platform': record.platform,
        }
    finally:
        if owns_session:
            session.close()


def weekly_summary(user_id: int, db: Session | None = None) -> dict:
    session = db or SessionLocal()
    owns_session = db is None
    try:
        _ensure_user_exists(session, user_id)
        start_date = date.today() - timedelta(days=6)
        records = (
            session.query(GigIncome)
            .filter(GigIncome.user_id == int(user_id), GigIncome.date >= start_date)
            .order_by(GigIncome.date.asc(), GigIncome.created_at.asc())
            .all()
        )
        if not records:
            return {
                'total_income': 0.0,
                'average_daily': 0.0,
                'avg_daily_earnings': 0.0,
                'total_orders': 0,
                'total_hours': 0.0,
                'total_loss_amount': 0.0,
                'avg_risk_score': 0.0,
                'best_day': None,
                'worst_day': None,
            }

        total_income = _round(sum(record.earnings for record in records))
        average_daily = _round(total_income / len(records))
        best_day = max(records, key=lambda record: record.earnings)
        worst_day = min(records, key=lambda record: record.earnings)

        return {
            'total_income': total_income,
            'average_daily': average_daily,
            'avg_daily_earnings': average_daily,
            'total_orders': sum(record.orders_completed for record in records),
            'total_hours': _round(sum(record.hours_worked for record in records)),
            'total_loss_amount': _round(sum(record.loss_amount for record in records)),
            'avg_risk_score': _round(sum(record.risk_score for record in records) / len(records)),
            'best_day': {
                'date': best_day.date,
                'earnings': _round(best_day.earnings),
                'weather_condition': best_day.weather_condition,
                'traffic_level': best_day.traffic_level,
                'disruption_type': best_day.disruption_type,
            },
            'worst_day': {
                'date': worst_day.date,
                'earnings': _round(worst_day.earnings),
                'weather_condition': worst_day.weather_condition,
                'traffic_level': worst_day.traffic_level,
                'disruption_type': worst_day.disruption_type,
            },
        }
    finally:
        if owns_session:
            session.close()
