"""
test_core_flows.py — Smoke tests for the 4 core API flows.

Flows covered
─────────────
1. Register   POST /auth/register
2. Login      POST /auth/login  (OAuth2 form)
3. /users/me  GET  (authenticated)
4. Lock       POST /events/{id}/lock-seats  (requires auth)
5. Confirm    POST /events/{id}/confirm-booking  (requires auth)
6. Payment    POST /events/{id}/process-payment  (requires auth)

Items 4-6 only assert that 401 is returned when *unauthenticated* and that
the correct error shape is returned when authenticated but no valid data
exists (no real event/seats in the SQLite test DB).

Run with:
    cd ticketing_system/backend
    pytest tests/ -v
"""
import time
import pytest

# Unique suffix so repeated test runs don't collide on the email UNIQUE constraint
_TS = int(time.time())
_EMAIL = f"smoketest_{_TS}@example.com"
_PASS = "smokepass123"


# ── helpers ────────────────────────────────────────────────────────────────────


def _register(client):
    return client.post(
        "/auth/register",
        json={"name": "Smoke Tester", "email": _EMAIL, "password": _PASS},
    )


def _login(client):
    return client.post(
        "/auth/login",
        data={"username": _EMAIL, "password": _PASS},
    )


@pytest.fixture(scope="module")
def auth_token(client):
    """Register once, log in, return the JWT access token."""
    reg = _register(client)
    if reg.status_code not in (200, 400):  # 400 = already registered
        pytest.fail(f"Unexpected register status: {reg.status_code} — {reg.text}")
    log = _login(client)
    assert log.status_code == 200, f"Login failed: {log.text}"
    return log.json()["access_token"]


@pytest.fixture(scope="module")
def auth_headers(auth_token):
    return {"Authorization": f"Bearer {auth_token}"}


# ── 1. Register ────────────────────────────────────────────────────────────────


def test_register_returns_token(client):
    """A fresh email must register successfully and return an access_token."""
    unique_email = f"reg_{_TS}@example.com"
    res = client.post(
        "/auth/register",
        json={"name": "Reg Test", "email": unique_email, "password": "reg1234!"},
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"


def test_register_duplicate_email_fails(client):
    """Re-registering an existing email must return 4xx."""
    _register(client)  # ensure it exists
    res = _register(client)
    assert res.status_code in (400, 409, 422), res.text


# ── 2. Login ───────────────────────────────────────────────────────────────────


def test_login_returns_token(client):
    _register(client)
    res = _login(client)
    assert res.status_code == 200, res.text
    assert "access_token" in res.json()


def test_login_wrong_password_rejected(client):
    _register(client)
    res = client.post(
        "/auth/login",
        data={"username": _EMAIL, "password": "wrongpassword"},
    )
    assert res.status_code in (400, 401, 403), res.text


# ── 3. Authenticated user endpoint ────────────────────────────────────────────


def test_get_me(client, auth_headers):
    res = client.get("/users/me", headers=auth_headers)
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["email"] == _EMAIL
    assert "id" in body


def test_get_me_unauthenticated(client):
    res = client.get("/users/me")
    assert res.status_code == 401


def test_bookings_list_empty(client, auth_headers):
    """A brand-new user should have an empty bookings list, not an error."""
    res = client.get("/users/me/bookings", headers=auth_headers)
    assert res.status_code == 200, res.text
    assert res.json() == []


def test_bookings_pagination_params_accepted(client, auth_headers):
    """skip / limit query params must be accepted without error."""
    res = client.get("/users/me/bookings?skip=0&limit=10", headers=auth_headers)
    assert res.status_code == 200


def test_bookings_unauthenticated(client):
    res = client.get("/users/me/bookings")
    assert res.status_code == 401


# ── 4. Lock seats — auth guard ─────────────────────────────────────────────────


def test_lock_requires_auth(client):
    res = client.post("/events/1/lock-seats", json={"seat_ids": [1, 2]})
    assert res.status_code == 401


def test_lock_nonexistent_event_returns_error(client, auth_headers):
    """With auth but no matching event/seats, expect 4xx (not 5xx)."""
    res = client.post(
        "/events/99999/lock-seats",
        json={"seat_ids": [99999]},
        headers=auth_headers,
    )
    assert res.status_code in (400, 404, 422), res.text


# ── 5. Confirm booking — auth guard ───────────────────────────────────────────


def test_confirm_requires_auth(client):
    res = client.post("/events/1/confirm-booking", json={"seat_ids": [1]})
    assert res.status_code == 401


# ── 6. Process payment — auth guard ───────────────────────────────────────────


def test_payment_requires_auth(client):
    res = client.post("/events/1/process-payment", params={"booking_id": 1})
    assert res.status_code == 401
