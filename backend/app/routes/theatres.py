from fastapi import APIRouter
from app.services.theatre_service import get_nearby_theatres

router = APIRouter(prefix="/theatres", tags=["Theatres"])


@router.get("/nearby")
def nearby_theatres(
    lat: float,
    lng: float,
    max_distance_km: float = 5,
):
    return get_nearby_theatres(
        user_lat=lat,
        user_lng=lng,
        max_distance_km=max_distance_km,
    )
