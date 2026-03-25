import os
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from .database import engine, SessionLocal, get_db
from .models import Base, Seat, Venue, Event
from . import models
from .services.movie_event_service import build_show_dates, build_showtimes_by_date
from .routes import (
    seats,
    auth,
    chat,
    users,
    admin,
    admin_auth,
    admin_events,
    admin_venues,
    booking,
    places,
    trips,
    plan_trip,
    theatres,
    movies,
)
from .routes.admin_auth import get_current_admin
from fastapi.middleware.cors import CORSMiddleware
from typing import List

load_dotenv()
FRONTEND_ORIGIN = os.getenv("FRONTEND_ORIGIN", "http://localhost:8080")

app = FastAPI()


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    message = exc.detail if isinstance(exc.detail, str) else "Request failed"
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": "http_error", "message": message},
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    message = "Validation error"
    if exc.errors():
        first = exc.errors()[0]
        message = first.get("msg", message)
    return JSONResponse(
        status_code=422,
        content={"error": "validation_error", "message": message},
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_ORIGIN],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(seats.router)
app.include_router(booking.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(chat.router)
app.include_router(admin.router)
app.include_router(admin_auth.router)
app.include_router(admin_events.router)
app.include_router(admin_venues.router)
app.include_router(places.router)
app.include_router(trips.router)
app.include_router(plan_trip.router)
app.include_router(theatres.router)
app.include_router(movies.router)

# Schema is managed by Alembic migrations.
# Run: alembic upgrade head
# Do NOT use Base.metadata.create_all() here — it silently ignores column changes.



@app.get("/")
def root():
    return {"message": "TicketBot API is running"}


@app.get("/events", response_model=List[dict])
def get_events(db: Session = Depends(get_db)):
    events = db.query(Event).filter(Event.status != "cancelled").order_by(Event.event_date).all()
    movie_configs = db.query(models.MovieShowConfig).filter(
        models.MovieShowConfig.status != models.EventStatus.cancelled
    ).order_by(models.MovieShowConfig.start_date).all()

    payload = []
    for e in events:
        payload.append({
            "id": e.id,
            "name": e.name,
            "venue_id": e.venue_id,
            "event_date": str(e.event_date),
            "price": e.base_price,
            "image_url": e.image_url,
            "event_type": e.event_type,
            "theatre_name": e.theatre_name,
            "theatre_location": e.theatre_location,
        })

    for config in movie_configs:
        start_date = config.start_date
        end_date = config.end_date
        payload.append({
            "id": config.id,
            "name": config.movie_title,
            "venue_id": config.venue_id,
            "event_date": start_date.isoformat() if start_date else None,
            "price": config.base_price,
            "image_url": config.image_url,
            "event_type": "movie",
            "theatre_name": config.theatre_name,
            "theatre_location": config.theatre_location,
            "available_dates": build_show_dates(start_date, end_date) if start_date and end_date else [],
            "show_times_by_date": build_showtimes_by_date(start_date, end_date, list(config.show_times or []))
            if start_date and end_date else {},
            "is_dynamic": True,
        })

    return payload


@app.get("/generate-seats/{venue_id}")
def generate_seats(venue_id: int, current_admin=Depends(get_current_admin)):
    db = SessionLocal()
    venue = db.query(Venue).filter(Venue.id == venue_id).first()

    if not venue:
        return {"error": "Venue not found"}

    for row in range(1, venue.total_rows + 1):
        for seat_num in range(1, venue.seats_per_row + 1):
            new_seat = Seat(
                venue_id=venue.id,
                row_number=row,
                seat_number=seat_num,
            )
            db.add(new_seat)

    db.commit()
    db.close()

    return {"message": "Seats generated successfully"}