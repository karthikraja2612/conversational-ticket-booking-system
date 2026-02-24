from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app import models
from datetime import datetime
from pydantic import BaseModel
from app.routes.admin_auth import get_current_admin
from app.schemas import EventCreate, EventUpdate

router = APIRouter(prefix="/admin/events", tags=["Admin Events"])

@router.post("/")
def create_event(
    data: EventCreate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):

    event = models.Event(
        name=data.name,
        venue_id=data.venue_id,
        event_date=data.event_date,
        base_price=data.base_price,
        image_url=data.image_url,
        status="draft"
    )

    db.add(event)
    db.commit()
    db.refresh(event)

    return event

@router.put("/{event_id}")
def edit_event(
    event_id: int,
    data: EventUpdate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):

    event = db.query(models.Event).filter(
        models.Event.id == event_id
    ).first()

    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(event, field, value)

    db.commit()
    db.refresh(event)

    return event

@router.patch("/{event_id}/publish")
def publish_event(
    event_id: int,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):

    event = db.query(models.Event).filter(
        models.Event.id == event_id
    ).first()

    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    event.status = "published"
    db.commit()

    return {"message": "Event published"}

@router.patch("/{event_id}/unpublish")
def unpublish_event(
    event_id: int,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):

    event = db.query(models.Event).filter(
        models.Event.id == event_id
    ).first()

    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    event.status = "draft"
    db.commit()

    return {"message": "Event moved to draft"}