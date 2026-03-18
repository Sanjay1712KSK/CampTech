import logging
import random
from datetime import date, timedelta

from sqlalchemy.orm import Session

from database.db import SessionLocal
from models.gig_income import GigIncome

logger = logging.getLogger('gig_insurance_backend.gig')

PLATFORMS = ['swiggy', 'zomato']
WEATHER_CONDITIONS = ['clear', 'cloudy', 'rain', 'heavy_rain', 'storm', 'heatwave']
TRAFFIC_LEVELS = ['LOW', 'MEDIUM', 'HIGH']


def _clamp(value, min_value, max_value):
    return max(min_value, min(max_value, value))


def _round(value, places=2):
    return float(round(value, places))


def _is_holiday(_date: date) -> bool:
    # simple placeholder: 15th and 26th of each month are mock holidays
    return _date.day in (15, 26)


def _generate_environ(day: date, disruption: str):
    if disruption == 'rain':
        weather = random.choice(['rain', 'heavy_rain'])
        temperature = _clamp(random.gauss(26, 2), 22, 32)
        humidity = _clamp(random.gauss(85, 5), 70, 100)
        rainfall = _clamp(random.gauss(8, 3), 3, 20)
        wind_speed = _clamp(random.gauss(18, 5), 8, 30)
        traffic = 'HIGH'
        traffic_score = _clamp(random.gauss(1.5, 0.2), 1.2, 2.5)
        aqi = random.randint(2, 4)
    elif disruption == 'heavy_rain':
        weather = 'heavy_rain'
        temperature = _clamp(random.gauss(24, 2), 21, 30)
        humidity = _clamp(random.gauss(88, 4), 75, 100)
        rainfall = _clamp(random.gauss(12, 4), 5, 25)
        wind_speed = _clamp(random.gauss(22, 6), 10, 35)
        traffic = 'HIGH'
        traffic_score = _clamp(random.gauss(1.7, 0.2), 1.3, 2.8)
        aqi = random.randint(2, 5)
    elif disruption == 'heatwave':
        weather = 'heatwave'
        temperature = _clamp(random.gauss(40, 3), 35, 45)
        humidity = _clamp(random.gauss(40, 8), 20, 60)
        rainfall = 0.0
        wind_speed = _clamp(random.gauss(8, 2), 3, 15)
        traffic = random.choice(['LOW', 'MEDIUM'])
        traffic_score = _clamp(random.gauss(1.1, 0.2), 0.8, 1.5)
        aqi = random.randint(3, 5)
    elif disruption == 'traffic':
        weather = random.choice(['cloudy', 'clear'])
        temperature = _clamp(random.gauss(32, 3), 28, 38)
        humidity = _clamp(random.gauss(50, 10), 30, 70)
        rainfall = _clamp(random.gauss(0.5, 1.0), 0, 4)
        wind_speed = _clamp(random.gauss(10, 3), 4, 18)
        traffic = 'HIGH'
        traffic_score = _clamp(random.gauss(1.6, 0.2), 1.3, 2.5)
        aqi = random.randint(2, 4)
    elif disruption == 'low_demand':
        weather = random.choice(['clear', 'cloudy'])
        temperature = _clamp(random.gauss(32, 4), 26, 40)
        humidity = _clamp(random.gauss(55, 10), 30, 85)
        rainfall = _clamp(random.gauss(0.4, 1.0), 0, 3)
        wind_speed = _clamp(random.gauss(8, 2), 3, 16)
        traffic = random.choice(['LOW', 'MEDIUM'])
        traffic_score = _clamp(random.gauss(1.1, 0.2), 0.9, 1.6)
        aqi = random.randint(2, 4)
    elif disruption == 'bandh':
        weather = random.choice(['cloudy', 'clear'])
        temperature = _clamp(random.gauss(30, 4), 24, 38)
        humidity = _clamp(random.gauss(60, 10), 30, 90)
        rainfall = _clamp(random.gauss(1, 2), 0, 8)
        wind_speed = _clamp(random.gauss(10, 4), 4, 20)
        traffic = 'LOW'
        traffic_score = _clamp(random.gauss(0.8, 0.2), 0.5, 1.2)
        aqi = random.randint(2, 4)
    else:
        weather = random.choice(['clear', 'cloudy'])
        temperature = _clamp(random.gauss(32, 3), 26, 38)
        humidity = _clamp(random.gauss(55, 10), 30, 75)
        rainfall = _clamp(random.gauss(0.5, 0.8), 0, 2)
        wind_speed = _clamp(random.gauss(9, 3), 4, 16)
        traffic = random.choice(['LOW', 'MEDIUM'])
        traffic_score = _clamp(random.gauss(1.0, 0.15), 0.7, 1.4)
        aqi = random.randint(1, 4)

    return {
        'weather_condition': weather,
        'temperature': _round(temperature),
        'humidity': _round(humidity),
        'rainfall': _round(rainfall),
        'wind_speed': _round(wind_speed),
        'aqi_level': aqi,
        'pm2_5': _round(random.gauss(30 + 10 * (aqi - 1), 8)),
        'pm10': _round(random.gauss(50 + 15 * (aqi - 1), 10)),
        'traffic_level': traffic,
        'traffic_score': _round(traffic_score, 3),
    }


def _compute_baseline_expected(orders_completed, disruption_type):
    if disruption_type == 'bandh':
        return 50.0
    if disruption_type in ('rain', 'traffic', 'low_demand', 'heatwave'):
        return max(0.0, orders_completed * 45.0)
    return orders_completed * 55.0


def _risk_score(stats):
    score = 0.0
    score += 0.3 * (stats['rainfall'] / 20.0)
    score += 0.2 * (stats['aqi_level'] / 5.0)
    score += 0.25 * _clamp((stats['traffic_score'] - 1.0) / 2.0, 0.0, 1.0)
    score += 0.2 * _clamp((stats['temperature'] - 30.0) / 20.0, 0.0, 1.0)
    score += 0.05 * _clamp(stats['loss_amount'] / max(stats['expected_baseline'], 1.0), 0.0, 1.0)
    return _round(_clamp(score, 0.0, 1.0), 3)


def _generate_day_record(user_id: int, day: date, expected_baseline: float = None):
    weekend = day.weekday() >= 5
    holiday = _is_holiday(day)

    disruption_roll = random.random()
    if disruption_roll < 0.08:
        disruption_type = 'bandh'
    elif disruption_roll < 0.18:
        disruption_type = 'rain'
    elif disruption_roll < 0.26:
        disruption_type = 'traffic'
    elif disruption_roll < 0.34:
        disruption_type = 'low_demand'
    elif disruption_roll < 0.39:
        disruption_type = 'heatwave'
    else:
        disruption_type = 'none'

    if disruption_type == 'bandh':
        orders = random.randint(0, 3)
        hours = _clamp(random.gauss(1.5, 0.5), 0.5, 4.0)
        earnings_per_order = _clamp(random.gauss(30, 15), 0, 60) if orders > 0 else 0.0
    elif disruption_type == 'rain':
        orders = random.randint(5, 12)
        hours = _clamp(random.gauss(6.5, 0.9), 4.0, 9.0)
        earnings_per_order = _clamp(random.gauss(42, 7), 28, 60)
    elif disruption_type == 'traffic':
        orders = random.randint(8, 14)
        hours = _clamp(random.gauss(8.5, 1.0), 5.0, 11.0)
        earnings_per_order = _clamp(random.gauss(44, 8), 30, 65)
    elif disruption_type == 'low_demand':
        orders = random.randint(4, 10)
        hours = _clamp(random.gauss(6.0, 1.0), 4.0, 9.0)
        earnings_per_order = _clamp(random.gauss(38, 8), 25, 55)
    elif disruption_type == 'heatwave':
        orders = random.randint(8, 14)
        hours = _clamp(random.gauss(7.0, 1.0), 4.0, 10.0)
        earnings_per_order = _clamp(random.gauss(40, 8), 30, 60)
    else:
        orders = random.randint(15, 22)
        hours = _clamp(random.gauss(7.5, 1.0), 5.5, 10.0)
        earnings_per_order = _clamp(random.gauss(52, 8), 32, 70)

    if weekend and disruption_type == 'none':
        orders = int(orders * random.uniform(1.2, 1.4))
        earnings_per_order = _clamp(earnings_per_order * random.uniform(1.05, 1.15), 35, 75)

    if holiday and disruption_type == 'none':
        orders = int(orders * random.uniform(1.1, 1.3))
        earnings_per_order = _clamp(earnings_per_order * random.uniform(1.03, 1.1), 35, 75)

    weather = _generate_environ(day, disruption_type)

    distance = _clamp(random.gauss(55, 12), 20, 90)
    avg_delivery_time = _clamp(random.gauss(28, 8), 15, 50)

    peak_hours = _clamp(random.gauss(4.0 if disruption_type != 'none' else 5.0, 0.8), 2.0, 7.0)
    off_peak = _clamp(hours - peak_hours, 0.0, 8.0)

    expected_orders = max(1, int(random.gauss(18, 3)))
    order_acceptance_rate = _clamp(random.gauss(0.93, 0.05), 0.7, 1.0)
    order_completion_rate = _clamp(random.gauss(0.96, 0.03), 0.7, 1.0)

    earnings = _round(orders * earnings_per_order)
    earnings_per_hour = _round(earnings / max(hours, 1.0))
    efficiency_score = _round(orders / max(hours, 1.0))

    baseline_target = _compute_baseline_expected(orders, disruption_type)
    loss_amount = _round(max(0.0, baseline_target - earnings))
    earnings_variance = _round(earnings - baseline_target)

    risk = _risk_score({
        'rainfall': weather['rainfall'],
        'aqi_level': weather['aqi_level'],
        'traffic_score': weather['traffic_score'],
        'temperature': weather['temperature'],
        'loss_amount': loss_amount,
        'expected_baseline': max(baseline_target, 1.0),
    })

    return {
        'date': day,
        'user_id': user_id,
        'orders_completed': orders,
        'hours_worked': _round(hours),
        'earnings': earnings,
        'earnings_per_order': _round(earnings_per_order),
        'platform': random.choice(PLATFORMS),
        'disruption_type': disruption_type,
        'weather_condition': weather['weather_condition'],
        'temperature': weather['temperature'],
        'humidity': weather['humidity'],
        'rainfall': weather['rainfall'],
        'wind_speed': weather['wind_speed'],
        'aqi_level': weather['aqi_level'],
        'pm2_5': weather['pm2_5'],
        'pm10': weather['pm10'],
        'traffic_level': weather['traffic_level'],
        'traffic_score': weather['traffic_score'],
        'peak_hours_active': _round(peak_hours),
        'off_peak_hours': _round(off_peak),
        'expected_orders': expected_orders,
        'order_acceptance_rate': _round(order_acceptance_rate, 3),
        'order_completion_rate': _round(order_completion_rate, 3),
        'distance_travelled_km': _round(distance),
        'avg_delivery_time_mins': _round(avg_delivery_time),
        'earnings_per_hour': earnings_per_hour,
        'efficiency_score': efficiency_score,
        'loss_amount': loss_amount,
        'earnings_variance': earnings_variance,
        'risk_score': risk,
        'is_weekend': weekend,
        'is_holiday': holiday,
        'city': random.choice(['Chennai', 'Bengaluru', 'Pune', 'Mumbai', 'Hyderabad']),
    }


def generate_data(user_id: int, days: int = 30):
    if days < 1:
        raise ValueError('days must be >= 1')

    session: Session = SessionLocal()
    try:
        start_date = date.today() - timedelta(days=days - 1)

        generated = []
        for i in range(days):
            day = start_date + timedelta(days=i)
            record_data = _generate_day_record(user_id=user_id, day=day)

            existing = session.query(GigIncome).filter(GigIncome.user_id == user_id, GigIncome.date == day).one_or_none()
            if existing:
                for k, v in record_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
            else:
                existing = GigIncome(**record_data)
                session.add(existing)

            generated.append(record_data)

        session.commit()
        return generated

    finally:
        session.close()


def income_history(user_id: int):
    session: Session = SessionLocal()
    try:
        records = session.query(GigIncome).filter(GigIncome.user_id == user_id).order_by(GigIncome.date).all()
        return [
            {
                'date': rec.date.isoformat(),
                'orders_completed': rec.orders_completed,
                'hours_worked': rec.hours_worked,
                'earnings': rec.earnings,
                'earnings_per_order': rec.earnings_per_order,
                'platform': rec.platform,
                'disruption_type': rec.disruption_type,
                'weather_condition': rec.weather_condition,
                'temperature': rec.temperature,
                'humidity': rec.humidity,
                'rainfall': rec.rainfall,
                'wind_speed': rec.wind_speed,
                'aqi_level': rec.aqi_level,
                'pm2_5': rec.pm2_5,
                'pm10': rec.pm10,
                'traffic_level': rec.traffic_level,
                'traffic_score': rec.traffic_score,
                'peak_hours_active': rec.peak_hours_active,
                'off_peak_hours': rec.off_peak_hours,
                'expected_orders': rec.expected_orders,
                'order_acceptance_rate': rec.order_acceptance_rate,
                'order_completion_rate': rec.order_completion_rate,
                'distance_travelled_km': rec.distance_travelled_km,
                'avg_delivery_time_mins': rec.avg_delivery_time_mins,
                'earnings_per_hour': rec.earnings_per_hour,
                'efficiency_score': rec.efficiency_score,
                'loss_amount': rec.loss_amount,
                'earnings_variance': rec.earnings_variance,
                'risk_score': rec.risk_score,
                'is_weekend': rec.is_weekend,
                'is_holiday': rec.is_holiday,
                'city': rec.city,
            }
            for rec in records
        ]
    finally:
        session.close()


def baseline_income(user_id: int):
    session: Session = SessionLocal()
    try:
        top_days = (
            session.query(GigIncome)
            .filter(GigIncome.user_id == user_id, GigIncome.disruption_type == 'none')
            .order_by(GigIncome.earnings.desc())
            .limit(5)
            .all()
        )
        if not top_days:
            return {'baseline_daily_income': 0.0}

        avg = sum(rec.earnings for rec in top_days) / len(top_days)
        return {'baseline_daily_income': _round(avg)}
    finally:
        session.close()


def today_income(user_id: int):
    session: Session = SessionLocal()
    try:
        today = date.today()
        rec = (
            session.query(GigIncome)
            .filter(GigIncome.user_id == user_id, GigIncome.date == today)
            .order_by(GigIncome.created_at.desc())
            .first()
        )
        if not rec:
            return {
                'earnings': 0.0,
                'orders_completed': 0,
                'hours_worked': 0.0,
                'disruption_type': 'none',
                'platform': 'swiggy',
            }

        return {
            'earnings': rec.earnings,
            'orders_completed': rec.orders_completed,
            'hours_worked': rec.hours_worked,
            'disruption_type': rec.disruption_type,
            'platform': rec.platform,
        }
    finally:
        session.close()


def weekly_summary(user_id: int):
    session: Session = SessionLocal()
    try:
        recent_week = (
            session.query(GigIncome)
            .filter(GigIncome.user_id == user_id)
            .order_by(GigIncome.date.desc())
            .limit(7)
            .all()
        )

        if not recent_week:
            return {
                'avg_daily_earnings': 0.0,
                'total_orders': 0,
                'total_hours': 0.0,
                'total_loss_amount': 0.0,
                'avg_risk_score': 0.0,
                'best_day': None,
                'worst_day': None,
            }

        total_earnings = sum(r.earnings for r in recent_week)
        total_orders = sum(r.orders_completed for r in recent_week)
        total_hours = sum(r.hours_worked for r in recent_week)
        total_loss_amount = sum(r.loss_amount for r in recent_week)
        avg_risk = sum(r.risk_score for r in recent_week) / len(recent_week)

        best = max(recent_week, key=lambda r: r.earnings)
        worst = min(recent_week, key=lambda r: r.earnings)

        as_record = lambda rec: {
            'date': rec.date.isoformat(),
            'earnings': rec.earnings,
            'weather_condition': rec.weather_condition,
            'traffic_level': rec.traffic_level,
            'disruption_type': rec.disruption_type,
        }

        return {
            'avg_daily_earnings': _round(total_earnings / len(recent_week)),
            'total_orders': total_orders,
            'total_hours': _round(total_hours),
            'total_loss_amount': _round(total_loss_amount),
            'avg_risk_score': _round(avg_risk),
            'best_day': as_record(best),
            'worst_day': as_record(worst),
        }
    finally:
        session.close()
