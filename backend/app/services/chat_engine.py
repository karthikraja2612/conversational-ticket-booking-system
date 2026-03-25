from typing import Optional

from sqlalchemy.orm import Session
from ..models import ChatSession, Event, Booking, Seat, MovieShowConfig, EventStatus
from .movie_event_service import build_show_dates, build_showtimes_by_date
from .seat_recommender import recommend_seats
from .place_service import load_places
from .theatre_service import get_nearby_theatres
from .movie_service import (
    ensure_movie_seed,
    get_movies,
    get_movies_by_theatre,
    get_showtimes,
    get_theatres_for_movie,
    get_theatre_names,
)
from .movie_event_service import ensure_movie_event, ensure_movie_event_instance
from .lock_service import extend_lock
from .itinerary_service import generate_itinerary
from datetime import datetime
import re
import httpx
import dateparser

def _format_seat_names(db: Session, seat_ids: list):
    if not seat_ids:
        return ""
    seats = db.query(Seat).filter(Seat.id.in_(seat_ids)).all()
    # Preserve original recommendation order
    seat_dict = {s.id: s for s in seats}
    names = []
    for sid in seat_ids:
        s = seat_dict.get(sid)
        if s:
            letters = ""
            temp = s.row_number
            while temp > 0:
                temp -= 1
                letters = chr(65 + (temp % 26)) + letters
                temp //= 26
            names.append(f"{letters}{s.seat_number}")
    return ', '.join(names)


def _fetch_event_catalog(db: Session) -> list[dict]:
    items: list[dict] = []

    events = db.query(Event).all()
    for event in events:
        items.append(
            {
                "id": event.id,
                "name": event.name,
                "price": event.base_price,
                "event_type": event.event_type,
                "theatre_name": event.theatre_name,
                "theatre_location": event.theatre_location,
                "event_date": event.event_date.isoformat() if event.event_date else None,
                "is_dynamic": False,
            }
        )

    configs = db.query(MovieShowConfig).all()
    for config in configs:
        status_value = getattr(config.status, "value", config.status)
        if status_value not in (EventStatus.published, "published"):
            continue
        available_dates = build_show_dates(config.start_date, config.end_date)
        items.append(
            {
                "id": config.id,
                "name": config.movie_title,
                "price": config.base_price,
                "event_type": "movie",
                "theatre_name": config.theatre_name,
                "theatre_location": config.theatre_location,
                "event_date": config.start_date.isoformat() if config.start_date else None,
                "is_dynamic": True,
                "available_dates": available_dates,
                "show_times_by_date": build_showtimes_by_date(
                    config.start_date,
                    config.end_date,
                    list(config.show_times or []),
                ),
            }
        )

    def _sort_key(item: dict):
        raw = item.get("event_date")
        try:
            return datetime.fromisoformat(raw) if raw else datetime.max
        except ValueError:
            return datetime.max

    return sorted(items, key=_sort_key)


def _fetch_movie_catalog(db: Session) -> list[dict]:
    items: list[dict] = []

    movies = get_movies(db)
    for movie in movies:
        title = movie.get("title")
        items.append(
            {
                "id": movie.get("id"),
                "title": title,
                "genre": movie.get("genre"),
                "duration_min": movie.get("duration_min"),
                "language": movie.get("language"),
                "title_key": _normalize_title(title),
            }
        )

    seen_titles = {str(item.get("title", "")).strip().lower() for item in items}
    configs = db.query(MovieShowConfig).all()
    for config in configs:
        status_value = getattr(config.status, "value", config.status)
        if status_value not in (EventStatus.published, "published"):
            continue
        title_key = (config.movie_title or "").strip().lower()
        if title_key and title_key in seen_titles:
            continue
        items.append(
            {
                "id": None,
                "title": config.movie_title,
                "genre": None,
                "duration_min": None,
                "language": None,
                "config_id": config.id,
                "theatre_name": config.theatre_name,
                "show_times": list(config.show_times or []),
                "available_dates": build_show_dates(config.start_date, config.end_date)
                if config.start_date and config.end_date else [],
                "is_dynamic": True,
                "title_key": _normalize_title(config.movie_title),
            }
        )

    return items


# ======================================================
# MAIN MESSAGE HANDLER
# ======================================================

def handle_message(db: Session, session: ChatSession, user_id: int, message: str):

    text = message.lower()
    ensure_movie_seed(db)
    if session.state == "event_selected" and text.isdigit():
        intent = "event_selected"
        entities = {"quantity": int(text)}
    else:
        last_intent = (session.context or {}).get("last_intent")
        short_reply = len(text.split()) <= 3
        if (
            last_intent in ("book_tickets", "select_seats", "ask_event", "list_events")
            and session.state == "awaiting_event"
            and short_reply
            and not text.isdigit()
        ):
            intent = "event_selected"
            entities = {}
        else:
            booking_keywords = ("book", "ticket", "reserve", "seat")
            plan_keywords = ("plan", "trip", "suggest")
            place_keywords = ("near", "nearby", "around", "close", "distance")
            theatre_keywords = ("theatre", "cinema", "watch movie")
            movie_keywords = (
                "movies",
                "what's playing",
                "whats playing",
                "show movies",
                "what can i watch",
            )

            if any(k in text for k in booking_keywords):
                intent = "book_tickets"
                entities = extract_entities(db, text)
            elif any(k in text for k in plan_keywords):
                intent = "plan_trip"
                entities = {}
            elif any(k in text for k in movie_keywords):
                intent = "ask_movies"
                entities = {}
            elif (
                (_contains_word(text, "movie") or any(k in text for k in theatre_keywords))
                and not _contains_word(text, "movies")
                and not any(k in text for k in booking_keywords)
            ):
                intent = "ask_theatres"
                entities = {}
            else:
                matched_movie = _match_movie_title(text, db)
                if matched_movie:
                    intent = "ask_movie_showtimes"
                    entities = {
                        "movie_id": matched_movie.get("id"),
                        "movie_title": matched_movie.get("title"),
                    }
                    if matched_movie.get("config_id"):
                        entities["movie_config_id"] = matched_movie.get("config_id")
                    session.context = dict(session.context or {})
                    session.context["movie_id"] = matched_movie.get("id")
                    session.context["movie_title"] = matched_movie.get("title")
                    if matched_movie.get("config_id"):
                        session.context["movie_config_id"] = matched_movie.get("config_id")
                        session.context["movie_theatre"] = matched_movie.get("theatre_name")
                    db.commit()
                else:
                    # Step 1: Detect intent + entities via locally hosted Rasa NLP
                    try:
                        response = httpx.post("http://localhost:5005/model/parse", json={"text": message}, timeout=3.0)
                        rasa_data = response.json()

                        intent = rasa_data.get("intent", {}).get("name", "unknown")
                        intent_confidence = rasa_data.get("intent", {}).get("confidence", 0.0)
                        intent_ranking = rasa_data.get("intent_ranking", [])
                        entities = {}

                        if intent_confidence < 0.7:
                            matched_movie = _match_movie_title(text, db)
                            if matched_movie:
                                intent = "ask_movie_showtimes"
                                entities["movie_id"] = matched_movie.get("id")
                                entities["movie_title"] = matched_movie.get("title")
                                if matched_movie.get("config_id"):
                                    entities["movie_config_id"] = matched_movie.get("config_id")
                                session.context = dict(session.context or {})
                                session.context["movie_id"] = matched_movie.get("id")
                                session.context["movie_title"] = matched_movie.get("title")
                                if matched_movie.get("config_id"):
                                    session.context["movie_config_id"] = matched_movie.get("config_id")
                                    session.context["movie_theatre"] = matched_movie.get("theatre_name")
                                db.commit()
                            else:
                                event_match = db.query(Event).filter(Event.name.ilike(f"%{text}%")).first()
                                if event_match:
                                    intent = "event_selected"
                                    entities["event_id"] = event_match.id
                                    entities["event_name"] = event_match.name
                                else:
                                    return {
                                        "intent": "clarify",
                                        "message": "Do you want to book tickets or find nearby places?"
                                    }

                        if len(intent_ranking) > 1:
                            top = intent_ranking[0].get("confidence", 0.0)
                            second = intent_ranking[1].get("confidence", 0.0)
                            if (top - second) <= 0.1:
                                matched_movie = _match_movie_title(text, db)
                                if matched_movie:
                                    intent = "ask_movie_showtimes"
                                    entities["movie_id"] = matched_movie.get("id")
                                    entities["movie_title"] = matched_movie.get("title")
                                    if matched_movie.get("config_id"):
                                        entities["movie_config_id"] = matched_movie.get("config_id")
                                    session.context = dict(session.context or {})
                                    session.context["movie_id"] = matched_movie.get("id")
                                    session.context["movie_title"] = matched_movie.get("title")
                                    if matched_movie.get("config_id"):
                                        session.context["movie_config_id"] = matched_movie.get("config_id")
                                        session.context["movie_theatre"] = matched_movie.get("theatre_name")
                                    db.commit()
                                else:
                                    event_match = db.query(Event).filter(Event.name.ilike(f"%{text}%")).first()
                                    if event_match:
                                        intent = "event_selected"
                                        entities["event_id"] = event_match.id
                                        entities["event_name"] = event_match.name
                                    else:
                                        return {
                                            "intent": "clarify",
                                            "message": "Do you want to book tickets or find nearby places?"
                                        }

                        trip_followup = _detect_trip_followup_intent(text)
                        if trip_followup:
                            intent = trip_followup

                        override_intent = _detect_place_intent(text)
                        if last_intent in ("book_tickets", "select_seats", "ask_event", "list_events"):
                            override_intent = None
                        if override_intent and any(k in text for k in place_keywords) and intent not in (
                            "ask_places",
                            "ask_fun",
                            "ask_relax",
                            "ask_food",
                            "ask_explore",
                            "plan_trip",
                            "shorten_plan",
                            "extend_plan",
                            "modify_preference",
                        ):
                            intent = override_intent

                        # Map new intents to our existing legacy state machine
                        if intent == "search_event":
                            intent = "list_events"
                        for ent in rasa_data.get("entities", []):
                            if ent["entity"] == "quantity":
                                try:
                                    entities["quantity"] = int(ent["value"])
                                except ValueError:
                                    pass
                            elif ent["entity"] == "time":
                                parsed_time = dateparser.parse(ent["value"])
                                if parsed_time:
                                    entities["time"] = parsed_time.isoformat()
                            elif ent["entity"] in ("budget", "duration", "preference"):
                                entities[ent["entity"]] = str(ent.get("value", "")).strip().lower()

                        if intent in ("ask_fun", "ask_relax", "ask_food", "ask_explore") and not trip_followup:
                            if any(k in text for k in place_keywords):
                                entities["place_intent"] = intent.replace("ask_", "")
                                intent = "ask_places"
                            else:
                                intent = "unknown"
                        elif intent == "plan_trip" and override_intent in (
                            "ask_fun",
                            "ask_relax",
                            "ask_food",
                            "ask_explore",
                        ):
                            entities["place_intent"] = override_intent.replace("ask_", "")

                    except Exception:
                        # Fallback to old regex system if Rasa is offline
                        intent = detect_intent(text)
                        entities = extract_entities(db, text)

                    if intent in ("ask_fun", "ask_relax", "ask_food", "ask_explore"):
                        if any(k in text for k in place_keywords):
                            entities["place_intent"] = intent.replace("ask_", "")
                            intent = "ask_places"
                        else:
                            intent = "unknown"

    # Legacy static mappings since we only trained Rasa on genre, not specific Event IDs
    events = db.query(Event).all()
    for event in events:
        if event.name.lower() in text:
            entities["event_id"] = event.id
            entities["event_name"] = event.name
            break

    if "vip" in text:
        entities["category"] = "VIP"
    elif "regular" in text:
        entities["category"] = "Regular"

    place_filters = _extract_place_filters(text)
    if place_filters:
        context_filters = dict((session.context or {}).get("place_filters", {}))
        context_filters.update(place_filters)
        updated_context = dict(session.context or {})
        updated_context["place_filters"] = context_filters
        session.context = updated_context
        db.commit()

    if intent == "unknown" and place_filters:
        intent = "ask_places"
        entities["place_intent"] = session.context.get("place_intent")

    movie_theatre = _extract_movie_theatre(text) or _match_theatre_name(text, db)
    if movie_theatre:
        entities["movie_theatre"] = movie_theatre
        session.context = dict(session.context or {})
        session.context["movie_theatre"] = movie_theatre
        db.commit()

    selected_movie = _match_movie_title(text, db)
    if selected_movie and intent in ("unknown", "ask_movies", "ask_theatres"):
        intent = "ask_movie_showtimes"
        entities["movie_id"] = selected_movie["id"]
        entities["movie_title"] = selected_movie["title"]
        if selected_movie.get("config_id"):
            entities["movie_config_id"] = selected_movie["config_id"]
        session.context = dict(session.context or {})
        session.context["movie_id"] = selected_movie["id"]
        session.context["movie_title"] = selected_movie["title"]
        if selected_movie.get("config_id"):
            session.context["movie_config_id"] = selected_movie["config_id"]
            session.context["movie_theatre"] = selected_movie.get("theatre_name")
        db.commit()

    if movie_theatre and intent == "unknown":
        intent = "ask_movies"

    selected_showtime = _extract_showtime(text)
    matched_theatre = _match_theatre_name(text, db)
    if selected_movie and selected_showtime:
        theatre_name = matched_theatre or session.context.get("movie_theatre")
        if theatre_name:
            updated_context = dict(session.context or {})
            updated_context["movie_id"] = selected_movie["id"]
            updated_context["movie_title"] = selected_movie["title"]
            updated_context["movie_theatre"] = theatre_name
            updated_context["movie_showtime"] = selected_showtime
            session.context = updated_context
            db.commit()

            config_id = session.context.get("movie_config_id")
            if config_id:
                config = db.query(MovieShowConfig).filter(MovieShowConfig.id == config_id).first()
                if config:
                    show_date = datetime.utcnow()
                    if config.start_date and config.end_date:
                        if config.start_date.date() <= show_date.date() <= config.end_date.date():
                            show_date = show_date
                        else:
                            show_date = config.start_date
                    event = ensure_movie_event_instance(db, config, show_date, selected_showtime)
                else:
                    event = ensure_movie_event(
                        db,
                        selected_movie["title"],
                        theatre_name,
                        selected_showtime,
                    )
            else:
                event = ensure_movie_event(
                    db,
                    selected_movie["title"],
                    theatre_name,
                    selected_showtime,
                )

            updated_context["event_id"] = event.id
            session.context = updated_context
            db.commit()

            quantity = entities.get("quantity") or updated_context.get("quantity")
            category = entities.get("category") or updated_context.get("category")
            if not quantity:
                session.state = "event_selected"
                db.commit()
                return {
                    "intent": "ask_quantity",
                    "event_id": event.id,
                    "message": f"Great choice! {selected_movie['title']} at {theatre_name} ({selected_showtime}). How many tickets would you like?",
                    "movie_title": selected_movie["title"],
                    "theatre_name": theatre_name,
                    "showtime": selected_showtime,
                }

            recommended = recommend_seats(db, event.id, int(quantity), category)
            updated_context["quantity"] = int(quantity)
            updated_context["category"] = category
            updated_context["recommended_seats"] = recommended
            session.context = updated_context
            session.state = "awaiting_seat_selection"
            db.commit()

            seat_list = _format_seat_names(db, recommended)
            return {
                "intent": "select_seats",
                "event_id": event.id,
                "quantity": int(quantity),
                "category": category,
                "recommended_seats": recommended,
                "movie_title": selected_movie["title"],
                "theatre_name": theatre_name,
                "showtime": selected_showtime,
                "message": f"Great! I recommend seat{'s' if int(quantity) > 1 else ''} {seat_list} for you. Tap \"Select Seats\" to proceed.",
            }

    session.context = dict(session.context or {})
    session.context["last_intent"] = intent
    db.commit()

    if text == "extend lock":

        result = extend_lock(db, user_id, session.context.get("event_id"))

        if not result["success"]:
            return {
                "intent": "extension_failed",
                "message": result["reason"]
            }

        return {
            "intent": "lock_extended",
            "new_expiry": result["new_expiry"],
            "message": "Lock extended by 60 seconds."
        }

    # ======================================================
    # ENTITY COMPLETION ENGINE (ONLY FOR BOOKING INTENT)
    # ======================================================

    # ======================================================
    # GLOBAL INTERRUPTS & CANCEL FLOW
    # ======================================================

    # ── Global: greet (works from any state) ──
    if intent == "greet":
        return {
            "intent": "greet",
            "message": "Hey! Great to hear from you. 😊 Want to browse events, check ticket prices, or jump straight to booking?"
        }

    # ── Global: goodbye ──
    if intent == "goodbye":
        session.state = "idle"
        session.context = {}
        db.commit()
        return {
            "intent": "goodbye",
            "message": "Goodbye! Hope to see you at a great show soon. 🎉 Take care!"
        }

    # ── Global: thanks ──
    if intent == "thanks":
        return {
            "intent": "thanks",
            "message": "You're very welcome! 😊 Is there anything else I can help you with?"
        }

    # ── Global: help ──
    if intent == "ask_help":
        return {
            "intent": "help",
            "message": "Here's what I can do for you:\n• 🎭 Browse events — say \"show events\"\n• 💰 Check prices — say \"how much are tickets?\"\n• 🎟️ Book tickets — say \"book 2 tickets for Jazz\"\n• 📋 View your bookings — say \"my bookings\"\n• ❌ Cancel anytime — say \"cancel\"\n\nWhat would you like to do?"
        }

    # ── Global: plan trip + follow-ups ──
    if intent in ("plan_trip", "shorten_plan", "extend_plan", "modify_preference"):
        duration_label, hours = _extract_trip_duration(text)
        distance_km = None
        if session.context.get("place_filters"):
            distance_km = session.context["place_filters"].get("distance_km")

        constraints = _extract_trip_constraints(text)
        flags = _extract_trip_flags(text)
        trip_intent = _extract_trip_intent(text)
        budget = entities.get("budget") or constraints.get("budget")
        preference = entities.get("preference") or constraints.get("preference")

        previous = dict(session.context.get("trip_params") or {})
        if intent in ("shorten_plan", "extend_plan", "modify_preference"):
            if not previous:
                return {
                    "intent": "plan_trip",
                    "message": "Please create a plan first.",
                }

            hours = hours or previous.get("hours")
            distance_km = distance_km or previous.get("distance_km")
            budget = budget or previous.get("budget")
            duration_label = duration_label or previous.get("duration")
            preference = preference or previous.get("preference")
            trip_intent = trip_intent or previous.get("intent")
            museum_focus = flags.get("museum_focus", previous.get("museum_focus"))
            demo_mode = flags.get("demo_mode", previous.get("demo_mode"))

            if intent == "shorten_plan":
                duration_label = "short"
            elif intent == "extend_plan":
                duration_label = "long"
        else:
            museum_focus = flags.get("museum_focus")
            demo_mode = flags.get("demo_mode")

        duration_param = None
        if duration_label == "short":
            duration_param = "short"
        elif duration_label == "long":
            duration_param = "long"

        result = generate_itinerary(
            lat=11.0168,
            lng=76.9558,
            intent=trip_intent,
            max_duration_hours=hours or 4,
            max_distance_km=distance_km or 5,
            budget=budget,
            duration=duration_param,
            preference=preference,
            museum_focus=bool(museum_focus),
            demo_mode=bool(demo_mode),
        )
        itinerary = result.get("itinerary", [])
        if not itinerary:
            return {
                "intent": "plan_trip",
                "message": "I couldn't find enough places to build a trip.",
                "itinerary": [],
                "total_estimated_time_min": 0,
            }

        updated_context = dict(session.context or {})
        updated_context["trip_params"] = {
            "lat": 11.0168,
            "lng": 76.9558,
            "hours": hours or 4,
            "distance_km": distance_km or 5,
            "duration": duration_label,
            "intent": trip_intent,
            "budget": budget,
            "preference": preference,
            "museum_focus": bool(museum_focus),
            "demo_mode": bool(demo_mode),
        }
        session.context = updated_context
        db.commit()

        summary = result.get("plan_summary")
        message = "Here's a plan for you:"
        if summary:
            message = f"Here's a plan for you: {summary}"

        return {
            "intent": "plan_trip",
            "message": message,
            "itinerary": itinerary,
            "total_estimated_time_min": result.get("total_estimated_time_min", 0),
            "plan_summary": summary,
        }

    # ── Global: nearby places ──
    if intent == "ask_places":
        if entities.get("place_intent"):
            session.context["place_intent"] = entities.get("place_intent")
            db.commit()
        return {
            "intent": "ask_places",
            "message": "Let me find a few places near you...",
            "place_intent": entities.get("place_intent") or session.context.get("place_intent"),
            "place_filters": session.context.get("place_filters")
        }

    if intent in ("ask_movies", "ask_movie_showtimes"):
        if session.state in ("awaiting_event", "event_selected", "awaiting_seat_selection"):
            return {
                "intent": "ask_movies",
                "message": "You're in the middle of a booking. Say \"cancel\" to stop and I can show movies.",
            }

        theatre_name = entities.get("movie_theatre") or session.context.get("movie_theatre")
        if intent == "ask_movies" and theatre_name:
            movies = get_movies_by_theatre(theatre_name, db)
            for movie in _fetch_movie_catalog(db):
                if movie.get("theatre_name") and movie["theatre_name"].strip().lower() == theatre_name.strip().lower():
                    movies.append(movie)
            if not movies:
                return {
                    "intent": "ask_movies",
                    "message": f"I couldn't find movies for {theatre_name}.",
                    "movies": [],
                }

            lines = [f"{idx}. {movie['title']}" for idx, movie in enumerate(movies, start=1)]
            return {
                "intent": "ask_movies",
                "message": "Here are movies playing:\n" + "\n".join(lines),
                "movies": movies,
                "theatre_name": theatre_name,
            }

        if intent == "ask_movie_showtimes":
            movie_id = entities.get("movie_id")
            config_id = entities.get("movie_config_id") or session.context.get("movie_config_id")
            theatre_hint = theatre_name

            if config_id:
                config = db.query(MovieShowConfig).filter(MovieShowConfig.id == config_id).first()
                if not config:
                    return {
                        "intent": "ask_movie_showtimes",
                        "message": "I couldn't find that movie configuration.",
                    }
                theatre_hint = theatre_hint or config.theatre_name
                show_times = list(config.show_times or [])
                if not show_times:
                    return {
                        "intent": "ask_movie_showtimes",
                        "message": "No showtimes configured for that movie yet.",
                    }
                return {
                    "intent": "ask_movie_showtimes",
                    "message": f"Showtimes at {theatre_hint}:\n" + ", ".join(show_times),
                    "movie_id": movie_id,
                    "movie_title": entities.get("movie_title") or session.context.get("movie_title"),
                    "theatre_name": theatre_hint,
                    "show_times": show_times,
                }

            if not theatre_hint:
                theatres = get_theatres_for_movie(movie_id, db)
                theatre_hint = theatres[0] if theatres else None

            if not theatre_hint:
                return {
                    "intent": "ask_movie_showtimes",
                    "message": "Which theatre would you like to watch it at?",
                }

            show_times = get_showtimes(movie_id, theatre_hint, db)
            if show_times is None:
                return {
                    "intent": "ask_movie_showtimes",
                    "message": "I couldn't find showtimes for that selection.",
                }

            return {
                "intent": "ask_movie_showtimes",
                "message": f"Showtimes at {theatre_hint}:\n" + ", ".join(show_times),
                "movie_id": movie_id,
                "movie_title": entities.get("movie_title") or session.context.get("movie_title"),
                "theatre_name": theatre_hint,
                "show_times": show_times,
            }

        movies = _fetch_movie_catalog(db)
        if not movies:
            return {
                "intent": "ask_movies",
                "message": "I couldn't find movies right now.",
                "movies": [],
            }

        lines = [f"{idx}. {movie['title']}" for idx, movie in enumerate(movies, start=1)]
        return {
            "intent": "ask_movies",
            "message": "Here are movies playing:\n" + "\n".join(lines),
            "movies": movies,
        }

    if intent == "ask_theatres":
        if session.state in ("awaiting_event", "event_selected", "awaiting_seat_selection"):
            return {
                "intent": "ask_theatres",
                "message": "You're in the middle of a booking. Say \"cancel\" to stop and I can suggest theatres.",
            }

        theatres = get_nearby_theatres(11.0168, 76.9558)
        top_three = theatres[:3]
        if not top_three:
            return {
                "intent": "ask_theatres",
                "message": "I couldn't find nearby theatres right now.",
            }

        lines = [
            f"{idx}. {item['name']} ({item['distance_km']} km)"
            for idx, item in enumerate(top_three, start=1)
        ]
        return {
            "intent": "ask_theatres",
            "message": "Here are nearby theatres:\n" + "\n".join(lines),
            "theatres": top_three,
        }

    # ── Global: bot challenge ──
    if intent == "bot_challenge":
        return {
            "intent": "bot_challenge",
            "message": "I'm TicketBot — your AI-powered ticketing assistant! I'm not human, but I'm pretty good at finding you great seats. 🤖🎟️"
        }

    if text in ["cancel", "restart", "start over", "stop", "abort"] or intent == "deny":
        session.state = "idle"
        session.context = {}
        db.commit()
        return {
            "intent": "booking_cancelled",
            "message": "Alright, I've cancelled that. No worries! 😊 Want to browse events or start a fresh booking?"
        }

    if intent == "list_events":
        events = _fetch_event_catalog(db)
        return {
            "intent": "list_events",
            "data": events,
        }

    if intent in ("booking_history", "ask_booking_history"):
        bookings = db.query(Booking).filter(
            Booking.user_id == user_id
        ).all()

        return {
            "intent": "booking_history",
            "data": [
                {
                    "booking_id": b.id,
                    "event_id": b.event_id,
                    "status": b.status,
                    "total_amount": b.total_amount
                }
                for b in bookings
            ]
        }

    if intent == "ask_pricing":
        events = db.query(Event).all()
        if events:
            price_lines = ", ".join([f"{e.name} (₹{int(e.base_price)})" for e in events])
            return {
                "intent": "ask_pricing",
                "message": f"Here are the current ticket prices: {price_lines}. VIP seats may cost a bit more. Which event catches your eye? 😊"
            }
        return {
            "intent": "ask_pricing",
            "message": "Ticket prices vary by event, typically ranging from ₹50 for standard to ₹150 for VIP seats. Want to browse available events?"
        }


    if intent == "book_tickets":

    # 1️⃣ FULL INFO → FAST FORWARD
        if "event_id" in entities and "quantity" in entities:

            event_id = entities["event_id"]
            quantity = entities["quantity"]

            # 🔥 NEW: Get recommended seats by applying category filter
            category = entities.get("category")
            recommended = recommend_seats(db, event_id, quantity, category)

            session.state = "awaiting_seat_selection"
            session.context = {
                "event_id": event_id,
                "quantity": quantity,
                "category": category,
                "recommended_seats": recommended
            }
            db.commit()

            seat_list = _format_seat_names(db, recommended)
            return {
                "intent": "select_seats",
                "event_id": event_id,
                "quantity": quantity,
                "category": entities.get("category"),
                "recommended_seats": recommended,
                "message": f"Great! I recommend seat{'s' if quantity > 1 else ''} {seat_list} for you. Tap \"Select Seats\" to proceed."
            }


        # 2️⃣ PARTIAL INFO: quantity only
        if "quantity" in entities:

            session.context = {"quantity": entities["quantity"]}
            session.state = "awaiting_event"
            db.commit()

            available_events = _fetch_event_catalog(db)
            event_names = ", ".join([e["name"] for e in available_events])

            qty = entities['quantity']
            return {
                "intent": "ask_event",
                "message": f"Got it — {qty} ticket{'s' if qty > 1 else ''}! 🎟️ We have these shows available: {event_names}. Which one would you like?"
            }

        # 3️⃣ PARTIAL INFO: event only
        if "event_id" in entities:

            session.context = {"event_id": entities["event_id"]}
            session.state = "event_selected"
            db.commit()

            event_name = entities.get("event_name", "that event")

            return {
                "intent": "ask_quantity",
                "event_id": entities["event_id"],
                "message": f"Great choice — {event_name}! 🎭 How many tickets would you like?"
            }

        # 4️⃣ ONLY NOW reset if needed
        if session.state != "idle":
            session.state = "awaiting_event"
            session.context = {}
            db.commit()

            available_events = _fetch_event_catalog(db)
            event_names = ", ".join([e["name"] for e in available_events])

            return {
                "intent": "ask_event",
                "message": f"Let's start fresh! 😊 We currently have: {event_names}. Which event would you like to book?"
            }

        # 5️⃣ Default booking start
        session.state = "awaiting_event"
        db.commit()

        available_events = _fetch_event_catalog(db)
        event_names = ", ".join([e["name"] for e in available_events])

        return {
            "intent": "ask_event",
            "message": f"Sure, I'd love to help you book tickets! 🎟️ We currently have: {event_names}. Which event catches your eye?"
        }


    # ======================================================
    # NORMAL STATE MACHINE (FOR EVERYTHING ELSE)
    # ======================================================

    # IDLE STATE
    if session.state == "idle":

        if intent == "list_events":
            events = _fetch_event_catalog(db)
            return {
                "intent": "list_events",
                "data": events,
            }

        return {"intent": "unknown", "message": "Hmm, I'm not quite sure what you mean. 🤔 Try saying \"show events\", \"book tickets\", or \"help\" to see what I can do!"}

    # AWAITING EVENT
    if session.state == "awaiting_event":

        event = db.query(Event).filter(
            Event.name.ilike(f"%{text}%")
        ).first()

        if event:
            # Preserve existing context (like quantity if it exists)
            current_context = dict(session.context or {})
            current_context["event_id"] = event.id
            
            quantity = current_context.get("quantity")
            category = current_context.get("category")
            
            if quantity:
                # Fast-forward directly to seat selection since we already have the quantity!
                recommended = recommend_seats(db, event.id, quantity, category)
                current_context["recommended_seats"] = recommended
                
                session.context = current_context
                session.state = "awaiting_seat_selection"
                db.commit()

                seat_list = _format_seat_names(db, recommended)
                return {
                    "intent": "select_seats",
                    "quantity": quantity,
                    "event_id": event.id,
                    "recommended_seats": recommended,
                    "message": f"Got it, booking {quantity} ticket{'s' if quantity > 1 else ''} for {event.name}. I recommend seat{'s' if quantity > 1 else ''} {seat_list}. Tap \"Select Seats\" to proceed."
                }
            else:
                # Only ask for quantity if we don't have it yet
                session.context = current_context
                session.state = "event_selected"
                db.commit()

                return {
                    "intent": "event_selected",
                    "event_id": event.id,
                    "message": f"Got it, booking for {event.name}. How many tickets?"
                }

        available_events = _fetch_event_catalog(db)
        event_names = ", ".join([e["name"] for e in available_events])
        return {"intent": "unknown_event", "message": f"Hmm, I couldn't find that event. 🤔 We currently have: {event_names}. Which one were you looking for?"}

    # EVENT SELECTED
    if session.state == "event_selected":

        if text.isdigit() or "quantity" in entities:
             # Try to get quantity from rasa entities first, fallback to text digit
            quantity = entities.get("quantity")
            if not quantity and text.isdigit():
                quantity = int(text)

            if quantity:
                current_context = dict(session.context or {})
                event_id = current_context.get("event_id")
                category = current_context.get("category")
                
                recommended = recommend_seats(db, event_id, quantity, category)

                current_context["quantity"] = quantity
                current_context["recommended_seats"] = recommended
                
                session.context = current_context
                session.state = "awaiting_seat_selection"
                db.commit()

                seat_list = _format_seat_names(db, recommended)
                return {
                    "intent": "select_seats",
                    "quantity": quantity,
                    "event_id": event_id,
                    "recommended_seats": recommended,
                    "message": f"Great! I recommend seat{'s' if quantity > 1 else ''} {seat_list} for you. Tap \"Select Seats\" to proceed."
                }

        return {"intent": "ask_quantity_again", "message": "Hmm, I need a number for the tickets. 😊 How many seats would you like? (e.g. type \"2\")"}

    return {"intent": "unknown", "message": "I'm not quite sure what you mean. Try saying \"help\" to see what I can do!"}


# ======================================================
# SESSION HANDLER
# ======================================================

def get_or_create_session(db: Session, user_id: int):

    session = db.query(ChatSession).filter(
        ChatSession.user_id == user_id
    ).first()

    if not session:
        session = ChatSession(
            user_id=user_id,
            state="idle",
            context={}
        )
        db.add(session)
        db.commit()
        db.refresh(session)

    return session


# ======================================================
# INTENT DETECTION
# ======================================================

def detect_intent(text: str):

    text = text.lower()

    if any(w in text for w in ["hi", "hello", "hey", "good morning", "good evening", "howdy", "greetings"]):
        return "greet"

    if any(w in text for w in ["bye", "goodbye", "see you", "take care", "later", "exit", "quit"]):
        return "goodbye"

    if any(w in text for w in ["thanks", "thank you", "cheers", "appreciate"]):
        return "thanks"

    if any(w in text for w in ["help", "what can you do", "how do i", "guide", "options", "menu"]):
        return "ask_help"

    if any(w in text for w in ["are you a bot", "are you human", "who are you", "what are you"]):
        return "bot_challenge"

    if "my booking" in text or "booking history" in text or "my tickets" in text or "past booking" in text:
        return "ask_booking_history"

    if any(w in text for w in ["show event", "list event", "what events", "any events", "browse", "what shows", "what's on"]):
        return "list_events"

    if any(w in text for w in ["price", "cost", "how much", "expensive", "cheap", "pricing"]):
        return "ask_pricing"

    if any(w in text for w in ["nearby", "places", "attractions", "things to do"]):
        return "ask_places"

    if any(w in text for w in ["movies", "what's playing", "whats playing", "show movies", "what can i watch"]):
        return "ask_movies"

    if _contains_word(text, "movie") or any(w in text for w in ["theatre", "cinema", "watch movie"]):
        return "ask_theatres"

    if any(w in text for w in ["fun", "bored", "entertainment", "exciting", "hangout"]):
        return "ask_fun"

    if any(w in text for w in ["relax", "calm", "peaceful", "chill", "quiet"]):
        return "ask_relax"

    if any(w in text for w in ["food", "hungry", "restaurant", "eat", "dinner", "lunch"]):
        return "ask_food"

    if any(w in text for w in ["explore", "museum", "history", "cultural"]):
        return "ask_explore"

    if any(w in text for w in ["plan my trip", "day plan", "plan a visit", "plan trip"]):
        return "plan_trip"

    if any(w in text for w in ["make it shorter", "shorter plan", "shorten the plan", "reduce the plan", "quick version"]):
        return "shorten_plan"

    if any(w in text for w in ["make it longer", "extend the plan", "longer plan", "add more stops", "full day"]):
        return "extend_plan"

    if any(w in text for w in ["outdoor only", "indoor only", "make it outdoor", "make it indoor", "prefer outdoor", "prefer indoor"]):
        return "modify_preference"

    if any(w in text for w in ["book", "ticket", "buy", "purchase", "reserve", "get me", "i want"]):
        return "book_tickets"

    return "unknown"



# ======================================================
# ENTITY EXTRACTION
# ======================================================

def extract_entities(db: Session, text: str):

    entities = {}

    # Quantity
    quantity_match = re.search(r'\b\d+\b', text)
    if quantity_match:
        entities["quantity"] = int(quantity_match.group())

    # Event name
    events = db.query(Event).all()
    for event in events:
        if event.name.lower() in text.lower():
            entities["event_id"] = event.id
            entities["event_name"] = event.name
            break

    # Category
    if "vip" in text:
        entities["category"] = "VIP"
    elif "regular" in text:
        entities["category"] = "Regular"

    return entities


def _detect_place_intent(text: str):
    if any(w in text for w in ["fun", "bored", "entertainment", "exciting", "hangout"]):
        return "ask_fun"
    if any(w in text for w in ["relax", "calm", "peaceful", "chill", "quiet"]):
        return "ask_relax"
    if any(w in text for w in ["food", "hungry", "restaurant", "eat", "dinner", "lunch"]):
        return "ask_food"
    if any(w in text for w in ["explore", "museum", "history", "cultural"]):
        return "ask_explore"
    if any(w in text for w in ["nearby", "places", "attractions", "things to do"]):
        return "ask_places"
    return None


def _extract_place_filters(text: str):
    filters = {}

    distance_match = re.search(r'within\s+(\d+(?:\.\d+)?)\s*km', text)
    if distance_match:
        try:
            filters["distance_km"] = float(distance_match.group(1))
        except ValueError:
            pass

    areas = {p.get("area", "") for p in load_places()}
    lowered = text.lower()
    for area in areas:
        if not isinstance(area, str) or not area.strip():
            continue
        if area.strip().lower() in lowered:
            filters["area"] = area
            break

    return filters


def _extract_trip_constraints(text: str):
    lowered = text.lower()
    constraints = {}
    if any(w in lowered for w in ["low budget", "cheap", "budget", "low cost"]):
        constraints["budget"] = "low"
    if any(w in lowered for w in ["medium budget", "mid budget", "moderate"]):
        constraints["budget"] = "medium"
    if any(w in lowered for w in ["high budget", "premium", "luxury", "expensive"]):
        constraints["budget"] = "high"
    if any(w in lowered for w in ["short", "quick", "brief"]):
        constraints["duration"] = "short"
    if any(w in lowered for w in ["medium", "moderate", "half day"]):
        constraints["duration"] = "medium"
    if any(w in lowered for w in ["long", "full day", "extended"]):
        constraints["duration"] = "long"
    if any(w in lowered for w in ["indoor", "inside", "indoors"]):
        constraints["preference"] = "indoor"
    if any(w in lowered for w in ["outdoor", "outside", "outdoors"]):
        constraints["preference"] = "outdoor"
    return constraints


def _extract_trip_flags(text: str) -> dict:
    lowered = text.lower()
    flags = {}
    if any(w in lowered for w in ["museum", "museums", "history", "cultural", "culture"]):
        flags["museum_focus"] = True
    if any(w in lowered for w in ["demo", "test", "demo mode", "demo plan", "demo trip", "show demo"]):
        flags["demo_mode"] = True
    return flags


def _extract_trip_intent(text: str) -> Optional[str]:
    lowered = text.lower()
    if any(w in lowered for w in ["food", "restaurant", "eat", "dinner", "lunch", "cafe"]):
        return "food"
    if any(w in lowered for w in ["relax", "calm", "peaceful", "chill", "quiet"]):
        return "relax"
    if any(w in lowered for w in ["explore", "sightseeing", "attractions", "discover"]):
        return "explore"
    if any(w in lowered for w in ["outdoor", "outside", "outdoors", "park", "garden"]):
        return "outdoor"
    return None


def _extract_trip_duration(text: str) -> tuple[Optional[str], Optional[int]]:
    lowered = text.lower()
    hours_match = re.search(r"(\d+)\s*(hour|hours|hr|hrs)", lowered)
    hours = int(hours_match.group(1)) if hours_match else None
    if any(w in lowered for w in ["short", "quick", "brief"]):
        return "short", hours
    if any(w in lowered for w in ["medium", "moderate", "half day"]):
        return "medium", hours
    if any(w in lowered for w in ["long", "full day", "extended"]):
        return "long", hours
    return None, hours


def _detect_trip_followup_intent(text: str) -> Optional[str]:
    lowered = text.lower()
    if any(w in lowered for w in ["make it shorter", "shorter plan", "shorten the plan", "reduce the plan", "quick version"]):
        return "shorten_plan"
    if any(w in lowered for w in ["make it longer", "extend the plan", "longer plan", "add more stops", "full day"]):
        return "extend_plan"
    if any(w in lowered for w in ["outdoor only", "indoor only", "make it outdoor", "make it indoor", "prefer outdoor", "prefer indoor"]):
        return "modify_preference"
    if any(w in lowered for w in ["museum", "museums", "history", "cultural", "culture"]):
        return "plan_trip"
    if any(w in lowered for w in ["demo", "test", "demo mode", "demo plan", "demo trip", "show demo"]):
        return "plan_trip"
    return None


def _extract_movie_theatre(text: str) -> Optional[str]:
    match = re.search(r"movies\s+(?:in|at)\s+(.+)", text, re.IGNORECASE)
    if match:
        theatre = match.group(1).strip()
        return theatre or None
    return None


def _match_movie_title(text: str, db: Session) -> Optional[dict]:
    lowered = text.lower()
    normalized = _normalize_title(text)
    for movie in _fetch_movie_catalog(db):
        title = movie.get("title")
        if not isinstance(title, str):
            continue
        title_key = movie.get("title_key") or _normalize_title(title)
        if title.lower() in lowered or (normalized and title_key and title_key in normalized):
            return movie
    return None


def _normalize_title(value: Optional[str]) -> str:
    if not value:
        return ""
    lowered = value.lower()
    return re.sub(r"[^a-z0-9]+", "", lowered)


def _match_theatre_name(text: str, db: Session) -> Optional[str]:
    lowered = text.lower()
    for theatre in get_theatre_names(db):
        if not isinstance(theatre, str):
            continue
        if theatre.lower() in lowered:
            return theatre
    return None


def _extract_showtime(text: str) -> Optional[str]:
    match = re.search(r"\b([01]?\d|2[0-3]):[0-5]\d\b", text)
    if match:
        return match.group(0)
    return None


def _contains_word(text: str, word: str) -> bool:
    return bool(re.search(rf"\b{re.escape(word)}\b", text, re.IGNORECASE))
