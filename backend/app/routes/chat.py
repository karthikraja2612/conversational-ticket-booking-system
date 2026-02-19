from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..security import get_current_user
from ..schemas import ChatRequest
from ..services.chat_engine import get_or_create_session, handle_message

router = APIRouter(prefix="/chat", tags=["Chat"])


@router.post("/")
def chat(request: ChatRequest,
         db: Session = Depends(get_db),
         current_user = Depends(get_current_user)):

    session = get_or_create_session(db, current_user.id)

    response = handle_message(
        db,
        session,
        current_user.id,
        request.message
    )

    return response
