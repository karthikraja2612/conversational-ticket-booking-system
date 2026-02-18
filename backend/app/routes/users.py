from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..security import get_current_user
from ..models import User,Booking

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "created_at": current_user.created_at
    }

@router.get("/me/bookings")
def get_my_bookings(db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):

    bookings = db.query(Booking).filter(
        Booking.user_id == current_user.id
    ).all()

    return bookings