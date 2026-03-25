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


def get_admin_analytics(db: Session):
    confirmed = models.BookingStatus.confirmed

    total_bookings = (
        db.query(func.count(models.Booking.id))
        .filter(models.Booking.status == confirmed)
        .scalar()
    )

    total_revenue = (
        db.query(func.coalesce(func.sum(models.Booking.total_amount), 0))
        .filter(models.Booking.status == confirmed)
        .scalar()
    )

    avg_booking_value = 0
    if total_bookings:
        avg_booking_value = total_revenue / total_bookings

    top_events = (
        db.query(
            models.Event.id,
            models.Event.name,
            func.count(models.Booking.id).label("bookings"),
        )
        .join(models.Booking, models.Booking.event_id == models.Event.id)
        .filter(models.Booking.status == confirmed)
        .group_by(models.Event.id, models.Event.name)
        .order_by(func.count(models.Booking.id).desc())
        .limit(5)
        .all()
    )

    return {
        "total_bookings": int(total_bookings or 0),
        "total_revenue": float(total_revenue or 0),
        "average_booking_value": round(float(avg_booking_value), 2),
        "most_booked_events": [
            {
                "event_id": row.id,
                "event_name": row.name,
                "bookings": int(row.bookings or 0),
            }
            for row in top_events
        ],
    }