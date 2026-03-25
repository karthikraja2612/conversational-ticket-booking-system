from typing import Optional

from .place_service import calculate_distance, get_nearby_places, load_places


def _parse_distance_km(distance_value: str) -> float:
    if not distance_value:
        return 0.0
    try:
        return float(distance_value.replace(" km", "").strip())
    except ValueError:
        return 0.0


def _estimate_travel_minutes(distance_km: float) -> int:
    # Simple estimate: 30 km/h average speed.
    return max(1, int((distance_km / 30.0) * 60))


def _visit_duration_minutes(category: str) -> int:
    category_key = (category or "").lower()
    if "museum" in category_key:
        return 90
    if "park" in category_key:
        return 45
    if "restaurant" in category_key or "food" in category_key:
        return 60
    if "entertainment" in category_key or "mall" in category_key:
        return 75
    return 45


def _category_priority(category: str) -> float:
    category_key = (category or "").lower()
    if "museum" in category_key:
        return 2.5
    if "attraction" in category_key or "entertainment" in category_key:
        return 1.8
    if "park" in category_key or "garden" in category_key:
        return 1.4
    if "restaurant" in category_key or "food" in category_key or "cafe" in category_key:
        return 1.2
    if "mall" in category_key:
        return 1.0
    return 0.6


def _intent_match_weight(intent: Optional[str], category: str) -> float:
    intent_key = (intent or "").lower().strip()
    category_key = (category or "").lower()
    if intent_key == "explore":
        if "museum" in category_key or "attraction" in category_key or "entertainment" in category_key:
            return 0.9
    if intent_key == "relax":
        if "park" in category_key or "garden" in category_key:
            return 0.9
    if intent_key == "food":
        if "restaurant" in category_key or "food" in category_key or "cafe" in category_key:
            return 0.9
    return 0.0


def _score_place(distance_km: float, intent: Optional[str], category: str, museum_focus: bool) -> float:
    inverse_distance = 1.0 / (1.0 + max(distance_km, 0.0))
    distance_weight = 1.0
    category_priority = _category_priority(category)
    intent_match_weight = _intent_match_weight(intent, category)
    museum_boost = 0.0
    if museum_focus and "museum" in (category or "").lower():
        museum_boost = 1.2
    return (distance_weight * inverse_distance) + intent_match_weight + category_priority + museum_boost


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


def _normalize_constraint(value: Optional[str], allowed: set[str]) -> Optional[str]:
    if not value:
        return None
    value_key = str(value).strip().lower()
    return value_key if value_key in allowed else None


def _matches_budget(category: str, budget: Optional[str]) -> bool:
    if not budget:
        return True
    category_key = (category or "").lower()
    allowed = {
        "low": ["park", "garden", "museum"],
        "medium": ["museum", "restaurant", "food", "attraction", "entertainment"],
        "high": ["mall", "entertainment", "attraction", "restaurant", "food"],
    }
    return any(tag in category_key for tag in allowed.get(budget, []))


def _matches_preference(category: str, preference: Optional[str]) -> bool:
    if not preference:
        return True
    category_key = (category or "").lower()
    allowed = {
        "indoor": ["museum", "restaurant", "food", "mall", "entertainment", "attraction"],
        "outdoor": ["park", "garden"],
    }
    return any(tag in category_key for tag in allowed.get(preference, []))


def _duration_score_bias(duration: Optional[str], category: str) -> float:
    if not duration:
        return 0.0
    visit_minutes = _visit_duration_minutes(category)
    if duration == "short":
        if visit_minutes <= 60:
            return 0.4
        if visit_minutes >= 75:
            return -0.3
    if duration == "long":
        if visit_minutes >= 75:
            return 0.4
        if visit_minutes <= 45:
            return -0.2
    return 0.0


def _inter_stop_distance_km(previous_km: float, current_km: float) -> float:
    previous_km = max(previous_km, 0.0)
    current_km = max(current_km, 0.0)
    return max(0.5, (previous_km + current_km) / 2.0)


def _format_minutes(total_minutes: int) -> str:
    hours = max(0, total_minutes) // 60
    minutes = max(0, total_minutes) % 60
    return f"{hours}:{minutes:02d}"


def _fallback_why_visit(category: str, intent: Optional[str], museum_focus: bool) -> str:
    category_key = (category or "").lower()
    intent_key = (intent or "").lower().strip()
    if "museum" in category_key:
        if museum_focus:
            return "Must-see exhibits and local history in one stop"
        return "Great for a quick cultural experience"
    if "park" in category_key or "garden" in category_key:
        return "Perfect for relaxing after a museum visit"
    if "restaurant" in category_key or "food" in category_key or "cafe" in category_key:
        return "Ideal for a tasty break"
    if "entertainment" in category_key or "attraction" in category_key or "mall" in category_key:
        return "Fun stop to round out the trip"
    if intent_key == "explore":
        return "Good for exploring nearby highlights"
    if intent_key == "relax":
        return "Nice place to unwind"
    if intent_key == "food":
        return "Good spot for a quick bite"
    return "Worth a short visit"


def _build_plan_summary(intent: Optional[str], itinerary: list[dict], duration: Optional[str]) -> str:
    intent_key = (intent or "").lower().strip()
    duration_key = (duration or "").lower().strip()

    themes = []
    for entry in itinerary:
        entry_type = (entry.get("type") or "").lower()
        category = (entry.get("category") or "").lower()
        if entry_type == "museum" or "museum" in category:
            if "culture" not in themes:
                themes.append("culture")
        if "park" in category or "garden" in category:
            if "outdoor" not in themes:
                themes.append("outdoor")
        if "restaurant" in category or "food" in category or "cafe" in category:
            if "food" not in themes:
                themes.append("food")
        if "entertainment" in category or "attraction" in category or "mall" in category:
            if "highlights" not in themes:
                themes.append("highlights")

    if intent_key == "explore" and duration_key == "short":
        return "A short exploration-focused trip covering key attractions efficiently"
    if intent_key == "relax" and "culture" in themes and "outdoor" in themes:
        return "A relaxed plan combining culture and light outdoor stops nearby"

    duration_desc = "short" if duration_key == "short" else "leisurely" if duration_key == "long" else "balanced"
    intent_desc = {
        "explore": "exploration-focused",
        "relax": "relaxed",
        "food": "food-focused",
    }.get(intent_key, "well-rounded")

    themes_text = " and ".join(themes[:2]) if themes else "local highlights"
    return f"A {duration_desc} {intent_desc} plan covering {themes_text}"


def _build_tag(category: str, distance_km: float, popularity: Optional[float]) -> str:
    category_key = (category or "").lower()
    if popularity is not None and popularity >= 0.8:
        return "Popular choice"
    if distance_km <= 2.0:
        return "Quick visit"
    if "park" in category_key or "garden" in category_key:
        return "Relaxing stop"
    return "Recommended stop"


def _build_demo_places(lat: float, lng: float) -> list[dict]:
    preferred_names = [
        "Gass Forest Museum",
        "Gedee Car Museum",
        "VOC Park and Zoo",
        "Annapoorna Gowrishankar",
        "KG Cinemas Complex",
        "Brookefields Mall",
    ]
    preferred_categories = ["Museum", "Park", "Restaurant", "Entertainment", "Mall"]
    places = load_places()
    if not places:
        fallback = []
        for category in preferred_categories:
            fallback.append(
                {
                    "name": f"Top {category}",
                    "category": category,
                    "area": "Central",
                    "distance": "1.0 km",
                    "distance_km": 1.0,
                    "popularity": _normalize_popularity(None, category),
                }
            )
        return fallback

    by_name = {str(place.get("name", "")).lower(): place for place in places}
    selected = []
    seen = set()
    for name in preferred_names:
        place = by_name.get(name.lower())
        if not place:
            continue
        place_name = str(place.get("name", "")).strip()
        if not place_name or place_name.lower() in seen:
            continue
        seen.add(place_name.lower())
        selected.append(place)

    for category in preferred_categories:
        if len(selected) >= len(preferred_categories) + 1:
            break
        for place in places:
            if str(place.get("category", "")) != category:
                continue
            place_name = str(place.get("name", "")).strip()
            if not place_name or place_name.lower() in seen:
                continue
            seen.add(place_name.lower())
            selected.append(place)
            break

    enriched = []
    for place in selected:
        place_name = str(place.get("name", "")).strip() or "Top spot"
        category = str(place.get("category", "Place"))
        area = str(place.get("area", "Nearby"))
        place_lat = place.get("latitude")
        place_lng = place.get("longitude")
        if place_lat is None or place_lng is None:
            distance_km = 1.0
        else:
            distance_km = calculate_distance(lat, lng, place_lat, place_lng)
        popularity = _normalize_popularity(place.get("popularity"), category)
        enriched.append(
            {
                "name": place_name,
                "category": category,
                "area": area,
                "distance": f"{distance_km:.1f} km",
                "distance_km": distance_km,
                "popularity": popularity,
            }
        )

    return enriched


def generate_itinerary(
    lat: float,
    lng: float,
    intent: Optional[str] = None,
    max_duration_hours: int = 4,
    max_distance_km: float = 5,
    budget: Optional[str] = None,
    duration: Optional[str] = None,
    preference: Optional[str] = None,
    museum_focus: bool = False,
    demo_mode: bool = False,
) -> dict:
    if lat is None or lng is None:
        lat, lng = 11.0168, 76.9558

    max_duration_hours = max(1, min(max_duration_hours, 12))
    max_distance_km = max(1.0, float(max_distance_km))

    budget = _normalize_constraint(budget, {"low", "medium", "high"})
    duration = _normalize_constraint(duration, {"short", "long"})
    preference = _normalize_constraint(preference, {"indoor", "outdoor"})

    if demo_mode:
        places = _build_demo_places(lat, lng)
        budget_filter = None
        preference_filter = None
    else:
        places = get_nearby_places(
            user_lat=lat,
            user_lng=lng,
            intent=intent,
            distance_km=max_distance_km,
            limit=10,
        )
        budget_filter = budget
        preference_filter = preference

    museums = []
    other_places = []
    seen_names = set()
    ranked_places = []
    for place in places:
        name = (place.get("name") or "").strip()
        if not name or name.lower() in seen_names:
            continue
        seen_names.add(name.lower())
        category = place.get("category", "")
        distance_km = _parse_distance_km(place.get("distance", "0"))
        if not _matches_budget(category, budget_filter):
            continue
        if not _matches_preference(category, preference_filter):
            continue
        popularity = _normalize_popularity(place.get("popularity"), category)
        popularity_weight = 0.6
        score = (
            _score_place(distance_km, intent, category, museum_focus)
            + _duration_score_bias(duration, category)
            + (popularity_weight * popularity)
        )
        ranked_place = dict(place)
        ranked_place["distance_km"] = distance_km
        ranked_place["score"] = score
        ranked_place["popularity"] = popularity
        ranked_places.append(ranked_place)

    if not ranked_places and (budget or duration or preference) and not demo_mode:
        for place in places:
            name = (place.get("name") or "").strip()
            if not name or name.lower() in seen_names:
                continue
            seen_names.add(name.lower())
            category = place.get("category", "")
            distance_km = _parse_distance_km(place.get("distance", "0"))
            popularity = _normalize_popularity(place.get("popularity"), category)
            popularity_weight = 0.6
            score = _score_place(distance_km, intent, category, museum_focus) + (popularity_weight * popularity)
            ranked_place = dict(place)
            ranked_place["distance_km"] = distance_km
            ranked_place["score"] = score
            ranked_place["popularity"] = popularity
            ranked_places.append(ranked_place)

    ranked_places.sort(
        key=lambda item: (
            -item.get("score", 0.0),
            -item.get("popularity", 0.0),
            item.get("distance_km", 0.0),
        )
    )

    for place in ranked_places:
        category = place.get("category", "")
        if "museum" in category.lower():
            museums.append(place)
        else:
            other_places.append(place)

    itinerary = []
    total_minutes = 0
    current_minutes = 0
    last_distance_km = None
    max_minutes = max_duration_hours * 60
    buffer_minutes_between_stops = 10

    def add_item(item_type: str, category: Optional[str], place: dict) -> bool:
        nonlocal total_minutes, current_minutes, last_distance_km
        distance_km = place.get("distance_km")
        if distance_km is None:
            distance_km = _parse_distance_km(place.get("distance", "0"))
        if last_distance_km is None:
            travel_distance_km = distance_km
            buffer_minutes = 0
        else:
            travel_distance_km = _inter_stop_distance_km(last_distance_km, distance_km)
            buffer_minutes = buffer_minutes_between_stops
        travel_minutes = _estimate_travel_minutes(travel_distance_km)
        visit_minutes = _visit_duration_minutes(category or "")
        start_minutes = current_minutes + travel_minutes + buffer_minutes
        end_minutes = start_minutes + visit_minutes
        estimated_time = end_minutes - current_minutes
        if end_minutes > max_minutes:
            return False

        highlight = place.get("highlight") or place.get("description")
        if not highlight:
            highlight = _fallback_why_visit(category or "", intent, museum_focus)

        entry = {
            "type": item_type,
            "name": place.get("name"),
            "distance_km": distance_km,
            "estimated_time_min": estimated_time,
            "start_time": _format_minutes(start_minutes),
            "end_time": _format_minutes(end_minutes),
            "why_visit": _fallback_why_visit(category or "", intent, museum_focus),
            "tag": _build_tag(category or "", distance_km, place.get("popularity")),
        }
        if item_type == "museum":
            entry["description"] = highlight
        else:
            entry["category"] = category or "place"
            entry["highlight"] = highlight

        itinerary.append(entry)
        current_minutes = end_minutes
        total_minutes = current_minutes
        last_distance_km = distance_km
        return True

    if museums:
        add_item("museum", "museum", museums[0])
        if museum_focus and len(museums) > 1:
            add_item("museum", "museum", museums[1])

    max_items = 2 if max_minutes <= 90 else 3
    if duration == "short":
        max_items = min(max_items, 2)
    elif duration == "long" and max_minutes >= 150:
        max_items = 4
    for place in other_places:
        if len(itinerary) >= max_items:
            break
        if not add_item("place", place.get("category"), place):
            break

    if not itinerary:
        for place in other_places[:max_items]:
            if not add_item("place", place.get("category"), place):
                break

    return {
        "itinerary": itinerary,
        "total_estimated_time_min": total_minutes,
        "plan_summary": _build_plan_summary(intent, itinerary, duration),
    }
