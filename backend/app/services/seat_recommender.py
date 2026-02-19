from sqlalchemy.orm import Session
from ..models import Seat, SeatLock, Booking, BookingSeat
from datetime import datetime

def recommend_seats(db: Session, event_id: int, quantity: int):

    current_time = datetime.utcnow()

    # Get booked seats
    booked = db.query(BookingSeat.seat_id)\
        .join(Booking, BookingSeat.booking_id == Booking.id)\
        .filter(
            Booking.event_id == event_id,
            Booking.status == "confirmed"
        ).all()

    booked_ids = [s[0] for s in booked]

    # Get active locks
    locked = db.query(SeatLock.seat_id).filter(
        SeatLock.event_id == event_id,
        SeatLock.status == "locked",
        SeatLock.expires_at > current_time
    ).all()

    locked_ids = [s[0] for s in locked]

    unavailable = set(booked_ids + locked_ids)

    seats = db.query(Seat).all()

    available = [s for s in seats if s.id not in unavailable]

    # Simple adjacency logic
    available_sorted = sorted(available, key=lambda x: (x.row_number, x.seat_number))

    for i in range(len(available_sorted) - quantity + 1):
        block = available_sorted[i:i+quantity]

        contiguous = True
        for j in range(len(block)-1):
            if not (
        block[j].row_number == block[j+1].row_number and
        block[j].seat_number + 1 == block[j+1].seat_number
    ):
                contiguous = False
                break

        if contiguous:
            return [seat.id for seat in block]

    # fallback
    return [seat.id for seat in available_sorted[:quantity]]
