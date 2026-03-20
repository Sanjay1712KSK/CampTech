import logging

from fastapi import APIRouter, Depends, Query

from schemas.environment_schema import CoordinatesQuery
from services.environment_service import get_environment
from services.gig_service import today_income
from services.risk_engine import calculate_risk
from schemas.risk_schema import GigContextResponse, RiskEnvelopeResponse

logger = logging.getLogger('gig_insurance_backend.risk.route')
router = APIRouter()


@router.get('/risk', response_model=RiskEnvelopeResponse)
def risk(
    params: CoordinatesQuery = Depends(),
    user_id: int | None = Query(default=None, gt=0),
):
    try:
        environment = get_environment(params.lat, params.lon)
        risk_result = calculate_risk(environment)

        response = {
            'environment': environment,
            'risk': risk_result,
            'gig_context': None,
        }

        if user_id is not None:
            try:
                today = today_income(user_id=user_id)
                response['gig_context'] = GigContextResponse(
                    earnings_today=float(today.get('earnings', 0.0)),
                    orders_completed=int(today.get('orders_completed', 0)),
                )
            except Exception as gig_exc:
                logger.warning('gig context unavailable for user_id=%s: %s', user_id, gig_exc)

        return RiskEnvelopeResponse.model_validate(response).model_dump()
    except Exception as exc:
        logger.exception('risk endpoint error: %s', exc)
        raise
