from __future__ import annotations

from sqlalchemy.orm import Session

from models.profile import Profile
from models.user_model import User
from services.claim_engine import _today_income_payload, process_claim
from services.claim_engine_v2 import (
    _confidence_score,
    _current_gig_snapshot,
    _detect_triggers,
    _explanation,
    _historical_baseline,
    _loss_estimation,
    auto_process_claim,
)
from services.environment_service import get_environment, get_environment_override_state
from services.fraud_intelligence_engine import evaluate_fraud_intelligence, get_device_status
from services.ml_service import expected_loss_prediction, get_latest_user_behavior
from services.premium_engine import calculate_weekly_premium
from services.risk_engine import calculate_risk

_PIPELINE_CACHE: dict[int, dict] = {}


def _user_or_404(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise ValueError('User not found')
    return user


def _resolve_city(user: User, db: Session, environment: dict) -> str:
    profile = db.query(Profile).filter(Profile.user_id == int(user.id)).first()
    return str(
        environment.get('city')
        or environment.get('resolved_city')
        or (profile.city if profile and profile.city else None)
        or user.active_city
        or 'Chennai'
    )


def _fraud_demo_claim(
    *,
    db: Session,
    user: User,
    environment: dict,
    risk: dict,
    premium: dict,
    lat: float,
    lon: float,
) -> dict:
    gig_data = _current_gig_snapshot(db, int(user.id))
    baseline = _historical_baseline(db, int(user.id))
    loss = _loss_estimation(baseline=baseline, gig_data=gig_data)
    confidence = _confidence_score(
        trigger_data={
            'trigger_detected': True,
            'triggers': ['manual_claim_story'],
            'primary_trigger': 'manual_claim_story',
            'trigger_strength': 0.82,
        },
        loss_data=loss,
        baseline=baseline,
        environment_data=environment,
        risk_data=risk,
    )
    city = _resolve_city(user, db, environment)
    predicted_loss = expected_loss_prediction(
        float(risk.get('risk_score', 0.0) or 0.0),
        float(loss.get('baseline_income', 0.0) or 0.0),
    )
    fraud = evaluate_fraud_intelligence(
        db=db,
        user=user,
        claim_id=f'demo_fraud_{user.id}',
        device_id='demo-untrusted-device',
        device_metadata={'model': 'DemoDevice', 'os': 'Android', 'app_version': 'demo'},
        location_logs=[
            {
                'lat': lat,
                'lon': lon,
                'timestamp': environment.get('last_updated'),
                'city': city,
            },
            {
                'lat': lat + 3.1,
                'lon': lon + 3.1,
                'timestamp': environment.get('last_updated'),
                'city': 'Unexpected City',
            },
        ],
        login_history=None,
        claim_data={
            'actual_income': float(loss['actual_income']),
            'baseline_income': float(loss['baseline_income']),
            'predicted_loss': predicted_loss,
            'actual_loss': max(float(loss['loss']), float(loss['baseline_income']) * 0.42),
            'lat': lat,
            'lon': lon,
            'city': city,
            'claim_reason': 'rain',
        },
        risk_data=risk,
        environment_data=environment,
        past_claims=None,
        user_behavior_profile=get_latest_user_behavior(db, user_id=int(user.id)),
        gig_data={
            **gig_data,
            'hours_worked': max(float(gig_data.get('hours_worked', 0.0) or 0.0), 1.0),
            'expected_orders': max(int(gig_data.get('orders_completed', 0) or 0), 14),
            'orders_completed': 1,
            'disruption_type': 'fake_rain_claim',
        },
    )
    explanation = (
        'Fraud demo triggered because the claim story conflicts with live conditions and the device/location pattern is inconsistent.'
    )
    return {
        'claim_triggered': True,
        'status': 'REJECTED' if fraud['decision'] == 'REJECTED' else 'UNDER_REVIEW',
        'loss': float(loss['loss']),
        'confidence': confidence['label'],
        'fraud': fraud,
        'payout': {
            'status': 'SKIPPED',
            'amount_paid': 0.0,
            'transaction_id': None,
            'message': 'Payout blocked because fraud validation did not approve the claim.',
            'time': '0.0 sec',
        },
        'explanation': explanation,
        'trigger': 'manual_claim_story',
        'timestamp': environment.get('last_updated'),
        'claim_id': f'demo_fraud_{user.id}',
        'loss_percentage': float(loss['loss_percentage']),
        'trigger_details': {
            'trigger_detected': True,
            'triggers': ['manual_claim_story'],
            'primary_trigger': 'manual_claim_story',
            'trigger_strength': 0.82,
        },
    }


def build_demo_pipeline(
    *,
    db: Session,
    user_id: int,
    lat: float,
    lon: float,
) -> dict:
    override = get_environment_override_state()
    cached = _PIPELINE_CACHE.get(int(user_id))
    if cached and cached.get('version') == int(override['version']):
        return cached['payload']

    user = _user_or_404(db, user_id)
    environment = get_environment(lat, lon, db=db, user_id=user_id)
    today_income = _today_income_payload(user_id, db)
    risk = calculate_risk(environment, user_id=user_id, db=db, today_income=today_income)
    premium = calculate_weekly_premium(
        user_id=user_id,
        lat=lat,
        lon=lon,
        db=db,
        environment_data=environment,
        risk_result=risk,
        persist_snapshots=False,
    )

    if override['fraud_mode']:
        claim = _fraud_demo_claim(
            db=db,
            user=user,
            environment=environment,
            risk=risk,
            premium=premium,
            lat=lat,
            lon=lon,
        )
        fraud = claim['fraud']
        payout = claim['payout']
        scenario = 'fraud_user'
    else:
        claim = auto_process_claim(user_id=user_id, db=db, lat=lat, lon=lon)
        fraud = claim.get('fraud') or {
            'fraud_score': 0.0,
            'decision': 'APPROVED',
            'signals': [],
            'explanation': 'No fraud review was required because no claim was triggered.',
        }
        payout = claim.get('payout') or {
            'status': 'PENDING',
            'amount_paid': 0.0,
            'transaction_id': None,
            'message': 'No payout processed yet.',
            'time': '0.0 sec',
        }
        scenario = 'real_user'

    pipeline = {
        'scenario': scenario,
        'override': override,
        'environment': environment,
        'risk': {
            'risk_score': float(risk.get('risk_score', 0.0) or 0.0),
            'risk_level': risk.get('risk_level'),
            'triggers': risk.get('active_triggers', []),
            'reasons': risk.get('reasons', []),
            'delivery_efficiency': risk.get('delivery_efficiency'),
        },
        'claim': claim,
        'fraud': fraud,
        'payout': payout,
        'device': get_device_status(user, db=db),
        'explainability': {
            'environment_inputs': {
                'rain': (environment.get('weather') or {}).get('rainfall'),
                'aqi': (environment.get('aqi') or {}).get('aqi'),
                'traffic': (environment.get('traffic') or {}).get('traffic_level'),
            },
            'risk_reason': risk.get('reasons', []),
            'claim_reason': claim.get('explanation'),
            'fraud_reason': fraud.get('explanation'),
            'payout_reason': payout.get('message'),
        },
    }
    _PIPELINE_CACHE[int(user_id)] = {
        'version': int(override['version']),
        'payload': pipeline,
    }
    return pipeline
