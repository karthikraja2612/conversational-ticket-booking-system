from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from app.services.movie_service import (
    get_movies,
    get_movies_by_theatre,
    get_showtimes,
)
from app.services.movie_event_service import ensure_movie_event_instance
from app.schemas import MovieShowInstanceRequest
from app.database import get_db
from app import models

router = APIRouter(prefix="/movies", tags=["Movies"])


@router.get("")
def list_movies():
    return {"movies": get_movies()}


@router.get("/theatre")
def movies_by_theatre(name: str):
    if not name:
        raise HTTPException(status_code=400, detail="Theatre name is required")
    return {
        "theatre_name": name,
        "movies": get_movies_by_theatre(name),
    }


@router.get("/showtimes")
def movie_showtimes(movie_id: int, theatre_name: str):
    show_times = get_showtimes(movie_id, theatre_name)
    if show_times is None:
        raise HTTPException(status_code=404, detail="Showtimes not found")
    return {
        "movie_id": movie_id,
        "theatre_name": theatre_name,
        "show_times": show_times,
    }


@router.post("/event-instance")
def movie_event_instance(
    request: MovieShowInstanceRequest,
    db: Session = Depends(get_db),
):
    config = db.query(models.MovieShowConfig).filter(
        models.MovieShowConfig.id == request.config_id
    ).first()
    if not config:
        raise HTTPException(status_code=404, detail="Movie config not found")

    try:
        event = ensure_movie_event_instance(db, config, request.show_date, request.show_time)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return {
        "event_id": event.id,
        "name": event.name,
        "venue_id": event.venue_id,
        "event_date": event.event_date.isoformat() if event.event_date else None,
        "base_price": event.base_price,
        "event_type": event.event_type,
        "theatre_name": event.theatre_name,
        "theatre_location": event.theatre_location,
        "image_url": event.image_url,
    }
