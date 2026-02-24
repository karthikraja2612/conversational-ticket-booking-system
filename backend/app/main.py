from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from .database import engine, SessionLocal, get_db
from .models import Base, Seat, Venue, Event
from .routes import seats, auth, chat, users
from fastapi.middleware.cors import CORSMiddleware
from typing import List

app = FastAPI()
app.include_router(seats.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(chat.router)

@app.get("/events")
def get_events(db: Session = Depends(get_db)):
    events = db.query(Event).all()
    return [
        {
            "id": e.id,
            "name": e.name,
            "venue_id": e.venue_id,
            "event_date": e.event_date.isoformat() if e.event_date else None,
            "price": e.price,
            "venue": e.venue.name if e.venue else "",
            "location": e.venue.location if e.venue else "",
        }
        for e in events
    ]
Base.metadata.create_all(bind=engine)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"message": "Backend running successfully"}

@app.get("/generate-seats/{venue_id}")
def generate_seats(venue_id: int):
    db = SessionLocal()
    venue = db.query(Venue).filter(Venue.id == venue_id).first()

    for row in range(1, venue.total_rows + 1):
        for seat in range(1, venue.seats_per_row + 1):
            new_seat = Seat(
                venue_id=venue.id,
                row_number=row,
                seat_number=seat
            )
            db.add(new_seat)

    db.commit()
    db.close()

    return {"message": "Seats generated successfully"}