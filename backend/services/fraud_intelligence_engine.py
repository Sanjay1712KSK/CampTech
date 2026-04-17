from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from models.models import ClaimHistory, UserBehavior
from models.user_model import User

LOCATION_EVENT_TYPE = 'location_update'
LOGIN_EVENT_TYPE = 'login_session'
DEFAULT_LOCATION_RATE_LIMIT_SECONDS = 60


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float | None, places: int = 3) -> float:
    return float(round(float(value or 0.0), places))


def _clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, float(value)))


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371.0
    d_lat = math.radians(float(lat2) - float(lat1))
    d_lon = math.radians(float(lon2) - float(lon1))
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(float(lat1)))
        * math.cos(math.radians(float(lat2)))
        * math.sin(d_lon / 2) ** 2
    )
    return radius * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)))


def _city_label(environment_data: dict, fallback: str = 'Unknown') -> str:
    return str(
        (environment_data or {}).get('city')
        or (environment_data or {}).get('resolved_city')
        or ((environment_data or {}).get('simulation_meta') or {}).get('city')
        or fallback
    )


def _parse_iso_datetime(raw_value: str | None) -> datetime | None:
    if not raw_value:
        return None
    try:
        return datetime.fromisoformat(str(raw_value).replace('Z', '+00:00')).replace(tzinfo=None)
    except ValueError:
        return None


def _extract_point(raw_point: dict) -> dict | None:
    if not isinstance(raw_point, dict):
        return None
    lat = raw_point.get('lat')
    lon = raw_point.get('lon')
    if lat is None or lon is None:
        return None
    return {
        'lat': float(lat),
        'lon': float(lon),
        'timestamp': _parse_iso_datetime(raw_point.get('timestamp')),
        'city': raw_point.get('city'),
        'source': raw_point.get('source') or 'client',
    }


def _location_logs_from_history(db: Session, user_id: int, limit: int = 10) -> list[dict]:
    events = (
        db.query(UserBehavior)
        .filter(
            UserBehavior.user_id == int(user_id),
            UserBehavior.event_type == LOCATION_EVENT_TYPE,
        )
        .order_by(UserBehavior.observed_at.desc(), UserBehavior.id.desc())
        .limit(max(limit, 1))
        .all()
    )
    points: list[dict] = []
    for event in reversed(events):
        meta = dict(event.behavior_metadata or {})
        point = _extract_point(
            {
                'lat': meta.get('lat'),
                'lon': meta.get('lon'),
                'timestamp': meta.get('timestamp') or (event.observed_at.isoformat() if event.observed_at else None),
                'city': meta.get('city'),
                'source': meta.get('source') or 'history',
            }
        )
        if point:
            points.append(point)
    return points


def _login_history_from_events(db: Session, user_id: int, limit: int = 10) -> list[dict]:
    events = (
        db.query(UserBehavior)
        .filter(
            UserBehavior.user_id == int(user_id),
            UserBehavior.event_type == LOGIN_EVENT_TYPE,
        )
        .order_by(UserBehavior.observed_at.desc(), UserBehavior.id.desc())
        .limit(max(limit, 1))
        .all()
    )
    items: list[dict] = []
    for event in reversed(events):
        meta = dict(event.behavior_metadata or {})
        items.append(
            {
                'device_id': meta.get('device_id'),
                'timestamp': meta.get('timestamp') or (event.observed_at.isoformat() if event.observed_at else None),
                'lat': meta.get('lat'),
                'lon': meta.get('lon'),
                'city': meta.get('city'),
                'device_metadata': meta.get('device_metadata') or {},
            }
        )
    return items


def record_login_event(
    db: Session,
    *,
    user: User,
    device_id: str | None,
    device_metadata: dict | None = None,
    lat: float | None = None,
    lon: float | None = None,
    city: str | None = None,
) -> None:
    event = UserBehavior(
        user_id=int(user.id),
        event_type=LOGIN_EVENT_TYPE,
        event_value=(device_id or '').strip() or None,
        confidence_score=1.0,
        behavior_metadata={
            'device_id': (device_id or '').strip() or None,
            'device_metadata': device_metadata or {},
            'lat': None if lat is None else float(lat),
            'lon': None if lon is None else float(lon),
            'city': city or user.active_city,
            'timestamp': _utcnow().isoformat(),
            'session_version': int(user.session_version or 1),
        },
    )
    db.add(event)
    db.flush()


def get_device_status(user: User, db: Session | None = None) -> dict:
    recent_devices: list[str] = []
    if db is not None:
        login_history = _login_history_from_events(db, user.id, limit=10)
        cutoff = _utcnow() - timedelta(hours=72)
        recent_devices = sorted(
            {
                str(item.get('device_id')).strip()
                for item in login_history
                if item.get('device_id') and (_parse_iso_datetime(item.get('timestamp')) or cutoff) >= cutoff
            }
        )
    return {
        'current_device_id': user.current_device_id,
        'device_switch_count': int(user.device_switch_count or 0),
        'single_device_enforced': True,
        'session_version': int(user.session_version or 1),
        'recent_devices': recent_devices,
        'status': 'LOCKED' if user.current_device_id else 'UNREGISTERED',
    }


def build_location_status(
    user: User,
    *,
    lat: float | None = None,
    lon: float | None = None,
    city: str | None = None,
) -> dict:
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
        'last_login_location': (
            {'lat': float(user.last_login_lat), 'lon': float(user.last_login_lon)}
            if user.last_login_lat is not None and user.last_login_lon is not None
            else None
        ),
        'active_city': city or user.active_city,
        'last_location_at': user.last_location_at.isoformat() if user.last_location_at else None,
        'last_login_at': user.last_login_at.isoformat() if user.last_login_at else None,
        'location_enabled': bool(user.location_enabled),
        'transition_distance_km': transition_distance_km,
        'unrealistic_jump': unrealistic_jump,
        'location_permission_required': True,
    }


def update_user_location_state(
    user: User,
    *,
    lat: float,
    lon: float,
    city: str | None = None,
    db: Session | None = None,
) -> dict:
    status = build_location_status(user, lat=lat, lon=lon, city=city)
    now = _utcnow()
    rate_limited = bool(user.last_location_at and (now - user.last_location_at).total_seconds() < DEFAULT_LOCATION_RATE_LIMIT_SECONDS)
    if city:
        user.active_city = city
    if not status['unrealistic_jump'] and not rate_limited:
        user.last_known_lat = float(lat)
        user.last_known_lon = float(lon)
        user.last_location_at = now
        if city:
            user.active_city = city
    if db is not None and not rate_limited:
        event = UserBehavior(
            user_id=int(user.id),
            event_type=LOCATION_EVENT_TYPE,
            event_value=city or user.active_city,
            confidence_score=1.0,
            behavior_metadata={
                'lat': float(lat),
                'lon': float(lon),
                'city': city or user.active_city,
                'timestamp': now.isoformat(),
                'source': 'platform',
            },
        )
        db.add(event)
        db.flush()
    updated = build_location_status(user, lat=lat, lon=lon, city=city)
    updated['rate_limited'] = rate_limited
    return updated


def record_continuous_location_update(
    db: Session,
    *,
    user: User,
    lat: float,
    lon: float,
    timestamp: datetime,
    city: str | None = None,
    device_id: str | None = None,
    location_enabled: bool = True,
) -> dict:
    user.location_enabled = bool(location_enabled)
    if device_id and user.current_device_id and str(device_id).strip() != str(user.current_device_id).strip():
        raise ValueError('Location update device does not match the active device')

    if timestamp.tzinfo is not None:
        timestamp = timestamp.astimezone(UTC).replace(tzinfo=None)

    now = _utcnow()
    if timestamp > now + timedelta(minutes=5):
        raise ValueError('Location timestamp is invalid')

    previous_lat = user.last_known_lat
    previous_lon = user.last_known_lon
    previous_at = user.last_location_at
    movement_km = None
    speed_kmh = None
    signals: list[str] = []

    if previous_lat is not None and previous_lon is not None:
        movement_km = _haversine_km(float(previous_lat), float(previous_lon), float(lat), float(lon))
        if previous_at is not None:
            delta_hours = max((timestamp - previous_at).total_seconds() / 3600.0, 0.001)
            speed_kmh = movement_km / delta_hours
            if movement_km > 20 and delta_hours < (5 / 60):
                signals.append('teleport_jump_detected')
            if speed_kmh > 140:
                signals.append('unrealistic_speed_detected')

    event = UserBehavior(
        user_id=int(user.id),
        event_type=LOCATION_EVENT_TYPE,
        event_value=city or user.active_city,
        confidence_score=1.0 if not signals else 0.45,
        behavior_metadata={
            'lat': float(lat),
            'lon': float(lon),
            'city': city or user.active_city,
            'timestamp': timestamp.isoformat(),
            'device_id': (device_id or '').strip() or None,
            'source': 'continuous_tracking',
            'signals': signals,
            'movement_km': _round(movement_km, 3) if movement_km is not None else None,
            'speed_kmh': _round(speed_kmh, 3) if speed_kmh is not None else None,
        },
        observed_at=timestamp,
    )
    db.add(event)
    db.flush()

    update_status = update_user_location_state(user, lat=lat, lon=lon, city=city, db=None)
    user.last_known_lat = float(lat)
    user.last_known_lon = float(lon)
    user.last_location_at = timestamp
    if city:
        user.active_city = city
    user.location_enabled = bool(location_enabled)

    status = build_location_status(user, lat=lat, lon=lon, city=city)
    status.update(
        {
            'movement_km': _round(movement_km, 3) if movement_km is not None else None,
            'speed_kmh': _round(speed_kmh, 3) if speed_kmh is not None else None,
            'signals': signals,
            'gps_status': 'SUSPICIOUS' if signals else 'VALID',
            'rate_limited': update_status.get('rate_limited', False),
        }
    )
    return status


def evaluate_login_location_anomaly(
    user: User,
    *,
    lat: float | None,
    lon: float | None,
    login_at: datetime | None = None,
) -> dict:
    if lat is None or lon is None or user.last_login_lat is None or user.last_login_lon is None or user.last_login_at is None:
        return {
            'session_anomaly': False,
            'distance_km': None,
            'speed_kmh': None,
            'signals': [],
            'explanation': 'No prior login-location baseline is available for anomaly comparison.',
        }

    login_at = login_at or _utcnow()
    if login_at.tzinfo is not None:
        login_at = login_at.astimezone(UTC).replace(tzinfo=None)

    distance_km = _haversine_km(float(user.last_login_lat), float(user.last_login_lon), float(lat), float(lon))
    delta_hours = max((login_at - user.last_login_at).total_seconds() / 3600.0, 0.001)
    speed_kmh = distance_km / delta_hours
    signals: list[str] = []

    if distance_km > 200 and delta_hours < 3:
        signals.append('impossible_travel')
    if speed_kmh > 900:
        signals.append('session_anomaly')

    return {
        'session_anomaly': bool(signals),
        'distance_km': _round(distance_km, 2),
        'speed_kmh': _round(speed_kmh, 2),
        'signals': signals,
        'explanation': (
            'Recent login locations imply impossible travel.'
            if signals
            else 'Recent login location is consistent with prior session movement.'
        ),
    }


def _build_gps_integrity(location_logs: list[dict], *, active_city: str | None = None) -> dict:
    points = [point for point in location_logs if point.get('lat') is not None and point.get('lon') is not None]
    signals: list[str] = []
    if len(points) < 2:
        return {
            'gps_integrity_score': 0.0,
            'status': 'VALID',
            'signals': [],
            'details': {'movement_samples': len(points)},
        }

    teleport_jumps = 0
    speed_spikes = 0
    acceleration_spikes = 0
    erratic_segments = 0
    city_jumps = 0
    prior_speed = None
    total_distance = 0.0

    for previous, current in zip(points, points[1:]):
        distance_km = _haversine_km(previous['lat'], previous['lon'], current['lat'], current['lon'])
        total_distance += distance_km
        delta_seconds = None
        if previous.get('timestamp') and current.get('timestamp'):
            delta_seconds = max((current['timestamp'] - previous['timestamp']).total_seconds(), 1.0)
        if delta_seconds is None:
            continue
        speed_kmh = distance_km / (delta_seconds / 3600.0)
        if distance_km > 20 and delta_seconds < 300:
            teleport_jumps += 1
        if speed_kmh > 140:
            speed_spikes += 1
        if prior_speed is not None:
            acceleration = abs(speed_kmh - prior_speed) / max(delta_seconds, 1.0)
            if acceleration > 0.03:
                acceleration_spikes += 1
        if distance_km > 10 and speed_kmh < 5:
            erratic_segments += 1
        if previous.get('city') and current.get('city') and previous.get('city') != current.get('city') and distance_km > 50:
            city_jumps += 1
        prior_speed = speed_kmh

    if teleport_jumps:
        signals.append('teleport_jump_detected')
    if speed_spikes:
        signals.append('speed_spike_detected')
    if acceleration_spikes:
        signals.append('acceleration_spike_detected')
    if erratic_segments:
        signals.append('route_inconsistency_detected')
    if city_jumps:
        signals.append('city_jump_detected')
    if active_city and points[-1].get('city') and str(active_city).lower() != str(points[-1]['city']).lower():
        signals.append('active_city_mismatch')

    score = _clamp(
        (teleport_jumps * 0.28)
        + (speed_spikes * 0.18)
        + (acceleration_spikes * 0.14)
        + (erratic_segments * 0.1)
        + (city_jumps * 0.16)
        + (0.08 if active_city and points[-1].get('city') and str(active_city).lower() != str(points[-1]['city']).lower() else 0.0)
    )
    if score > 0.7:
        status = 'FRAUD'
    elif score >= 0.35:
        status = 'SUSPICIOUS'
    else:
        status = 'VALID'

    return {
        'gps_integrity_score': _round(score),
        'status': status,
        'signals': signals,
        'details': {
            'movement_samples': len(points),
            'teleport_jumps': teleport_jumps,
            'speed_spikes': speed_spikes,
            'acceleration_spikes': acceleration_spikes,
            'erratic_segments': erratic_segments,
            'city_jumps': city_jumps,
            'total_distance_km': _round(total_distance, 2),
        },
    }


def _identity_signal(
    *,
    user: User,
    current_device_id: str | None,
    device_metadata: dict | None,
    login_history: list[dict],
) -> tuple[float, list[str], dict, list[str]]:
    fraud_types: list[str] = []
    explanations: list[str] = []
    device_signals: list[str] = []
    score = 0.0

    normalized_device_id = (current_device_id or '').strip() or None
    if normalized_device_id and user.current_device_id and normalized_device_id != user.current_device_id:
        score += 0.35
        fraud_types.append('device_anomaly')
        explanations.append('Claim was initiated from a device different from the active trusted device.')
        device_signals.append('trusted_device_mismatch')

    if int(user.device_switch_count or 0) >= 3:
        score += 0.25
        fraud_types.append('device_anomaly')
        explanations.append('This account has switched devices frequently, which raises identity risk.')
        device_signals.append('high_device_switch_frequency')

    cutoff = _utcnow() - timedelta(hours=24)
    recent_devices = {
        str(item.get('device_id')).strip()
        for item in login_history
        if item.get('device_id') and (_parse_iso_datetime(item.get('timestamp')) or cutoff) >= cutoff
    }
    if len(recent_devices) >= 2:
        score += 0.25
        fraud_types.append('multi_device_access')
        explanations.append('Multiple devices accessed the account within a short time window.')
        device_signals.append('multi_device_access_24h')

    metadata = device_metadata or {}
    missing_fingerprint_parts = [key for key in ['model', 'os', 'app_version'] if not metadata.get(key)]
    if missing_fingerprint_parts:
        score += 0.1
        explanations.append('Device fingerprint metadata is incomplete for this claim session.')
        device_signals.append('incomplete_device_fingerprint')

    return _clamp(score), sorted(set(fraud_types)), {
        'current_device_id': normalized_device_id,
        'trusted_device_id': user.current_device_id,
        'device_switch_count': int(user.device_switch_count or 0),
        'recent_device_count_24h': len(recent_devices),
        'device_metadata': metadata,
        'signals': device_signals,
    }, explanations


def _session_signal(login_history: list[dict]) -> tuple[float, list[str], dict, list[str]]:
    fraud_types: list[str] = []
    explanations: list[str] = []
    session_signals: list[str] = []
    score = 0.0

    cutoff = _utcnow() - timedelta(hours=48)
    records: list[dict] = []
    for item in login_history:
        timestamp = _parse_iso_datetime(item.get('timestamp'))
        if timestamp and timestamp >= cutoff and item.get('lat') is not None and item.get('lon') is not None:
            records.append(
                {
                    'lat': float(item['lat']),
                    'lon': float(item['lon']),
                    'timestamp': timestamp,
                    'city': item.get('city'),
                    'device_id': item.get('device_id'),
                }
            )

    impossible_travel_count = 0
    account_sharing_count = 0
    for previous, current in zip(records, records[1:]):
        distance_km = _haversine_km(previous['lat'], previous['lon'], current['lat'], current['lon'])
        delta_hours = max((current['timestamp'] - previous['timestamp']).total_seconds() / 3600.0, 0.01)
        speed_kmh = distance_km / delta_hours
        if distance_km > 200 and delta_hours < 3:
            impossible_travel_count += 1
        if previous.get('device_id') and current.get('device_id') and previous['device_id'] != current['device_id'] and distance_km > 80 and delta_hours < 2:
            account_sharing_count += 1
        if speed_kmh > 900:
            impossible_travel_count += 1

    if impossible_travel_count:
        score += min(0.5, impossible_travel_count * 0.22)
        fraud_types.append('session_hijack')
        explanations.append('Recent login history shows impossible travel between sessions.')
        session_signals.append('impossible_travel')

    if account_sharing_count:
        score += min(0.45, account_sharing_count * 0.2)
        fraud_types.append('account_sharing')
        explanations.append('Separate devices appear to be using the same account from distant regions too quickly.')
        session_signals.append('distributed_multi_region_access')

    return _clamp(score), sorted(set(fraud_types)), {
        'recent_login_count': len(records),
        'impossible_travel_count': impossible_travel_count,
        'account_sharing_count': account_sharing_count,
        'signals': session_signals,
    }, explanations


def _behavior_signal(
    *,
    claim_data: dict,
    risk_data: dict,
    past_claims: list[ClaimHistory],
    user_behavior_profile: dict,
    gig_data: dict,
) -> tuple[float, list[str], dict, list[str]]:
    fraud_types: list[str] = []
    explanations: list[str] = []
    signals: list[str] = []

    baseline_income = max(float(claim_data.get('baseline_income', 0.0) or 0.0), 1.0)
    actual_income = float(claim_data.get('actual_income', 0.0) or 0.0)
    actual_loss = max(float(claim_data.get('actual_loss', baseline_income - actual_income) or 0.0), 0.0)
    predicted_loss = max(float(claim_data.get('predicted_loss', 0.0) or 0.0), 0.0)
    anomaly_score = abs(actual_loss - predicted_loss) / baseline_income
    score = 0.0

    if anomaly_score > 0.45:
        score += 0.35
        fraud_types.append('behavioral_anomaly')
        explanations.append('Actual loss materially deviates from the risk-predicted loss pattern.')
        signals.append('predicted_vs_actual_gap')

    avg_loss = float(user_behavior_profile.get('avg_loss', 0.0) or 0.0)
    avg_hours = float(user_behavior_profile.get('avg_hours', 0.0) or 0.0)
    avg_income = float(user_behavior_profile.get('avg_income', 0.0) or 0.0)
    current_hours = float(gig_data.get('hours_worked', 0.0) or 0.0)
    orders_completed = int(gig_data.get('orders_completed', 0) or 0)
    deliveries_per_hour = orders_completed / max(current_hours, 1.0)
    expected_orders = float(gig_data.get('expected_orders', 0.0) or 0.0)
    expected_deliveries_per_hour = expected_orders / max(current_hours, 1.0) if current_hours > 0 and expected_orders > 0 else 0.0
    active_triggers = [str(item).upper() for item in (risk_data.get('active_triggers') or [])]

    if avg_loss > 0 and (actual_loss / max(avg_loss, 1.0)) > 2.0:
        score += 0.12
        explanations.append('Claimed loss is far above the user historical loss profile.')
        signals.append('loss_profile_deviation')

    if avg_income > 0 and actual_income < (avg_income * 0.35) and not active_triggers:
        score += 0.15
        fraud_types.append('behavioral_anomaly')
        explanations.append('Income collapsed sharply without supporting disruption triggers.')
        signals.append('income_collapse_without_trigger')

    if avg_hours > 0 and current_hours > 0 and abs(current_hours - avg_hours) / max(avg_hours, 1.0) > 0.8:
        score += 0.08
        explanations.append('Work-hour pattern deviates materially from the user historical profile.')
        signals.append('hours_profile_deviation')

    if current_hours > 0 and expected_deliveries_per_hour > 0:
        delivery_drop_ratio = max(expected_deliveries_per_hour - deliveries_per_hour, 0.0) / max(expected_deliveries_per_hour, 1.0)
    else:
        delivery_drop_ratio = 0.0

    if delivery_drop_ratio > 0.5 and not active_triggers:
        score += 0.22
        fraud_types.append('efficiency_manipulation')
        explanations.append('Operational efficiency dropped sharply without any valid disruption support.')
        signals.append('delivery_efficiency_drop')

    claims_last_7_days = sum(1 for item in past_claims if item.claim_date >= (_utcnow().date() - timedelta(days=7)))
    if claims_last_7_days > 2:
        score += min(0.25, 0.08 * claims_last_7_days)
        fraud_types.append('frequent_claim_abuse')
        explanations.append('Claim frequency over the last 7 days is unusually high.')
        signals.append('claim_frequency_abuse')

    return _clamp(score), sorted(set(fraud_types)), {
        'predicted_loss': _round(predicted_loss, 2),
        'actual_loss': _round(actual_loss, 2),
        'anomaly_score': _round(anomaly_score),
        'claims_count_last_7_days': claims_last_7_days,
        'deliveries_per_hour': _round(deliveries_per_hour),
        'expected_deliveries_per_hour': _round(expected_deliveries_per_hour),
        'signals': signals,
    }, explanations


def _context_signal(
    *,
    db: Session,
    user_id: int,
    claim_data: dict,
    risk_data: dict,
    environment_data: dict,
    current_city: str,
) -> tuple[float, list[str], dict, list[str]]:
    fraud_types: list[str] = []
    explanations: list[str] = []
    signals: list[str] = []
    score = 0.0

    snapshot = (environment_data or {}).get('snapshot') or {}
    weather = (environment_data or {}).get('weather') or {}
    traffic = (environment_data or {}).get('traffic') or {}
    active_triggers = [str(item).upper() for item in (risk_data.get('active_triggers') or [])]
    actual_loss = max(float(claim_data.get('actual_loss', 0.0) or 0.0), 0.0)
    claim_reason = str(claim_data.get('claim_reason') or '').strip().lower()

    rain = float(snapshot.get('rain_estimate', weather.get('rainfall', 0.0)) or 0.0)
    traffic_score = float(traffic.get('traffic_score', snapshot.get('traffic_index', 1.0)) or 1.0)
    aqi = float(snapshot.get('aqi', 0.0) or 0.0)
    disruption_supported = bool(active_triggers) or rain >= 2.0 or traffic_score >= 1.15 or aqi >= 90

    if actual_loss > 0 and not disruption_supported:
        score += 0.35
        fraud_types.append('weather_mismatch')
        explanations.append('Claimed disruption is not supported by weather, AQI, or traffic conditions.')
        signals.append('environment_mismatch')

    if claim_reason and 'rain' in claim_reason and rain < 1.0:
        score += 0.15
        fraud_types.append('weather_mismatch')
        explanations.append('Claim reason references rain, but rainfall evidence is weak.')
        signals.append('rain_reason_mismatch')

    if claim_reason and 'traffic' in claim_reason and traffic_score < 1.08:
        score += 0.12
        fraud_types.append('weather_mismatch')
        explanations.append('Claim reason references traffic, but congestion evidence is weak.')
        signals.append('traffic_reason_mismatch')

    if claim_reason and 'aqi' in claim_reason and aqi < 80:
        score += 0.1
        fraud_types.append('weather_mismatch')
        explanations.append('Claim reason references AQI, but air-quality evidence is weak.')
        signals.append('aqi_reason_mismatch')

    collusion_peers = (
        db.query(ClaimHistory)
        .filter(
            ClaimHistory.user_id != int(user_id),
            ClaimHistory.claim_date >= (_utcnow().date() - timedelta(days=1)),
        )
        .all()
    )
    normal_environment = rain < 1.0 and traffic_score < 1.08 and aqi < 80
    clustered_claims = sum(1 for peer in collusion_peers if peer.status in {'FLAGGED', 'REJECTED', 'APPROVED'})
    if normal_environment and clustered_claims >= 3:
        score += 0.22
        fraud_types.append('collusion_detected')
        explanations.append('Multiple nearby claims are clustering while environment conditions appear normal.')
        signals.append('claim_cluster_without_environment_support')

    return _clamp(score), sorted(set(fraud_types)), {
        'active_triggers': active_triggers,
        'rain': _round(rain, 2),
        'traffic_score': _round(traffic_score, 3),
        'aqi': _round(aqi, 2),
        'clustered_claims_24h': clustered_claims,
        'city': current_city,
        'signals': signals,
    }, explanations


def evaluate_fraud_intelligence(
    *,
    db: Session,
    user: User,
    claim_id: str | None,
    device_id: str | None,
    device_metadata: dict | None,
    location_logs: list[dict] | None,
    login_history: list[dict] | None,
    claim_data: dict,
    risk_data: dict,
    environment_data: dict,
    past_claims: list[ClaimHistory] | None,
    user_behavior_profile: dict | None,
    gig_data: dict | None = None,
) -> dict:
    login_history = list(login_history or _login_history_from_events(db, user.id, limit=12))
    past_claims = list(past_claims or (
        db.query(ClaimHistory)
        .filter(ClaimHistory.user_id == int(user.id))
        .order_by(ClaimHistory.claim_date.desc(), ClaimHistory.id.desc())
        .limit(12)
        .all()
    ))
    user_behavior_profile = dict(user_behavior_profile or {})

    historical_points = _location_logs_from_history(db, user.id, limit=12)
    client_points = [_extract_point(item) for item in (location_logs or [])]
    client_points = [point for point in client_points if point]
    if claim_data.get('lat') is not None and claim_data.get('lon') is not None:
        client_points.append(
            {
                'lat': float(claim_data['lat']),
                'lon': float(claim_data['lon']),
                'timestamp': _utcnow(),
                'city': claim_data.get('city'),
                'source': 'claim',
            }
        )
    merged_location_logs = historical_points + client_points

    identity_score, identity_types, identity_signals, identity_explanations = _identity_signal(
        user=user,
        current_device_id=device_id,
        device_metadata=device_metadata,
        login_history=login_history,
    )
    session_score, session_types, session_signals, session_explanations = _session_signal(login_history)
    gps_integrity = _build_gps_integrity(merged_location_logs, active_city=claim_data.get('city') or user.active_city)
    gps_score = float(gps_integrity['gps_integrity_score'])
    gps_types = []
    gps_explanations = []
    if gps_integrity['status'] != 'VALID':
        gps_types.append('gps_spoofing')
        gps_explanations.append('GPS integrity checks found suspicious movement patterns.')
    if 'city_jump_detected' in gps_integrity.get('signals', []):
        gps_types.append('geo_transition')

    behavior_score, behavior_types, behavior_signals, behavior_explanations = _behavior_signal(
        claim_data=claim_data,
        risk_data=risk_data,
        past_claims=past_claims,
        user_behavior_profile=user_behavior_profile,
        gig_data=gig_data or {},
    )
    context_score, context_types, context_signals, context_explanations = _context_signal(
        db=db,
        user_id=user.id,
        claim_data=claim_data,
        risk_data=risk_data,
        environment_data=environment_data,
        current_city=str(claim_data.get('city') or user.active_city or _city_label(environment_data)),
    )

    fraud_score = _clamp(
        (0.2 * identity_score)
        + (0.2 * session_score)
        + (0.2 * gps_score)
        + (0.2 * behavior_score)
        + (0.2 * context_score)
    )

    if fraud_score < 0.4:
        decision = 'APPROVED'
        confidence = 'LOW'
    elif fraud_score <= 0.7:
        decision = 'FLAGGED'
        confidence = 'MEDIUM'
    else:
        decision = 'REJECTED'
        confidence = 'HIGH'

    fraud_types = sorted(set(identity_types + session_types + gps_types + behavior_types + context_types))
    explanation_parts = identity_explanations + session_explanations + gps_explanations + behavior_explanations + context_explanations
    if not explanation_parts:
        explanation_parts.append('Fraud telemetry aligns with the expected risk, location, and user behavior pattern.')

    return {
        'claim_id': claim_id,
        'fraud_score': _round(fraud_score),
        'decision': decision,
        'confidence': confidence,
        'fraud_types': fraud_types,
        'signal_list': sorted(
            set(
                identity_signals.get('signals', [])
                + session_signals.get('signals', [])
                + gps_integrity.get('signals', [])
                + behavior_signals.get('signals', [])
                + context_signals.get('signals', [])
            )
        ),
        'signals': {
            'device': {'score': _round(identity_score), **identity_signals},
            'session': {'score': _round(session_score), **session_signals},
            'gps': {'score': _round(gps_score), **gps_integrity},
            'behavior': {'score': _round(behavior_score), **behavior_signals},
            'context': {'score': _round(context_score), **context_signals},
        },
        'explanation': ' '.join(explanation_parts),
    }
