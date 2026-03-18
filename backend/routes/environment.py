import logging

from fastapi import APIRouter, HTTPException, Query

from services.environment_service import get_environment

logger = logging.getLogger('gig_insurance_backend.environment.route')
router = APIRouter()


@router.get('/environment')
def environment(lat: float = Query(...), lon: float = Query(...)):
    try:
        response = get_environment(lat, lon)
        return response
    except Exception as exc:
        logger.exception('environment endpoint error: %s', exc)
        raise HTTPException(status_code=500, detail='Failed to compute environment data')
