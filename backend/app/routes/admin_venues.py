from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app import models
from app.schemas import VenueCreate, VenueUpdate
from app.routes.admin_auth import get_current_admin

router = APIRouter(prefix="/admin/venues", tags=["Admin Venues"])

@router.post("")
def create_venue(
    data: VenueCreate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):

    venue = models.Venue(
        name=data.name,
        location=data.location,
        total_rows=data.total_rows,
        seats_per_row=data.seats_per_row
    )

    db.add(venue)
    db.commit()
    db.refresh(venue)

    # 🔥 Generate seats automatically
    for row in range(1, venue.total_rows + 1):
        for seat in range(1, venue.seats_per_row + 1):
            new_seat = models.Seat(
                venue_id=venue.id,
                row_number=row,
                seat_number=seat
            )
            db.add(new_seat)

    db.commit()

    return {
        "id": venue.id,
        "name": venue.name,
        "location": venue.location,
        "total_rows": venue.total_rows,
        "seats_per_row": venue.seats_per_row,
    }

@router.put("/{venue_id}")
def update_venue(
    venue_id: int,
    data: VenueUpdate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):

    venue = db.query(models.Venue).filter(
        models.Venue.id == venue_id
    ).first()

    if not venue:
        raise HTTPException(status_code=404, detail="Venue not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(venue, field, value)

    db.commit()
    db.refresh(venue)

    return {
        "id": venue.id,
        "name": venue.name,
        "location": venue.location,
        "total_rows": venue.total_rows,
        "seats_per_row": venue.seats_per_row,
    }

@router.get("")
def list_venues(
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):
    venues = db.query(models.Venue).all()
    return [
        {
            "id": v.id,
            "name": v.name,
            "location": v.location,
            "total_rows": v.total_rows,
            "seats_per_row": v.seats_per_row,
        }
        for v in venues
    ]