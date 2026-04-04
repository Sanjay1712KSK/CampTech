import logging

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.environment_schema import CoordinatesQuery, EnvironmentResponse
from services.environment_service import get_environment

logger = logging.getLogger('gig_insurance_backend.environment.route')
router = APIRouter()


@router.get('/environment', response_model=EnvironmentResponse)
def environment(params: CoordinatesQuery = Depends(), db: Session = Depends(get_db)):
    try:
        response = get_environment(params.lat, params.lon, db=db, user_id=params.user_id)
        return EnvironmentResponse.model_validate(response).model_dump()
    except Exception as exc:
        logger.exception('environment endpoint error: %s', exc)
        raise
