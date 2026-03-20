from fastapi import APIRouter, HTTPException, Query

from schemas.gig_schema import (
    BaselineIncomeResponse,
    GenerateGigDataRequest,
    GenerateGigDataResponse,
    GigIncomeHistoryItem,
    TodayIncomeResponse,
    WeeklySummaryResponse,
)
from services.gig_service import baseline_income, generate_data, income_history, today_income, weekly_summary

router = APIRouter(prefix='/gig')


@router.post('/generate-data', response_model=GenerateGigDataResponse)
def generate_data_endpoint(payload: GenerateGigDataRequest):
    try:
        data = generate_data(user_id=payload.user_id, days=payload.days)
        return GenerateGigDataResponse(generated=len(data), data=data).model_dump(mode='json')
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get('/income-history', response_model=list[GigIncomeHistoryItem])
def income_history_endpoint(user_id: int = Query(..., gt=0)):
    return income_history(user_id=user_id)


@router.get('/baseline-income', response_model=BaselineIncomeResponse)
def baseline_income_endpoint(user_id: int = Query(..., gt=0)):
    return baseline_income(user_id=user_id)


@router.get('/today-income', response_model=TodayIncomeResponse)
def today_income_endpoint(user_id: int = Query(..., gt=0)):
    return today_income(user_id=user_id)


@router.get('/weekly-summary', response_model=WeeklySummaryResponse)
def weekly_summary_endpoint(user_id: int = Query(..., gt=0)):
    return weekly_summary(user_id=user_id)
