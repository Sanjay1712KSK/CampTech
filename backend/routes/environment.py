import logging

from fastapi import APIRouter, Query

from services.environment_service import get_environment
from utils.response import success_response, error_response

logger = logging.getLogger('gig_insurance_backend.environment.route')
router = APIRouter()


@router.get('/environment')
def environment(lat: float = Query(..., ge=-90, le=90), lon: float = Query(..., ge=-180, le=180)):
    try:
        response = get_environment(lat, lon)
        return success_response(response)
    except Exception as exc:
        logger.exception('environment endpoint error: %s', exc)
        return error_response('ENVIRONMENT_FAILED', 'Failed to compute environment data')
