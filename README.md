# TicketBot — AI-Powered Conversational Ticketing System

A production-grade event ticketing platform with a conversational chatbot interface, real-time seat locking, dynamic pricing, payment processing, and QR-based ticket generation.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Security](#security)

---

## Overview

TicketBot allows users to discover events, select seats through a conversational chat interface powered by Rasa NLP, lock seats in real time, pay via a card form, and receive a shareable QR-code ticket — all inside a Flutter mobile app backed by a FastAPI REST service.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App (Android)               │
│   HomeScreen → EventDetail → Chat → SeatSelection       │
│   → PaymentModal → TicketConfirmation → BookingHistory  │
└───────────────────┬─────────────────────────────────────┘
                    │ HTTP / REST
          ┌─────────▼──────────┐       ┌──────────────────┐
          │   FastAPI Backend   │       │   Rasa NLP Server │
          │   (port 8000)       │◄─────►│   (port 5005)     │
          │   SQLAlchemy ORM    │       │   Custom Actions  │
          └─────────┬──────────┘       └──────────────────┘
                    │
            ┌───────▼───────┐
            │  MySQL Database│
            │  (Alembic mgd) │
            └───────────────┘
```

---

## Features

### 1. User Authentication
- JWT access + refresh token flow
- Tokens stored in Android Keystore via `flutter_secure_storage`
- Auto-refresh on 401 responses — seamless session continuity
- Passwords hashed with bcrypt

### 2. Event Browsing
- Live event listing fetched from the backend with retry on network failure
- Dedicated **Event Detail Screen** showing event info and a seat-count stepper (1–8 seats)

### 3. Conversational Chatbot Booking
- Rasa NLP processes natural language input (e.g. *"tomorrow at 7pm"*)
- Chat state machine guides users through the booking flow
- Animated chat bubbles, typing indicators, and glassmorphic UI
- Supports booking history queries via dedicated intent

### 4. Real-Time Seat Locking
- Selected seats are locked server-side for **5 minutes**
- Lock countdown banner in the Flutter UI with colour transitions:
  - 🔵 Blue (5–4 min) → 🟠 Orange (4–2 min) → 🔴 Red (< 2 min)
- Expired locks auto-release seats and navigate the user back to chat
- `user_id` always derived from the JWT — no spoofing via request body

### 5. Dynamic / VIP Pricing
- `SeatCategory` and `PricingRule` models enable tiered pricing (Standard, VIP, etc.)
- Final price resolved via a category multiplier + optional per-seat price override
- Managed through an Alembic migration (revision `a2f8c5d9e1b4`)

### 6. Payment Processing
- Full card form inside a modal overlay:
  - Card number auto-formatted with spaces
  - Expiry field formatted as `MM/YY`
  - Real-time CVV and field-length validation
- Calls `POST /events/{id}/process-payment?booking_id={booking_id}` on submission

### 7. QR Ticket Generation & Sharing
- After payment, a QR code embedding the booking ID is generated on-device
- Users can **share** the ticket text or **save** the QR image via `share_plus`
- Professional ticket card UI with event, seat, and price details

### 8. Booking History
- Paginated `GET /users/me/bookings` endpoint (`skip` / `limit` params)
- Event name joined server-side and returned alongside booking metadata
- Displayed in a dedicated `BookingsHistoryScreen`

### 9. Push Notifications
- **Booking Confirmed** — fires immediately after successful payment
- **Lock Expiry Warning** — fires when the 5-minute seat lock is about to expire
- Powered by `flutter_local_notifications` v20

### 10. Admin Panel
- Separate admin authentication with `get_current_admin` route guard
- Manage events (`/admin/events`), venues (`/admin/venues`)
- View analytics (revenue, booking counts) at `/admin/analytics`
- Admin-only seat generation endpoint `/generate-seats`

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend API | FastAPI, SQLAlchemy, Alembic, MySQL |
| Authentication | JWT (`python-jose`), bcrypt |
| Chatbot | Rasa (NLU + Core + Custom Actions) |
| Frontend | Flutter 3.41 (Dart), Provider |
| Secure Storage | Android Keystore via `flutter_secure_storage` |
| Push Notifications | `flutter_local_notifications` |
| QR & Sharing | `qr_flutter`, `share_plus` |
| Runtime Config | `flutter_dotenv` + `.env` files |
| Backend Tests | `pytest`, `httpx` |

---

## Project Structure

```
ticketing_system/
├── backend/
│   ├── app/
│   │   ├── main.py               # FastAPI app, CORS, router registration
│   │   ├── models.py             # SQLAlchemy ORM models (User, Event, Seat, Booking, SeatCategory, PricingRule…)
│   │   ├── schemas.py            # Pydantic request/response schemas
│   │   ├── crud.py               # All DB logic (lock_seats, confirm_booking, process_payment…)
│   │   ├── database.py           # Engine, session factory
│   │   ├── security.py           # Password hashing, JWT creation/verification
│   │   └── routes/
│   │       ├── auth.py           # /auth/register, /auth/login, /auth/refresh
│   │       ├── seats.py          # /events/{id}/seats-status, lock-seats
│   │       ├── booking.py        # /events/{id}/confirm-booking, /events/{id}/process-payment
│   │       ├── users.py          # /users/me, /users/me/bookings (paginated)
│   │       ├── chat.py           # /chat — proxies to Rasa
│   │       ├── admin.py          # /admin/analytics
│   │       ├── admin_auth.py     # Admin JWT guard
│   │       ├── admin_events.py   # /admin/events CRUD
│   │       └── admin_venues.py   # /admin/venues CRUD
│   ├── services/
│   │   ├── analytics_service.py
│   │   ├── chat_engine.py
│   │   ├── lock_service.py
│   │   └── seat_recommender.py
│   ├── alembic/                  # Database migration history
│   │   └── versions/
│   │       ├── 664031ccf339_initial_schema_with_enums.py
│   │       └── a2f8c5d9e1b4_add_seat_categories_and_pricing_rules.py
│   ├── chatbot_nlp/              # Rasa project
│   │   ├── data/nlu.yml          # Intents and training examples
│   │   ├── data/stories.yml      # Conversation flows
│   │   ├── data/rules.yml
│   │   ├── domain.yml
│   │   └── actions/actions.py    # Custom Rasa actions
│   └── tests/
│       └── test_core_flows.py    # 12 end-to-end smoke tests
│
└── frontend/ticketing_app/
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── constants/app_constants.dart   # baseUrl from .env
        │   ├── theme/                          # Neo-dark glassmorphic theme
        │   └── utils/validators.dart
        ├── data/
        │   ├── models/             # Event, Booking, Seat, User, Message
        │   ├── repositories/       # Event, Booking, Seat repositories
        │   └── services/
        │       ├── api_service.dart         # HTTP client with retry logic
        │       ├── chatbot_service.dart     # Rasa REST integration
        │       ├── notification_service.dart
        │       └── qr_service.dart
        ├── domain/state/
        │   ├── auth_state.dart         # Login, tokens (FlutterSecureStorage)
        │   ├── booking_state.dart      # Global booking flow state
        │   ├── chat_state.dart         # Conversation state
        │   └── seat_selection_state.dart
        └── presentation/
            ├── screens/
            │   ├── home_screen.dart
            │   ├── event_detail_screen.dart
            │   ├── chat_screen.dart
            │   ├── seat_selection_screen.dart
            │   ├── ticket_confirmation_screen.dart
            │   └── bookings_history_screen.dart
            └── widgets/
                ├── payment/payment_modal.dart      # Card form + validation
                ├── seats/                          # SeatGrid, SeatItem, LockTimerBanner
                ├── chat/                           # MessageBubble, TypingIndicator
                └── common/                         # GlassContainer, GradientButton…
```

---

## Getting Started

### Prerequisites

- Python 3.10+
- Flutter 3.41+
- MySQL (running locally)
- Rasa 3.x (`pip install rasa`)
- Android emulator or physical device

### 1. Backend Setup

```bash
cd ticketing_system/backend

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

# Install dependencies
pip install fastapi uvicorn sqlalchemy pymysql alembic python-jose[cryptography] bcrypt python-dotenv

# Configure environment
# Create backend/.env with:
# DATABASE_URL=mysql+pymysql://user:password@localhost/ticketing_system
# SECRET_KEY=your-secret-key-here
# FRONTEND_ORIGIN=http://localhost:8080

# Run migrations
alembic upgrade head

# Start the API server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### 2. Chatbot Setup

```bash
cd ticketing_system/backend/chatbot_nlp

# Train the Rasa model
rasa train

# Start the action server (Terminal 1)
rasa run actions

# Start the Rasa API server (Terminal 2)
rasa run --enable-api --cors "*" --port 5005
```

### 3. Flutter App Setup

```bash
cd ticketing_system/frontend/ticketing_app

# Install dependencies
flutter pub get

# Configure API URL
# Edit assets/.env:
# API_BASE_URL=http://10.0.2.2:8000    ← Android emulator
# API_BASE_URL=http://localhost:8000   ← iOS simulator
# API_BASE_URL=http://192.168.x.x:8000 ← Physical device (use your local IP)

# Run the app
flutter run
```

### End-to-End Flow

1. **Home Screen** → Browse available events
2. **Event Detail** → Select seat count (1–8) → Tap "Find Seats"
3. **Chat Screen** → Type a time preference (e.g. *"tomorrow at 7pm"*)
4. **Seat Selection** → Choose seats → Tap "Lock Seats" (5-minute timer starts)
5. **Confirm Booking** → Tap "Confirm Booking" before timer expires
6. **Payment Modal** → Enter card details → Tap "Confirm Payment"
7. **Ticket Screen** → View QR ticket → Share or save

---

## API Reference

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/auth/register` | — | Register a new user |
| `POST` | `/auth/login` | — | Login, returns JWT access + refresh tokens |
| `POST` | `/auth/refresh` | Refresh token | Obtain a new access token |
| `GET` | `/events` | — | List all active events |
| `GET` | `/events/{id}/seats-status` | — | Get seat availability for an event |
| `POST` | `/events/{id}/lock-seats` | JWT | Lock selected seats for 5 minutes |
| `POST` | `/events/{id}/confirm-booking` | JWT | Confirm a locked booking |
| `POST` | `/events/{id}/process-payment?booking_id={booking_id}` | JWT | Process payment and issue ticket |
| `GET` | `/users/me` | JWT | Get current user profile |
| `GET` | `/users/me/bookings` | JWT | Get paginated booking history |
| `POST` | `/chat` | JWT | Send message to Rasa chatbot |
| `GET` | `/admin/analytics` | Admin JWT | Revenue and booking analytics |
| `POST` | `/admin/events` | Admin JWT | Create a new event |
| `POST` | `/admin/venues` | Admin JWT | Create a new venue |

---

## Testing

### Backend Smoke Tests

```bash
cd ticketing_system/backend
pytest tests/ -v
```

Covers 12 end-to-end scenarios: register → login → browse events → lock seats → confirm booking → process payment.

### Flutter Static Analysis

```bash
cd ticketing_system/frontend/ticketing_app
flutter analyze
```

### Manual API Testing

```bash
# Health check
curl http://localhost:8000/

# List events
curl http://localhost:8000/events

# Register a user
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "secret123"}'

# Login
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "secret123"}'

# Lock seats (replace TOKEN and EVENT_ID)
curl -X POST http://localhost:8000/events/1/lock-seats \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"seat_ids": [1, 2, 3]}'
```

---

## Security

- **JWT tokens**: Short-lived access tokens + refresh tokens; secrets loaded from `.env`
- **CORS**: Restricted to `FRONTEND_ORIGIN` defined in `.env` — no wildcard in production
- **User identity**: `user_id` extracted from JWT on every booking/lock endpoint, never trusted from the request body
- **Password storage**: bcrypt hashing — plaintext passwords never persisted
- **Secure token storage**: Android Keystore via `flutter_secure_storage` (not `SharedPreferences`)
- **Input validation**: `max_length` enforced on chat messages; Pydantic schemas validate all API inputs
- **Admin routes**: Separate `get_current_admin` dependency guards all admin endpoints
- **Database schema**: Managed exclusively by Alembic migrations — no ad-hoc `create_all()` calls
