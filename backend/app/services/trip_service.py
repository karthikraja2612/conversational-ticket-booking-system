from __future__ import annotations

from datetime import datetime, timedelta
import logging
from typing import Optional, Tuple

from sqlalchemy.orm import Session

from ..models import Booking, Event, Venue
from .place_service import calculate_distance, get_nearby_places
from .theatre_service import load_theatres

DEFAULT_LAT = 11.0168
DEFAULT_LNG = 76.9558
LOGGER = logging.getLogger(__name__)


class TripService:
    _plan_cache: dict[tuple[int, str], dict] = {}

    @staticmethod
    def get_nearby_places(lat: float, lng: float, radius_km: float, intent: Optional[str]) -> list[dict]:
        return get_nearby_places(
            user_lat=lat,
            user_lng=lng,
            limit=10,
            intent=intent,
            distance_km=radius_km,
        )

    @staticmethod
    def filter_by_intent(places: list[dict], intent: Optional[str]) -> list[dict]:
        if not intent:
            return places
        intent_key = intent.strip().lower()
        if not intent_key:
            return places

        intent_map = {
            "fun": ["entertainment", "mall", "show", "theatre"],
            "relax": ["park", "garden", "lake"],
            "food": ["restaurant", "food", "cafe"],
            "explore": ["museum", "heritage", "art", "history", "attraction"],
        }
        keywords = intent_map.get(intent_key)
        if not keywords:
            return places

        filtered = []
        for place in places:
            category = str(place.get("category", "")).lower()
            if any(k in category for k in keywords):
                filtered.append(place)
        return filtered or places

    @staticmethod
    def generate_itinerary(
        event_time: datetime,
        user_location: Tuple[float, float],
        intent: Optional[str],
        event_name: Optional[str] = None,
    ) -> dict:
        lat, lng = user_location
        places = TripService.get_nearby_places(lat, lng, radius_km=5.0, intent=intent)
        places = TripService.filter_by_intent(places, intent)

        now = TripService._now()
        minutes_to_event = int((event_time - now).total_seconds() / 60)
        buffer_before_min = 15
        buffer_after_min = 15

        before_window_min = max(0, min(120, minutes_to_event - buffer_before_min))
        after_window_min = 120
        event_duration_min = 120

        event_start = event_time
        event_end = event_time + timedelta(minutes=event_duration_min)
        before_end = event_start - timedelta(minutes=buffer_before_min)
        before_start = before_end - timedelta(minutes=before_window_min)
        after_start = event_end + timedelta(minutes=buffer_after_min)
        after_end = after_start + timedelta(minutes=after_window_min)

        if not TripService._is_window_open(before_start, before_end):
            before_window_min = 0
        if not TripService._is_window_open(after_start, after_end):
            after_window_min = 0

        before_end = before_start + timedelta(minutes=before_window_min)
        after_end = after_start + timedelta(minutes=after_window_min)

        before_places = TripService._filter_open_places(places, before_start, before_end)
        after_places = TripService._filter_open_places(places, after_start, after_end)

        max_before = 3 if before_window_min >= 60 else 1
        max_after = 2 if after_window_min >= 60 else 1

        before_entries = TripService._build_place_entries(
            places=before_places,
            start_time=before_start,
            window_minutes=before_window_min,
            max_items=max_before,
            center_lat=lat,
            center_lng=lng,
            window_end=before_end,
        )
        after_entries = TripService._build_place_entries(
            places=after_places,
            start_time=after_start,
            window_minutes=after_window_min,
            max_items=max_after,
            center_lat=lat,
            center_lng=lng,
            window_end=after_end,
            skip_names={entry["place"] for entry in before_entries},
        )

        available_total = before_window_min + after_window_min
        if available_total < 60:
            total_allowed = 1
            if len(before_entries) >= total_allowed:
                after_entries = []
            else:
                after_entries = after_entries[: total_allowed - len(before_entries)]

        plan = []
        plan.extend(before_entries)
        plan.append(
            {
                "time": TripService._format_range(event_start, event_end),
                "place": event_name or "Event",
                "type": "event",
            }
        )
        plan.extend(after_entries)

        return {
            "event": {
                "name": event_name or "Event",
                "time": event_time.strftime("%H:%M"),
            },
            "plan": plan,
        }

    @classmethod
    def plan_from_booking(
        cls,
        db: Session,
        booking_id: int,
        intent: Optional[str],
        refresh: bool = False,
    ) -> dict:
        cache_key = (booking_id, (intent or "").strip().lower())
        if not refresh and cache_key in cls._plan_cache:
            return cls._plan_cache[cache_key]

        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise ValueError("Booking not found")

        event = db.query(Event).filter(Event.id == booking.event_id).first()
        if not event:
            raise ValueError("Event not found for booking")

        venue = None
        if event.venue_id is not None:
            venue = db.query(Venue).filter(Venue.id == event.venue_id).first()

        event_time = event.event_date or datetime.utcnow()
        lat, lng = cls._resolve_event_location(event, venue)

        result = cls.generate_itinerary(
            event_time=event_time,
            user_location=(lat, lng),
            intent=intent,
            event_name=event.name,
        )

        LOGGER.info(
            "Trip plan generated",
            extra={
                "booking_id": booking_id,
                "intent": intent,
                "plan_size": len(result.get("plan", [])),
            },
        )

        cls._plan_cache[cache_key] = result
        return result

    @staticmethod
    def _resolve_event_location(event: Event, venue: Optional[Venue]) -> Tuple[float, float]:
        query = ""
        if event.theatre_name:
            query = event.theatre_name
        elif venue and venue.name:
            query = venue.name
        elif event.theatre_location:
            query = event.theatre_location
        elif venue and venue.location:
            query = venue.location

        query_key = query.strip().lower()
        if query_key:
            for theatre in load_theatres():
                name = str(theatre.get("name", "")).strip().lower()
                area = str(theatre.get("area", "")).strip().lower()
                if not name:
                    continue
                if query_key in name or name in query_key or query_key in area:
                    lat = theatre.get("latitude")
                    lng = theatre.get("longitude")
                    if lat is not None and lng is not None:
                        return float(lat), float(lng)

        return DEFAULT_LAT, DEFAULT_LNG

    @staticmethod
    def _build_place_entries(
        places: list[dict],
        start_time: datetime,
        window_minutes: int,
        max_items: int,
        center_lat: float,
        center_lng: float,
        window_end: datetime,
        skip_names: Optional[set[str]] = None,
    ) -> list[dict]:
        entries = []
        remaining = window_minutes
        current = start_time
        seen = skip_names or set()

        for place in places:
            if len(entries) >= max_items or remaining <= 0:
                break
            name = str(place.get("name", "")).strip() or "Place"
            if name in seen:
                continue

            duration = TripService._estimate_duration_minutes(place.get("category"))
            end_time = current + timedelta(minutes=duration)
            if end_time > window_end:
                continue
            if duration > remaining:
                continue

            distance_km = TripService._extract_distance_km(place, lat=center_lat, lng=center_lng)
            entry = {
                "time": TripService._format_range(current, end_time),
                "place": name,
                "type": TripService._map_type(place.get("category")),
                "distance_km": distance_km,
            }
            entries.append(entry)
            seen.add(name)
            current = end_time
            remaining -= duration

        return entries

    @staticmethod
    def _filter_open_places(places: list[dict], window_start: datetime, window_end: datetime) -> list[dict]:
        open_places = []
        for place in places:
            if TripService._is_open_for_window(place, window_start, window_end):
                open_places.append(place)
        return open_places

    @staticmethod
    def _is_window_open(window_start: datetime, window_end: datetime) -> bool:
        open_hour = 9
        close_hour = 22
        if window_start.hour < open_hour or window_end.hour >= close_hour:
            return False
        return True

    @staticmethod
    def _is_open_for_window(place: dict, window_start: datetime, window_end: datetime) -> bool:
        category = str(place.get("category", "")).lower()
        is_food = "restaurant" in category or "food" in category or "cafe" in category

        open_hour = 9
        close_hour = 23 if is_food else 22

        if window_start.hour < open_hour or window_end.hour >= close_hour:
            return False
        return True

    @staticmethod
    def _now() -> datetime:
        return datetime.utcnow()

    @staticmethod
    def _format_range(start: datetime, end: datetime) -> str:
        return f"{start.strftime('%H:%M')} - {end.strftime('%H:%M')}"

    @staticmethod
    def _estimate_duration_minutes(category: Optional[str]) -> int:
        category_key = (category or "").lower()
        if "museum" in category_key:
            return 90
        if "park" in category_key or "garden" in category_key:
            return 45
        if "restaurant" in category_key or "food" in category_key or "cafe" in category_key:
            return 60
        if "entertainment" in category_key or "mall" in category_key:
            return 75
        return 45

    @staticmethod
    def _map_type(category: Optional[str]) -> str:
        category_key = (category or "").lower()
        if "restaurant" in category_key or "food" in category_key or "cafe" in category_key:
            return "food"
        if "park" in category_key or "garden" in category_key:
            return "relax"
        if "museum" in category_key or "heritage" in category_key or "art" in category_key:
            return "explore"
        if "entertainment" in category_key or "mall" in category_key:
            return "fun"
        return "explore"

    @staticmethod
    def _extract_distance_km(place: dict, lat: float, lng: float) -> float:
        distance = place.get("distance")
        if isinstance(distance, str):
            raw = distance.replace("km", "").strip()
            try:
                return round(float(raw), 1)
            except ValueError:
                pass
        distance_km = place.get("distance_km")
        if isinstance(distance_km, (int, float)):
            return round(float(distance_km), 1)

        place_lat = place.get("latitude")
        place_lng = place.get("longitude")
        if place_lat is not None and place_lng is not None:
            return round(calculate_distance(lat, lng, place_lat, place_lng), 1)

        return 0.0
