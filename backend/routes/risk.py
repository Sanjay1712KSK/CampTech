import logging

from fastapi import APIRouter, Query

from services.environment_service import get_environment
from services.gig_service import today_income
from services.risk_engine import calculate_risk
from utils.response import success_response, error_response

logger = logging.getLogger('gig_insurance_backend.risk.route')
router = APIRouter()


@router.get('/risk')
def risk(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    user_id: int | None = Query(default=None, gt=0),
):
    try:
        environment = get_environment(lat, lon)
        risk_result = calculate_risk(environment)

        response = {
            'environment': environment,
            'risk': risk_result,
            'gig_context': None,
        }

        if user_id is not None:
            try:
                today = today_income(user_id=user_id)
                response['gig_context'] = {
                    'earnings_today': float(today.get('earnings', 0.0)),
                    'orders_completed': int(today.get('orders_completed', 0)),
                }
            except Exception as gig_exc:
                logger.warning('gig context unavailable for user_id=%s: %s', user_id, gig_exc)

        return success_response(response)
    except Exception as exc:
        logger.exception('risk endpoint error: %s', exc)
        return error_response('RISK_ENGINE_FAILED', 'Failed to compute delivery risk')
