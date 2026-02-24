from datetime import datetime

from pydantic import BaseModel,EmailStr
from typing import List

class ChatRequest(BaseModel):
    message: str

class LockSeatsRequest(BaseModel):
    user_id: int
    seat_ids: List[int]

class ConfirmBookingRequest(BaseModel):
    user_id: int
    seat_ids: list[int]

class SeatResponse(BaseModel):
    id: int
    row_number: int
    seat_number: int

    class Config:
        orm_mode = True

class SeatStatusResponse(BaseModel):
    id: int
    row_number: int
    seat_number: int
    status: str  # available / locked / booked

    class Config:
        orm_mode = True

class EventResponse(BaseModel):
    id: int
    name: str
    venue_id: int
    event_date: str
    price: float

    class Config:
        orm_mode = True

class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class EventCreate(BaseModel):
    name: str
    venue_id: int
    event_date: datetime
    base_price: float
    image_url: str | None = None


class EventUpdate(BaseModel):
    name: str | None = None
    event_date: datetime | None = None
    base_price: float | None = None
    image_url: str | None = None


class VenueCreate(BaseModel):
    name: str
    location: str
    total_rows: int
    seats_per_row: int


class VenueUpdate(BaseModel):
    name: str | None = None
    location: str | None = None
    total_rows: int | None = None
    seats_per_row: int | None = None