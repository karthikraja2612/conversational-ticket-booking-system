from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..schemas import ChatRequest
from ..database import get_db
from ..security import get_current_user
from ..models import Event, Booking

router = APIRouter(prefix="/chat", tags=["Chat"])

@router.post("/")
def chat(request: ChatRequest,
         db: Session = Depends(get_db),
         current_user = Depends(get_current_user)):

    text = request.message.lower()

    # Simple intent detection
    if "show events" in text:
        events = db.query(Event).all()
        return {
            "intent": "list_events",
            "data": [
                {"id": e.id, "name": e.name, "price": e.price}
                for e in events
            ]
        }

    if "my bookings" in text:
        bookings = db.query(Booking).filter(
            Booking.user_id == current_user.id
        ).all()

        return {
            "intent": "booking_history",
            "data": [
                {"id": b.id, "status": b.status, "amount": b.total_amount}
                for b in bookings
            ]
        }

    if "book" in text:
        return {"intent": "start_booking"}

    return {"intent": "unknown"}

