from fastapi import APIRouter
from app.services.place_service import get_nearby_places

router = APIRouter(prefix="/places", tags=["Places"])


@router.get("/nearby")
def nearby_places(
    lat: float,
    lng: float,
    intent: str = None,
    distance_km: float = None,
    area: str = None,
):
    places = get_nearby_places(
        user_lat=lat,
        user_lng=lng,
        intent=intent,
        distance_km=distance_km,
        area=area,
    )
    return places
