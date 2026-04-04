from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.simulation_schema import SimulationInputRequest
from services.simulation_input_service import simulate_inputs

router = APIRouter(prefix='/simulate', tags=['simulation'])


@router.post('/input')
def simulate_input_endpoint(payload: SimulationInputRequest, db: Session = Depends(get_db)):
    return simulate_inputs(
        db,
        enable_simulation=payload.enable_simulation,
        regenerate_income=payload.regenerate_income,
        days=payload.days,
    )
