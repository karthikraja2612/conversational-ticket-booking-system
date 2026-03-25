from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..schemas import PlanTripRequest
from ..services.itinerary_service import generate_itinerary

router = APIRouter(tags=["Trip"])


@router.post("/plan-trip")
def plan_trip(request: PlanTripRequest, db: Session = Depends(get_db)):
    result = generate_itinerary(
        lat=request.lat,
        lng=request.lng,
        intent=request.intent,
        max_duration_hours=request.max_duration_hours,
        max_distance_km=request.max_distance_km,
        budget=request.budget,
        duration=request.duration,
        preference=request.preference,
        museum_focus=bool(request.museum_focus),
        demo_mode=bool(request.demo_mode),
    )

    itinerary = result.get("itinerary", [])
    if not itinerary:
        return {
            "message": "No places found to build a trip plan.",
            "itinerary": [],
            "total_estimated_time_min": 0,
        }

    has_museum = any(item.get("type") == "museum" for item in itinerary)
    if not has_museum:
        result = dict(result)
        result["message"] = "No museums found nearby, here's a place-based plan."

    return result
