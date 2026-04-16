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
        'active_city': city or user.active_city,
        'last_location_at': user.last_location_at.isoformat() if user.last_location_at else None,
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

