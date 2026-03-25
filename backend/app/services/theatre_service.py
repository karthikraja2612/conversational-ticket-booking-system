import json
from pathlib import Path
from typing import Any, Dict, List

from .place_service import calculate_distance

_theatres_cache: List[Dict[str, Any]] | None = None


def load_theatres() -> List[Dict[str, Any]]:
    global _theatres_cache

    if _theatres_cache is not None:
        return _theatres_cache

    data_path = Path(__file__).resolve().parents[2] / "data" / "coimbatore_theatres.json"
    try:
        with data_path.open("r", encoding="utf-8") as handle:
            _theatres_cache = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Failed to load theatres dataset: {exc}")
        _theatres_cache = []

    return _theatres_cache


def get_nearby_theatres(
    user_lat: float,
    user_lng: float,
    max_distance_km: float = 5,
) -> List[Dict[str, Any]]:
    theatres = load_theatres()
    results: List[Dict[str, Any]] = []

    for theatre in theatres:
        name = theatre.get("name")
        area = theatre.get("area")
        lat = theatre.get("latitude")
        lng = theatre.get("longitude")
        if not name or lat is None or lng is None:
            continue

        distance_km = calculate_distance(user_lat, user_lng, lat, lng)
        if max_distance_km is not None and distance_km > max_distance_km:
            continue

        results.append(
            {
                "name": name,
                "area": area or "Nearby",
                "distance_km": round(distance_km, 2),
                "screens": theatre.get("screens"),
                "total_seats": theatre.get("total_seats"),
                "price_range_inr": theatre.get("price_range_inr"),
            }
        )

    results.sort(key=lambda item: item["distance_km"])
    return results
