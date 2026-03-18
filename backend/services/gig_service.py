import logging
import random
from datetime import date, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from database.db import SessionLocal
from models.gig_income import GigIncome

logger = logging.getLogger('gig_insurance_backend.gig')

PLATFORMS = ['swiggy', 'zomato']
DISRUPTION_TYPES = ['none', 'rain', 'traffic', 'low_demand', 'bandh']


def _clamp(x, minimum, maximum):
    return max(minimum, min(maximum, x))


def _make_normal(mean, std, minimum, maximum):
    return _clamp(round(random.gauss(mean, std), 2), minimum, maximum)


def _generate_day_stats(day: date):
    on_weekend = day.weekday() >= 5
    is_disruption = random.random() < 0.27

    disruption = 'none'

    if is_disruption:
        disruption = random.choice(['rain', 'traffic', 'low_demand', 'bandh'])

    if disruption == 'rain':
        orders = random.randint(5, 12)
        earnings_per_order = _make_normal(40, 8, 30, 55)
        hours = _make_normal(5.5, 1.0, 4.0, 8.0)

    elif disruption == 'traffic':
        orders = _make_normal(12, 2.5, 8, 18)
        earnings_per_order = _make_normal(45, 9, 30, 60)
        hours = _make_normal(8.2, 0.9, 5.0, 11.0)
        orders = int(orders)

    elif disruption == 'low_demand':
        orders = random.randint(4, 10)
        earnings_per_order = _make_normal(35, 7, 30, 55)
        hours = _make_normal(5.5, 1.2, 4.0, 7.5)

    elif disruption == 'bandh':
        orders = random.randint(0, 3)
        hours = _make_normal(1.5, 0.7, 0.0, 3.0)
        if orders == 0:
            earnings_per_order = 0.0
        else:
            earnings_per_order = _make_normal(30, 12, 10, 40)

    else:
        orders = random.randint(12, 22)
        earnings_per_order = _make_normal(50, 10, 30, 70)
        hours = _make_normal(6.8, 1.0, 4.0, 10.0)

    if on_weekend and disruption == 'none':
        boost_pct = random.uniform(0.20, 0.40)
        orders = int(orders * (1 + boost_pct))

    if disruption == 'rain':
        hours = _make_normal(hours, 1.0, 4.0, 9.0)

    earnings = round(orders * earnings_per_order, 2)

    return {
        'orders_completed': int(orders),
        'hours_worked': float(round(hours, 2)),
        'earnings_per_order': float(round(earnings_per_order if earnings_per_order is not None else 0.0, 2)),
        'earnings': float(round(earnings, 2)),
        'disruption_type': disruption,
    }


def generate_data(user_id: int, days: int = 30):
    if days < 1:
        raise ValueError('days must be >= 1')

    session: Session = SessionLocal()
    try:
        start_date = date.today() - timedelta(days=days - 1)

        generated = []

        for i in range(days):
            d = start_date + timedelta(days=i)
            stats = _generate_day_stats(d)
            platform = random.choice(PLATFORMS)

            existing = session.query(GigIncome).filter(GigIncome.user_id == user_id, GigIncome.date == d).one_or_none()
            if existing:
                existing.orders_completed = stats['orders_completed']
                existing.hours_worked = stats['hours_worked']
                existing.earnings = stats['earnings']
                existing.earnings_per_order = stats['earnings_per_order']
                existing.platform = platform
                existing.disruption_type = stats['disruption_type']
            else:
                existing = GigIncome(
                    user_id=user_id,
                    date=d,
                    orders_completed=stats['orders_completed'],
                    hours_worked=stats['hours_worked'],
                    earnings=stats['earnings'],
                    earnings_per_order=stats['earnings_per_order'],
                    platform=platform,
                    disruption_type=stats['disruption_type'],
                )
                session.add(existing)

            generated.append({
                'date': d.isoformat(),
                'orders_completed': existing.orders_completed,
                'hours_worked': existing.hours_worked,
                'earnings': existing.earnings,
                'earnings_per_order': existing.earnings_per_order,
                'platform': existing.platform,
                'disruption_type': existing.disruption_type,
            })

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

        average = float(round(sum(d.earnings for d in top_days) / len(top_days), 2))
        return {'baseline_daily_income': average}

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