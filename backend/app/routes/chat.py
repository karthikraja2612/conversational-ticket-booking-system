from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..security import get_current_user
from ..schemas import ChatRequest, ChatHistoryItem
from ..services.chat_engine import get_or_create_session, handle_message
from .. import models

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

    db.add(models.ChatMessage(
        user_id=current_user.id,
        sender="user",
        content=request.message,
    ))

    bot_message = response.get("message") if isinstance(response, dict) else None
    if not bot_message:
        bot_message = "Here is the latest update."
    db.add(models.ChatMessage(
        user_id=current_user.id,
        sender="bot",
        content=bot_message,
    ))
    db.commit()

    return response


@router.get("/history", response_model=list[ChatHistoryItem])
def get_history(
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    limit = max(1, min(20, limit))
    rows = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.user_id == current_user.id)
        .order_by(models.ChatMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    rows.reverse()
    return [
        ChatHistoryItem(
            sender=row.sender,
            content=row.content,
            timestamp=row.created_at,
        )
        for row in rows
    ]


@router.delete("/history")
def clear_history(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    db.query(models.ChatMessage).filter(
        models.ChatMessage.user_id == current_user.id
    ).delete()
    db.query(models.ChatSession).filter(
        models.ChatSession.user_id == current_user.id
    ).update({"state": "idle", "context": {}})
    db.commit()
    return {"message": "Chat history cleared"}
