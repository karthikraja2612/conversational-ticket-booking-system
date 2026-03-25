from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..security import get_current_user
from ..schemas import PlanTripFromBookingRequest
from ..services.trip_planner import plan_trip
from ..services.trip_service import TripService
from .. import models

router = APIRouter(prefix="/trip", tags=["Trip"])


@router.get("/plan")
def plan_my_trip(
    lat: float = Query(..., description="User latitude"),
    lng: float = Query(..., description="User longitude"),
    intent: str | None = None,
    distance_km: float | None = None,
    area: str | None = None,
    hours: int = 4,
    start_time: str | None = None,
    max_events: int = 2,
    max_places: int = 4,
    db: Session = Depends(get_db),
):
    return plan_trip(
        db=db,
        user_lat=lat,
        user_lng=lng,
        intent=intent,
        distance_km=distance_km,
        area=area,
        hours=hours,
        start_time=start_time,
        max_events=max_events,
        max_places=max_places,
    )


@router.post("/plan-from-booking")
def plan_from_booking(
    request: PlanTripFromBookingRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    booking = (
        db.query(models.Booking)
        .filter(models.Booking.id == request.booking_id)
        .first()
    )
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed to access this booking")

    try:
        return TripService.plan_from_booking(
            db=db,
            booking_id=request.booking_id,
            intent=request.intent,
            refresh=bool(request.refresh),
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
