from sqlalchemy.orm import Session
from ..models import ChatSession, Event, Booking
from .seat_recommender import recommend_seats
from .lock_service import extend_lock
from datetime import datetime
import re


# ======================================================
# MAIN MESSAGE HANDLER
# ======================================================

def handle_message(db: Session, session: ChatSession, user_id: int, message: str):

    text = message.lower()

    # Step 1: Detect intent + entities
    intent = detect_intent(text)
    entities = extract_entities(db, text)


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

    # GLOBAL INTERRUPTS
    if intent == "list_events":
        events = db.query(Event).all()
        return {
            "intent": "list_events",
            "data": [
                {"id": e.id, "name": e.name, "price": e.base_price}
                for e in events
            ]
        }

    if intent == "booking_history":
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


    if intent == "book_tickets":

    # 1️⃣ FULL INFO → FAST FORWARD
        if "event_id" in entities and "quantity" in entities:

            event_id = entities["event_id"]
            quantity = entities["quantity"]

            # 🔥 NEW: Get recommended seats
            recommended = recommend_seats(db, event_id, quantity)

            session.state = "awaiting_seat_selection"
            session.context = {
                "event_id": event_id,
                "quantity": quantity,
                "category": entities.get("category"),
                "recommended_seats": recommended
            }
            db.commit()

            seat_list = ', '.join(f'#{s}' for s in recommended)
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

            return {
                "intent": "ask_event",
                "message": f"You want {entities['quantity']} tickets. Which event?"
            }

        # 3️⃣ PARTIAL INFO: event only
        if "event_id" in entities:

            session.context = {"event_id": entities["event_id"]}
            session.state = "event_selected"
            db.commit()

            return {
                "intent": "ask_quantity",
                "event_id": entities["event_id"],
                "message": "How many tickets would you like?"
            }

        # 4️⃣ ONLY NOW reset if needed
        if session.state != "idle":
            session.state = "awaiting_event"
            session.context = {}
            db.commit()

            return {
                "intent": "ask_event",
                "message": "Starting a new booking. Which event?"
            }

        # 5️⃣ Default booking start
        session.state = "awaiting_event"
        db.commit()

        return {
            "intent": "ask_event",
            "message": "Which event would you like to book?"
        }


    # ======================================================
    # NORMAL STATE MACHINE (FOR EVERYTHING ELSE)
    # ======================================================

    # IDLE STATE
    if session.state == "idle":

        if intent == "list_events":
            events = db.query(Event).all()
            return {
                "intent": "list_events",
                "data": [
                    {"id": e.id, "name": e.name, "price": e.base_price}
                    for e in events
                ]
            }

        if intent == "booking_history":
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

        return {"intent": "unknown"}

    # AWAITING EVENT
    if session.state == "awaiting_event":

        event = db.query(Event).filter(
            Event.name.ilike(f"%{text}%")
        ).first()

        if event:
            session.state = "event_selected"
            session.context = {"event_id": event.id}
            db.commit()

            return {
                "intent": "event_selected",
                "event_id": event.id,
                "message": f"{event.name} selected. How many tickets?"
            }

        return {"intent": "unknown_event"}

    # EVENT SELECTED
    if session.state == "event_selected":

        if text.isdigit():
            quantity = int(text)

            event_id = session.context.get("event_id")
            recommended = recommend_seats(db, event_id, quantity)

            session.context["quantity"] = quantity
            session.context["recommended_seats"] = recommended
            session.state = "awaiting_seat_selection"
            db.commit()

            seat_list = ', '.join(f'#{s}' for s in recommended)
            return {
                "intent": "select_seats",
                "quantity": quantity,
                "event_id": event_id,
                "recommended_seats": recommended,
                "message": f"Great! I recommend seat{'s' if quantity > 1 else ''} {seat_list} for you. Tap \"Select Seats\" to proceed."
            }

        return {"intent": "ask_quantity_again", "message": "Please enter a valid number. How many tickets?"}

    return {"intent": "unknown"}


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

    if "my booking" in text or "booking history" in text:
        return "booking_history"

    if "show" in text and "event" in text:
        return "list_events"

    if "book" in text or "ticket" in text:
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
