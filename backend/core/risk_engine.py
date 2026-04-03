from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from core.adaptive_layer import get_weights, update_weights
from core.disruption_model import calculate_delivery_efficiency, calculate_disruption
from models.gig_income import GigIncome

logger = logging.getLogger('gig_insurance_backend.core_risk_engine')

CITY_COORDINATES = {
    'chennai': (13.0827, 80.2707),
    'bengaluru': (12.9716, 77.5946),
    'mumbai': (19.0760, 72.8777),
    'pune': (18.5204, 73.8567),
    'hyderabad': (17.3850, 78.4867),
}


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def resolve_city_from_coordinates(lat: float, lon: float) -> str:
    closest_city = 'Chennai'
    closest_distance = float('inf')
    for city, (city_lat, city_lon) in CITY_COORDINATES.items():
        distance = ((lat - city_lat) ** 2) + ((lon - city_lon) ** 2)
        if distance < closest_distance:
            closest_distance = distance
            closest_city = city.title()
    return closest_city


def _aqi_factor(snapshot: dict) -> float:
    return _clamp((float(snapshot.get('aqi', 50.0)) - 50.0) / 250.0)


def _rain_factor(snapshot: dict) -> float:
    return _clamp(float(snapshot.get('rain_estimate', 0.0)) / 12.0)


def _traffic_factor(snapshot: dict) -> float:
    return _clamp((float(snapshot.get('traffic_index', 1.0)) - 1.0) / 1.2)


def _wind_factor(snapshot: dict) -> float:
    return _clamp(float(snapshot.get('wind_speed', 0.0)) / 25.0)


def _heat_factor(snapshot: dict) -> float:
    return _clamp((float(snapshot.get('temperature', 30.0)) - 32.0) / 12.0)


def _risk_level(score: float) -> str:
    if score < 0.35:
        return 'LOW'
    if score < 0.65:
        return 'MEDIUM'
    return 'HIGH'


def _trigger_payload(snapshot: dict) -> dict:
    active = []
    rain = float(snapshot.get('rain_estimate', 0.0))
    traffic_index = float(snapshot.get('traffic_index', 1.0))
    aqi = float(snapshot.get('aqi', 50.0))
    temperature = float(snapshot.get('temperature', 30.0))

    if rain >= 3.0:
        active.append('RAIN_TRIGGER')
    if traffic_index >= 1.35:
        active.append('TRAFFIC_TRIGGER')
    if aqi >= 150.0:
        active.append('AQI_TRIGGER')
    if temperature >= 37.0:
        active.append('HEAT_TRIGGER')
    if len(active) >= 2:
        active.append('COMBINED_TRIGGER')

    severity = 'LOW'
    if 'COMBINED_TRIGGER' in active or len(active) >= 3:
        severity = 'HIGH'
    elif active:
        severity = 'MEDIUM'

    return {
        'active_triggers': active,
        'severity': severity,
    }


def _fraud_signals(environment_data: dict, user_id: int | None = None, db: Session | None = None, today_income: dict | None = None) -> dict:
    snapshot = environment_data.get('snapshot') or {}
    environment_city = environment_data.get('city') or environment_data.get('resolved_city')
    majority_city = None
    if db is not None and user_id is not None:
        records = (
            db.query(GigIncome)
            .filter(GigIncome.user_id == int(user_id))
            .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
            .limit(20)
            .all()
        )
        if records:
            counts: dict[str, int] = {}
            for record in records:
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

    return {
        'location_match': location_match,
        'environment_match': environment_match,
    }


def calculate_risk(environment_data: dict, user_id: int | None = None, db: Session | None = None, today_income: dict | None = None) -> dict:
    snapshot = (environment_data or {}).get('snapshot') or {}
    hyper_local = (environment_data or {}).get('hyper_local_analysis') or {}
    predictive = (environment_data or {}).get('predictive_risk') or {}
    time_slot_risk = (environment_data or {}).get('time_slot_risk') or {}

    weights = get_weights(db) if db is not None else {
        'rain_weight': 0.35,
        'traffic_weight': 0.25,
        'aqi_weight': 0.25,
        'wind_weight': 0.15,
    }
    if db is not None:
        weights = update_weights(db, user_id=user_id)

    disruption = calculate_disruption(snapshot)
    delivery_efficiency = calculate_delivery_efficiency(snapshot, disruption)
    expected_income_loss_ratio = _clamp(1.0 - float(delivery_efficiency['score']))

    rain_factor = _rain_factor(snapshot)
    traffic_factor = _traffic_factor(snapshot)
    aqi_factor = _aqi_factor(snapshot)
    wind_factor = max(_wind_factor(snapshot), _heat_factor(snapshot))

    weighted_score = (
        (weights['rain_weight'] * rain_factor)
        + (weights['traffic_weight'] * traffic_factor)
        + (weights['aqi_weight'] * aqi_factor)
        + (weights['wind_weight'] * wind_factor)
    )
    risk_score = _clamp((0.65 * weighted_score) + (0.35 * expected_income_loss_ratio))
    hyper_local_risk = float(hyper_local.get('hyper_local_risk', 1.0) or 1.0)
    risk_score = _clamp(risk_score * min(max(hyper_local_risk, 0.8), 1.5))

    trigger_payload = _trigger_payload(snapshot)
    fraud_signals = _fraud_signals(environment_data, user_id=user_id, db=db, today_income=today_income)
    risk_level = _risk_level(risk_score)

    reasons = []
    if rain_factor >= 0.3:
        reasons.append('Rain is reducing delivery capacity')
    if traffic_factor >= 0.3:
        reasons.append('Traffic congestion is increasing route time')
    if aqi_factor >= 0.3:
        reasons.append('AQI conditions may reduce working willingness')
    if _heat_factor(snapshot) >= 0.2:
        reasons.append('Heat is reducing sustainable working hours')
    hyper_insight = hyper_local.get('insight')
    if hyper_insight:
        reasons.append(hyper_insight)
    if predictive.get('trend') == 'increasing':
        reasons.append('Conditions are expected to worsen over the next 6 hours')

    result = {
        'risk_score': _round(risk_score),
        'risk_level': risk_level,
        'expected_income_loss': f'{int(round(expected_income_loss_ratio * 100))}%',
        'delivery_efficiency': delivery_efficiency,
        'hyper_local_risk': _round(hyper_local_risk),
        'hyper_local_analysis': hyper_local,
        'time_slot_risk': time_slot_risk,
        'predictive_risk': predictive,
        'active_triggers': trigger_payload['active_triggers'],
        'trigger_severity': trigger_payload['severity'],
        'fraud_signals': fraud_signals,
        'reasons': reasons,
        'risk_factors': {
            'rain_risk': _round(rain_factor),
            'traffic_risk': _round(traffic_factor),
            'aqi_risk': _round(aqi_factor),
            'wind_risk': _round(wind_factor),
        },
        'adaptive_weights': {key: _round(value, 4) for key, value in weights.items()},
        'recommendation': 'Avoid delivery if possible' if risk_level == 'HIGH' else ('Be cautious' if risk_level == 'MEDIUM' else 'Safe to deliver'),
    }

    logger.info('final risk result: %s', result)
    return result
