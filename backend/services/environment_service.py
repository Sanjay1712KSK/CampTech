from sqlalchemy.orm import Session

from core.environment_engine import build_environment
from services.simulation_input_service import get_simulated_environment_for_user, is_simulation_mode


def get_environment(lat: float, lon: float, db: Session | None = None, user_id: int | None = None) -> dict:
    if is_simulation_mode() and db is not None and user_id is not None:
        return get_simulated_environment_for_user(db, user_id=user_id, lat=lat, lon=lon)
    return build_environment(lat=lat, lon=lon, db=db, user_id=user_id)
