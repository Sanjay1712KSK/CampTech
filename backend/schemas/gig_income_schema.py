from datetime import date

from pydantic import BaseModel


class GigIncomeResponse(BaseModel):
    id: int
    user_id: int
    date: date
    orders_completed: int
    hours_worked: float
    earnings: float
    earnings_per_order: float
    platform: str
    disruption_type: str

    class Config:
        from_attributes = True
