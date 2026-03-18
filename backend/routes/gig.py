from fastapi import APIRouter, HTTPException, Query

from services.gig_service import generate_data, income_history, baseline_income, today_income

router = APIRouter(prefix='/gig')


@router.post('/generate-data')
def generate_data_endpoint(payload: dict):
    try:
        user_id = int(payload.get('user_id', 0))
        days = int(payload.get('days', 30))
    except Exception:
        raise HTTPException(status_code=400, detail='user_id and days must be integers')

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
