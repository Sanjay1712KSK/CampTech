from pydantic import BaseModel, ConfigDict, Field


class SimulationInputRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    enable_simulation: bool = True
    regenerate_income: bool = True
    days: int = Field(default=30, ge=7, le=60)
