from fastapi import APIRouter, HTTPException, Query

from schemas.gig_schema import GenerateGigDataRequest
from services.gig_service import generate_data, income_history, baseline_income, today_income, weekly_summary
from utils.response import success_response, error_response

router = APIRouter(prefix='/gig')


@router.post('/generate-data')
def generate_data_endpoint(payload: GenerateGigDataRequest):
    try:
        data = generate_data(user_id=payload.user_id, days=payload.days)
        return success_response({'generated': len(data), 'data': data})
    except ValueError as exc:
        return error_response('INVALID_INPUT', str(exc))
    except Exception as exc:
        return error_response('GIG_GENERATE_FAILED', str(exc))


@router.get('/income-history')
def income_history_endpoint(user_id: int = Query(..., gt=0)):
    try:
        return success_response(income_history(user_id=user_id))
    except Exception as exc:
        return error_response('GIG_INCOME_HISTORY_FAILED', str(exc))


@router.get('/baseline-income')
def baseline_income_endpoint(user_id: int = Query(..., gt=0)):
    try:
        return success_response(baseline_income(user_id=user_id))
    except Exception as exc:
        return error_response('GIG_BASELINE_FAILED', str(exc))


@router.get('/today-income')
def today_income_endpoint(user_id: int = Query(..., gt=0)):
    try:
        return success_response(today_income(user_id=user_id))
    except Exception as exc:
        return error_response('GIG_TODAY_FAILED', str(exc))


@router.get('/weekly-summary')
def weekly_summary_endpoint(user_id: int = Query(..., gt=0)):
    try:
        return success_response(weekly_summary(user_id=user_id))
    except Exception as exc:
        return error_response('GIG_WEEKLY_SUMMARY_FAILED', str(exc))
