from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app import models
from datetime import datetime
from pydantic import BaseModel
from app.routes.admin_auth import get_current_admin
from app.schemas import EventCreate, EventUpdate, MovieShowConfigCreate, MovieShowConfigUpdate
from app.services.movie_event_service import build_show_dates
from app.services.event_categorizer import categorize_event_type

router = APIRouter(prefix="/admin/events", tags=["Admin Events"])

@router.get("")
def list_events(
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):
    events = db.query(models.Event).order_by(models.Event.event_date).all()
    movie_configs = db.query(models.MovieShowConfig).order_by(models.MovieShowConfig.start_date).all()

    result = []
    for e in events:
        result.append({
            "id": e.id,
            "name": e.name,
            "venue_id": e.venue_id,
            "event_date": e.event_date.isoformat() if e.event_date else None,
            "base_price": e.base_price,
            "event_type": e.event_type,
            "theatre_name": e.theatre_name,
            "theatre_location": e.theatre_location,
            "status": e.status or "draft",
            "image_url": e.image_url,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        })

    for config in movie_configs:
        result.append({
            "id": config.id,
            "name": config.movie_title,
            "venue_id": config.venue_id,
            "event_date": config.start_date.isoformat() if config.start_date else None,
            "base_price": config.base_price,
            "event_type": "movie",
            "theatre_name": config.theatre_name,
            "theatre_location": config.theatre_location,
            "status": config.status or "draft",
            "image_url": config.image_url,
            "created_at": config.created_at.isoformat() if config.created_at else None,
            "show_times": list(config.show_times or []),
            "start_date": config.start_date.isoformat() if config.start_date else None,
            "end_date": config.end_date.isoformat() if config.end_date else None,
            "available_dates": build_show_dates(config.start_date, config.end_date)
            if config.start_date and config.end_date else [],
            "is_dynamic": True,
        })

    def _sort_key(item: dict):
        raw = item.get("event_date")
        try:
            return datetime.fromisoformat(raw) if raw else datetime.max
        except ValueError:
            return datetime.max

    return sorted(result, key=_sort_key)

@router.post("")
def create_event(
    data: EventCreate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin)
):
    if data.event_type == "movie":
        raise HTTPException(status_code=400, detail="Use /admin/events/movie-configs for movie events")

    event = models.Event(
        name=data.name,
        venue_id=data.venue_id,
        event_date=data.event_date,
        base_price=data.base_price,
        image_url=data.image_url,
        theatre_name=data.theatre_name,
        theatre_location=data.theatre_location,
        event_type=data.event_type or categorize_event_type(data.name, data.theatre_name),
        status="draft"
    )

    db.add(event)
    db.commit()
    db.refresh(event)

    return {
        "id": event.id,
        "name": event.name,
        "venue_id": event.venue_id,
        "event_date": event.event_date.isoformat() if event.event_date else None,
        "base_price": event.base_price,
        "event_type": event.event_type,
        "theatre_name": event.theatre_name,
        "theatre_location": event.theatre_location,
        "status": event.status or "draft",
        "image_url": event.image_url,
        "created_at": event.created_at.isoformat() if event.created_at else None,
    }


@router.post("/movie-configs")
def create_movie_config(
    data: MovieShowConfigCreate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin),
):
    venue = db.query(models.Venue).filter(models.Venue.id == data.venue_id).first()
    if not venue:
        raise HTTPException(status_code=404, detail="Venue not found")
    if not data.show_times:
        raise HTTPException(status_code=400, detail="At least one show time is required")
    if data.start_date > data.end_date:
        raise HTTPException(status_code=400, detail="Start date cannot be after end date")

    config = models.MovieShowConfig(
        movie_title=data.movie_title,
        movie_id=data.movie_id,
        venue_id=data.venue_id,
        theatre_name=data.theatre_name,
        theatre_location=data.theatre_location,
        show_times=data.show_times,
        start_date=data.start_date,
        end_date=data.end_date,
        base_price=data.base_price,
        pricing_overrides=data.pricing_overrides,
        image_url=data.image_url,
        status=models.EventStatus.draft,
    )

    db.add(config)
    db.commit()
    db.refresh(config)

    return {
        "id": config.id,
        "name": config.movie_title,
        "venue_id": config.venue_id,
        "event_date": config.start_date.isoformat() if config.start_date else None,
        "base_price": config.base_price,
        "event_type": "movie",
        "theatre_name": config.theatre_name,
        "theatre_location": config.theatre_location,
        "status": config.status or "draft",
        "image_url": config.image_url,
        "created_at": config.created_at.isoformat() if config.created_at else None,
        "show_times": list(config.show_times or []),
        "start_date": config.start_date.isoformat() if config.start_date else None,
        "end_date": config.end_date.isoformat() if config.end_date else None,
        "available_dates": build_show_dates(config.start_date, config.end_date)
        if config.start_date and config.end_date else [],
        "is_dynamic": True,
    }


@router.put("/movie-configs/{config_id}")
def update_movie_config(
    config_id: int,
    data: MovieShowConfigUpdate,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin),
):
    config = db.query(models.MovieShowConfig).filter(models.MovieShowConfig.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Movie config not found")

    payload = data.model_dump(exclude_unset=True)
    if "show_times" in payload and not payload["show_times"]:
        raise HTTPException(status_code=400, detail="At least one show time is required")
    start_date = payload.get("start_date", config.start_date)
    end_date = payload.get("end_date", config.end_date)
    if start_date and end_date and start_date > end_date:
        raise HTTPException(status_code=400, detail="Start date cannot be after end date")

    for field, value in payload.items():
        setattr(config, field, value)

    db.commit()
    db.refresh(config)

    return {
        "id": config.id,
        "name": config.movie_title,
        "venue_id": config.venue_id,
        "event_date": config.start_date.isoformat() if config.start_date else None,
        "base_price": config.base_price,
        "event_type": "movie",
        "theatre_name": config.theatre_name,
        "theatre_location": config.theatre_location,
        "status": config.status or "draft",
        "image_url": config.image_url,
        "created_at": config.created_at.isoformat() if config.created_at else None,
        "show_times": list(config.show_times or []),
        "start_date": config.start_date.isoformat() if config.start_date else None,
        "end_date": config.end_date.isoformat() if config.end_date else None,
        "available_dates": build_show_dates(config.start_date, config.end_date)
        if config.start_date and config.end_date else [],
        "is_dynamic": True,
    }


@router.patch("/movie-configs/{config_id}/publish")
def publish_movie_config(
    config_id: int,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin),
):
    config = db.query(models.MovieShowConfig).filter(models.MovieShowConfig.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Movie config not found")
    config.status = models.EventStatus.published
    db.commit()
    return {"message": "Movie config published"}


@router.patch("/movie-configs/{config_id}/unpublish")
def unpublish_movie_config(
    config_id: int,
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin),
):
    config = db.query(models.MovieShowConfig).filter(models.MovieShowConfig.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Movie config not found")
    config.status = models.EventStatus.draft
    db.commit()
    return {"message": "Movie config moved to draft"}

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

    return {
        "id": event.id,
        "name": event.name,
        "venue_id": event.venue_id,
        "event_date": event.event_date.isoformat() if event.event_date else None,
        "base_price": event.base_price,
        "event_type": event.event_type,
        "theatre_name": event.theatre_name,
        "theatre_location": event.theatre_location,
        "status": event.status or "draft",
        "image_url": event.image_url,
        "created_at": event.created_at.isoformat() if event.created_at else None,
    }

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