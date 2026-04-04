from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import relationship

from database.db import Base


class GigAccount(Base):
    __tablename__ = 'gig_accounts'
    __table_args__ = (
        UniqueConstraint('user_id', 'platform', name='uq_gig_account_user_platform'),
        UniqueConstraint('platform', 'worker_id', name='uq_gig_account_platform_worker'),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False, index=True)
    platform = Column(String(50), nullable=False, index=True)
    worker_id = Column(String(64), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='gig_accounts')
