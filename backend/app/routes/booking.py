from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..schemas import ConfirmBookingRequest
from ..security import get_current_user
from .. import crud

router = APIRouter()


@router.post("/events/{event_id}/confirm-booking")
def confirm_booking(
    event_id: int,
    request: ConfirmBookingRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        booking = crud.confirm_booking(db, event_id, current_user.id, request.seat_ids)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return {
        "message": "Booking confirmed",
        "booking_id": booking.id,
        "total_amount": booking.total_amount,
    }


@router.post("/events/{event_id}/process-payment")
def process_payment(
    event_id: int,
    booking_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        payment = crud.process_payment(db, event_id, current_user.id, booking_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {
        "message": "Payment successful, booking confirmed",
        "transaction_id": payment.transaction_id,
    }
