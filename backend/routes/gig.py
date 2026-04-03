from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.gig_schema import (
    BaselineIncomeResponse,
    GigConnectRequest,
    GigConnectResponse,
    GenerateGigDataRequest,
    GenerateGigDataResponse,
    GigIncomeHistoryItem,
    TodayIncomeResponse,
    WeeklySummaryResponse,
)
from services.gig_service import (
    baseline_income,
    connect_gig_account,
    debug_all_records,
    generate_data,
    income_history,
    today_income,
    weekly_summary,
)

router = APIRouter(prefix='/gig')


@router.post('/generate-data', response_model=GenerateGigDataResponse)
def generate_data_endpoint(payload: GenerateGigDataRequest, db: Session = Depends(get_db)):
    try:
        data = generate_data(user_id=payload.user_id, days=payload.days, db=db)
        return GenerateGigDataResponse(generated=len(data), data=data).model_dump(mode='json')
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post('/connect', response_model=GigConnectResponse)
def connect_gig_account_endpoint(payload: GigConnectRequest, db: Session = Depends(get_db)):
    try:
        return connect_gig_account(
            user_id=payload.user_id,
            platform=payload.platform,
            worker_id=payload.worker_id,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get('/income-history', response_model=list[GigIncomeHistoryItem])
def income_history_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return income_history(user_id=user_id, db=db)


@router.get('/debug-all', response_model=list[dict])
def debug_all_endpoint(db: Session = Depends(get_db)):
    return debug_all_records(db=db)


@router.get('/baseline-income', response_model=BaselineIncomeResponse)
def baseline_income_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return baseline_income(user_id=user_id, db=db)


@router.get('/today-income', response_model=TodayIncomeResponse)
def today_income_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return today_income(user_id=user_id, db=db)


@router.get('/weekly-summary', response_model=WeeklySummaryResponse)
def weekly_summary_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return weekly_summary(user_id=user_id, db=db)
