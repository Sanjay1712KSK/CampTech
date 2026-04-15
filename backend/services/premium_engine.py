import logging
from datetime import date

from sqlalchemy.orm import Session

from models.gig_account import GigAccount
from models.gig_income import GigIncome
from models.models import IncomeSummary, PremiumSnapshot, RiskSnapshot
from models.profile import Profile
from services.environment_service import get_environment
from services.gig_service import calculate_baseline_value
from services.risk_engine import calculate_risk

CITY_COORDINATES = {
    'chennai': (13.0827, 80.2707),
    'bengaluru': (12.9716, 77.5946),
    'mumbai': (19.0760, 72.8777),
    'pune': (18.5204, 73.8567),
    'hyderabad': (17.3850, 78.4867),
}

logger = logging.getLogger('gig_insurance_backend.premium')


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _baseline_value(user_id: int, db: Session) -> float:
    return calculate_baseline_value(user_id=user_id, db=db)


def baseline_value(user_id: int, db: Session) -> float:
    return _baseline_value(user_id, db)


def resolve_city_from_coordinates(lat: float, lon: float) -> str:
    closest_city = 'Chennai'
    closest_distance = float('inf')
    for city, (city_lat, city_lon) in CITY_COORDINATES.items():
        distance = ((lat - city_lat) ** 2) + ((lon - city_lon) ** 2)
        if distance < closest_distance:
            closest_distance = distance
            closest_city = city.title()
    return closest_city


def _build_explanation(risk: dict) -> str:
    reasons = [str(item) for item in (risk.get('reasons') or []) if str(item).strip()]
    if reasons:
        lead = reasons[:2]
        return f"Pricing is based on {' and '.join(lead).lower()}"
    severity = str(risk.get('trigger_severity', 'MEDIUM')).lower()
    return f'Pricing is based on {severity} disruption conditions from the live risk engine'


def _latest_profile_context(user_id: int, db: Session) -> tuple[str | None, str | None]:
    profile = db.query(Profile).filter(Profile.user_id == int(user_id)).first()
    latest_account = (
        db.query(GigAccount)
        .filter(GigAccount.user_id == int(user_id))
        .order_by(GigAccount.created_at.desc(), GigAccount.id.desc())
        .first()
    )
    city = profile.city if profile and profile.city else None
    platform = latest_account.platform if latest_account else (profile.platform if profile else None)
    return city, platform


def _persist_income_summary(user_id: int, baseline: float, city: str | None, platform: str | None, db: Session) -> IncomeSummary:
    recent_records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == int(user_id))
        .order_by(GigIncome.date.desc(), GigIncome.created_at.desc())
        .limit(30)
        .all()
    )
    total_income = _round(sum(float(item.earnings) for item in recent_records))
    total_hours = _round(sum(float(item.hours_worked) for item in recent_records))
    total_orders = sum(int(item.orders_completed) for item in recent_records)
    disruption_days = sum(1 for item in recent_records if str(item.disruption_type or 'none') != 'none')
    summary_date = max((item.date for item in recent_records), default=date.today())
    summary = (
        db.query(IncomeSummary)
        .filter(
            IncomeSummary.user_id == int(user_id),
            IncomeSummary.summary_date == summary_date,
            IncomeSummary.summary_type == 'baseline_30d',
        )
        .first()
    )
    if summary is None:
        summary = IncomeSummary(
            user_id=int(user_id),
            summary_date=summary_date,
            summary_type='baseline_30d',
        )
        db.add(summary)
    summary.platform = platform
    summary.city = city
    summary.total_income = total_income
    summary.average_income = _round(baseline)
    summary.total_hours = total_hours
    summary.total_orders = total_orders
    summary.disruption_days = disruption_days
    summary.summary_metadata = {
        'window_days': len(recent_records),
        'baseline_income': _round(baseline),
    }
    db.flush()
    return summary


def _persist_risk_snapshot(
    user_id: int,
    lat: float,
    lon: float,
    city: str,
    risk_result: dict,
    environment: dict,
    income_summary_id: int | None,
    db: Session,
) -> RiskSnapshot:
    snapshot = RiskSnapshot(
        user_id=int(user_id),
        income_summary_id=income_summary_id,
        snapshot_date=date.today(),
        lat=float(lat),
        lon=float(lon),
        city=city,
        risk_score=float(risk_result.get('risk_score', 0.0) or 0.0),
        risk_level=str(risk_result.get('risk_level', 'LOW') or 'LOW'),
        expected_income_loss_pct=int(risk_result.get('expected_income_loss_pct', 0) or 0),
        trigger_severity=str(risk_result.get('trigger_severity', 'LOW') or 'LOW'),
        delivery_efficiency=risk_result.get('delivery_efficiency'),
        time_slot_risk=risk_result.get('time_slot_risk'),
        predictive_risk=risk_result.get('predictive_risk'),
        active_triggers=risk_result.get('active_triggers'),
        reasons=risk_result.get('reasons'),
        fraud_signals=risk_result.get('fraud_signals'),
        adaptive_weights=risk_result.get('adaptive_weights'),
        environment_context=environment,
    )
    db.add(snapshot)
    db.flush()
    return snapshot


def _persist_premium_snapshot(
    user_id: int,
    risk_snapshot_id: int | None,
    baseline: float,
    weekly_income: float,
    weekly_premium: float,
    coverage: float,
    explanation: str,
    linked_risk: dict,
    db: Session,
) -> PremiumSnapshot:
    snapshot = PremiumSnapshot(
        user_id=int(user_id),
        risk_snapshot_id=risk_snapshot_id,
        baseline_income=_round(baseline),
        weekly_income=_round(weekly_income),
        weekly_premium=_round(weekly_premium),
        coverage=_round(coverage),
        pricing_factor=0.07,
        explanation=explanation,
        pricing_metadata={
            'risk': linked_risk,
            'pricing_source': 'risk_engine',
        },
    )
    db.add(snapshot)
    db.flush()
    return snapshot


def calculate_weekly_premium(
    user_id: int,
    lat: float,
    lon: float,
    db: Session,
    *,
    environment_data: dict | None = None,
    risk_result: dict | None = None,
    persist_snapshots: bool = True,
) -> dict:
    baseline = _baseline_value(user_id, db)
    environment = environment_data or get_environment(lat, lon, db=db, user_id=user_id)
    risk_result = risk_result or calculate_risk(environment, user_id=user_id, db=db)
    risk_score = float(risk_result.get('risk_score', 0.0) or 0.0)
    active_triggers = [str(item) for item in (risk_result.get('active_triggers') or [])]
    trigger_severity = str(risk_result.get('trigger_severity', 'MEDIUM') or 'MEDIUM').upper()

    weekly_income = _round(baseline * 7)
    weekly_premium = weekly_income * risk_score * 0.07
    if trigger_severity == 'HIGH':
        weekly_premium *= 1.15
    if 'COMBINED_TRIGGER' in active_triggers:
        weekly_premium *= 1.10
    weekly_premium = _round(weekly_premium)
    coverage = _round(weekly_income * 0.8)

    linked_risk = {
        'risk_score': _round(risk_score),
        'expected_income_loss': risk_result.get('expected_income_loss', '0%'),
        'expected_income_loss_pct': int(risk_result.get('expected_income_loss_pct', 0) or 0),
        'trigger_severity': trigger_severity,
        'active_triggers': active_triggers,
        'reasons': risk_result.get('reasons', []),
    }
    explanation = _build_explanation(linked_risk)

    income_summary = None
    risk_snapshot = None
    premium_snapshot = None
    resolved_city = resolve_city_from_coordinates(lat, lon)
    profile_city, profile_platform = _latest_profile_context(user_id, db)

    if persist_snapshots:
        income_summary = _persist_income_summary(
            user_id=user_id,
            baseline=baseline,
            city=profile_city or resolved_city,
            platform=profile_platform,
            db=db,
        )
        risk_snapshot = _persist_risk_snapshot(
            user_id=user_id,
            lat=lat,
            lon=lon,
            city=profile_city or resolved_city,
            risk_result=risk_result,
            environment=environment,
            income_summary_id=income_summary.id if income_summary else None,
            db=db,
        )
        premium_snapshot = _persist_premium_snapshot(
            user_id=user_id,
            risk_snapshot_id=risk_snapshot.id if risk_snapshot else None,
            baseline=baseline,
            weekly_income=weekly_income,
            weekly_premium=weekly_premium,
            coverage=coverage,
            explanation=explanation,
            linked_risk=linked_risk,
            db=db,
        )

    response = {
        'baseline': _round(baseline),
        'weekly_income': weekly_income,
        'weekly_premium': weekly_premium,
        'coverage': coverage,
        'risk_score': _round(risk_score),
        'risk': linked_risk,
        'explanation': explanation,
        'resolved_city': profile_city or resolved_city,
        'risk_snapshot_id': risk_snapshot.id if risk_snapshot else None,
        'premium_snapshot_id': premium_snapshot.id if premium_snapshot else None,
        'income_summary_id': income_summary.id if income_summary else None,
        'eligible': bool(baseline > 0 and weekly_income > 0),
        'reason': 'Eligible for premium quote' if baseline > 0 and weekly_income > 0 else 'Insufficient gig history for pricing',
        'last_updated': (environment or {}).get('last_updated'),
        'breakdown': {
            'base_rate': 0.07,
            'trigger_severity': trigger_severity,
            'active_triggers': active_triggers,
            'severity_multiplier': 1.15 if trigger_severity == 'HIGH' else 1.0,
            'combined_trigger_multiplier': 1.10 if 'COMBINED_TRIGGER' in active_triggers else 1.0,
            'final_formula': 'weekly_income * risk_score * base_rate * severity_multiplier * combined_trigger_multiplier',
        },
    }

    logger.info(
        'premium calculated user_id=%s lat=%s lon=%s premium=%s risk_score=%s severity=%s risk_snapshot_id=%s premium_snapshot_id=%s',
        user_id,
        lat,
        lon,
        weekly_premium,
        linked_risk['risk_score'],
        trigger_severity,
        risk_snapshot.id if risk_snapshot else None,
        premium_snapshot.id if premium_snapshot else None,
    )

    return response
