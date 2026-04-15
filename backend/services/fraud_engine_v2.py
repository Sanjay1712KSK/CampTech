from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from models.models import ClaimHistory
from models.user_model import User


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float, places: int = 3) -> float:
    return float(round(float(value), places))


def _clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    return radius * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)))


def _distance_from_user(user: User, lat: float, lon: float) -> float | None:
    if user.last_known_lat is None or user.last_known_lon is None:
        return None
    return _haversine_km(float(user.last_known_lat), float(user.last_known_lon), float(lat), float(lon))


def _city_label(environment_data: dict, fallback: str = 'Unknown') -> str:
    return str(
        (environment_data or {}).get('city')
        or (environment_data or {}).get('resolved_city')
        or ((environment_data or {}).get('simulation_meta') or {}).get('city')
        or fallback
    )


def get_device_status(user: User) -> dict:
    return {
        'current_device_id': user.current_device_id,
        'device_switch_count': int(user.device_switch_count or 0),
        'single_device_enforced': True,
        'session_version': int(user.session_version or 1),
        'status': 'LOCKED' if user.current_device_id else 'UNREGISTERED',
    }


def build_location_status(user: User, *, lat: float | None = None, lon: float | None = None, city: str | None = None) -> dict:
    transition_distance_km = None
    unrealistic_jump = False
    if lat is not None and lon is not None and user.last_known_lat is not None and user.last_known_lon is not None:
        transition_distance_km = _round(
            _haversine_km(float(user.last_known_lat), float(user.last_known_lon), float(lat), float(lon)),
            2,
        )
        if user.last_location_at is not None:
            minutes_since_last = max((_utcnow() - user.last_location_at).total_seconds() / 60.0, 1.0)
            unrealistic_jump = transition_distance_km > 200 and minutes_since_last < 180

    return {
        'last_known_location': (
            {'lat': float(user.last_known_lat), 'lon': float(user.last_known_lon)}
            if user.last_known_lat is not None and user.last_known_lon is not None
            else None
        ),
        'active_city': city or user.active_city,
        'last_location_at': user.last_location_at.isoformat() if user.last_location_at else None,
        'transition_distance_km': transition_distance_km,
        'unrealistic_jump': unrealistic_jump,
    }


def update_user_location_state(user: User, *, lat: float, lon: float, city: str | None = None) -> dict:
    status = build_location_status(user, lat=lat, lon=lon, city=city)
    if city:
        user.active_city = city
    if not status['unrealistic_jump']:
        user.last_known_lat = float(lat)
        user.last_known_lon = float(lon)
        user.last_location_at = _utcnow()
        if city:
            user.active_city = city
    return build_location_status(user, lat=lat, lon=lon, city=city)


def evaluate_claim_fraud(
    *,
    db: Session,
    user: User,
    lat: float,
    lon: float,
    environment_data: dict,
    risk_data: dict,
    premium_data: dict,
    gig_data: dict,
    predicted_loss: float,
    actual_loss: float,
    current_device_id: str | None = None,
) -> dict:
    fraud_types: list[str] = []
    explanation_parts: list[str] = []
    signal_weights: list[float] = []

    snapshot = (environment_data or {}).get('snapshot') or {}
    weather = (environment_data or {}).get('weather') or {}
    traffic = (environment_data or {}).get('traffic') or {}
    risk_factors = (risk_data or {}).get('risk_factors') or {}
    active_triggers = [str(item) for item in ((risk_data or {}).get('active_triggers') or [])]
    behavior_snapshot = ((risk_data or {}).get('user_behavior') or {})

    distance_from_last = _distance_from_user(user, lat, lon)
    if distance_from_last is not None and distance_from_last > 200:
        if user.last_location_at and (_utcnow() - user.last_location_at) < timedelta(hours=3):
            fraud_types.append('GEO_TRANSITION_DETECTED')
            explanation_parts.append('Location changed unrealistically quickly between sessions.')
            signal_weights.append(0.18)

    if distance_from_last is not None and distance_from_last > 25:
        fraud_types.append('GPS_SPOOFING')
        explanation_parts.append('Claim location is materially different from the recent trusted location.')
        signal_weights.append(0.12)

    if active_triggers:
        weather_support = float(snapshot.get('rain_estimate', weather.get('rainfall', 0.0)) or 0.0)
        traffic_support = float(traffic.get('traffic_score', snapshot.get('traffic_index', 1.0)) or 1.0)
        aqi_support = float(snapshot.get('aqi', 0.0) or 0.0)
        mismatch = False
        if 'RAIN_TRIGGER' in active_triggers and weather_support < 2.0:
            mismatch = True
        if 'TRAFFIC_TRIGGER' in active_triggers and traffic_support < 1.15:
            mismatch = True
        if 'AQI_TRIGGER' in active_triggers and aqi_support < 90:
            mismatch = True
        if mismatch:
            fraud_types.append('WEATHER_MISMATCH')
            explanation_parts.append('Claim triggers are not strongly supported by the environment snapshot.')
            signal_weights.append(0.12)

    baseline = max(float(premium_data.get('weekly_income', 0.0) or 0.0) / 7.0, 1.0)
    behavioral_gap = abs(float(actual_loss) - float(predicted_loss)) / baseline
    if behavioral_gap > 0.45:
        fraud_types.append('BEHAVIORAL_ANOMALY')
        explanation_parts.append('Actual loss differs sharply from the model-predicted loss.')
        signal_weights.append(0.15)

    avg_loss = float(behavior_snapshot.get('avg_loss', 0.0) or 0.0)
    avg_hours = float(behavior_snapshot.get('avg_hours', 0.0) or 0.0)
    current_hours = float(gig_data.get('hours_worked', 0.0) or 0.0)
    user_behavior_deviation = 0.0
    if avg_loss > 0:
        user_behavior_deviation += abs(float(actual_loss) - avg_loss) / baseline
    if avg_hours > 0:
        user_behavior_deviation += abs(current_hours - avg_hours) / max(avg_hours, 1.0)
    if user_behavior_deviation > 0.6:
        fraud_types.append('USER_BEHAVIOR_DEVIATION')
        explanation_parts.append('Current claim behavior deviates from the user historical profile.')
        signal_weights.append(0.1)

    earnings = float(gig_data.get('earnings', 0.0) or 0.0)
    orders_completed = int(gig_data.get('orders_completed', 0) or 0)
    efficiency_score = float(gig_data.get('efficiency_score', 0.0) or 0.0)
    if current_hours > 0 and (
        efficiency_score > 4.0
        or orders_completed / current_hours > 5.5
        or (earnings <= 0 and actual_loss > 0 and orders_completed > 0)
    ):
        fraud_types.append('EFFICIENCY_MANIPULATION')
        explanation_parts.append('Operational efficiency metrics are inconsistent with the claimed outcome.')
        signal_weights.append(0.08)

    recent_claims = (
        db.query(ClaimHistory)
        .filter(ClaimHistory.user_id == int(user.id))
        .order_by(ClaimHistory.claim_date.desc(), ClaimHistory.id.desc())
        .limit(10)
        .all()
    )
    recent_count = sum(1 for item in recent_claims if item.claim_date >= (_utcnow().date() - timedelta(days=30)))
    if recent_count >= 3:
        fraud_types.append('FREQUENCY_ABUSE')
        explanation_parts.append('Claim frequency is elevated relative to the recent history window.')
        signal_weights.append(0.08)

    duplicate = any(
        abs(float(item.claimed_loss or 0.0) - float(actual_loss)) < 1.0
        and item.claim_date >= (_utcnow().date() - timedelta(days=7))
        for item in recent_claims
    )
    if duplicate:
        fraud_types.append('DUPLICATE_CLAIM')
        explanation_parts.append('A very similar claim appears in the recent claim history.')
        signal_weights.append(0.18)

    city = _city_label(environment_data, fallback=user.active_city or 'Unknown')
    peer_claim_count = (
        db.query(ClaimHistory)
        .filter(
            ClaimHistory.user_id != int(user.id),
            ClaimHistory.claim_date >= (_utcnow().date() - timedelta(days=1)),
            ClaimHistory.reasons.isnot(None),
        )
        .count()
    )
    if peer_claim_count >= 5 and city and str(city).lower() == str(user.active_city or city).lower():
        fraud_types.append('COLLUSION_DETECTION')
        explanation_parts.append('Multiple nearby claims are clustering unusually around the same time window.')
        signal_weights.append(0.06)

    if current_device_id and user.current_device_id and current_device_id != user.current_device_id:
        fraud_types.append('DEVICE_INTEGRITY')
        explanation_parts.append('Claim is coming from a device that differs from the active trusted device.')
        signal_weights.append(0.15)

    if distance_from_last is not None and distance_from_last > 200:
        fraud_types.append('GEO_TRANSITION_DETECTED')
        explanation_parts.append('Geo transition check flagged an improbable long-distance jump.')
        signal_weights.append(0.12)

    fraud_score = _clamp(sum(signal_weights))
    if fraud_score >= 0.7:
        decision = 'REJECTED'
    elif fraud_score >= 0.35:
        decision = 'FLAGGED'
    else:
        decision = 'APPROVED'

    if fraud_score >= 0.7:
        confidence = 'HIGH'
    elif fraud_score >= 0.35:
        confidence = 'MEDIUM'
    else:
        confidence = 'LOW'

    if not explanation_parts:
        explanation_parts.append('Fraud checks align with the expected disruption and user behavior pattern.')

    return {
        'fraud_score': _round(fraud_score),
        'fraud_types': sorted(set(fraud_types)),
        'decision': decision,
        'confidence': confidence,
        'explanation': ' '.join(explanation_parts),
        'signals': {
            'distance_from_last_km': _round(distance_from_last, 2) if distance_from_last is not None else None,
            'behavioral_gap': _round(behavioral_gap),
            'recent_claim_count_30d': recent_count,
            'peer_claim_count_24h': peer_claim_count,
            'weather_risk': _round(
                max(
                    float(risk_factors.get('rain_risk', 0.0) or 0.0),
                    float(risk_factors.get('aqi_risk', 0.0) or 0.0),
                    float(risk_factors.get('traffic_risk', 0.0) or 0.0),
                )
            ),
        },
    }
