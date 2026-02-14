from pydantic import BaseModel
from typing import List

class LockSeatsRequest(BaseModel):
    user_id: int
    seat_ids: List[int]

class ConfirmBookingRequest(BaseModel):
    user_id: int
    seat_ids: list[int]
