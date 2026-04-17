from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database.db import get_db
from routes.claim import payout_claim_endpoint
from schemas.insurance_schema import AutoClaimProcessRequest, ClaimPayoutRequest
from schemas.user_schema import LocationUpdateRequest
from services.bank_service import insurance_summary, transaction_history
from services.claim_engine import process_claim
from services.claim_engine_v2 import auto_process_claim
from services.environment_service import get_environment, get_environment_override
from services.fraud_intelligence_engine import build_location_status, get_device_status, record_continuous_location_update, update_user_location_state
from services.gig_service import today_income
from services.premium_engine import calculate_weekly_premium
from services.prediction_engine import build_worker_prediction_message
from services.policy_service import get_latest_policy
from services.risk_engine import calculate_risk
from services.auth_service import build_user_session
from models.user_model import User

router = APIRouter(tags=['ui-api'])


def _require_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    return user


def _demo_payout_from_claim(claim: dict) -> dict:
    payout = claim.get('payout')
    if isinstance(payout, dict):
        return payout
    transaction = claim.get('transaction')
    if isinstance(transaction, dict):
        return {
            'status': transaction.get('status'),
            'amount_paid': transaction.get('amount'),
            'transaction_id': transaction.get('transaction_id'),
            'processed_at': transaction.get('processed_at') or transaction.get('created_at'),
            'message': 'Payout successfully credited' if transaction.get('status') == 'SUCCESS' else 'Payout was not completed',
        }
    return {
        'status': 'SKIPPED',
        'amount_paid': 0.0,
        'transaction_id': None,
        'processed_at': None,
        'message': 'No payout was processed for this claim path.',
    }


@router.get('/dashboard/worker')
async def dashboard_worker(
    user_id: int = Query(..., gt=0),
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    db: Session = Depends(get_db),
):
    user = _require_user(db, user_id)
    environment = get_environment(lat, lon, db=db, user_id=user_id)
    risk = calculate_risk(environment, user_id=user_id, db=db, today_income=today_income(user_id=user_id, db=db))
    premium = calculate_weekly_premium(
        user_id=user_id,
        lat=lat,
        lon=lon,
        db=db,
        environment_data=environment,
        risk_result=risk,
        persist_snapshots=False,
    )
    policy = get_latest_policy(user_id, db)
    payout_summary = insurance_summary(db=db, user_id=user_id)
    location_status = update_user_location_state(
        user,
        lat=lat,
        lon=lon,
        city=environment.get('city') or environment.get('resolved_city'),
        db=db,
    )
    db.commit()
    return {
        'user': build_user_session(user),
        'environment': environment,
        'risk': risk,
        'premium': premium,
        'policy': (
            {
                'policy_id': policy.id,
                'start_date': policy.start_date.isoformat(),
                'end_date': policy.end_date.isoformat(),
                'premium_paid': bool(policy.premium_paid),
                'status': policy.status,
            }
            if policy
            else None
        ),
        'payout': {
            'payout_status': payout_summary.get('payout_status'),
            'amount': payout_summary.get('last_payout'),
            'transaction_id': payout_summary.get('payout_transaction_id'),
            'time': payout_summary.get('payout_time'),
        },
        'prediction': build_worker_prediction_message(db, user_id=user_id),
        'status': {
            'coverage_active': bool(policy and policy.premium_paid and policy.status == 'ACTIVE'),
            'auto_payout_enabled': bool(user.location_enabled),
            'device': get_device_status(user, db=db),
            'location': location_status,
        },
    }


@router.get('/risk/details')
async def risk_details(
    user_id: int = Query(..., gt=0),
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    db: Session = Depends(get_db),
):
    environment = get_environment(lat, lon, db=db, user_id=user_id)
    risk = calculate_risk(environment, user_id=user_id, db=db, today_income=today_income(user_id=user_id, db=db))
    return {
        'risk_score': risk['risk_score'],
        'factors': risk.get('factors'),
        'triggers': risk.get('active_triggers', []),
        'risk_level': risk.get('risk_level'),
        'explanation': risk.get('reasons', []),
        'last_updated': risk.get('last_updated'),
    }


@router.get('/premium/details')
async def premium_details(
    user_id: int = Query(..., gt=0),
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    db: Session = Depends(get_db),
):
    environment = get_environment(lat, lon, db=db, user_id=user_id)
    risk = calculate_risk(environment, user_id=user_id, db=db, today_income=today_income(user_id=user_id, db=db))
    premium = calculate_weekly_premium(
        user_id=user_id,
        lat=lat,
        lon=lon,
        db=db,
        environment_data=environment,
        risk_result=risk,
        persist_snapshots=False,
    )
    return {
        'weekly_income': premium['weekly_income'],
        'risk_score': premium['risk_score'],
        'premium': premium['weekly_premium'],
        'coverage': premium['coverage'],
        'breakdown': premium.get('breakdown', {}),
        'eligible': premium.get('eligible', False),
        'reason': premium.get('reason'),
        'explanation': premium.get('explanation'),
        'last_updated': premium.get('last_updated'),
    }


@router.get('/demo/full-pipeline')
async def demo_full_pipeline(
    user_id: int = Query(..., gt=0),
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    db: Session = Depends(get_db),
):
    user = _require_user(db, user_id)
    environment = get_environment(lat, lon, db=db, user_id=user_id)
    risk = calculate_risk(environment, user_id=user_id, db=db, today_income=today_income(user_id=user_id, db=db))
    premium = calculate_weekly_premium(
        user_id=user_id,
        lat=lat,
        lon=lon,
        db=db,
        environment_data=environment,
        risk_result=risk,
        persist_snapshots=False,
    )

    override = get_environment_override()
    scenario = str(override.get('scenario') or 'live')
    if scenario == 'fraud':
        claim = process_claim(
            user_id=user_id,
            db=db,
            lat=lat,
            lon=lon,
            device_id=user.current_device_id,
            claim_reason='rain',
        )
    else:
        claim = auto_process_claim(user_id=user_id, db=db, lat=lat, lon=lon)

    payout = _demo_payout_from_claim(claim)
    return {
        'scenario': scenario,
        'override': override,
        'environment': environment,
        'risk': risk,
        'premium': premium,
        'claim': claim,
        'fraud': claim.get('fraud') or {
            'fraud_score': 0.0,
            'decision': 'APPROVED',
            'signals': {},
            'explanation': 'Fraud evaluation is not available for this pipeline snapshot.',
        },
        'payout': payout,
    }


@router.post('/fraud/check')
async def fraud_check(
    payload: AutoClaimProcessRequest,
    db: Session = Depends(get_db),
):
    result = auto_process_claim(
        user_id=payload.user_id,
        db=db,
        lat=payload.lat,
        lon=payload.lon,
    )
    return {
        'status': result.get('status'),
        'claim_id': result.get('claim_id'),
        'fraud': result.get('fraud'),
        'explanation': result.get('explanation'),
    }


@router.post('/payout/process')
async def payout_process(
    payload: ClaimPayoutRequest,
    db: Session = Depends(get_db),
):
    return payout_claim_endpoint(payload=payload, db=db)


@router.get('/transactions/history')
async def transactions_history(
    user_id: int = Query(..., gt=0),
    limit: int = Query(default=10, ge=1, le=20),
    db: Session = Depends(get_db),
):
    history = transaction_history(db=db, user_id=user_id, limit=limit)
    return [
        {
            'type': item['transaction_type'].lower().replace('_payment', '').replace('claim_', 'payout'),
            'amount': item['amount'],
            'transaction_id': item['reference_id'] or item['transaction_id'],
            'status': item['status'],
            'created_at': item['created_at'],
            'remark': item.get('remark'),
        }
        for item in history['transactions']
    ]


@router.get('/user/device-status')
async def user_device_status(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    user = _require_user(db, user_id)
    return get_device_status(user, db=db)


@router.get('/user/location-status')
async def user_location_status(
    user_id: int = Query(..., gt=0),
    lat: float | None = Query(default=None, ge=-90.0, le=90.0),
    lon: float | None = Query(default=None, ge=-180.0, le=180.0),
    city: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    user = _require_user(db, user_id)
    if lat is not None and lon is not None:
        status = update_user_location_state(user, lat=lat, lon=lon, city=city, db=db)
        db.commit()
        return status
    return build_location_status(user, city=city)


@router.post('/location/update')
async def location_update(payload: LocationUpdateRequest, db: Session = Depends(get_db)):
    user = _require_user(db, payload.user_id)
    try:
        location_status = record_continuous_location_update(
            db,
            user=user,
            lat=payload.lat,
            lon=payload.lon,
            timestamp=payload.timestamp
            or datetime.now(UTC).replace(tzinfo=None),
            city=payload.city,
            device_id=payload.device_id,
            location_enabled=payload.location_enabled,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    db.commit()
    return location_status
