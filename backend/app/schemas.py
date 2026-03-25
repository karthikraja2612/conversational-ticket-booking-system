from datetime import datetime

from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional, Literal, Dict

EventCategory = Literal["movie", "concert", "festival", "sports", "comedy", "others"]

class ChatRequest(BaseModel):
    message: str = Field(..., max_length=500)


class ChatHistoryItem(BaseModel):
    sender: str
    content: str
    timestamp: datetime

class LockSeatsRequest(BaseModel):
    seat_ids: List[int]

class ConfirmBookingRequest(BaseModel):
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
    base_price: float
    event_type: EventCategory
    theatre_name: Optional[str] = None
    theatre_location: Optional[str] = None

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
    theatre_name: str | None = None
    theatre_location: str | None = None
    event_type: EventCategory | None = None


class EventUpdate(BaseModel):
    name: str | None = None
    event_date: datetime | None = None
    base_price: float | None = None
    image_url: str | None = None
    theatre_name: str | None = None
    theatre_location: str | None = None
    event_type: EventCategory | None = None


class MovieShowConfigCreate(BaseModel):
    movie_title: str
    movie_id: int | None = None
    venue_id: int
    theatre_name: str
    theatre_location: str | None = None
    show_times: List[str]
    start_date: datetime
    end_date: datetime
    base_price: float
    pricing_overrides: Dict[str, float] | None = None
    image_url: str | None = None


class MovieShowConfigUpdate(BaseModel):
    movie_title: str | None = None
    movie_id: int | None = None
    venue_id: int | None = None
    theatre_name: str | None = None
    theatre_location: str | None = None
    show_times: List[str] | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    base_price: float | None = None
    pricing_overrides: Dict[str, float] | None = None
    image_url: str | None = None
    status: Literal["draft", "published", "cancelled"] | None = None


class MovieShowConfigResponse(BaseModel):
    id: int
    movie_title: str
    movie_id: int | None = None
    venue_id: int
    theatre_name: str
    theatre_location: str | None = None
    show_times: List[str]
    start_date: datetime
    end_date: datetime
    base_price: float
    pricing_overrides: Dict[str, float] | None = None
    status: str | None = None
    image_url: str | None = None
    created_at: datetime | None = None

    class Config:
        orm_mode = True


class MovieShowInstanceRequest(BaseModel):
    config_id: int
    show_date: datetime
    show_time: str


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


class PlanTripRequest(BaseModel):
    lat: float
    lng: float
    intent: Optional[str] = None
    max_duration_hours: Optional[int] = 4
    max_distance_km: Optional[float] = 5.0
    budget: Optional[str] = None
    duration: Optional[str] = None
    preference: Optional[str] = None
    museum_focus: Optional[bool] = False
    demo_mode: Optional[bool] = False


class PlanTripFromBookingRequest(BaseModel):
    booking_id: int
    intent: Optional[str] = None
    refresh: Optional[bool] = False