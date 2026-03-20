import json
import random
import sys
from datetime import date, timedelta
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = CURRENT_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from database.db import SessionLocal, ensure_schema
from models.digilocker_request import DigiLockerRequest
from models.gig_income import GigIncome
from models.user_model import User
from services.digilocker_service import MOCK_DATASET_PATH, refresh_mock_documents
from utils.security import hash_password


RANDOM_SEED = 20260320
CITY = 'Chennai'
PLATFORMS = ['swiggy', 'zomato']
TRAFFIC_LEVELS = ['LOW', 'MEDIUM', 'HIGH']
WEATHER_LEVELS = ['clear', 'rain', 'storm']
DISRUPTIONS = ['none', 'rain', 'traffic', 'heat', 'strike']

USERS = [
    {
        'name': 'Guidewire User',
        'email': 'guidewire_user@test.com',
        'phone': '9123456789',
        'password': 'securePass123',
        'is_verified': False,
    },
    {
        'name': 'Test Rider One',
        'email': 'test_rider_one@test.com',
        'phone': '9234567890',
        'password': 'securePass123',
        'is_verified': False,
    },
    {
        'name': 'Test Rider Two',
        'email': 'test_rider_two@test.com',
        'phone': '9345678901',
        'password': 'securePass123',
        'is_verified': False,
    },
]


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def round2(value: float) -> float:
    return float(round(value, 2))


def is_holiday(day: date) -> bool:
    return day.day in (15, 26)


def choose_disruption(day: date) -> str:
    if day.weekday() >= 5:
        weights = [0.55, 0.15, 0.15, 0.10, 0.05]
    else:
        weights = [0.50, 0.18, 0.18, 0.09, 0.05]
    return random.choices(DISRUPTIONS, weights=weights, k=1)[0]


def generate_aadhaar(existing_numbers: set[str]) -> str:
    while True:
        value = ''.join(random.choices('0123456789', k=12))
        if value not in existing_numbers:
            existing_numbers.add(value)
            return value


def generate_license(existing_numbers: set[str]) -> str:
    letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    digits = '0123456789'
    while True:
        value = (
            f"TN{random.choice(digits)}{random.choice(digits)}"
            f"{random.choice(letters)}{random.choice(letters)}"
            f"{''.join(random.choices(digits, k=4))}"
        )
        if value not in existing_numbers:
            existing_numbers.add(value)
            return value


def build_digilocker_dataset() -> list[dict]:
    names = [user['name'] for user in USERS]
    genders = {
        'Guidewire User': 'Male',
        'Test Rider One': 'Female',
        'Test Rider Two': 'Male',
    }
    dobs = {
        'Guidewire User': '1998-08-14',
        'Test Rider One': '1996-04-22',
        'Test Rider Two': '1994-12-03',
    }

    existing_numbers: set[str] = set()
    records: list[dict] = []

    records.append(
        {
            'document_type': 'aadhaar',
            'document_number': '123456789012',
            'name': 'Guidewire User',
            'dob': dobs['Guidewire User'],
            'gender': genders['Guidewire User'],
            'address': 'Chennai, Tamil Nadu',
            'issued_by': 'UIDAI',
            'issued_date': '2019-07-12',
            'status': 'valid',
        }
    )
    existing_numbers.add('123456789012')

    for index in range(9):
        name = names[index % len(names)]
        records.append(
            {
                'document_type': 'aadhaar',
                'document_number': generate_aadhaar(existing_numbers),
                'name': name,
                'dob': dobs[name],
                'gender': genders[name],
                'address': 'Chennai, Tamil Nadu',
                'issued_by': 'UIDAI',
                'issued_date': f'20{16 + (index % 8)}-0{(index % 9) + 1}-15',
                'status': 'valid',
            }
        )

    for index in range(10):
        name = names[index % len(names)]
        records.append(
            {
                'document_type': 'license',
                'document_number': generate_license(existing_numbers),
                'name': name,
                'dob': dobs[name],
                'gender': genders[name],
                'address': 'Chennai, Tamil Nadu',
                'issued_by': 'RTO Tamil Nadu',
                'issued_date': f'20{18 + (index % 6)}-{(index % 9) + 1:02d}-10',
                'status': 'valid',
            }
        )

    return records


def write_digilocker_dataset(records: list[dict]) -> int:
    MOCK_DATASET_PATH.parent.mkdir(parents=True, exist_ok=True)
    MOCK_DATASET_PATH.write_text(json.dumps(records, indent=2), encoding='utf-8')
    refresh_mock_documents()
    return len(records)


def upsert_users(session) -> list[User]:
    users: list[User] = []
    for user_payload in USERS:
        user = session.query(User).filter(User.email == user_payload['email']).one_or_none()
        if user is None:
            user = User(
                name=user_payload['name'],
                email=user_payload['email'],
                phone=user_payload['phone'],
                password=hash_password(user_payload['password']),
                is_verified=user_payload['is_verified'],
            )
            session.add(user)
        else:
            user.name = user_payload['name']
            user.phone = user_payload['phone']
            user.is_verified = user_payload['is_verified']
            if not user.password:
                user.password = hash_password(user_payload['password'])
        users.append(user)

    session.flush()
    return users


def build_gig_record(user_id: int, day: date) -> dict:
    disruption_type = choose_disruption(day)
    weekend = day.weekday() >= 5
    holiday = is_holiday(day)

    if disruption_type == 'rain':
        orders_completed = random.randint(6, 14)
        hours_worked = clamp(random.uniform(5.0, 9.0), 4.0, 10.0)
        earnings_per_order = random.uniform(30.0, 42.0)
        weather_condition = random.choice(['rain', 'storm'])
        rainfall = random.uniform(5.5, 10.0)
        temperature = random.uniform(25.0, 31.0)
        humidity = random.uniform(72.0, 90.0)
        wind_speed = random.uniform(6.0, 15.0)
        traffic_level = 'HIGH'
        traffic_score = random.uniform(1.4, 2.0)
        avg_delivery_time_mins = random.uniform(34.0, 52.0)
    elif disruption_type == 'traffic':
        orders_completed = random.randint(8, 18)
        hours_worked = clamp(random.uniform(6.0, 10.0), 4.0, 10.0)
        earnings_per_order = random.uniform(33.0, 48.0)
        weather_condition = 'clear'
        rainfall = random.uniform(0.0, 2.0)
        temperature = random.uniform(28.0, 35.0)
        humidity = random.uniform(45.0, 70.0)
        wind_speed = random.uniform(3.0, 10.0)
        traffic_level = 'HIGH'
        traffic_score = random.uniform(1.5, 2.0)
        avg_delivery_time_mins = random.uniform(38.0, 58.0)
    elif disruption_type == 'heat':
        orders_completed = random.randint(7, 16)
        hours_worked = clamp(random.uniform(4.5, 8.5), 4.0, 10.0)
        earnings_per_order = random.uniform(34.0, 46.0)
        weather_condition = 'clear'
        rainfall = random.uniform(0.0, 1.0)
        temperature = random.uniform(36.0, 40.0)
        humidity = random.uniform(40.0, 62.0)
        wind_speed = random.uniform(1.0, 8.0)
        traffic_level = random.choice(['MEDIUM', 'HIGH'])
        traffic_score = random.uniform(1.0, 1.6)
        avg_delivery_time_mins = random.uniform(28.0, 42.0)
    elif disruption_type == 'strike':
        orders_completed = random.randint(5, 10)
        hours_worked = clamp(random.uniform(4.0, 7.0), 4.0, 10.0)
        earnings_per_order = random.uniform(28.0, 40.0)
        weather_condition = random.choice(WEATHER_LEVELS)
        rainfall = random.uniform(0.0, 4.0)
        temperature = random.uniform(27.0, 34.0)
        humidity = random.uniform(45.0, 78.0)
        wind_speed = random.uniform(2.0, 12.0)
        traffic_level = random.choice(['LOW', 'MEDIUM'])
        traffic_score = random.uniform(0.8, 1.3)
        avg_delivery_time_mins = random.uniform(24.0, 40.0)
    else:
        orders_completed = random.randint(16, 25)
        hours_worked = clamp(random.uniform(6.0, 10.0), 4.0, 10.0)
        earnings_per_order = random.uniform(42.0, 58.0)
        weather_condition = 'clear'
        rainfall = random.uniform(0.0, 1.5)
        temperature = random.uniform(27.0, 34.0)
        humidity = random.uniform(45.0, 68.0)
        wind_speed = random.uniform(2.0, 9.0)
        traffic_level = random.choice(['LOW', 'MEDIUM'])
        traffic_score = random.uniform(0.8, 1.3)
        avg_delivery_time_mins = random.uniform(18.0, 32.0)

    if weekend and disruption_type == 'none':
        orders_completed += random.randint(2, 4)
        earnings_per_order += random.uniform(1.5, 4.0)

    if holiday and disruption_type == 'none':
        orders_completed += random.randint(1, 3)

    earnings = orders_completed * earnings_per_order
    expected_orders = max(orders_completed, random.randint(orders_completed, orders_completed + 5))
    peak_hours_active = clamp(random.uniform(2.5, min(hours_worked, 6.5)), 2.0, hours_worked)
    off_peak_hours = max(0.0, hours_worked - peak_hours_active)
    order_acceptance_rate = clamp(random.uniform(0.78, 0.99), 0.7, 1.0)
    order_completion_rate = clamp(random.uniform(0.80, 0.99), 0.7, 1.0)
    distance_travelled_km = random.uniform(28.0, 85.0)
    aqi_level = random.randint(1, 5)
    pm2_5 = random.uniform(15.0 + (aqi_level * 8), 25.0 + (aqi_level * 12))
    pm10 = random.uniform(30.0 + (aqi_level * 10), 50.0 + (aqi_level * 16))
    earnings_per_hour = earnings / max(hours_worked, 1.0)
    efficiency_score = orders_completed / max(hours_worked, 1.0)

    baseline_orders = expected_orders
    baseline_income = baseline_orders * 48.0
    if disruption_type == 'none':
        earnings = max(earnings, baseline_income * random.uniform(1.0, 1.2))
        loss_amount = 0.0
    else:
        earnings = min(earnings, baseline_income * random.uniform(0.55, 0.88))
        loss_amount = max(0.0, baseline_income - earnings)

    earnings_variance = earnings - baseline_income
    risk_score = (
        0.25 * (rainfall / 10.0)
        + 0.20 * ((temperature - 25.0) / 15.0)
        + 0.20 * ((traffic_score - 0.8) / 1.2)
        + 0.15 * ((aqi_level - 1) / 4.0)
        + 0.20 * (loss_amount / max(baseline_income, 1.0))
    )
    risk_score = clamp(risk_score, 0.0, 1.0)

    return {
        'user_id': user_id,
        'date': day,
        'orders_completed': orders_completed,
        'hours_worked': round2(hours_worked),
        'earnings': round2(earnings),
        'earnings_per_order': round2(earnings / max(orders_completed, 1)),
        'platform': random.choice(PLATFORMS),
        'disruption_type': disruption_type,
        'weather_condition': weather_condition,
        'temperature': round2(temperature),
        'humidity': round2(humidity),
        'rainfall': round2(rainfall),
        'wind_speed': round2(wind_speed),
        'aqi_level': aqi_level,
        'pm2_5': round2(pm2_5),
        'pm10': round2(pm10),
        'traffic_level': traffic_level,
        'traffic_score': round2(traffic_score),
        'peak_hours_active': round2(peak_hours_active),
        'off_peak_hours': round2(off_peak_hours),
        'expected_orders': expected_orders,
        'order_acceptance_rate': round2(order_acceptance_rate),
        'order_completion_rate': round2(order_completion_rate),
        'distance_travelled_km': round2(distance_travelled_km),
        'avg_delivery_time_mins': round2(avg_delivery_time_mins),
        'earnings_per_hour': round2(earnings_per_hour),
        'efficiency_score': round2(efficiency_score),
        'loss_amount': round2(loss_amount),
        'earnings_variance': round2(earnings_variance),
        'risk_score': round2(risk_score),
        'is_weekend': weekend,
        'is_holiday': holiday,
        'city': CITY,
    }


def upsert_gig_records(session, users: list[User], days: int = 30) -> int:
    generated_count = 0
    start_date = date.today() - timedelta(days=days - 1)

    for user in users:
        for offset in range(days):
            record_day = start_date + timedelta(days=offset)
            record_data = build_gig_record(user.id, record_day)
            existing = (
                session.query(GigIncome)
                .filter(GigIncome.user_id == user.id, GigIncome.date == record_day)
                .one_or_none()
            )
            if existing is None:
                session.add(GigIncome(**record_data))
            else:
                for field_name, field_value in record_data.items():
                    setattr(existing, field_name, field_value)
            generated_count += 1

    return generated_count


def clear_mock_requests(session) -> None:
    session.query(DigiLockerRequest).filter(
        DigiLockerRequest.user_id.in_(
            session.query(User.id).filter(
                User.email.in_([user['email'] for user in USERS])
            )
        )
    ).delete(synchronize_session=False)


def main() -> None:
    random.seed(RANDOM_SEED)
    ensure_schema()

    session = SessionLocal()
    try:
        users = upsert_users(session)
        clear_mock_requests(session)
        digilocker_count = write_digilocker_dataset(build_digilocker_dataset())
        gig_count = upsert_gig_records(session, users, days=30)
        session.commit()
        print(f'Seeded {len(users)} users, {gig_count} gig records, {digilocker_count} digilocker records')
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


if __name__ == '__main__':
    main()
