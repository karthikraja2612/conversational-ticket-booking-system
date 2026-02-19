from fastapi import FastAPI
from .database import engine,SessionLocal
from .models import Base,Seat,Venue
from .routes import seats,auth,chat,users
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.include_router(seats.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(chat.router)
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