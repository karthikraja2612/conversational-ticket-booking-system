from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from ..models import Event, Venue
from .place_service import get_nearby_places


_INTENT_KEYWORDS = {
    "fun": ["concert", "music", "show", "festival", "comedy", "party", "movie", "theatre", "jazz"],
    "relax": ["yoga", "acoustic", "classical", "calm", "meditation", "wellness"],
    "food": ["food", "tasting", "brunch", "dinner", "culinary", "street"],
    "explore": ["museum", "exhibition", "heritage", "art", "history"],
}


def _parse_start_time(start_time: Optional[str]) -> datetime:
    if not start_time:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(start_time)
    except ValueError:
        return datetime.utcnow()


def _filter_events_by_intent(events: list[dict], intent: Optional[str]) -> list[dict]:
    if not intent:
        return events
    intent_key = intent.lower().strip()
    keywords = _INTENT_KEYWORDS.get(intent_key)
    if not keywords:
        return events
    matched = [e for e in events if any(k in e["name"].lower() for k in keywords)]
    return matched if matched else events


def _serialize_event(event: Event, venue: Optional[Venue]) -> dict:
    return {
        "id": event.id,
        "name": event.name,
        "event_date": event.event_date.isoformat() if event.event_date else None,
        "base_price": event.base_price,
        "event_type": event.event_type,
        "venue": {
            "id": venue.id if venue else None,
            "name": venue.name if venue else None,
            "location": venue.location if venue else None,
        },
        "image_url": event.image_url,
    }


def plan_trip(
    db: Session,
    user_lat: float,
    user_lng: float,
    intent: Optional[str] = None,
    distance_km: Optional[float] = None,
    area: Optional[str] = None,
    hours: int = 4,
    start_time: Optional[str] = None,
    max_events: int = 2,
    max_places: int = 4,
) -> dict:
    hours = max(1, min(hours, 12))
    max_events = max(0, min(max_events, 5))
    max_places = max(0, min(max_places, 10))

    events_rows = (
        db.query(Event, Venue)
        .join(Venue, Event.venue_id == Venue.id, isouter=True)
        .filter(Event.status != "cancelled")
        .order_by(Event.event_date)
        .all()
    )
    events = [_serialize_event(event, venue) for event, venue in events_rows]
    events = _filter_events_by_intent(events, intent)[:max_events]

    places = get_nearby_places(
        user_lat=user_lat,
        user_lng=user_lng,
        limit=max_places,
        intent=intent,
        distance_km=distance_km,
        area=area,
    )

    schedule = []
    current_time = _parse_start_time(start_time)
    remaining_minutes = hours * 60

    def add_item(item_type: str, name: str, duration_minutes: int, details: dict):
        nonlocal current_time, remaining_minutes
        if remaining_minutes <= 0:
            return
        duration = min(duration_minutes, remaining_minutes)
        end_time = current_time + timedelta(minutes=duration)
        schedule.append(
            {
                "type": item_type,
                "name": name,
                "start_time": current_time.isoformat(),
                "end_time": end_time.isoformat(),
                "details": details,
            }
        )
        current_time = end_time
        remaining_minutes -= duration

    event_index = 0
    place_index = 0
    while remaining_minutes > 0 and (event_index < len(events) or place_index < len(places)):
        if event_index < len(events):
            event = events[event_index]
            add_item("event", event["name"], 120, event)
            event_index += 1
            if remaining_minutes <= 0:
                break
        if place_index < len(places):
            place = places[place_index]
            add_item("place", place["name"], 60, place)
            place_index += 1
        if event_index >= len(events) and place_index >= len(places):
            break

    return {
        "intent": intent,
        "start_time": schedule[0]["start_time"] if schedule else _parse_start_time(start_time).isoformat(),
        "total_hours": hours,
        "events": events,
        "nearby_places": places,
        "itinerary": schedule,
    }
