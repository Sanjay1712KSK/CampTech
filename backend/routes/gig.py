from fastapi import APIRouter, HTTPException, Query

from schemas.gig_schema import GenerateGigDataRequest
from services.gig_service import generate_data, income_history, baseline_income, today_income, weekly_summary

router = APIRouter(prefix='/gig')


@router.post('/generate-data')
def generate_data_endpoint(payload: GenerateGigDataRequest):
    user_id = payload.user_id
    days = payload.days

    if user_id <= 0 or days <= 0:
        raise HTTPException(status_code=400, detail='user_id and days must be positive')

    result = generate_data(user_id=user_id, days=days)
    return {'generated': len(result), 'data': result}


@router.get('/income-history')
def income_history_endpoint(user_id: int = Query(...)):
    return income_history(user_id=user_id)


@router.get('/baseline-income')
def baseline_income_endpoint(user_id: int = Query(...)):
    return baseline_income(user_id=user_id)


@router.get('/today-income')
def today_income_endpoint(user_id: int = Query(...)):
    return today_income(user_id=user_id)


@router.get('/weekly-summary')
def weekly_summary_endpoint(user_id: int = Query(...)):
    return weekly_summary(user_id=user_id)
