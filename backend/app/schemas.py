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