from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..schemas import LockSeatsRequest, ConfirmBookingRequest, SeatResponse, SeatStatusResponse
from ..security import get_current_user
from .. import crud

router = APIRouter()


@router.get("/events/{event_id}/available-seats", response_model=List[SeatResponse])
def get_available_seats(event_id: int, db: Session = Depends(get_db)):
    return crud.get_available_seats(db, event_id)


@router.get("/events/{event_id}/seats-status", response_model=List[SeatStatusResponse])
def get_seat_status(event_id: int, db: Session = Depends(get_db)):
    result = crud.get_seat_status_for_event(db, event_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Event not found")
    return result


@router.post("/events/{event_id}/lock-seats")
def lock_seats(
    event_id: int,
    request: LockSeatsRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        expiry = crud.lock_seats(db, event_id, current_user.id, request.seat_ids)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"message": "Seats locked successfully", "expires_at": expiry}


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