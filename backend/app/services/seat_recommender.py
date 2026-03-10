from sqlalchemy.orm import Session
from sqlalchemy import func as sqlfunc
from ..models import Seat, SeatLock, Booking, BookingSeat, Event
from datetime import datetime

def recommend_seats(db: Session, event_id: int, quantity: int, category: str = None):

    current_time = datetime.utcnow()

    # Resolve the event's venue so we only consider seats for that venue —
    # this must match exactly what the seats-status API returns.
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        return []

    # Use the same min-ID deduplication as the seats-status endpoint:
    # pick the lowest seat.id per (row_number, seat_number) for this venue.
    subq = (
        db.query(sqlfunc.min(Seat.id).label("min_id"))
        .filter(Seat.venue_id == event.venue_id)
        .group_by(Seat.row_number, Seat.seat_number)
        .subquery()
    )
    venue_seats = (
        db.query(Seat)
        .filter(Seat.id.in_(subq))
        .order_by(Seat.row_number, Seat.seat_number)
        .all()
    )

    # Seats confirmed-booked for this event
    booked_ids = {
        s[0] for s in
        db.query(BookingSeat.seat_id)
        .join(Booking, BookingSeat.booking_id == Booking.id)
        .filter(
            Booking.event_id == event_id,
            Booking.status == "confirmed"
        ).all()
    }

    # Seats actively locked for this event (not expired)
    locked_ids = {
        s[0] for s in
        db.query(SeatLock.seat_id).filter(
            SeatLock.event_id == event_id,
            SeatLock.status == "locked",
            SeatLock.expires_at > current_time
        ).all()
    }

    unavailable = booked_ids | locked_ids

    # Apply category filter (VIP = first 2 rows, Regular = beyond row 2)
    if category:
        if category.lower() == 'vip':
            available = [s for s in venue_seats if s.id not in unavailable and s.row_number <= 2]
        else:
            available = [s for s in venue_seats if s.id not in unavailable and s.row_number > 2]
    else:
        available = [s for s in venue_seats if s.id not in unavailable]

    # Find the best contiguous block in the same row
    for i in range(len(available) - quantity + 1):
        block = available[i:i + quantity]
        contiguous = all(
            block[j].row_number == block[j + 1].row_number and
            block[j].seat_number + 1 == block[j + 1].seat_number
            for j in range(len(block) - 1)
        )
        if contiguous:
            return [seat.id for seat in block]

    # Fallback: return the first N available seats
    return [seat.id for seat in available[:quantity]]
