import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.environment_schema import CoordinatesQuery
from core.risk_engine import resolve_city_from_coordinates
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
    db: Session = Depends(get_db),
):
    try:
        environment = get_environment(params.lat, params.lon, db=db, user_id=user_id)
        today = None
        gig_context = None

        if user_id is not None:
            try:
                today = today_income(user_id=user_id, db=db)
                gig_context = GigContextResponse(
                    earnings_today=float(today.get('earnings', 0.0)),
                    orders_completed=int(today.get('orders_completed', 0)),
                )
            except Exception as gig_exc:
                logger.warning('gig context unavailable for user_id=%s: %s', user_id, gig_exc)

        environment['resolved_city'] = resolve_city_from_coordinates(params.lat, params.lon)
        environment['city'] = environment['resolved_city']
        risk_result = calculate_risk(environment, user_id=user_id, db=db, today_income=today)

        response = {
            **risk_result,
            'environment': environment,
            'gig_context': gig_context,
        }
        return RiskEnvelopeResponse.model_validate(response).model_dump()
    except Exception as exc:
        logger.exception('risk endpoint error: %s', exc)
        raise
