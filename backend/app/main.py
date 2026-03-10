import os
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from .database import engine, SessionLocal, get_db
from .models import Base, Seat, Venue, Event
from .routes import seats, auth, chat, users, admin, admin_auth, admin_events, admin_venues, booking
from .routes.admin_auth import get_current_admin
from fastapi.middleware.cors import CORSMiddleware
from typing import List

load_dotenv()
FRONTEND_ORIGIN = os.getenv("FRONTEND_ORIGIN", "http://localhost:8080")

app = FastAPI()

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

# Schema is managed by Alembic migrations.
# Run: alembic upgrade head
# Do NOT use Base.metadata.create_all() here — it silently ignores column changes.



@app.get("/")
def root():
    return {"message": "TicketBot API is running"}


@app.get("/events", response_model=List[dict])
def get_events(db: Session = Depends(get_db)):
    events = db.query(Event).filter(Event.status != "cancelled").order_by(Event.event_date).all()
    return [
        {
            "id": e.id,
            "name": e.name,
            "venue_id": e.venue_id,
            "event_date": str(e.event_date),
            "price": e.base_price,
            "image_url": e.image_url,
        }
        for e in events
    ]


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