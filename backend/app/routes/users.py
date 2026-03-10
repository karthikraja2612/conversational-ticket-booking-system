from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Any
from ..database import get_db
from ..security import get_current_user
from ..models import User
from .. import crud

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "created_at": current_user.created_at
    }

@router.get("/me/bookings", response_model=List[Any])
def get_my_bookings(
    skip: int = Query(default=0, ge=0, description="Number of records to skip"),
    limit: int = Query(default=50, ge=1, le=200, description="Max records to return"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return paginated bookings for the current user, newest first."""
    return crud.get_user_bookings(db, current_user.id, skip=skip, limit=limit)
