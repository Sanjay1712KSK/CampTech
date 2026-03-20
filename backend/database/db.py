import os
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

BACKEND_DIR = Path(__file__).resolve().parent.parent
DEFAULT_SQLITE_PATH = BACKEND_DIR / 'gig_insurance.db'


def _resolve_database_url(raw_url: str | None) -> str:
    if not raw_url:
        return f"sqlite:///{DEFAULT_SQLITE_PATH.as_posix()}"

    if raw_url.startswith('sqlite:///'):
        sqlite_path = raw_url.replace('sqlite:///', '', 1)
        if sqlite_path == ':memory:' or os.path.isabs(sqlite_path):
            return raw_url
        return f"sqlite:///{(BACKEND_DIR / sqlite_path).resolve().as_posix()}"

    return raw_url


DATABASE_URL = _resolve_database_url(os.getenv('DATABASE_URL'))

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith('sqlite') else {},
    echo=False,
    future=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def reset_database():
    """Drop all tables and recreate schema. Development-only helper."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)


from sqlalchemy import text


def _sqlite_has_column(table_name: str, column_name: str) -> bool:
    with engine.connect() as conn:
        result = conn.execute(text(f"PRAGMA table_info('{table_name}')"))
        return any(row[1] == column_name for row in result)


def ensure_schema():
    """Ensure DB schema matches models; reset in development if mismatch."""
    if not DATABASE_URL.startswith('sqlite'):
        Base.metadata.create_all(bind=engine)
        return

    required_columns = {
        'users': ['verified_at', 'is_verified'],
        'bank_accounts': ['user_id', 'account_number', 'ifsc', 'balance', 'created_at'],
        'bank_transactions': ['user_id', 'transaction_type', 'amount', 'status', 'reference_id', 'metadata_json'],
        'policies': ['user_id', 'start_date', 'end_date', 'premium_paid', 'status'],
        'claims': ['user_id', 'week', 'loss', 'payout', 'fraud_score', 'status', 'reasons_json'],
        'gig_income': [
            'weather_condition',
            'temperature',
            'humidity',
            'rainfall',
            'wind_speed',
            'aqi_level',
            'pm2_5',
            'pm10',
            'traffic_level',
            'traffic_score',
            'peak_hours_active',
            'off_peak_hours',
            'expected_orders',
            'order_acceptance_rate',
            'order_completion_rate',
            'distance_travelled_km',
            'avg_delivery_time_mins',
            'earnings_per_hour',
            'efficiency_score',
            'loss_amount',
            'earnings_variance',
            'risk_score',
            'is_weekend',
            'is_holiday',
            'city',
        ],
        'digilocker_requests': ['verified_name', 'verified_dob', 'blockchain_txn_id'],
    }

    schema_ok = True
    for table_name, columns in required_columns.items():
        for column_name in columns:
            if not _sqlite_has_column(table_name, column_name):
                schema_ok = False
                break
        if not schema_ok:
            break

    if not schema_ok:
        print('Schema mismatch detected: resetting database schema (dev mode)')
        reset_database()
    else:
        Base.metadata.create_all(bind=engine)

