from __future__ import annotations

from sqlalchemy.orm import Session

from models.gig_income import GigIncome


def evaluate_fraud_signals(
    environment_data: dict,
    user_id: int | None = None,
    db: Session | None = None,
    today_income: dict | None = None,
) -> dict:
    snapshot = environment_data.get('snapshot') or {}
    environment_city = environment_data.get('city') or environment_data.get('resolved_city')
    majority_city = None
    pattern_flag = False

    recent_records = []
    if db is not None and user_id is not None:
        recent_records = (
            db.query(GigIncome)
            .filter(GigIncome.user_id == int(user_id))
            .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
            .limit(20)
            .all()
        )
        if recent_records:
            counts: dict[str, int] = {}
            for record in recent_records:
                city = (record.city or '').strip()
                if city:
                    counts[city] = counts.get(city, 0) + 1
            if counts:
                majority_city = max(counts.items(), key=lambda item: item[1])[0]

    location_match = True
    if majority_city and environment_city:
        location_match = str(majority_city).lower() == str(environment_city).lower()

    disruption_type = str((today_income or {}).get('disruption_type', 'none') or 'none').lower()
    environment_match = True
    if disruption_type == 'rain':
        environment_match = float(snapshot.get('rain_estimate', 0.0)) >= 1.0
    elif disruption_type == 'traffic':
        environment_match = float(snapshot.get('traffic_index', 1.0)) >= 1.2
    elif disruption_type == 'heatwave':
        environment_match = float(snapshot.get('temperature', 30.0)) >= 36.0

    if recent_records and today_income:
        recent_losses = [float(record.loss_amount or 0.0) for record in recent_records[:10]]
        average_recent_loss = sum(recent_losses) / max(len(recent_losses), 1)
        today_earnings = float(today_income.get('earnings', 0.0) or 0.0)
        low_environment_disruption = (
            float(snapshot.get('rain_estimate', 0.0)) < 1.0
            and float(snapshot.get('traffic_index', 1.0)) < 1.15
            and float(snapshot.get('aqi', 50.0)) < 120.0
        )
        pattern_flag = low_environment_disruption and average_recent_loss > 0 and today_earnings < (average_recent_loss * 0.5)

    return {
        'location_match': location_match,
        'environment_match': environment_match,
        'pattern_flag': pattern_flag,
    }
