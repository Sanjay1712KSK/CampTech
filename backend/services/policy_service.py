import json
from datetime import date, timedelta

from sqlalchemy.orm import Session

from models.insurance import Claim, Policy


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _policy_status(policy: Policy, today: date | None = None) -> str:
    today = today or date.today()
    return 'EXPIRED' if today > policy.end_date else 'ACTIVE'


def refresh_policy_status(policy: Policy, today: date | None = None) -> Policy:
    policy.status = _policy_status(policy, today=today)
    return policy


def get_latest_policy(user_id: int, db: Session) -> Policy | None:
    policy = (
        db.query(Policy)
        .filter(Policy.user_id == int(user_id))
        .order_by(Policy.end_date.desc(), Policy.id.desc())
        .first()
    )
    if policy:
        refresh_policy_status(policy)
    return policy


def get_claimable_policy(user_id: int, db: Session) -> Policy | None:
    today = date.today()
    policy = (
        db.query(Policy)
        .filter(
            Policy.user_id == int(user_id),
            Policy.premium_paid.is_(True),
            Policy.end_date < today,
        )
        .order_by(Policy.end_date.desc(), Policy.id.desc())
        .first()
    )
    if policy:
        refresh_policy_status(policy, today=today)
    return policy


def create_policy(user_id: int, db: Session, start_date: date | None = None) -> Policy:
    latest_policy = get_latest_policy(user_id=int(user_id), db=db)
    if start_date is None:
        if latest_policy is not None and latest_policy.end_date >= date.today():
            start_date = latest_policy.end_date + timedelta(days=1)
        else:
            start_date = date.today()
    end_date = start_date + timedelta(days=6)

    policy = Policy(
        user_id=int(user_id),
        start_date=start_date,
        end_date=end_date,
        premium_paid=True,
        status='ACTIVE',
    )
    db.add(policy)
    db.flush()
    return policy


def create_claim_record(
    user_id: int,
    db: Session,
    week: str,
    loss: float,
    payout: float,
    fraud_score: float,
    status: str,
    reasons: list[str] | None = None,
) -> Claim:
    claim = Claim(
        user_id=int(user_id),
        week=week,
        loss=_round(loss),
        payout=_round(payout),
        fraud_score=float(round(fraud_score, 3)),
        status=status,
        reasons_json=json.dumps(reasons or []),
    )
    db.add(claim)
    db.flush()
    return claim
