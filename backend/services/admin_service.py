from __future__ import annotations

import hmac
import os
from collections import Counter
from datetime import UTC, datetime, timedelta

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func
from sqlalchemy.orm import Session

from database.db import get_db
from models.bank_account import BankTransaction
from models.fraud_log import FraudLog
from models.insurance import Policy
from models.models import ClaimHistory, PremiumSnapshot, RiskSnapshot
from models.user_model import User

ADMIN_EMAIL = os.getenv('ADMIN_EMAIL', 'admin@gigshield.com').strip().lower()
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'admin123')
ADMIN_TOKEN = os.getenv('ADMIN_TOKEN', 'admin_token')

_bearer = HTTPBearer(auto_error=False)


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float | None, places: int = 2) -> float:
    return float(round(float(value or 0.0), places))


def admin_login(*, email: str, password: str) -> dict:
    normalized_email = email.strip().lower()
    if not (
        hmac.compare_digest(normalized_email, ADMIN_EMAIL)
        and hmac.compare_digest(password, ADMIN_PASSWORD)
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid admin credentials')
    return {'token': ADMIN_TOKEN, 'role': 'insurer'}


def get_current_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    if credentials is None or credentials.scheme.lower() != 'bearer':
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Missing admin token')
    if not hmac.compare_digest(credentials.credentials, ADMIN_TOKEN):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid admin token')
    return {'role': 'insurer', 'email': ADMIN_EMAIL}


def _premium_totals(db: Session) -> float:
    total = (
        db.query(func.coalesce(func.sum(BankTransaction.amount), 0.0))
        .filter(
            BankTransaction.transaction_type == 'PREMIUM_PAYMENT',
            BankTransaction.status == 'SUCCESS',
        )
        .scalar()
    )
    return _round(total)


def _payout_totals(db: Session) -> float:
    total = (
        db.query(func.coalesce(func.sum(BankTransaction.amount), 0.0))
        .filter(
            BankTransaction.transaction_type.in_(['CLAIM_PAYOUT', 'MANUAL_CLAIM_PAYOUT']),
            BankTransaction.status == 'SUCCESS',
        )
        .scalar()
    )
    return _round(total)


def get_overview(db: Session) -> dict:
    total_users = db.query(func.count(User.id)).scalar() or 0
    active_policies = (
        db.query(func.count(Policy.id))
        .filter(Policy.status == 'ACTIVE', Policy.premium_paid.is_(True))
        .scalar()
        or 0
    )
    total_claims = db.query(func.count(ClaimHistory.id)).scalar() or 0
    total_payouts = _payout_totals(db)
    total_premiums = _premium_totals(db)
    loss_ratio = _round(total_payouts / total_premiums, 4) if total_premiums > 0 else 0.0
    return {
        'total_users': int(total_users),
        'active_policies': int(active_policies),
        'total_claims': int(total_claims),
        'total_payouts': total_payouts,
        'total_premiums': total_premiums,
        'loss_ratio': loss_ratio,
    }


def get_fraud_stats(db: Session) -> dict:
    total_claims = db.query(func.count(ClaimHistory.id)).scalar() or 0
    flagged_claims = (
        db.query(func.count(ClaimHistory.id))
        .filter(ClaimHistory.status == 'FLAGGED')
        .scalar()
        or 0
    )
    rejected_claims = (
        db.query(func.count(ClaimHistory.id))
        .filter(ClaimHistory.status == 'REJECTED')
        .scalar()
        or 0
    )
    fraud_logs = db.query(FraudLog.fraud_types).all()
    counter: Counter[str] = Counter()
    for row in fraud_logs:
        for fraud_type in (row[0] or []):
            cleaned = str(fraud_type).strip().lower()
            if cleaned:
                counter[cleaned] += 1
    fraudulent_claims = flagged_claims + rejected_claims
    fraud_rate = _round(fraudulent_claims / total_claims, 4) if total_claims > 0 else 0.0
    top_fraud_types = [{'type': fraud_type, 'count': count} for fraud_type, count in counter.most_common(5)]
    hotspot_rows = (
        db.query(FraudLog.city, func.count(FraudLog.id))
        .filter(FraudLog.city.isnot(None), FraudLog.city != '')
        .group_by(FraudLog.city)
        .order_by(func.count(FraudLog.id).desc())
        .limit(5)
        .all()
    )
    hotspots = [{'city': str(city), 'count': int(count)} for city, count in hotspot_rows]
    return {
        'fraud_rate': fraud_rate,
        'flagged_claims': int(flagged_claims),
        'rejected_claims': int(rejected_claims),
        'top_fraud_types': top_fraud_types,
        'hotspots': hotspots,
    }


def get_claims_stats(db: Session) -> dict:
    status_rows = (
        db.query(ClaimHistory.status, func.count(ClaimHistory.id))
        .group_by(ClaimHistory.status)
        .all()
    )
    status_counts = {str(status or 'PENDING').upper(): int(count) for status, count in status_rows}
    avg_payout = db.query(func.coalesce(func.avg(ClaimHistory.approved_payout), 0.0)).scalar() or 0.0
    avg_loss = db.query(func.coalesce(func.avg(ClaimHistory.actual_loss), 0.0)).scalar() or 0.0
    return {
        'approved': int(status_counts.get('APPROVED', 0)),
        'rejected': int(status_counts.get('REJECTED', 0)),
        'flagged': int(status_counts.get('FLAGGED', 0)),
        'avg_payout': _round(avg_payout),
        'avg_loss': _round(avg_loss),
    }


def get_risk_stats(db: Session) -> dict:
    latest_snapshot_subquery = (
        db.query(
            RiskSnapshot.user_id.label('user_id'),
            func.max(RiskSnapshot.created_at).label('latest_created_at'),
        )
        .group_by(RiskSnapshot.user_id)
        .subquery()
    )
    latest_risks = (
        db.query(RiskSnapshot)
        .join(
            latest_snapshot_subquery,
            (RiskSnapshot.user_id == latest_snapshot_subquery.c.user_id)
            & (RiskSnapshot.created_at == latest_snapshot_subquery.c.latest_created_at),
        )
        .all()
    )
    high_risk_users = sum(1 for item in latest_risks if float(item.risk_score or 0.0) >= 0.7)
    avg_risk_score = _round(sum(float(item.risk_score or 0.0) for item in latest_risks) / len(latest_risks), 4) if latest_risks else 0.0
    trigger_counter: Counter[str] = Counter()
    for snapshot in latest_risks:
        for trigger in (snapshot.active_triggers or []):
            normalized = str(trigger).replace('_TRIGGER', '').replace('_', ' ').strip().lower()
            if normalized:
                trigger_counter[normalized] += 1
    return {
        'high_risk_users': int(high_risk_users),
        'avg_risk_score': avg_risk_score,
        'top_triggers': [name for name, _ in trigger_counter.most_common(3)],
    }


def get_financials(db: Session) -> dict:
    total_premiums = _premium_totals(db)
    total_payouts = _payout_totals(db)
    return {
        'total_premiums': total_premiums,
        'total_payouts': total_payouts,
        'profit': _round(total_premiums - total_payouts),
    }


def get_predictions(db: Session) -> dict:
    now = _utcnow()
    last_7d_start = now.date() - timedelta(days=7)
    prev_7d_start = now.date() - timedelta(days=14)

    claims_last_7 = (
        db.query(func.count(ClaimHistory.id))
        .filter(ClaimHistory.claim_date >= last_7d_start)
        .scalar()
        or 0
    )
    claims_prev_7 = (
        db.query(func.count(ClaimHistory.id))
        .filter(ClaimHistory.claim_date >= prev_7d_start, ClaimHistory.claim_date < last_7d_start)
        .scalar()
        or 0
    )
    avg_payout_last_7 = (
        db.query(func.coalesce(func.avg(ClaimHistory.approved_payout), 0.0))
        .filter(ClaimHistory.claim_date >= last_7d_start)
        .scalar()
        or 0.0
    )
    avg_risk_last_7 = (
        db.query(func.coalesce(func.avg(RiskSnapshot.risk_score), 0.0))
        .filter(RiskSnapshot.created_at >= now - timedelta(days=7))
        .scalar()
        or 0.0
    )
    avg_risk_prev_7 = (
        db.query(func.coalesce(func.avg(RiskSnapshot.risk_score), 0.0))
        .filter(
            RiskSnapshot.created_at >= now - timedelta(days=14),
            RiskSnapshot.created_at < now - timedelta(days=7),
        )
        .scalar()
        or 0.0
    )
    risk_delta = float(avg_risk_last_7 or 0.0) - float(avg_risk_prev_7 or 0.0)
    if risk_delta > 0.03:
        risk_trend = 'increasing'
    elif risk_delta < -0.03:
        risk_trend = 'decreasing'
    else:
        risk_trend = 'stable'

    recent_trigger_counter: Counter[str] = Counter()
    recent_risks = (
        db.query(RiskSnapshot.active_triggers)
        .filter(RiskSnapshot.created_at >= now - timedelta(days=7))
        .all()
    )
    for row in recent_risks:
        for trigger in (row[0] or []):
            normalized = str(trigger).replace('_TRIGGER', '').replace('_', ' ').strip().lower()
            if normalized:
                recent_trigger_counter[normalized] += 1
    leading_trigger = recent_trigger_counter.most_common(1)
    leading_label = leading_trigger[0][0].title() if leading_trigger else 'Risk'

    if claims_prev_7 == 0:
        next_week_claims = int(claims_last_7)
    else:
        growth_factor = claims_last_7 / max(claims_prev_7, 1)
        next_week_claims = int(round(claims_last_7 * ((1 + growth_factor) / 2)))
    next_week_claims = max(next_week_claims, 0)
    expected_payout = _round(next_week_claims * float(avg_payout_last_7 or 0.0))

    if risk_trend == 'increasing':
        insight = f'{leading_label} increase may lead to higher claims next week'
    elif risk_trend == 'decreasing':
        insight = f'{leading_label} pressure is easing, which may reduce claims next week'
    else:
        insight = f'{leading_label} conditions look stable, so claims are likely to stay near the recent average'

    return {
        'next_week_claims': int(next_week_claims),
        'expected_payout': expected_payout,
        'risk_trend': risk_trend,
        'insight': insight,
    }


def get_payout_stats(db: Session) -> dict:
    payout_query = db.query(BankTransaction).filter(
        BankTransaction.transaction_type.in_(['CLAIM_PAYOUT', 'MANUAL_CLAIM_PAYOUT'])
    )
    total_records = payout_query.count()
    successful_records = payout_query.filter(BankTransaction.status == 'SUCCESS')
    total_payouts = successful_records.with_entities(func.coalesce(func.sum(BankTransaction.amount), 0.0)).scalar() or 0.0
    avg_payout = successful_records.with_entities(func.coalesce(func.avg(BankTransaction.amount), 0.0)).scalar() or 0.0
    success_count = successful_records.count()
    payout_success_rate = _round(success_count / total_records, 4) if total_records > 0 else 0.0
    return {
        'total_payouts': _round(total_payouts),
        'avg_payout': _round(avg_payout),
        'payout_success_rate': payout_success_rate,
    }
