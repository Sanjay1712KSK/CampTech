from sqlalchemy.orm import Session

from core.environment_engine import build_environment


def get_environment(lat: float, lon: float, db: Session | None = None, user_id: int | None = None) -> dict:
    return build_environment(lat=lat, lon=lon, db=db, user_id=user_id)
