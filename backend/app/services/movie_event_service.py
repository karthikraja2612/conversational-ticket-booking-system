from __future__ import annotations

from datetime import datetime, timedelta
from math import ceil
from typing import Optional

from sqlalchemy.orm import Session

from .. import models
from .theatre_service import load_theatres

DEFAULT_SEAT_ROWS = 10
DEFAULT_SEATS_PER_ROW = 20
DEFAULT_BASE_PRICE = 200.0


def _find_theatre_meta(theatre_name: str) -> dict | None:
    if not theatre_name:
        return None
    theatre_key = theatre_name.strip().lower()
    for theatre in load_theatres():
        name = theatre.get("name")
        if isinstance(name, str) and name.strip().lower() == theatre_key:
            return theatre
    return None


def _parse_price_range(value: Optional[str]) -> float:
    if not value:
        return DEFAULT_BASE_PRICE
    parts = value.replace("INR", "").replace("inr", "").split("-")
    if len(parts) != 2:
        return DEFAULT_BASE_PRICE
    try:
        low = float(parts[0].strip())
        high = float(parts[1].strip())
        return (low + high) / 2
    except ValueError:
        return DEFAULT_BASE_PRICE


def _build_event_name(movie_title: str, theatre_name: str, showtime: str) -> str:
    return f"{movie_title} @ {theatre_name} {showtime}"


def _parse_showtime(showtime: str) -> datetime:
    now = datetime.now()
    try:
        show_time = datetime.strptime(showtime, "%H:%M").time()
        return datetime.combine(now.date(), show_time)
    except ValueError:
        return now


def _ensure_venue(db: Session, theatre_name: str) -> models.Venue:
    venue = db.query(models.Venue).filter(models.Venue.name.ilike(theatre_name)).first()
    if venue:
        return venue

    theatre_meta = _find_theatre_meta(theatre_name) or {}
    total_seats = theatre_meta.get("total_seats")
    total_rows = DEFAULT_SEAT_ROWS
    seats_per_row = DEFAULT_SEATS_PER_ROW
    if isinstance(total_seats, int) and total_seats > 0:
        total_rows = DEFAULT_SEAT_ROWS
        seats_per_row = max(1, ceil(total_seats / total_rows))

    venue = models.Venue(
        name=theatre_name,
        location=theatre_meta.get("area") or "",
        total_rows=total_rows,
        seats_per_row=seats_per_row,
    )
    db.add(venue)
    db.flush()

    return venue


def _ensure_seats(db: Session, venue: models.Venue) -> None:
    existing = db.query(models.Seat).filter(models.Seat.venue_id == venue.id).first()
    if existing:
        return

    for row in range(1, venue.total_rows + 1):
        for seat_num in range(1, venue.seats_per_row + 1):
            db.add(
                models.Seat(
                    venue_id=venue.id,
                    row_number=row,
                    seat_number=seat_num,
                )
            )


def ensure_movie_event(
    db: Session,
    movie_title: str,
    theatre_name: str,
    showtime: str,
) -> models.Event:
    event_name = _build_event_name(movie_title, theatre_name, showtime)
    event_date = _parse_showtime(showtime)

    event = db.query(models.Event).filter(
        models.Event.name == event_name,
        models.Event.theatre_name == theatre_name,
    ).first()
    if event:
        return event

    venue = _ensure_venue(db, theatre_name)
    _ensure_seats(db, venue)

    theatre_meta = _find_theatre_meta(theatre_name) or {}
    base_price = _parse_price_range(theatre_meta.get("price_range_inr"))

    event = models.Event(
        name=event_name,
        venue_id=venue.id,
        event_date=event_date,
        base_price=base_price,
        event_type="movie",
        status=models.EventStatus.published,
        image_url=None,
        theatre_name=theatre_name,
        theatre_location=theatre_meta.get("area"),
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


def build_show_dates(start_date: datetime, end_date: datetime) -> list[str]:
    if start_date > end_date:
        start_date, end_date = end_date, start_date
    days = (end_date.date() - start_date.date()).days
    if days < 0:
        return []
    return [
        (start_date.date() + timedelta(days=offset)).isoformat()
        for offset in range(days + 1)
    ]


def build_showtimes_by_date(start_date: datetime, end_date: datetime, show_times: list[str]) -> dict[str, list[str]]:
    return {date_str: list(show_times) for date_str in build_show_dates(start_date, end_date)}


def _ensure_pricing_rules(db: Session, event_id: int, overrides: dict | None) -> None:
    if not overrides:
        return
    for name, price in overrides.items():
        if price is None:
            continue
        category = db.query(models.SeatCategory).filter(
            models.SeatCategory.name.ilike(str(name))
        ).first()
        if not category:
            continue
        existing = db.query(models.PricingRule).filter(
            models.PricingRule.event_id == event_id,
            models.PricingRule.seat_category_id == category.id,
        ).first()
        if existing:
            existing.price_override = float(price)
        else:
            db.add(
                models.PricingRule(
                    event_id=event_id,
                    seat_category_id=category.id,
                    price_override=float(price),
                )
            )


def ensure_movie_event_instance(
    db: Session,
    config: models.MovieShowConfig,
    show_date: datetime,
    show_time: str,
) -> models.Event:
    date_only = show_date.date()
    if date_only < config.start_date.date() or date_only > config.end_date.date():
        raise ValueError("Show date is outside configured range")
    if show_time not in (config.show_times or []):
        raise ValueError("Show time is not configured")

    try:
        time_part = datetime.strptime(show_time, "%H:%M").time()
    except ValueError:
        raise ValueError("Invalid show time format")

    event_date = datetime.combine(date_only, time_part)
    event_name = f"{config.movie_title} @ {config.theatre_name} {date_only.isoformat()} {show_time}"

    event = db.query(models.Event).filter(
        models.Event.name == event_name,
        models.Event.theatre_name == config.theatre_name,
        models.Event.event_date == event_date,
    ).first()
    if event:
        return event

    venue = db.query(models.Venue).filter(models.Venue.id == config.venue_id).first()
    if not venue:
        venue = _ensure_venue(db, config.theatre_name)

    _ensure_seats(db, venue)

    event = models.Event(
        name=event_name,
        venue_id=venue.id,
        event_date=event_date,
        base_price=config.base_price,
        event_type="movie",
        status=models.EventStatus.published,
        image_url=config.image_url,
        theatre_name=config.theatre_name,
        theatre_location=config.theatre_location,
    )
    db.add(event)
    db.flush()

    _ensure_pricing_rules(db, event.id, config.pricing_overrides)

    db.commit()
    db.refresh(event)
    return event
