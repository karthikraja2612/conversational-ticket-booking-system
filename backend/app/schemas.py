from pydantic import BaseModel
from typing import List

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
