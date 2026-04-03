from __future__ import annotations

import logging
from datetime import date, timedelta

from sqlalchemy.orm import Session

from models.adaptive_risk_weight import AdaptiveRiskWeight
from models.insurance import Claim
from models.gig_income import GigIncome

logger = logging.getLogger('gig_insurance_backend.adaptive_layer')

DEFAULT_WEIGHTS = {
    'rain_weight': 0.35,
    'traffic_weight': 0.25,
    'aqi_weight': 0.25,
    'wind_weight': 0.15,
}


def _round(value: float, places: int = 4) -> float:
    return float(round(float(value), places))


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def _normalize(values: dict[str, float]) -> dict[str, float]:
    total = sum(max(v, 0.001) for v in values.values())
    if total <= 0:
        return DEFAULT_WEIGHTS.copy()
    return {key: _round(max(value, 0.001) / total) for key, value in values.items()}


def get_weight_record(db: Session) -> AdaptiveRiskWeight:
    record = db.query(AdaptiveRiskWeight).order_by(AdaptiveRiskWeight.id.asc()).first()
    if record is None:
        record = AdaptiveRiskWeight(**DEFAULT_WEIGHTS, sample_count=0)
        db.add(record)
        db.commit()
        db.refresh(record)
    return record


def get_weights(db: Session) -> dict[str, float]:
    record = get_weight_record(db)
    return {
        'rain_weight': float(record.rain_weight),
        'traffic_weight': float(record.traffic_weight),
        'aqi_weight': float(record.aqi_weight),
        'wind_weight': float(record.wind_weight),
    }


def update_weights(db: Session, user_id: int | None = None, data: list[dict] | None = None) -> dict[str, float]:
    record = get_weight_record(db)
    values = DEFAULT_WEIGHTS.copy()

    cutoff_date = date.today() - timedelta(days=45)
    query = db.query(GigIncome).filter(GigIncome.date >= cutoff_date)
    if user_id is not None:
        query = query.filter(GigIncome.user_id == int(user_id))
    recent_income = query.order_by(GigIncome.date.desc()).limit(90).all()

    samples = []
    if data:
        for item in data:
            samples.append({
                'rainfall': float(item.get('rainfall', 0.0) or 0.0),
                'traffic_score': float(item.get('traffic_score', 1.0) or 1.0),
                'aqi_level': float(item.get('aqi_level', 1.0) or 1.0),
                'wind_speed': float(item.get('wind_speed', 0.0) or 0.0),
                'loss_ratio': float(item.get('loss_ratio', 0.0) or 0.0),
            })

    for row in recent_income:
        baseline = max(float(row.earnings) + max(float(row.loss_amount), 0.0), 1.0)
        samples.append({
            'rainfall': float(row.rainfall),
            'traffic_score': float(row.traffic_score),
            'aqi_level': float(row.aqi_level),
            'wind_speed': float(row.wind_speed),
            'loss_ratio': _clamp(float(row.loss_amount) / baseline),
        })

    if samples:
        weighted_loss_total = max(sum(sample['loss_ratio'] for sample in samples), 0.001)
        rain_signal = sum(_clamp(sample['rainfall'] / 12.0) * sample['loss_ratio'] for sample in samples) / weighted_loss_total
        traffic_signal = sum(_clamp((sample['traffic_score'] - 1.0) / 1.2) * sample['loss_ratio'] for sample in samples) / weighted_loss_total
        aqi_signal = sum(_clamp((sample['aqi_level'] - 1.0) / 4.0) * sample['loss_ratio'] for sample in samples) / weighted_loss_total
        wind_signal = sum(_clamp(sample['wind_speed'] / 25.0) * sample['loss_ratio'] for sample in samples) / weighted_loss_total

        values = _normalize({
            'rain_weight': (0.55 * DEFAULT_WEIGHTS['rain_weight']) + (0.45 * rain_signal),
            'traffic_weight': (0.55 * DEFAULT_WEIGHTS['traffic_weight']) + (0.45 * traffic_signal),
            'aqi_weight': (0.55 * DEFAULT_WEIGHTS['aqi_weight']) + (0.45 * aqi_signal),
            'wind_weight': (0.55 * DEFAULT_WEIGHTS['wind_weight']) + (0.45 * wind_signal),
        })

    claims_query = db.query(Claim)
    if user_id is not None:
        claims_query = claims_query.filter(Claim.user_id == int(user_id))
    recent_claims = claims_query.order_by(Claim.created_at.desc()).limit(25).all()
    approved_claim_pressure = 0.0
    if recent_claims:
        approved_count = sum(1 for claim in recent_claims if str(claim.status).upper() == 'APPROVED')
        review_count = sum(1 for claim in recent_claims if str(claim.status).upper() == 'NEEDS_REVIEW')
        approved_claim_pressure = (approved_count + (0.5 * review_count)) / len(recent_claims)

    if approved_claim_pressure > 0:
        values = _normalize({
            'rain_weight': values['rain_weight'] + (0.04 * approved_claim_pressure),
            'traffic_weight': values['traffic_weight'] + (0.03 * approved_claim_pressure),
            'aqi_weight': values['aqi_weight'] + (0.02 * approved_claim_pressure),
            'wind_weight': values['wind_weight'] + (0.01 * approved_claim_pressure),
        })

    record.rain_weight = values['rain_weight']
    record.traffic_weight = values['traffic_weight']
    record.aqi_weight = values['aqi_weight']
    record.wind_weight = values['wind_weight']
    record.sample_count = len(samples)
    db.commit()

    logger.info('adaptive weights updated: %s', values)
    return values
