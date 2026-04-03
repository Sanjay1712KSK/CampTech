import os
import time
import logging
from pathlib import Path

from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.exc import OperationalError
from sqlalchemy.pool import NullPool

from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

logger = logging.getLogger('gig_insurance_backend.db')

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

engine_kwargs = {
    'echo': False,
    'future': True,
}

if DATABASE_URL.startswith('sqlite'):
    engine_kwargs['connect_args'] = {
        'check_same_thread': False,
        'timeout': 30,
    }
    engine_kwargs['poolclass'] = NullPool
else:
    engine_kwargs['connect_args'] = {}

engine = create_engine(DATABASE_URL, **engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)
Base = declarative_base()


if DATABASE_URL.startswith('sqlite'):
    @event.listens_for(engine, 'connect')
    def _set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        try:
            cursor.execute('PRAGMA busy_timeout=30000;')
            try:
                cursor.execute('PRAGMA journal_mode=WAL;')
                cursor.execute('PRAGMA synchronous=NORMAL;')
            except Exception as exc:
                logger.warning('Could not fully apply SQLite WAL pragmas, continuing with defaults: %s', exc)
        finally:
            cursor.close()


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

def _run_sqlite_with_retries(action, attempts: int = 5, delay_seconds: float = 0.25):
    last_error = None
    for attempt in range(1, attempts + 1):
        try:
            return action()
        except OperationalError as exc:
            if 'database is locked' not in str(exc).lower():
                raise
            last_error = exc
            if attempt == attempts:
                break
            time.sleep(delay_seconds * attempt)
    raise last_error


def _sqlite_has_column(table_name: str, column_name: str) -> bool:
    def _action():
        with engine.connect() as conn:
            result = conn.execute(text(f"PRAGMA table_info('{table_name}')"))
            return any(row[1] == column_name for row in result)

    return _run_sqlite_with_retries(_action)


def ensure_schema():
    """Ensure DB schema matches models; reset in development if mismatch."""
    if not DATABASE_URL.startswith('sqlite'):
        Base.metadata.create_all(bind=engine)
        return

    required_columns = {
        'users': [
            'email',
            'phone',
            'username',
            'name',
            'password_hash',
            'is_email_verified',
            'is_phone_verified',
            'is_account_confirmed',
            'is_digilocker_verified',
            'has_completed_first_login_2fa',
            'verified_at',
        ],
        'profiles': ['user_id', 'platform', 'city', 'avg_income'],
        'verifications': ['user_id', 'otp_code', 'type', 'channel', 'expires_at', 'attempts'],
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
        'digilocker_requests': [
            'doc_type',
            'status',
            'document_number_masked',
            'consent_granted',
            'redirect_url',
            'oauth_state',
            'verified_name',
            'verified_dob',
            'blockchain_txn_id',
        ],
    }

    schema_ok = True
    inspector = inspect(engine)
    for table_name, columns in required_columns.items():
        if not inspector.has_table(table_name):
            schema_ok = False
            break
        for column_name in columns:
            if not _sqlite_has_column(table_name, column_name):
                schema_ok = False
                break
        if not schema_ok:
            break

    if not schema_ok:
        print('Schema mismatch detected: resetting database schema (dev mode)')
        _run_sqlite_with_retries(reset_database)
    else:
        _run_sqlite_with_retries(lambda: Base.metadata.create_all(bind=engine))

