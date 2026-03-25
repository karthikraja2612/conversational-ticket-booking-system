"""
Central CRUD layer — all database read/write logic lives here.
Routes import these functions instead of querying the DB directly.
"""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import and_, func as sqlfunc
import random
import uuid

from . import models
from .models import BookingStatus, SeatLockStatus, PaymentStatus
from .models import RefundStatus


def _seat_price(db: Session, event: models.Event, seat: models.Seat) -> float:
    """Return the price for a single seat, respecting SeatCategory multipliers
    and any per-event PricingRule override.  Falls back to event.base_price."""
    if seat.category_id:
        rule = (
            db.query(models.PricingRule)
            .filter(
                models.PricingRule.event_id == event.id,
                models.PricingRule.seat_category_id == seat.category_id,
            )
            .first()
        )
        if rule and rule.price_override is not None:
            return rule.price_override
        if seat.category:
            return event.base_price * seat.category.multiplier
    return event.base_price


# ---------------------------------------------------------------------------
# Seats
# ---------------------------------------------------------------------------

def release_expired_locks(db: Session, event_id: int) -> None:
    """Mark any expired seat locks as released."""
    db.query(models.SeatLock).filter(
        models.SeatLock.event_id == event_id,
        models.SeatLock.status == SeatLockStatus.locked,
        models.SeatLock.expires_at < datetime.utcnow(),
    ).update({"status": SeatLockStatus.released})
    db.commit()


def get_available_seats(db: Session, event_id: int):
    """Return seats that are neither confirmed-booked nor actively locked."""
    release_expired_locks(db, event_id)
    now = datetime.utcnow()

    booked_ids = [
        r[0]
        for r in db.query(models.BookingSeat.seat_id)
        .join(models.Booking, models.BookingSeat.booking_id == models.Booking.id)
        .filter(
            models.Booking.event_id == event_id,
            models.Booking.status == BookingStatus.confirmed,
        )
        .all()
    ]

    locked_ids = [
        r[0]
        for r in db.query(models.SeatLock.seat_id)
        .filter(
            and_(
                models.SeatLock.event_id == event_id,
                models.SeatLock.status == SeatLockStatus.locked,
                models.SeatLock.expires_at > now,
            )
        )
        .all()
    ]

    return db.query(models.Seat).filter(
        ~models.Seat.id.in_(booked_ids + locked_ids)
    ).all()


def get_seat_status_for_event(db: Session, event_id: int):
    """Return a list of dicts with id/row/seat/status for every seat in the event's venue."""
    release_expired_locks(db, event_id)
    now = datetime.utcnow()

    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        return None  # caller raises 404

    # Deduplicate seats by (row, seat_number) — keep lowest id
    subq = (
        db.query(sqlfunc.min(models.Seat.id).label("min_id"))
        .filter(models.Seat.venue_id == event.venue_id)
        .group_by(models.Seat.row_number, models.Seat.seat_number)
        .subquery()
    )
    seats = (
        db.query(models.Seat)
        .filter(models.Seat.id.in_(subq))
        .order_by(models.Seat.row_number, models.Seat.seat_number)
        .all()
    )

    booked_ids = {
        r[0]
        for r in db.query(models.BookingSeat.seat_id)
        .join(models.Booking, models.BookingSeat.booking_id == models.Booking.id)
        .filter(
            models.Booking.event_id == event_id,
            models.Booking.status == BookingStatus.confirmed,
        )
        .all()
    }

    locked_ids = {
        r[0]
        for r in db.query(models.SeatLock.seat_id)
        .filter(
            models.SeatLock.event_id == event_id,
            models.SeatLock.status == SeatLockStatus.locked,
            models.SeatLock.expires_at > now,
        )
        .all()
    }

    result = []
    for seat in seats:
        if seat.id in booked_ids:
            status = "booked"
        elif seat.id in locked_ids:
            status = "locked"
        else:
            status = "available"

        result.append(
            {"id": seat.id, "row_number": seat.row_number, "seat_number": seat.seat_number, "status": status}
        )
    return result


# ---------------------------------------------------------------------------
# Locks
# ---------------------------------------------------------------------------

def lock_seats(db: Session, event_id: int, user_id: int, seat_ids: list[int]):
    """
    Attempt to lock the given seats for a user.
    Returns (locks, expiry) on success or raises ValueError if any seat is already locked.
    """
    release_expired_locks(db, event_id)
    now = datetime.utcnow()
    expiry = now + timedelta(minutes=5)

    existing = db.query(models.SeatLock).filter(
        models.SeatLock.event_id == event_id,
        models.SeatLock.seat_id.in_(seat_ids),
        models.SeatLock.status == SeatLockStatus.locked,
        models.SeatLock.expires_at > now,
    ).all()

    if existing:
        raise ValueError("One or more seats already locked")

    for seat_id in seat_ids:
        db.add(
            models.SeatLock(
                seat_id=seat_id,
                event_id=event_id,
                user_id=user_id,
                locked_at=now,
                expires_at=expiry,
                status=SeatLockStatus.locked,
            )
        )
    db.commit()
    return expiry


# ---------------------------------------------------------------------------
# Bookings
# ---------------------------------------------------------------------------

def confirm_booking(db: Session, event_id: int, user_id: int, seat_ids: list[int]):
    """
    Validate locks, create a Booking + BookingSeat rows, mark locks as pending.
    Returns the new Booking object.
    """
    now = datetime.utcnow()

    locks = db.query(models.SeatLock).filter(
        models.SeatLock.event_id == event_id,
        models.SeatLock.seat_id.in_(seat_ids),
        models.SeatLock.user_id == user_id,
        models.SeatLock.status == SeatLockStatus.locked,
        models.SeatLock.expires_at > now,
    ).all()

    if len(locks) != len(seat_ids):
        raise ValueError("Invalid or expired lock")

    event = db.query(models.Event).filter(models.Event.id == event_id).first()
    if not event:
        raise LookupError("Event not found")

    seats_qs = db.query(models.Seat).filter(models.Seat.id.in_(seat_ids)).all()
    seat_map = {s.id: s for s in seats_qs}
    total_amount = sum(_seat_price(db, event, seat_map[sid]) for sid in seat_ids)

    booking = models.Booking(
        user_id=user_id,
        event_id=event_id,
        total_amount=total_amount,
        status=BookingStatus.pending,
    )
    db.add(booking)
    db.flush()

    for seat_id in seat_ids:
        db.add(models.BookingSeat(booking_id=booking.id, seat_id=seat_id))

    for lock in locks:
        lock.status = SeatLockStatus.pending

    db.commit()
    db.refresh(booking)
    return booking


def process_payment(db: Session, user_id: int, booking_id: int, force_fail: bool = False):
    """
    Simulate payment, confirm booking, mark locks confirmed.
    Returns the Payment object.
    """
    booking = db.query(models.Booking).filter(
        models.Booking.id == booking_id,
        models.Booking.user_id == user_id,
        models.Booking.status.in_([BookingStatus.pending, BookingStatus.payment_failed]),
    ).first()

    if not booking:
        raise ValueError("Invalid booking")

    payment = models.Payment(
        booking_id=booking_id,
        payment_status=PaymentStatus.pending,
        transaction_id=f"TXN-{uuid.uuid4().hex[:12].upper()}",
        paid_at=datetime.utcnow(),
    )
    db.add(payment)
    db.flush()

    should_fail = force_fail or (random.random() < 0.2)

    if should_fail:
        payment.payment_status = PaymentStatus.failed
        booking.status = BookingStatus.payment_failed

        db.query(models.SeatLock).filter(
            models.SeatLock.event_id == booking.event_id,
            models.SeatLock.user_id == booking.user_id,
            models.SeatLock.status == SeatLockStatus.pending,
        ).update({"status": SeatLockStatus.released})

        db.commit()
        db.refresh(payment)
        raise ValueError("Payment failed")

    payment.payment_status = PaymentStatus.success
    booking.status = BookingStatus.confirmed

    db.query(models.SeatLock).filter(
        models.SeatLock.event_id == booking.event_id,
        models.SeatLock.user_id == booking.user_id,
        models.SeatLock.status == SeatLockStatus.pending,
    ).update({"status": SeatLockStatus.confirmed})

    db.commit()
    db.refresh(payment)
    return payment


def get_user_bookings(db: Session, user_id: int, skip: int = 0, limit: int = 50):
    rows = (
        db.query(models.Booking, models.Event.name.label("event_name"))
        .join(models.Event, models.Booking.event_id == models.Event.id)
        .filter(models.Booking.user_id == user_id)
        .order_by(models.Booking.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    result = []
    for booking, event_name in rows:
        # Fetch seat IDs for this booking
        seat_ids = [
            bs.seat_id
            for bs in db.query(models.BookingSeat).filter(
                models.BookingSeat.booking_id == booking.id
            ).all()
        ]
        result.append({
            "booking_id": booking.id,
            "event_id": booking.event_id,
            "event_name": event_name,
            "user_id": booking.user_id,
            "total_amount": booking.total_amount,
            "status": booking.status.value if hasattr(booking.status, "value") else booking.status,
            "created_at": booking.created_at.isoformat() if booking.created_at else None,
            "cancellation_time": booking.cancellation_time.isoformat() if booking.cancellation_time else None,
            "refund_status": booking.refund_status.value if hasattr(booking.refund_status, "value") else booking.refund_status,
            "seat_ids": seat_ids,
        })
    return result


def cancel_booking(db: Session, user_id: int, booking_id: int):
    booking = db.query(models.Booking).filter(
        models.Booking.id == booking_id,
        models.Booking.user_id == user_id,
    ).first()

    if not booking:
        raise ValueError("Invalid booking")

    if booking.status == BookingStatus.cancelled:
        raise ValueError("Booking already cancelled")

    event = db.query(models.Event).filter(models.Event.id == booking.event_id).first()
    if not event:
        raise LookupError("Event not found")

    if event.event_date and event.event_date <= datetime.utcnow():
        raise ValueError("Event already started")

    payment = db.query(models.Payment).filter(
        models.Payment.booking_id == booking.id,
        models.Payment.payment_status == PaymentStatus.success,
    ).first()

    booking.status = BookingStatus.cancelled
    booking.cancellation_time = datetime.utcnow()
    booking.refund_status = RefundStatus.initiated if payment else RefundStatus.completed

    db.commit()
    db.refresh(booking)
    return booking


def get_active_booking(db: Session, user_id: int):
    now = datetime.utcnow()
    recent_cutoff = now - timedelta(minutes=30)

    booking = (
        db.query(models.Booking)
        .join(models.Event, models.Booking.event_id == models.Event.id)
        .filter(
            models.Booking.user_id == user_id,
            models.Booking.status.in_([BookingStatus.pending, BookingStatus.payment_failed]),
            models.Event.event_date > now,
            models.Booking.created_at > recent_cutoff,
        )
        .order_by(models.Booking.created_at.desc())
        .first()
    )

    if booking:
        newer_confirmed = (
            db.query(models.Booking)
            .filter(
                models.Booking.user_id == user_id,
                models.Booking.status == BookingStatus.confirmed,
                models.Booking.created_at > booking.created_at,
            )
            .first()
        )
        if newer_confirmed:
            return None
        seat_ids = [
            bs.seat_id
            for bs in db.query(models.BookingSeat).filter(
                models.BookingSeat.booking_id == booking.id
            ).all()
        ]
        event = db.query(models.Event).filter(models.Event.id == booking.event_id).first()
        return {
            "kind": "payment",
            "booking_id": booking.id,
            "event_id": booking.event_id,
            "event_name": event.name if event else None,
            "seat_ids": seat_ids,
            "total_amount": booking.total_amount,
            "status": booking.status.value if hasattr(booking.status, "value") else booking.status,
            "expires_at": None,
            "created_at": booking.created_at.isoformat() if booking.created_at else None,
        }

    return None
