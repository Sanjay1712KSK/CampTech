from sqlalchemy.orm import Session

from core.environment_engine import build_environment
from services.simulation_input_service import get_simulated_environment_for_user, has_simulated_profile, is_simulation_mode


def get_environment(lat: float, lon: float, db: Session | None = None, user_id: int | None = None) -> dict:
    if db is not None and user_id is not None and (is_simulation_mode() or has_simulated_profile(db, user_id)):
        return get_simulated_environment_for_user(db, user_id=user_id, lat=lat, lon=lon)
    return build_environment(lat=lat, lon=lon, db=db, user_id=user_id)
