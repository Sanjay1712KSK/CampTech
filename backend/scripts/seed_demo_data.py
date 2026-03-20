import json
import random
import sys
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = CURRENT_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from database.db import SessionLocal, ensure_schema
from models.bank_account import BankAccount, BankTransaction
from models.digilocker_request import DigiLockerRequest
from models.gig_income import GigIncome
from models.insurance import Claim, Policy
from models.user_model import User
from services.bank_service import link_account, log_transaction
from services.digilocker_service import MOCK_DATASET_PATH, refresh_mock_documents
from utils.security import hash_password


RANDOM_SEED = 20260320
CITY = 'Chennai'

USERS = [
    {
        'name': 'Perfect User',
        'email': 'perfect_user@test.com',
        'phone': '9000000001',
        'password': 'securePass123',
        'scenario': 'approved_claim',
    },
    {
        'name': 'Fraud User',
        'email': 'fraud_user@test.com',
        'phone': '9000000002',
        'password': 'securePass123',
        'scenario': 'fraud_rejected',
    },
    {
        'name': 'Insufficient Data User',
        'email': 'insufficient_user@test.com',
        'phone': '9000000003',
        'password': 'securePass123',
        'scenario': 'insufficient_data',
    },
    {
        'name': 'Normal Week User',
        'email': 'normal_week_user@test.com',
        'phone': '9000000004',
        'password': 'securePass123',
        'scenario': 'normal_week',
    },
    {
        'name': 'Escalation User',
        'email': 'escalation_user@test.com',
        'phone': '9000000005',
        'password': 'securePass123',
        'scenario': 'needs_review',
    },
]


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def _is_weekend(day: date) -> bool:
    return day.weekday() >= 5


def _base_record(
    user_id: int,
    day: date,
    *,
    platform: str,
    city: str,
    disruption_type: str,
    earnings: float,
    orders_completed: int,
    hours_worked: float,
    weather_condition: str,
    rainfall: float,
    temperature: float,
    humidity: float,
    traffic_level: str,
    traffic_score: float,
    wind_speed: float = 6.0,
    aqi_level: int = 2,
) -> dict:
    earnings_per_order = earnings / max(orders_completed, 1)
    earnings_per_hour = earnings / max(hours_worked, 1.0)
    expected_orders = max(orders_completed, orders_completed + random.randint(0, 4))
    peak_hours_active = _clamp(hours_worked * 0.62, 2.0, hours_worked)
    off_peak_hours = max(0.0, hours_worked - peak_hours_active)
    baseline_reference = expected_orders * 48.0
    loss_amount = max(0.0, baseline_reference - earnings)
    earnings_variance = earnings - baseline_reference
    risk_score = _clamp(
        (rainfall / 10.0) * 0.3
        + ((traffic_score - 0.8) / 1.2) * 0.2
        + ((temperature - 25.0) / 15.0) * 0.15
        + ((aqi_level - 1) / 4.0) * 0.15
        + (loss_amount / max(baseline_reference, 1.0)) * 0.2,
        0.0,
        1.0,
    )
    return {
        'user_id': user_id,
        'date': day,
        'orders_completed': orders_completed,
        'hours_worked': _round(hours_worked),
        'earnings': _round(earnings),
        'earnings_per_order': _round(earnings_per_order),
        'platform': platform,
        'disruption_type': disruption_type,
        'weather_condition': weather_condition,
        'temperature': _round(temperature),
        'humidity': _round(humidity),
        'rainfall': _round(rainfall),
        'wind_speed': _round(wind_speed),
        'aqi_level': aqi_level,
        'pm2_5': _round(16 + (aqi_level * 9)),
        'pm10': _round(26 + (aqi_level * 14)),
        'traffic_level': traffic_level,
        'traffic_score': _round(traffic_score),
        'peak_hours_active': _round(peak_hours_active),
        'off_peak_hours': _round(off_peak_hours),
        'expected_orders': expected_orders,
        'order_acceptance_rate': _round(random.uniform(0.82, 0.98)),
        'order_completion_rate': _round(random.uniform(0.86, 0.99)),
        'distance_travelled_km': _round(random.uniform(28.0, 70.0)),
        'avg_delivery_time_mins': _round(random.uniform(22.0, 48.0)),
        'earnings_per_hour': _round(earnings_per_hour),
        'efficiency_score': _round(orders_completed / max(hours_worked, 1.0)),
        'loss_amount': _round(loss_amount),
        'earnings_variance': _round(earnings_variance),
        'risk_score': _round(risk_score),
        'is_weekend': _is_weekend(day),
        'is_holiday': day.day in (15, 26),
        'city': city,
    }


def _scenario_records(user_id: int, scenario: str) -> list[dict]:
    records: list[dict] = []
    start_date = date.today() - timedelta(days=29)
    platform = 'swiggy' if user_id % 2 else 'zomato'

    if scenario == 'insufficient_data':
        for offset in range(3):
            day = date.today() - timedelta(days=offset)
            records.append(
                _base_record(
                    user_id,
                    day,
                    platform=platform,
                    city=CITY,
                    disruption_type='none',
                    earnings=760 + (offset * 18),
                    orders_completed=15 + offset,
                    hours_worked=7.2,
                    weather_condition='clear',
                    rainfall=0.0,
                    temperature=31.0,
                    humidity=58.0,
                    traffic_level='MEDIUM',
                    traffic_score=1.1,
                )
            )
        return records

    for offset in range(30):
        day = start_date + timedelta(days=offset)
        in_claim_week = offset >= 22

        if scenario == 'approved_claim':
            if in_claim_week:
                earnings = 360 + ((offset - 22) * 12)
                records.append(
                    _base_record(
                        user_id,
                        day,
                        platform=platform,
                        city=CITY,
                        disruption_type='rain',
                        earnings=earnings,
                        orders_completed=6 + (offset % 3),
                        hours_worked=6.4,
                        weather_condition='rain',
                        rainfall=7.5,
                        temperature=26.5,
                        humidity=88.0,
                        traffic_level='HIGH',
                        traffic_score=1.7,
                        wind_speed=11.0,
                    )
                )
            else:
                records.append(
                    _base_record(
                        user_id,
                        day,
                        platform=platform,
                        city=CITY,
                        disruption_type='none',
                        earnings=940 + ((offset % 5) * 12),
                        orders_completed=18 + (offset % 3),
                        hours_worked=8.2,
                        weather_condition='clear',
                        rainfall=0.0,
                        temperature=31.0,
                        humidity=56.0,
                        traffic_level='MEDIUM',
                        traffic_score=1.1,
                    )
                )
        elif scenario == 'fraud_rejected':
            if in_claim_week:
                records.append(
                    _base_record(
                        user_id,
                        day,
                        platform=platform,
                        city=CITY,
                        disruption_type='rain',
                        earnings=865 + ((offset - 22) * 4),
                        orders_completed=16,
                        hours_worked=7.4,
                        weather_condition='clear',
                        rainfall=0.0,
                        temperature=32.0,
                        humidity=54.0,
                        traffic_level='LOW',
                        traffic_score=0.9,
                    )
                )
            else:
                records.append(
                    _base_record(
                        user_id,
                        day,
                        platform=platform,
                        city=CITY,
                        disruption_type='none',
                        earnings=910 + ((offset % 4) * 10),
                        orders_completed=18,
                        hours_worked=7.8,
                        weather_condition='clear',
                        rainfall=0.0,
                        temperature=31.0,
                        humidity=55.0,
                        traffic_level='LOW',
                        traffic_score=0.95,
                    )
                )
        elif scenario == 'normal_week':
            records.append(
                _base_record(
                    user_id,
                    day,
                    platform=platform,
                    city=CITY,
                    disruption_type='none',
                    earnings=870 + ((offset % 6) * 11),
                    orders_completed=17 + (offset % 2),
                    hours_worked=7.7,
                    weather_condition='clear',
                    rainfall=0.0,
                    temperature=30.5,
                    humidity=57.0,
                    traffic_level='MEDIUM',
                    traffic_score=1.0,
                )
            )
        elif scenario == 'needs_review':
            city = CITY if offset < 24 else 'Bengaluru'
            if in_claim_week:
                disruption_type = 'traffic' if offset % 2 == 0 else 'rain'
                records.append(
                    _base_record(
                        user_id,
                        day,
                        platform=platform,
                        city=city,
                        disruption_type=disruption_type,
                        earnings=640 + ((offset - 22) * 16),
                        orders_completed=10 + (offset % 3),
                        hours_worked=7.0,
                        weather_condition='rain' if disruption_type == 'rain' else 'clear',
                        rainfall=3.5 if disruption_type == 'rain' else 0.4,
                        temperature=29.5 if disruption_type == 'rain' else 32.0,
                        humidity=74.0,
                        traffic_level='HIGH' if disruption_type == 'traffic' else 'MEDIUM',
                        traffic_score=1.35 if disruption_type == 'traffic' else 1.15,
                    )
                )
            else:
                records.append(
                    _base_record(
                        user_id,
                        day,
                        platform=platform,
                        city=city,
                        disruption_type='none',
                        earnings=880 + ((offset % 4) * 9),
                        orders_completed=17,
                        hours_worked=7.8,
                        weather_condition='clear',
                        rainfall=0.0,
                        temperature=31.2,
                        humidity=56.0,
                        traffic_level='MEDIUM',
                        traffic_score=1.05,
                    )
                )

    return records


def _build_digilocker_documents() -> list[dict]:
    records = []
    for index, user in enumerate(USERS, start=1):
        records.append(
            {
                'document_type': 'aadhaar',
                'document_number': f'{index:02d}3456789012',
                'name': user['name'],
                'dob': f'199{index}-0{(index % 9) + 1}-1{index % 9}',
                'gender': 'Male' if index % 2 else 'Female',
                'address': f'{CITY}, Tamil Nadu',
                'issued_by': 'UIDAI',
                'issued_date': f'202{index % 5}-05-10',
                'status': 'valid',
            }
        )
        records.append(
            {
                'document_type': 'license',
                'document_number': f'TN0{index}AB12{30 + index}',
                'name': user['name'],
                'dob': f'199{index}-0{(index % 9) + 1}-1{index % 9}',
                'gender': 'Male' if index % 2 else 'Female',
                'address': f'{CITY}, Tamil Nadu',
                'issued_by': 'RTO Tamil Nadu',
                'issued_date': f'202{index % 5}-03-15',
                'status': 'valid',
            }
        )

    MOCK_DATASET_PATH.parent.mkdir(parents=True, exist_ok=True)
    MOCK_DATASET_PATH.write_text(json.dumps(records, indent=2), encoding='utf-8')
    refresh_mock_documents()
    return records


def _upsert_users(session) -> list[User]:
    users: list[User] = []
    for payload in USERS:
        user = session.query(User).filter(User.email == payload['email']).one_or_none()
        if user is None:
            user = User(
                name=payload['name'],
                email=payload['email'],
                phone=payload['phone'],
                password=hash_password(payload['password']),
                is_verified=True,
                verified_at=datetime.now(UTC),
            )
            session.add(user)
        else:
            user.name = payload['name']
            user.phone = payload['phone']
            user.password = hash_password(payload['password'])
            user.is_verified = True
            user.verified_at = datetime.now(UTC)
        users.append(user)
    session.flush()
    return users


def _clear_existing_demo_state(session, user_ids: list[int]) -> None:
    session.query(Claim).filter(Claim.user_id.in_(user_ids)).delete(synchronize_session=False)
    session.query(Policy).filter(Policy.user_id.in_(user_ids)).delete(synchronize_session=False)
    session.query(BankTransaction).filter(BankTransaction.user_id.in_(user_ids)).delete(synchronize_session=False)
    session.query(BankAccount).filter(BankAccount.user_id.in_(user_ids)).delete(synchronize_session=False)
    session.query(DigiLockerRequest).filter(DigiLockerRequest.user_id.in_(user_ids)).delete(synchronize_session=False)
    session.query(GigIncome).filter(GigIncome.user_id.in_(user_ids)).delete(synchronize_session=False)


def _seed_verified_request(session, user: User, document_number: str) -> None:
    session.add(
        DigiLockerRequest(
            request_id=f'demo-{user.id}-verified',
            user_id=user.id,
            status='VERIFIED',
            document_type='aadhaar',
            document_number_masked=f'********{document_number[-4:]}',
            consent_given=True,
            verification_score=0.98,
            verified_name=user.name,
            verified_dob='1995-01-01',
            verified_gender='Male',
            verified_address=f'{CITY}, Tamil Nadu',
            issued_by='UIDAI',
            issued_date='2023-01-01',
            blockchain_txn_id=f'MOCK_TXN_{user.id}',
            verified_at=datetime.now(UTC),
        )
    )


def _seed_policy_and_claims(session, user: User, scenario: str) -> None:
    if scenario == 'insufficient_data':
        session.add(
            Policy(
                user_id=user.id,
                start_date=date.today() - timedelta(days=2),
                end_date=date.today() + timedelta(days=5),
                premium_paid=False,
                status='ACTIVE',
            )
        )
        return

    expired_policy = Policy(
        user_id=user.id,
        start_date=date.today() - timedelta(days=8),
        end_date=date.today() - timedelta(days=1),
        premium_paid=True,
        status='EXPIRED',
    )
    session.add(expired_policy)

    if scenario == 'approved_claim':
        session.add(
            Claim(
                user_id=user.id,
                week=expired_policy.start_date.strftime('%G-W%V'),
                loss=2100.0,
                payout=1680.0,
                fraud_score=0.12,
                status='APPROVED',
                reasons_json='[]',
            )
        )
    elif scenario == 'fraud_rejected':
        session.add(
            Claim(
                user_id=user.id,
                week=expired_policy.start_date.strftime('%G-W%V'),
                loss=0.0,
                payout=0.0,
                fraud_score=0.92,
                status='REJECTED',
                reasons_json=json.dumps(['Weather data does not support a rain-related claim']),
            )
        )
    elif scenario == 'normal_week':
        session.add(
            Claim(
                user_id=user.id,
                week=expired_policy.start_date.strftime('%G-W%V'),
                loss=0.0,
                payout=0.0,
                fraud_score=0.25,
                status='REJECTED',
                reasons_json=json.dumps(['No eligible weekly loss detected']),
            )
        )
    elif scenario == 'needs_review':
        session.add(
            Claim(
                user_id=user.id,
                week=expired_policy.start_date.strftime('%G-W%V'),
                loss=1200.0,
                payout=0.0,
                fraud_score=0.58,
                status='NEEDS_REVIEW',
                reasons_json=json.dumps(['Borderline fraud score detected', 'City pattern needs manual review']),
            )
        )


def _seed_financials(session, user: User, scenario: str) -> None:
    account = link_account(
        db=session,
        user_id=user.id,
        account_number=f'50000000{user.id:04d}',
        ifsc='HDFC0001234',
        opening_balance=5000.0,
    )
    session.flush()

    if scenario != 'insufficient_data':
        log_transaction(
            db=session,
            user_id=user.id,
            transaction_type='PREMIUM_PAYMENT',
            amount=214.0,
            metadata={'seeded': True},
        )
        account.balance = _round(account.balance - 214.0)

    if scenario == 'approved_claim':
        log_transaction(
            db=session,
            user_id=user.id,
            transaction_type='CLAIM_PAYOUT',
            amount=1680.0,
            metadata={'seeded': True},
        )
        account.balance = _round(account.balance + 1680.0)


def main() -> None:
    random.seed(RANDOM_SEED)
    ensure_schema()

    session = SessionLocal()
    try:
        documents = _build_digilocker_documents()
        users = _upsert_users(session)
        user_ids = [user.id for user in users]
        _clear_existing_demo_state(session, user_ids)

        for user, payload in zip(users, USERS):
            document_number = next(
                document['document_number']
                for document in documents
                if document['name'] == user.name and document['document_type'] == 'aadhaar'
            )
            _seed_verified_request(session, user, document_number)
            for record in _scenario_records(user.id, payload['scenario']):
                session.add(GigIncome(**record))
            _seed_financials(session, user, payload['scenario'])
            _seed_policy_and_claims(session, user, payload['scenario'])

        session.commit()
        total_gig_records = session.query(GigIncome).filter(GigIncome.user_id.in_(user_ids)).count()
        print(f'Seeded {len(users)} users, {total_gig_records} gig records, {len(documents)} digilocker records')
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


if __name__ == '__main__':
    main()
