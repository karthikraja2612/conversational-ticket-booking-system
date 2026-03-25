from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..schemas import ConfirmBookingRequest
from ..security import get_current_user
from .. import crud
from .. import models

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


@router.post("/bookings/{booking_id}/process-payment")
def process_payment(
    booking_id: int,
    force_fail: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        payment = crud.process_payment(db, current_user.id, booking_id, force_fail)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {
        "message": "Payment successful, booking confirmed",
        "transaction_id": payment.transaction_id,
    }


@router.post("/bookings/{booking_id}/cancel")
def cancel_booking(
    booking_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        booking = crud.cancel_booking(db, current_user.id, booking_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    seat_ids = [
        bs.seat_id
        for bs in db.query(models.BookingSeat).filter(
            models.BookingSeat.booking_id == booking.id
        ).all()
    ]
    event = db.query(models.Event).filter(models.Event.id == booking.event_id).first()
    return {
        "message": "Booking cancelled",
        "booking_id": booking.id,
        "event_id": booking.event_id,
        "event_name": event.name if event else None,
        "user_id": booking.user_id,
        "total_amount": booking.total_amount,
        "seat_ids": seat_ids,
        "status": booking.status.value if hasattr(booking.status, "value") else booking.status,
        "refund_status": booking.refund_status.value if hasattr(booking.refund_status, "value") else booking.refund_status,
        "cancellation_time": booking.cancellation_time.isoformat() if booking.cancellation_time else None,
    }


@router.get("/bookings/active")
def get_active_booking(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    active = crud.get_active_booking(db, current_user.id)
    if not active:
        return {"active": False}
    return {"active": True, **active}
