from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100))
    email = Column(String(100), unique=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Venue(Base):
    __tablename__ = "venues"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200))
    location = Column(String(200))
    total_rows = Column(Integer)
    seats_per_row = Column(Integer)


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200))
    venue_id = Column(Integer, ForeignKey("venues.id"))
    event_date = Column(DateTime)
    price = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

    venue = relationship("Venue")


class Seat(Base):
    __tablename__ = "seats"

    id = Column(Integer, primary_key=True, index=True)
    venue_id = Column(Integer, ForeignKey("venues.id"))
    row_number = Column(Integer)
    seat_number = Column(Integer)
    is_active = Column(Boolean, default=True)

    venue = relationship("Venue")


class SeatLock(Base):
    __tablename__ = "seat_locks"

    id = Column(Integer, primary_key=True, index=True)
    seat_id = Column(Integer, ForeignKey("seats.id"))
    event_id = Column(Integer, ForeignKey("events.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    locked_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime)
    status = Column(String(50))  # locked / released / confirmed


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    event_id = Column(Integer, ForeignKey("events.id"))
    total_amount = Column(Float)
    status = Column(String(50))  # pending / confirmed / cancelled
    created_at = Column(DateTime, default=datetime.utcnow)


class BookingSeat(Base):
    __tablename__ = "booking_seats"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"))
    seat_id = Column(Integer, ForeignKey("seats.id"))


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"))
    payment_status = Column(String(50))
    transaction_id = Column(String(200))
    paid_at = Column(DateTime)
