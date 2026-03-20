from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from database.db import get_db
from models.gig_income import GigIncome
from schemas.gig_schema import (
    BaselineIncomeResponse,
    GenerateGigDataRequest,
    GenerateGigDataResponse,
    TodayIncomeResponse,
    WeeklySummaryResponse,
)
from schemas.gig_income_schema import GigIncomeResponse
from services.gig_service import baseline_income, generate_data, today_income, weekly_summary

router = APIRouter(prefix='/gig')


@router.post('/generate-data', response_model=GenerateGigDataResponse)
def generate_data_endpoint(payload: GenerateGigDataRequest):
    try:
        data = generate_data(user_id=payload.user_id, days=payload.days)
        return GenerateGigDataResponse(generated=len(data), data=data).model_dump(mode='json')
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get('/income-history', response_model=List[GigIncomeResponse])
def income_history_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    user_id = int(user_id)
    records = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == user_id)
        .order_by(GigIncome.date.desc())
        .all()
    )
    print(f"[DEBUG] Found {len(records)} records for user_id={user_id}")
    return records


@router.get('/debug-all', response_model=List[GigIncomeResponse])
def debug_all_endpoint(db: Session = Depends(get_db)):
    return db.query(GigIncome).all()


@router.get('/baseline-income', response_model=BaselineIncomeResponse)
def baseline_income_endpoint(user_id: int = Query(..., gt=0)):
    return baseline_income(user_id=user_id)


@router.get('/today-income', response_model=GigIncomeResponse | TodayIncomeResponse)
def today_income_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    user_id = int(user_id)
    record = (
        db.query(GigIncome)
        .filter(GigIncome.user_id == user_id)
        .order_by(GigIncome.date.desc())
        .first()
    )
    if record is not None:
        return record
    return today_income(user_id=user_id)


@router.get('/weekly-summary', response_model=WeeklySummaryResponse)
def weekly_summary_endpoint(user_id: int = Query(..., gt=0)):
    return weekly_summary(user_id=user_id)
