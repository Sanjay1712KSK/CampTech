from sqlalchemy.orm import Session

from core.risk_engine import calculate_risk as calculate_final_risk


def calculate_risk(
    environment_data: dict,
    user_id: int | None = None,
    db: Session | None = None,
    today_income: dict | None = None,
) -> dict:
    return calculate_final_risk(
        environment_data=environment_data,
        user_id=user_id,
        db=db,
        today_income=today_income,
    )
