from sqlalchemy.orm import Session

from core.risk_engine import calculate_risk as calculate_final_risk
from services.ml_service import get_latest_user_behavior


def calculate_risk(
    environment_data: dict,
    user_id: int | None = None,
    db: Session | None = None,
    today_income: dict | None = None,
) -> dict:
    result = calculate_final_risk(
        environment_data=environment_data,
        user_id=user_id,
        db=db,
        today_income=today_income,
    )
    result['factors'] = {
        'weather': {
            'rain': float((result.get('risk_factors') or {}).get('rain_risk', 0.0) or 0.0),
            'wind': float((result.get('risk_factors') or {}).get('wind_risk', 0.0) or 0.0),
        },
        'traffic': float((result.get('risk_factors') or {}).get('traffic_risk', 0.0) or 0.0),
        'aqi': float((result.get('risk_factors') or {}).get('aqi_risk', 0.0) or 0.0),
    }
    result['last_updated'] = (environment_data or {}).get('last_updated')
    if db is not None and user_id is not None:
        result['user_behavior'] = get_latest_user_behavior(db, user_id=user_id)
    else:
        result['user_behavior'] = {}
    return result
