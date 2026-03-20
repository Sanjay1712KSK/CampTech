from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import PremiumCalculationResponse
from services.premium_engine import calculate_weekly_premium

router = APIRouter(prefix='/premium', tags=['premium'])


@router.get('', response_model=PremiumCalculationResponse)
def calculate_premium_root_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return calculate_weekly_premium(user_id=user_id, db=db)


@router.get('/calculate', response_model=PremiumCalculationResponse)
def calculate_premium_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return calculate_weekly_premium(user_id=user_id, db=db)
