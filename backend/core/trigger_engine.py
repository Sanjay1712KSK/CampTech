from __future__ import annotations

RAIN_TRIGGER_THRESHOLD = 3.0
TRAFFIC_TRIGGER_THRESHOLD = 1.35
AQI_TRIGGER_THRESHOLD = 150.0
HEAT_TRIGGER_THRESHOLD = 37.0


def evaluate_triggers(snapshot: dict) -> dict:
    active: list[str] = []
    rain = float(snapshot.get('rain_estimate', 0.0))
    traffic_index = float(snapshot.get('traffic_index', 1.0))
    aqi = float(snapshot.get('aqi', 50.0))
    temperature = float(snapshot.get('temperature', 30.0))

    if rain >= RAIN_TRIGGER_THRESHOLD:
        active.append('RAIN_TRIGGER')
    if traffic_index >= TRAFFIC_TRIGGER_THRESHOLD:
        active.append('TRAFFIC_TRIGGER')
    if aqi >= AQI_TRIGGER_THRESHOLD:
        active.append('AQI_TRIGGER')
    if temperature >= HEAT_TRIGGER_THRESHOLD:
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
