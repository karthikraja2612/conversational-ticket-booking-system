from sqlalchemy.orm import Session
from sqlalchemy import func
from app import models


def get_event_summary(db: Session, event_id: int):

    tickets_sold = (
        db.query(func.count(models.BookingSeat.id))
        .join(models.Booking, models.Booking.id == models.BookingSeat.booking_id)
        .filter(
            models.Booking.event_id == event_id,
            models.Booking.status == "confirmed"
        )
        .scalar()
    )

    revenue = (
        db.query(func.coalesce(func.sum(models.Booking.total_amount), 0))
        .filter(
            models.Booking.event_id == event_id,
            models.Booking.status == "confirmed"
        )
        .scalar()
    )

    total_bookings = (
        db.query(func.count(models.Booking.id))
        .filter(models.Booking.event_id == event_id)
        .scalar()
    )

    confirmed_bookings = (
        db.query(func.count(models.Booking.id))
        .filter(
            models.Booking.event_id == event_id,
            models.Booking.status == "confirmed"
        )
        .scalar()
    )

    conversion_rate = 0
    if total_bookings > 0:
        conversion_rate = confirmed_bookings / total_bookings

    abandoned = (
        db.query(func.count(models.Booking.id))
        .filter(
            models.Booking.event_id == event_id,
            models.Booking.status == "pending"
        )
        .scalar()
    )

    return {
        "tickets_sold": tickets_sold or 0,
        "revenue": revenue or 0,
        "conversion_rate": round(conversion_rate, 2),
        "abandoned_bookings": abandoned or 0
    }