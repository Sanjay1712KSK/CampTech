from sqlalchemy import Column, DateTime, Float, Integer, String, Text, func

from database.db import Base


class BankAccount(Base):
    __tablename__ = 'bank_accounts'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False, unique=True)
    account_number = Column(String(64), nullable=False)
    ifsc = Column(String(32), nullable=False)
    balance = Column(Float, nullable=False, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class BankTransaction(Base):
    __tablename__ = 'bank_transactions'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    transaction_type = Column(String(32), nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(String(32), nullable=False, default='SUCCESS')
    reference_id = Column(String(128), nullable=True)
    metadata_json = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
