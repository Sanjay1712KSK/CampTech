from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import SupportChatRequest, SupportChatResponse
from services.support_service import generate_support_response

router = APIRouter(prefix='/support', tags=['support'])


@router.post('/chat', response_model=SupportChatResponse)
def support_chat_endpoint(payload: SupportChatRequest, db: Session = Depends(get_db)):
    return {'response': generate_support_response(payload.user_id, payload.query, db)}
