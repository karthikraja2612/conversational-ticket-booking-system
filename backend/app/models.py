import enum
from sqlalchemy import JSON, Column, Integer, String, DateTime, ForeignKey, Boolean, Float, func, Enum as SQLAlchemyEnum
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base


class BookingStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"


class SeatLockStatus(str, enum.Enum):
    locked = "locked"
    released = "released"
    pending = "pending"
    confirmed = "confirmed"


class EventStatus(str, enum.Enum):
    draft = "draft"
    published = "published"
    cancelled = "cancelled"


class PaymentStatus(str, enum.Enum):
    success = "success"
    failed = "failed"
    refunded = "refunded"

class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    state = Column(String(50), default="idle")
    context = Column(JSON, default=dict)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ...existing code...
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    # FIX 1: DB column is 'password', not 'hashed_password'
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
# ...existing code...


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
    base_price = Column(Float)
    status = Column(SQLAlchemyEnum(EventStatus), default=EventStatus.draft)
    image_url = Column(String(300), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    venue = relationship("Venue")


class SeatCategory(Base):
    """Categorical label for a seat (e.g. standard, vip).  The multiplier is
    applied to the event's base_price to derive the per-seat price unless a
    PricingRule overrides it explicitly."""
    __tablename__ = "seat_categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False, unique=True)   # e.g. "standard", "vip"
    multiplier = Column(Float, nullable=False, default=1.0)


class Seat(Base):
    __tablename__ = "seats"

    id = Column(Integer, primary_key=True, index=True)
    venue_id = Column(Integer, ForeignKey("venues.id"))
    row_number = Column(Integer)
    seat_number = Column(Integer)
    is_active = Column(Boolean, default=True)
    category_id = Column(Integer, ForeignKey("seat_categories.id"), nullable=True)

    venue = relationship("Venue")
    category = relationship("SeatCategory")


class PricingRule(Base):
    """Per-event price override for a seat category.  If price_override is set
    it replaces base_price * multiplier.  Useful to set an exact VIP price
    for a specific event rather than a blanket multiplier."""
    __tablename__ = "pricing_rules"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("events.id"), nullable=False)
    seat_category_id = Column(Integer, ForeignKey("seat_categories.id"), nullable=False)
    price_override = Column(Float, nullable=True)  # None → use base_price * multiplier

    event = relationship("Event")
    seat_category = relationship("SeatCategory")


class SeatLock(Base):
    __tablename__ = "seat_locks"

    id = Column(Integer, primary_key=True, index=True)
    seat_id = Column(Integer, ForeignKey("seats.id"))
    event_id = Column(Integer, ForeignKey("events.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    locked_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime)
    status = Column(SQLAlchemyEnum(SeatLockStatus), nullable=False)
    extension_used = Column(Boolean, default=False)


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    event_id = Column(Integer, ForeignKey("events.id"))
    total_amount = Column(Float)
    status = Column(SQLAlchemyEnum(BookingStatus), nullable=False, default=BookingStatus.pending)
    created_at = Column(DateTime, default=datetime.utcnow)
    confirmed_at = Column(DateTime, nullable=True)


class BookingSeat(Base):
    __tablename__ = "booking_seats"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"))
    seat_id = Column(Integer, ForeignKey("seats.id"))


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"))
    payment_status = Column(SQLAlchemyEnum(PaymentStatus), nullable=False)
    transaction_id = Column(String(200))
    paid_at = Column(DateTime)


class Admin(Base):
    __tablename__ = "admins"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, index=True)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


