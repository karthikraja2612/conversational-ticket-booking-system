import json
import math
import random
from pathlib import Path

_places_cache = None
_last_query = None
_last_results = []


def load_places():
    global _places_cache

    if _places_cache is not None:
        return _places_cache

    data_path = Path(__file__).resolve().parents[2] / "data" / "coimbatore_places.json"
    try:
        with data_path.open("r", encoding="utf-8") as handle:
            _places_cache = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Failed to load places dataset: {exc}")
        _places_cache = []

    return _places_cache


def calculate_distance(lat1, lon1, lat2, lon2):
    radius_km = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius_km * c


def _default_popularity(category: str) -> float:
    category_key = (category or "").lower()
    if "museum" in category_key:
        return 0.85
    if "attraction" in category_key or "entertainment" in category_key:
        return 0.8
    if "park" in category_key or "garden" in category_key:
        return 0.7
    if "restaurant" in category_key or "food" in category_key or "cafe" in category_key:
        return 0.75
    if "mall" in category_key:
        return 0.65
    return 0.6


def _normalize_popularity(value, category: str) -> float:
    try:
        number = float(value)
        if number < 0:
            return 0.0
        if number > 1.0:
            return min(1.0, number / 5.0)
        return number
    except (TypeError, ValueError):
        return _default_popularity(category)


def get_nearby_places(
    user_lat: float,
    user_lng: float,
    limit: int = 5,
    intent: str = None,
    distance_km: float = None,
    area: str = None,
):
    global _last_query, _last_results

    intent_key = intent.lower() if intent else None
    area_key = area.strip().lower() if isinstance(area, str) else None
    distance_key = float(distance_km) if distance_km is not None else None
    query_key = (round(user_lat, 5), round(user_lng, 5), intent_key, distance_key, area_key, limit)
    if _last_query == query_key:
        return list(_last_results)

    intent_map = {
        "fun": ["Mall", "Entertainment"],
        "relax": ["Park"],
        "food": ["Restaurant"],
        "explore": ["Museum"],
    }

    places = load_places()
    if intent_key in intent_map:
        allowed = set(intent_map[intent_key])
        filtered = [p for p in places if p.get("category") in allowed]
    else:
        filtered = list(places)

    if area_key:
        filtered = [
            p for p in filtered
            if isinstance(p.get("area"), str)
            and area_key in p.get("area").strip().lower()
        ]

    enriched = []
    for place in filtered:
        name = place.get("name")
        category = place.get("category")
        area = place.get("area")
        lat = place.get("latitude")
        lng = place.get("longitude")
        if not name or lat is None or lng is None:
            continue

        distance_value = calculate_distance(user_lat, user_lng, lat, lng)
        if distance_key is not None and distance_value > distance_key:
            continue

        popularity = _normalize_popularity(place.get("popularity"), category)
        enriched.append(
            {
                "name": name,
                "category": category or "Place",
                "area": area or "Nearby",
                "distance_km": distance_value,
                "popularity": popularity,
            }
        )

    enriched.sort(key=lambda item: item["distance_km"])

    seen_categories = set()
    diverse = []
    for item in enriched:
        if item["category"] not in seen_categories:
            diverse.append(item)
            seen_categories.add(item["category"])
        if len(diverse) >= limit:
            break

    selected = diverse if len(diverse) >= limit else enriched[:limit]
    if intent_key is None and len(selected) > 1:
        random.shuffle(selected)

    limited = [
        {
            "name": item["name"],
            "category": item["category"],
            "area": item["area"],
            "distance": f"{item['distance_km']:.1f} km",
            "popularity": item.get("popularity"),
        }
        for item in selected
    ]

    _last_query = query_key
    _last_results = list(limited)
    return limited