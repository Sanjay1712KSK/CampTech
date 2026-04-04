from __future__ import annotations

import os
import random
import json
from datetime import UTC, date, datetime, timedelta

from sqlalchemy.orm import Session

from models.bank_account import BankTransaction
from models.gig_account import GigAccount
from models.gig_income import GigIncome
from models.insurance import Claim, Policy
from models.models import BlockchainRecord, ClaimHistory, UserBehavior, UserSettings
from models.profile import Profile
from models.user_model import User
from services.bank_service import link_account, log_transaction
from services.blockchain_service import create_policy_record, log_claim, record_payout
from services.policy_service import create_policy, refresh_policy_status
from utils.security import hash_password

DEFAULT_SIMULATION_PASSWORD = 'Demo@1234'
_SIMULATION_MODE_OVERRIDE: bool | None = None

SIMULATED_USERS = {
    'good_actor': {
        'email': 'good.actor@gigshield.demo',
        'phone': '+919100000001',
        'username': 'good_actor',
        'name': 'Arjun Kumar',
        'persona': 'Trusted Professional',
        'platform': 'swiggy',
        'city': 'Chennai',
        'worker_id': 'SWG-GOOD-001',
        'lat': 13.0827,
        'lon': 80.2707,
    },
    'bad_actor': {
        'email': 'bad.actor@gigshield.demo',
        'phone': '+919100000002',
        'username': 'bad_actor',
        'name': 'Ravi Sharma',
        'persona': 'System Gamer',
        'platform': 'zomato',
        'city': 'Bengaluru',
        'worker_id': 'ZMT-BAD-002',
        'lat': 12.9716,
        'lon': 77.5946,
    },
    'edge_case': {
        'email': 'edge.case@gigshield.demo',
        'phone': '+919100000003',
        'username': 'edge_case',
        'name': 'Meena Das',
        'persona': 'Uncertain Case',
        'platform': 'swiggy',
        'city': 'Mumbai',
        'worker_id': 'SWG-EDGE-003',
        'lat': 19.0760,
        'lon': 72.8777,
    },
    'low_risk': {
        'email': 'low.risk@gigshield.demo',
        'phone': '+919100000004',
        'username': 'low_risk',
        'name': 'Karthik Nair',
        'persona': 'Normal Day',
        'platform': 'zomato',
        'city': 'Hyderabad',
        'worker_id': 'ZMT-LOW-004',
        'lat': 17.3850,
        'lon': 78.4867,
    },
    'premium_success': {
        'email': 'suresh.patel@gigshield.demo',
        'phone': '+919100000005',
        'username': 'premium_success',
        'name': 'Suresh Patel',
        'persona': 'Premium Success User',
        'platform': 'swiggy',
        'city': 'Pune',
        'worker_id': 'SWG-SURESH-005',
        'lat': 18.5204,
        'lon': 73.8567,
    },
}


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _round(value: float, places: int = 2) -> float:
    return float(round(float(value), places))


def set_simulation_mode(enabled: bool) -> None:
    global _SIMULATION_MODE_OVERRIDE
    _SIMULATION_MODE_OVERRIDE = bool(enabled)


def is_simulation_mode() -> bool:
    if _SIMULATION_MODE_OVERRIDE is not None:
        return _SIMULATION_MODE_OVERRIDE
    return str(os.getenv('SIMULATION_MODE', 'false')).strip().lower() in {'1', 'true', 'yes', 'on'}


def _latest_simulation_profile(db: Session, user_id: int) -> str | None:
    record = (
        db.query(UserBehavior)
        .filter(UserBehavior.user_id == int(user_id), UserBehavior.event_type == 'simulation_profile')
        .order_by(UserBehavior.observed_at.desc(), UserBehavior.id.desc())
        .first()
    )
    if record and (record.behavior_metadata or {}).get('user_type'):
        return str(record.behavior_metadata['user_type'])

    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        return None
    for user_type, config in SIMULATED_USERS.items():
        if user.username == config['username']:
            return user_type
    return None


def has_simulated_profile(db: Session, user_id: int) -> bool:
    return _latest_simulation_profile(db, user_id) is not None


def get_simulated_environment(user_type: str, lat: float | None = None, lon: float | None = None) -> dict:
    normalized = user_type.strip().lower()
    if normalized not in SIMULATED_USERS:
        normalized = 'edge_case'
    base = SIMULATED_USERS[normalized]
    now = _utcnow()

    if normalized == 'good_actor':
        temperature = 29.0
        humidity = 88.0
        wind_speed = 18.0
        rain = 11.5
        aqi = 92.0
        traffic_index = 1.92
        traffic_level = 'HIGH'
    elif normalized == 'premium_success':
        temperature = 28.0
        humidity = 90.0
        wind_speed = 20.0
        rain = 13.2
        aqi = 86.0
        traffic_index = 1.74
        traffic_level = 'HIGH'
    elif normalized == 'bad_actor':
        temperature = 30.0
        humidity = 54.0
        wind_speed = 8.0
        rain = 0.2
        aqi = 58.0
        traffic_index = 1.05
        traffic_level = 'LOW'
    elif normalized == 'low_risk':
        temperature = 27.0
        humidity = 46.0
        wind_speed = 6.0
        rain = 0.0
        aqi = 42.0
        traffic_index = 1.0
        traffic_level = 'LOW'
    else:
        temperature = 32.0
        humidity = 66.0
        wind_speed = 10.0
        rain = 4.4
        aqi = 104.0
        traffic_index = 1.34
        traffic_level = 'MEDIUM'

    hourly_forecast = []
    for offset in range(24):
        rain_factor = rain * (0.8 if offset < 6 else (0.55 if offset < 12 else 0.35))
        traffic_factor = traffic_index if 7 <= ((now.hour + offset) % 24) <= 10 or 17 <= ((now.hour + offset) % 24) <= 21 else max(1.0, traffic_index - 0.18)
        hourly_forecast.append(
            {
                'time': (now + timedelta(hours=offset)).isoformat(),
                'hour': (now.hour + offset) % 24,
                'temperature': _round(temperature + random.uniform(-1.5, 1.5)),
                'wind_speed': _round(max(1.0, wind_speed + random.uniform(-2.0, 2.0))),
                'humidity': _round(min(98.0, max(28.0, humidity + random.uniform(-6.0, 6.0)))),
                'rain_estimate': _round(max(0.0, rain_factor + random.uniform(-1.2, 1.2))),
                'aqi': _round(max(25.0, aqi + random.uniform(-8.0, 12.0))),
                'traffic_index': _round(max(1.0, traffic_factor + random.uniform(-0.08, 0.08)), 3),
            }
        )

    time_slot_risk = {
        'morning': 'HIGH' if traffic_index >= 1.6 or rain >= 8 else ('MEDIUM' if traffic_index >= 1.2 or rain >= 3 else 'LOW'),
        'afternoon': 'MEDIUM' if normalized in {'edge_case', 'good_actor', 'premium_success'} else 'LOW',
        'evening': 'HIGH' if normalized in {'good_actor', 'premium_success'} else ('MEDIUM' if normalized == 'edge_case' else 'LOW'),
        'night': 'LOW',
    }
    next_6hr = _round(min(1.0, ((rain / 12.0) * 0.4) + (((traffic_index - 1.0) / 1.2) * 0.3) + (((aqi - 50.0) / 250.0) * 0.3)), 3)

    return {
        'weather': {
            'temperature': _round(temperature),
            'humidity': _round(humidity),
            'wind_speed': _round(wind_speed),
            'rainfall': _round(rain),
            'rain_estimate': _round(rain),
            'hourly': hourly_forecast,
        },
        'aqi': {
            'aqi': int(round(max(1, min(5, aqi / 60)))),
            'aqi_index': _round(aqi),
            'pm2_5': _round(aqi * 0.6),
            'pm10': _round(aqi * 0.95),
        },
        'traffic': {
            'traffic_score': _round(traffic_index, 3),
            'traffic_index': _round(traffic_index, 3),
            'traffic_level': traffic_level,
            'route_duration_seconds': _round(1680 * traffic_index),
            'free_flow_duration_seconds': 1680.0,
        },
        'context': {
            'hour': now.hour,
            'day_type': 'weekend' if now.weekday() >= 5 else 'weekday',
        },
        'snapshot': {
            'temperature': _round(temperature),
            'wind_speed': _round(wind_speed),
            'humidity': _round(humidity),
            'rain_estimate': _round(rain),
            'aqi': _round(aqi),
            'traffic_index': _round(traffic_index, 3),
        },
        'hyper_local_risk': 1.38 if normalized == 'premium_success' else (1.32 if normalized == 'good_actor' else (1.08 if normalized == 'edge_case' else 0.88 if normalized == 'low_risk' else 0.96)),
        'hyper_local_analysis': {
            'hyper_local_risk': 1.38 if normalized == 'premium_success' else (1.32 if normalized == 'good_actor' else (1.08 if normalized == 'edge_case' else 0.88 if normalized == 'low_risk' else 0.96)),
            'insight': (
                'A protected worker is facing strong weather disruption beyond the recent local average'
                if normalized == 'premium_success'
                else
                'Disruption is much higher than the recent local average'
                if normalized == 'good_actor'
                else 'Conditions look normal despite the claim pattern'
                if normalized == 'bad_actor'
                else 'Conditions are slightly worse than the recent average'
                if normalized == 'edge_case'
                else 'Conditions are calmer than the recent local average'
            ),
            'baseline_snapshot': {
                'temperature': _round(temperature - 2.0),
                'wind_speed': _round(max(1.0, wind_speed - 2.0)),
                'humidity': _round(max(20.0, humidity - 8.0)),
                'rain_estimate': _round(max(0.0, rain * 0.4)),
                'aqi': _round(max(25.0, aqi - 18.0)),
                'traffic_index': _round(max(1.0, traffic_index - 0.22), 3),
            },
            'source': 'simulation',
        },
        'time_slot_risk': time_slot_risk,
        'predictive_risk': {
            'next_6hr_risk': next_6hr,
            'trend': 'increasing' if normalized in {'good_actor', 'premium_success'} else ('stable' if normalized in {'edge_case', 'bad_actor'} else 'decreasing'),
        },
        'hourly_forecast': hourly_forecast,
        'simulation_meta': {
            'user_type': normalized,
            'lat': lat if lat is not None else base['lat'],
            'lon': lon if lon is not None else base['lon'],
        },
    }


def get_simulated_environment_for_user(db: Session, user_id: int, lat: float, lon: float) -> dict:
    user_type = _latest_simulation_profile(db, user_id) or 'edge_case'
    return get_simulated_environment(user_type=user_type, lat=lat, lon=lon)


def _ensure_user(db: Session, user_type: str) -> User:
    config = SIMULATED_USERS[user_type]
    user = db.query(User).filter(User.username == config['username']).first()
    if user is None:
        user = User(
            email=config['email'],
            phone=config['phone'],
            username=config['username'],
            name=config['name'],
            password_hash=hash_password(DEFAULT_SIMULATION_PASSWORD),
            is_email_verified=True,
            is_phone_verified=True,
            is_account_confirmed=True,
            is_digilocker_verified=True,
            has_completed_first_login_2fa=True,
            verified_at=_utcnow(),
        )
        db.add(user)
        db.flush()
    else:
        user.email = config['email']
        user.phone = config['phone']
        user.name = config['name']
        user.password_hash = hash_password(DEFAULT_SIMULATION_PASSWORD)
        user.is_email_verified = True
        user.is_phone_verified = True
        user.is_account_confirmed = True
        user.is_digilocker_verified = True
        user.has_completed_first_login_2fa = True
        user.verified_at = _utcnow()
    return user


def _ensure_profile_and_settings(db: Session, user: User, user_type: str) -> None:
    config = SIMULATED_USERS[user_type]
    profile = db.query(Profile).filter(Profile.user_id == user.id).first()
    if profile is None:
        profile = Profile(user_id=user.id)
        db.add(profile)
    profile.platform = config['platform']
    profile.city = config['city']

    settings = db.query(UserSettings).filter(UserSettings.user_id == user.id).first()
    if settings is None:
        settings = UserSettings(user_id=user.id, ml_consent=True, data_sharing_consent=True)
        db.add(settings)
    settings.notification_preferences = {
        'allow_model_training': True,
        'simulation_user': True,
        'user_type': user_type,
        'persona': config.get('persona'),
    }

    account = (
        db.query(GigAccount)
        .filter(GigAccount.user_id == user.id, GigAccount.platform == config['platform'])
        .first()
    )
    if account is None:
        db.add(
            GigAccount(
                user_id=user.id,
                platform=config['platform'],
                worker_id=config['worker_id'],
            )
        )


def _record_user_behavior(db: Session, user: User, user_type: str) -> None:
    avg_income_by_user_type = {
        'good_actor': 945.0,
        'bad_actor': 802.0,
        'edge_case': 768.0,
        'low_risk': 692.0,
        'premium_success': 928.0,
    }
    avg_loss_by_user_type = {
        'good_actor': 210.0,
        'bad_actor': 42.0,
        'edge_case': 135.0,
        'low_risk': 18.0,
        'premium_success': 390.0,
    }
    db.add(
        UserBehavior(
            user_id=user.id,
            event_type='simulation_profile',
            event_value=user_type,
            confidence_score=1.0,
            behavior_metadata={
                'user_type': user_type,
                'simulation_source': 'input_only',
                'persona': SIMULATED_USERS[user_type].get('persona'),
            },
        )
    )
    work_pattern = (
        'steady'
        if user_type in {'good_actor', 'premium_success'}
        else 'anomalous'
        if user_type == 'bad_actor'
        else 'variable'
        if user_type == 'edge_case'
        else 'low_risk'
    )
    db.add(
        UserBehavior(
            user_id=user.id,
            event_type='behavior_snapshot',
            event_value=work_pattern,
            confidence_score=0.92,
            behavior_metadata={
                'avg_income': avg_income_by_user_type.get(user_type, 0.0),
                'avg_loss': avg_loss_by_user_type.get(user_type, 0.0),
                'work_pattern': work_pattern,
                'source': 'simulation_input',
                'persona': SIMULATED_USERS[user_type].get('persona'),
            },
        )
    )


def _clear_policy_state(db: Session, user: User) -> None:
    db.query(BlockchainRecord).filter(BlockchainRecord.user_id == user.id).delete(synchronize_session=False)
    db.query(ClaimHistory).filter(ClaimHistory.user_id == user.id).delete(synchronize_session=False)
    db.query(Claim).filter(Claim.user_id == user.id).delete(synchronize_session=False)
    db.query(BankTransaction).filter(BankTransaction.user_id == user.id).delete(synchronize_session=False)
    db.query(Policy).filter(Policy.user_id == user.id).delete(synchronize_session=False)


def _seed_good_actor_story(db: Session, user: User) -> None:
    account = link_account(
        db,
        user_id=user.id,
        account_number='50123456789001',
        ifsc='HDFC0001001',
        opening_balance=11600.0,
    )
    policy = create_policy(user_id=user.id, db=db, start_date=date.today() - timedelta(days=2))
    refresh_policy_status(policy)
    premium_amount = 185.0
    log_transaction(
        db,
        user_id=user.id,
        transaction_type='PREMIUM_PAYMENT',
        amount=premium_amount,
        reference_id=f'premium_{user.id}_{policy.id}',
        metadata={'remark': f'Weekly premium paid for policy #{policy.id}', 'scenario': 'good_actor'},
    )
    create_policy_record(user_id=user.id, premium=premium_amount, baseline_income=945.0, policy_id=policy.id, db=db)
    account.balance = _round(account.balance - premium_amount)


def _seed_bad_actor_story(db: Session, user: User) -> None:
    account = link_account(
        db,
        user_id=user.id,
        account_number='50123456789002',
        ifsc='HDFC0001002',
        opening_balance=10950.0,
    )
    policy = create_policy(user_id=user.id, db=db, start_date=date.today() - timedelta(days=7))
    refresh_policy_status(policy)
    premium_amount = 82.0
    fraud_score = 0.86
    claim_reference = f'CLAIM-RAVI-{policy.id}'
    log_transaction(
        db,
        user_id=user.id,
        transaction_type='PREMIUM_PAYMENT',
        amount=premium_amount,
        reference_id=f'premium_{user.id}_{policy.id}',
        metadata={'remark': f'Weekly premium paid for policy #{policy.id}', 'scenario': 'bad_actor'},
    ).created_at = _utcnow() - timedelta(days=7)
    claim = Claim(
        user_id=user.id,
        week=policy.start_date.strftime('%G-W%V'),
        loss=280.0,
        payout=0.0,
        fraud_score=fraud_score,
        status='REJECTED',
        reasons_json=json.dumps(
            [
                'No strong disruption triggers were active',
                'Claimed loss did not match the environment pattern',
            ]
        ),
        created_at=_utcnow(),
    )
    db.add(claim)
    db.flush()
    db.add(
        ClaimHistory(
            user_id=user.id,
            policy_id=policy.id,
            claim_reference=claim_reference,
            claim_date=date.today(),
            status='REJECTED',
            predicted_loss=55.0,
            actual_loss=280.0,
            claimed_loss=280.0,
            approved_payout=0.0,
            fraud_score=fraud_score,
            trigger_snapshot={
                'active_triggers': [],
                'trigger_flags': {'rain': 0.0, 'traffic': 0.0, 'aqi': 0.0, 'heat': 0.0, 'combined': 0.0},
                'risk_score': 0.09,
                'baseline_income': 802.0,
            },
            reasons=[
                'Claimed loss is inconsistent with live disruption data',
                'User behavior deviates from the expected loss pattern',
            ],
            review_notes='Rejected system gamer demo case',
        )
    )
    create_policy_record(user_id=user.id, premium=premium_amount, baseline_income=802.0, policy_id=policy.id, db=db)
    log_claim(
        claim_id=claim_reference,
        details={
            'user_id': user.id,
            'policy_id': policy.id,
            'loss': 280.0,
            'payout': 0.0,
            'status': 'REJECTED',
            'fraud_score': fraud_score,
        },
        db=db,
    )
    account.balance = _round(account.balance - premium_amount)


def _seed_edge_case_story(db: Session, user: User) -> None:
    account = link_account(
        db,
        user_id=user.id,
        account_number='50123456789003',
        ifsc='HDFC0001003',
        opening_balance=11150.0,
    )
    policy = create_policy(user_id=user.id, db=db, start_date=date.today() - timedelta(days=7))
    refresh_policy_status(policy)
    premium_amount = 118.0
    fraud_score = 0.56
    claim_reference = f'CLAIM-MEENA-{policy.id}'
    log_transaction(
        db,
        user_id=user.id,
        transaction_type='PREMIUM_PAYMENT',
        amount=premium_amount,
        reference_id=f'premium_{user.id}_{policy.id}',
        metadata={'remark': f'Weekly premium paid for policy #{policy.id}', 'scenario': 'edge_case'},
    ).created_at = _utcnow() - timedelta(days=7)
    claim = Claim(
        user_id=user.id,
        week=policy.start_date.strftime('%G-W%V'),
        loss=170.0,
        payout=0.0,
        fraud_score=fraud_score,
        status='FLAGGED',
        reasons_json=json.dumps(
            [
                'Moderate disruption was detected, but the loss pattern is borderline',
                'Manual review is recommended',
            ]
        ),
        created_at=_utcnow(),
    )
    db.add(claim)
    db.flush()
    db.add(
        ClaimHistory(
            user_id=user.id,
            policy_id=policy.id,
            claim_reference=claim_reference,
            claim_date=date.today(),
            status='FLAGGED',
            predicted_loss=140.0,
            actual_loss=170.0,
            claimed_loss=170.0,
            approved_payout=0.0,
            fraud_score=fraud_score,
            trigger_snapshot={
                'active_triggers': ['RAIN_TRIGGER'],
                'trigger_flags': {'rain': 1.0, 'traffic': 0.0, 'aqi': 0.0, 'heat': 0.0, 'combined': 0.0},
                'risk_score': 0.37,
                'baseline_income': 768.0,
            },
            reasons=[
                'Loss pattern is plausible but not strong enough for auto approval',
                'This case should be reviewed manually',
            ],
            review_notes='Flagged uncertain demo case',
        )
    )
    create_policy_record(user_id=user.id, premium=premium_amount, baseline_income=768.0, policy_id=policy.id, db=db)
    log_claim(
        claim_id=claim_reference,
        details={
            'user_id': user.id,
            'policy_id': policy.id,
            'loss': 170.0,
            'payout': 0.0,
            'status': 'FLAGGED',
            'fraud_score': fraud_score,
        },
        db=db,
    )
    account.balance = _round(account.balance - premium_amount)


def _seed_low_risk_story(db: Session, user: User) -> None:
    link_account(
        db,
        user_id=user.id,
        account_number='50123456789004',
        ifsc='HDFC0001004',
        opening_balance=10480.0,
    )


def _daily_profile(user_type: str, day: date) -> dict:
    weekend = day.weekday() >= 5
    if user_type == 'good_actor':
        base_income = random.uniform(820, 1120)
        orders = random.randint(18, 28)
        hours = random.uniform(7.5, 10.0)
        disruption = 'rain' if random.random() < 0.45 else 'traffic'
        rain = random.uniform(7.5, 16.0)
        traffic_score = random.uniform(1.5, 2.0)
        aqi_level = random.randint(2, 3)
        income_multiplier = random.uniform(0.48, 0.74)
    elif user_type == 'premium_success':
        base_income = random.uniform(860, 1160)
        orders = random.randint(20, 30)
        hours = random.uniform(7.5, 9.5)
        disruption = 'rain'
        rain = random.uniform(9.0, 17.0)
        traffic_score = random.uniform(1.45, 1.9)
        aqi_level = random.randint(2, 3)
        income_multiplier = random.uniform(0.46, 0.7)
    elif user_type == 'bad_actor':
        base_income = random.uniform(760, 980)
        orders = random.randint(16, 24)
        hours = random.uniform(7.0, 9.0)
        disruption = 'none'
        rain = random.uniform(0.0, 1.0)
        traffic_score = random.uniform(1.0, 1.12)
        aqi_level = random.randint(1, 2)
        income_multiplier = random.uniform(0.96, 1.03)
    elif user_type == 'low_risk':
        base_income = random.uniform(640, 860)
        orders = random.randint(14, 20)
        hours = random.uniform(6.5, 8.5)
        disruption = 'none'
        rain = 0.0
        traffic_score = random.uniform(1.0, 1.08)
        aqi_level = 1
        income_multiplier = random.uniform(0.98, 1.06)
    else:
        base_income = random.uniform(700, 930)
        orders = random.randint(15, 23)
        hours = random.uniform(6.5, 8.8)
        disruption = random.choice(['traffic', 'low_demand', 'none'])
        rain = random.uniform(1.5, 6.0)
        traffic_score = random.uniform(1.18, 1.42)
        aqi_level = random.randint(2, 3)
        income_multiplier = random.uniform(0.72, 0.92)

    if weekend:
        base_income += random.uniform(90, 180)
        orders += random.randint(2, 5)

    earnings = base_income * income_multiplier
    if disruption != 'none':
        orders = max(8, int(round(orders * income_multiplier)))

    return {
        'expected_income': _round(base_income),
        'earnings': _round(earnings),
        'orders_completed': max(6, orders),
        'hours_worked': _round(hours),
        'disruption_type': disruption,
        'rainfall': _round(rain),
        'traffic_score': _round(traffic_score, 3),
        'aqi_level': aqi_level,
        'is_weekend': weekend,
    }


def _generate_income_inputs(db: Session, user: User, user_type: str, days: int, regenerate_income: bool) -> None:
    config = SIMULATED_USERS[user_type]
    start_date = date.today() - timedelta(days=days - 1)
    existing = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == user.id, GigIncome.date >= start_date)
        .all()
    )
    existing_by_date = {item.date: item for item in existing}

    if regenerate_income:
        for item in existing:
            db.delete(item)
        existing_by_date = {}

    generated_earnings = []
    for offset in range(days):
        target_date = start_date + timedelta(days=offset)
        day_profile = _daily_profile(user_type, target_date)
        earnings = day_profile['earnings']
        orders_completed = day_profile['orders_completed']
        hours_worked = day_profile['hours_worked']
        earnings_per_hour = _round(earnings / max(hours_worked, 1.0))
        earnings_per_order = _round(earnings / max(orders_completed, 1))
        current = existing_by_date.get(target_date)
        payload = {
            'user_id': user.id,
            'date': target_date,
            'orders_completed': orders_completed,
            'hours_worked': hours_worked,
            'earnings': earnings,
            'earnings_per_order': earnings_per_order,
            'platform': config['platform'],
            'disruption_type': day_profile['disruption_type'],
            'weather_condition': 'rain' if day_profile['rainfall'] > 0 else 'clear',
            'temperature': _round(27 + random.uniform(-2.0, 6.0)),
            'humidity': _round(52 + random.uniform(-6.0, 20.0)),
            'rainfall': day_profile['rainfall'],
            'wind_speed': _round(5 + random.uniform(0.0, 10.0)),
            'aqi_level': day_profile['aqi_level'],
            'pm2_5': _round(18 + (day_profile['aqi_level'] * 10) + random.uniform(0.0, 8.0)),
            'pm10': _round(34 + (day_profile['aqi_level'] * 14) + random.uniform(0.0, 10.0)),
            'traffic_level': 'HIGH' if day_profile['traffic_score'] >= 1.5 else 'MEDIUM' if day_profile['traffic_score'] >= 1.2 else 'LOW',
            'traffic_score': day_profile['traffic_score'],
            'peak_hours_active': _round(min(hours_worked, 4.8)),
            'off_peak_hours': _round(max(0.0, hours_worked - min(hours_worked, 4.8))),
            'expected_orders': max(orders_completed, orders_completed + random.randint(1, 5)),
            'order_acceptance_rate': _round(random.uniform(0.88, 0.98), 3),
            'order_completion_rate': _round(random.uniform(0.9, 0.99), 3),
            'distance_travelled_km': _round(random.uniform(32.0, 74.0)),
            'avg_delivery_time_mins': _round(random.uniform(19.0, 41.0)),
            'earnings_per_hour': earnings_per_hour,
            'efficiency_score': _round(orders_completed / max(hours_worked, 1.0), 3),
            'loss_amount': _round(max(0.0, day_profile['expected_income'] - earnings)),
            'earnings_variance': _round(earnings - day_profile['expected_income']),
            'risk_score': _round(min(1.0, max(0.0, ((day_profile['traffic_score'] - 1.0) * 0.45) + (day_profile['rainfall'] / 20.0) * 0.35 + (day_profile['aqi_level'] / 5.0) * 0.2)), 3),
            'is_weekend': day_profile['is_weekend'],
            'is_holiday': False,
            'city': config['city'],
        }
        if current is None:
            db.add(GigIncome(**payload))
        else:
            for key, value in payload.items():
                if hasattr(current, key):
                    setattr(current, key, value)
        generated_earnings.append(earnings)

    profile = db.query(Profile).filter(Profile.user_id == user.id).first()
    if profile is not None and generated_earnings:
        profile.avg_income = _round(sum(generated_earnings) / len(generated_earnings))


def _seed_premium_success_story(db: Session, user: User) -> None:
    db.query(BlockchainRecord).filter(BlockchainRecord.user_id == user.id).delete(synchronize_session=False)
    db.query(ClaimHistory).filter(ClaimHistory.user_id == user.id).delete(synchronize_session=False)
    db.query(Claim).filter(Claim.user_id == user.id).delete(synchronize_session=False)
    db.query(BankTransaction).filter(BankTransaction.user_id == user.id).delete(synchronize_session=False)
    db.query(Policy).filter(Policy.user_id == user.id).delete(synchronize_session=False)

    account = link_account(
        db,
        user_id=user.id,
        account_number='50123456789012',
        ifsc='HDFC0005678',
        opening_balance=12500.0,
    )

    policy = create_policy(user_id=user.id, db=db, start_date=date.today() - timedelta(days=7))
    refresh_policy_status(policy)

    premium_amount = 150.0
    baseline_income = 920.0
    loss_amount = 400.0
    payout_amount = 320.0
    fraud_score = 0.18

    premium_txn = log_transaction(
        db,
        user_id=user.id,
        transaction_type='PREMIUM_PAYMENT',
        amount=premium_amount,
        reference_id=f'premium_{user.id}_{policy.id}',
        metadata={
            'remark': f'Weekly premium paid for policy #{policy.id}',
            'scenario': 'premium_success',
        },
    )
    premium_txn.created_at = _utcnow() - timedelta(days=7)

    claim = Claim(
        user_id=user.id,
        week=policy.start_date.strftime('%G-W%V'),
        loss=_round(loss_amount),
        payout=_round(payout_amount),
        fraud_score=fraud_score,
        status='APPROVED',
        reasons_json=json.dumps(
            [
                'Heavy rain trigger was active',
                'Traffic disruption reduced delivery capacity',
                'Income loss matched the weather anomaly',
            ]
        ),
        created_at=_utcnow(),
    )
    db.add(claim)
    db.flush()

    claim_history = ClaimHistory(
        user_id=user.id,
        policy_id=policy.id,
        claim_reference=f'CLAIM-SURESH-{policy.id}',
        claim_date=date.today(),
        status='APPROVED',
        predicted_loss=_round(365.0),
        actual_loss=_round(loss_amount),
        claimed_loss=_round(loss_amount),
        approved_payout=_round(payout_amount),
        fraud_score=fraud_score,
        trigger_snapshot={
            'active_triggers': ['RAIN_TRIGGER', 'COMBINED_TRIGGER'],
            'trigger_flags': {
                'rain': 1.0,
                'traffic': 0.0,
                'aqi': 0.0,
                'heat': 0.0,
                'combined': 1.0,
            },
            'risk_score': 0.64,
            'baseline_income': baseline_income,
        },
        reasons=[
            'Protected worker experienced a real disruption after paying premium',
            'Weather anomaly matched reduced earnings',
        ],
        review_notes='Auto-approved premium success demo case',
    )
    db.add(claim_history)
    db.flush()

    payout_txn = log_transaction(
        db,
        user_id=user.id,
        transaction_type='CLAIM_PAYOUT',
        amount=payout_amount,
        reference_id=f'payout_{claim_history.claim_reference}',
        metadata={
            'remark': 'Auto payout credited after approved claim',
            'claim_reference': claim_history.claim_reference,
            'scenario': 'premium_success',
        },
    )
    payout_txn.created_at = _utcnow()
    account.balance = _round(account.balance - premium_amount + payout_amount)

    create_policy_record(
        user_id=user.id,
        premium=premium_amount,
        baseline_income=baseline_income,
        policy_id=policy.id,
        db=db,
    )
    log_claim(
        claim_id=claim_history.claim_reference,
        details={
            'user_id': user.id,
            'policy_id': policy.id,
            'claim_history_id': claim_history.id,
            'loss': _round(loss_amount),
            'payout': _round(payout_amount),
            'status': 'APPROVED',
        },
        db=db,
    )
    record_payout(
        claim_id=claim_history.claim_reference,
        amount=payout_amount,
        user_id=user.id,
        db=db,
    )


def simulate_inputs(db: Session, *, enable_simulation: bool = True, regenerate_income: bool = True, days: int = 30) -> dict:
    set_simulation_mode(enable_simulation)
    seeded_users = []

    for user_type in SIMULATED_USERS:
        user = _ensure_user(db, user_type)
        _ensure_profile_and_settings(db, user, user_type)
        _generate_income_inputs(db, user, user_type, days=days, regenerate_income=regenerate_income)
        _record_user_behavior(db, user, user_type)
        _clear_policy_state(db, user)
        if user_type == 'good_actor':
            _seed_good_actor_story(db, user)
        elif user_type == 'bad_actor':
            _seed_bad_actor_story(db, user)
        elif user_type == 'edge_case':
            _seed_edge_case_story(db, user)
        elif user_type == 'low_risk':
            _seed_low_risk_story(db, user)
        if user_type == 'premium_success':
            _seed_premium_success_story(db, user)
        config = SIMULATED_USERS[user_type]
        seeded_users.append(
            {
                'user_type': user_type,
                'user_id': user.id,
                'username': user.username,
                'email': user.email,
                'city': config['city'],
                'platform': config['platform'],
                'lat': config['lat'],
                'lon': config['lon'],
            }
        )

    db.commit()
    return {
        'simulation_mode': is_simulation_mode(),
        'message': 'Simulation input data generated successfully',
        'users': seeded_users,
        'days_generated': days,
        'note': 'Only input data was simulated. Risk, premium, and claim outputs still come from the real engines.',
    }
