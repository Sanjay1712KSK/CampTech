from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import LinkBankRequest, LinkBankResponse
from services.bank_service import link_account

router = APIRouter(prefix='/bank', tags=['bank'])


@router.post('/link-account', response_model=LinkBankResponse)
def link_account_endpoint(payload: LinkBankRequest, db: Session = Depends(get_db)):
    account = link_account(
        db=db,
        user_id=payload.user_id,
        account_number=payload.account_number,
        ifsc=payload.ifsc,
    )
    db.commit()
    db.refresh(account)
    return {
        'status': 'LINKED',
        'user_id': payload.user_id,
        'balance': float(account.balance),
    }
