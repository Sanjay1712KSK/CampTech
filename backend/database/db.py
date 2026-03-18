import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///./gig_insurance.db')

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

    # simple column existence check for expected new column
    if not _sqlite_has_column('users', 'verified_at') or not _sqlite_has_column('users', 'is_verified'):
        print('Schema mismatch detected: resetting database schema (dev mode)')
        reset_database()
    else:
        Base.metadata.create_all(bind=engine)

