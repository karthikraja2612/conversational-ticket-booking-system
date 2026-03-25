import time
from datetime import datetime, timedelta

import pytest

from app.models import Booking, BookingStatus, Event, User, Venue
from app.services.trip_service import TripService

_TS = int(time.time())
_EMAIL = f"triptest_{_TS}@example.com"
_PASS = "triptest123"


def _register(client):
    return client.post(
        "/auth/register",
        json={"name": "Trip Tester", "email": _EMAIL, "password": _PASS},
    )


def _login(client):
    return client.post(
        "/auth/login",
        data={"username": _EMAIL, "password": _PASS},
    )


@pytest.fixture(scope="module")
def auth_headers(client):
    reg = _register(client)
    if reg.status_code not in (200, 400):
        pytest.fail(f"Unexpected register status: {reg.status_code} — {reg.text}")
    log = _login(client)
    assert log.status_code == 200, f"Login failed: {log.text}"
    token = log.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def booking_id(client, auth_headers, db_session):
    me = client.get("/users/me", headers=auth_headers).json()
    user_id = me["id"]

    venue = Venue(name="Test Venue", location="Central", total_rows=10, seats_per_row=10)
    db_session.add(venue)
    db_session.commit()

    event = Event(
        name="Late Night Jazz",
        venue_id=venue.id,
        event_date=datetime.utcnow() + timedelta(hours=4),
        base_price=200.0,
        event_type="concert",
        theatre_name="KG Cinemas",
        theatre_location="Race Course",
    )
    db_session.add(event)
    db_session.commit()

    booking = Booking(
        user_id=user_id,
        event_id=event.id,
        total_amount=400.0,
        status=BookingStatus.confirmed,
        created_at=datetime.utcnow(),
    )
    db_session.add(booking)
    db_session.commit()

    return booking.id


def test_plan_from_booking_event_only_when_no_places(client, auth_headers, booking_id, monkeypatch):
    monkeypatch.setattr(TripService, "get_nearby_places", lambda *args, **kwargs: [])

    res = client.post(
        "/trip/plan-from-booking",
        json={"booking_id": booking_id, "intent": "fun"},
        headers=auth_headers,
    )
    assert res.status_code == 200, res.text
    body = res.json()
    plan = body.get("plan", [])
    assert len(plan) == 1
    assert plan[0]["type"] == "event"


def test_short_window_limits_places(client, auth_headers, booking_id, monkeypatch, db_session):
    fixed_now = datetime(2026, 1, 1, 21, 30)
    event_time = fixed_now + timedelta(minutes=30)

    booking = db_session.query(Booking).filter(Booking.id == booking_id).first()
    event = db_session.query(Event).filter(Event.id == booking.event_id).first()
    event.event_date = event_time
    db_session.commit()

    monkeypatch.setattr(TripService, "_now", lambda: fixed_now)
    monkeypatch.setattr(
        TripService,
        "get_nearby_places",
        lambda *args, **kwargs: [
            {"name": "Cafe A", "category": "Restaurant", "distance": "1.0 km"},
            {"name": "Park B", "category": "Park", "distance": "2.0 km"},
            {"name": "Museum C", "category": "Museum", "distance": "3.0 km"},
        ],
    )

    res = client.post(
        "/trip/plan-from-booking",
        json={"booking_id": booking_id, "intent": "food", "refresh": True},
        headers=auth_headers,
    )
    assert res.status_code == 200, res.text
    plan = res.json().get("plan", [])
    non_event = [item for item in plan if item.get("type") != "event"]
    assert len(non_event) <= 1


def test_intent_switching_changes_plan(client, auth_headers, booking_id, monkeypatch):
    def _places(*args, **kwargs):
        intent = kwargs.get("intent")
        if intent == "food":
            return [{"name": "Food Stop", "category": "Restaurant", "distance": "1.0 km"}]
        return [{"name": "Fun Stop", "category": "Entertainment", "distance": "1.5 km"}]

    monkeypatch.setattr(TripService, "get_nearby_places", _places)

    food = client.post(
        "/trip/plan-from-booking",
        json={"booking_id": booking_id, "intent": "food", "refresh": True},
        headers=auth_headers,
    )
    fun = client.post(
        "/trip/plan-from-booking",
        json={"booking_id": booking_id, "intent": "fun", "refresh": True},
        headers=auth_headers,
    )

    assert food.status_code == 200
    assert fun.status_code == 200

    food_plan = food.json().get("plan", [])
    fun_plan = fun.json().get("plan", [])

    assert any(item.get("place") == "Food Stop" for item in food_plan)
    assert any(item.get("place") == "Fun Stop" for item in fun_plan)


def test_plan_from_booking_not_found(client, auth_headers):
    res = client.post(
        "/trip/plan-from-booking",
        json={"booking_id": 999999, "intent": "fun"},
        headers=auth_headers,
    )
    assert res.status_code == 404
