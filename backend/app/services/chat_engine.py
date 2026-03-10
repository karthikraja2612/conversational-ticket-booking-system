from sqlalchemy.orm import Session
from ..models import ChatSession, Event, Booking, Seat
from .seat_recommender import recommend_seats
from .lock_service import extend_lock
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


# ======================================================
# MAIN MESSAGE HANDLER
# ======================================================

def handle_message(db: Session, session: ChatSession, user_id: int, message: str):

    text = message.lower()

    # Step 1: Detect intent + entities via locally hosted Rasa NLP
    try:
        response = httpx.post("http://localhost:5005/model/parse", json={"text": message}, timeout=3.0)
        rasa_data = response.json()
        
        intent = rasa_data.get("intent", {}).get("name", "unknown")
        
        # Map new intents to our existing legacy state machine
        if intent == "search_event":
            intent = "list_events"
            
        entities = {}
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
                    
    except Exception:
        # Fallback to old regex system if Rasa is offline
        intent = detect_intent(text)
        entities = extract_entities(db, text)

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
        events = db.query(Event).all()
        return {
            "intent": "list_events",
            "data": [
                {"id": e.id, "name": e.name, "price": e.base_price}
                for e in events
            ]
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

            available_events = db.query(Event).all()
            event_names = ", ".join([e.name for e in available_events])

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

            available_events = db.query(Event).all()
            event_names = ", ".join([e.name for e in available_events])

            return {
                "intent": "ask_event",
                "message": f"Let's start fresh! 😊 We currently have: {event_names}. Which event would you like to book?"
            }

        # 5️⃣ Default booking start
        session.state = "awaiting_event"
        db.commit()

        available_events = db.query(Event).all()
        event_names = ", ".join([e.name for e in available_events])

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
            events = db.query(Event).all()
            return {
                "intent": "list_events",
                "data": [
                    {"id": e.id, "name": e.name, "price": e.base_price}
                    for e in events
                ]
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

        available_events = db.query(Event).all()
        event_names = ", ".join([e.name for e in available_events])
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
