import os
import re
from typing import Any, Dict, List, Optional, Text

import requests
from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher
from rasa_sdk.events import SlotSet


class ActionGetNearbyPlaces(Action):
    def name(self) -> Text:
        return "action_get_nearby_places"

    def run(
        self,
        dispatcher: CollectingDispatcher,
        tracker: Tracker,
        domain: Dict[Text, Any],
    ) -> List[Dict[Text, Any]]:
        base_url = os.getenv("TICKETBOT_API_URL", "http://localhost:8000")
        lat = 11.0168
        lng = 76.9558

        intent = tracker.latest_message.get("intent", {}).get("name")
        intent_map = {
            "ask_fun": "fun",
            "ask_relax": "relax",
            "ask_food": "food",
            "ask_explore": "explore",
        }
        mapped_intent = intent_map.get(intent)

        try:
            params = {"lat": lat, "lng": lng}
            if mapped_intent:
                params["intent"] = mapped_intent
            response = requests.get(
                f"{base_url}/places/nearby",
                params=params,
                timeout=8,
            )
            response.raise_for_status()
            places = response.json()
        except requests.RequestException:
            dispatcher.utter_message(
                text="Sorry, I couldn't fetch nearby places right now."
            )
            return []

        if not places:
            dispatcher.utter_message(text="I couldn't find places nearby.")
            return []

        category_icons = {
            "Mall": "🏬",
            "Museum": "🏛",
            "Park": "🌳",
            "Restaurant": "🍴",
            "Entertainment": "🎭",
        }

        top_places = places[:3]
        lines = []
        for place in top_places:
            name = place.get("name", "Unknown")
            category = place.get("category", "Place")
            distance = place.get("distance", "")
            icon = category_icons.get(category, "📍")
            suffix = f" ({distance})" if distance else ""
            lines.append(f"{icon} {name}{suffix}")

        message = "Here are some places near you:\n" + "\n".join(lines)
        dispatcher.utter_message(text=message)
        return []


class ActionPlanTrip(Action):
    def name(self) -> Text:
        return "action_plan_trip"

    def _extract_hours(self, tracker: Tracker) -> Optional[int]:
        for ent in tracker.latest_message.get("entities", []):
            if ent.get("entity") == "time":
                text = str(ent.get("value", ""))
                match = re.search(r"(\d+)", text)
                if match:
                    return max(1, int(match.group(1)))
        return None

    def _extract_location(self, tracker: Tracker) -> Optional[str]:
        for ent in tracker.latest_message.get("entities", []):
            if ent.get("entity") in ("location", "area", "city"):
                value = ent.get("value")
                if value:
                    return str(value)
        return None

    def _extract_constraint(self, tracker: Tracker, entity_names: List[str]) -> Optional[str]:
        for ent in tracker.latest_message.get("entities", []):
            if ent.get("entity") in entity_names:
                value = ent.get("value")
                if value:
                    return str(value)
        return None

    def _format_duration(self, minutes: int) -> str:
        if minutes >= 60:
            return f"{minutes / 60:.1f} hrs"
        return f"{minutes} mins"

    def _format_step(self, label: str, item: Dict[str, Any]) -> str:
        name = item.get("name", "Place")
        minutes = int(item.get("estimated_time_min", 0))
        duration = self._format_duration(minutes) if minutes else ""
        suffix = f" ({duration})" if duration else ""
        return f"{label} {name}{suffix}"

    def _slot_value(self, tracker: Tracker, key: str) -> Optional[str]:
        value = tracker.get_slot(key)
        if value is None:
            return None
        return str(value)

    def run(
        self,
        dispatcher: CollectingDispatcher,
        tracker: Tracker,
        domain: Dict[Text, Any],
    ) -> List[Dict[Text, Any]]:
        base_url = os.getenv("TICKETBOT_API_URL", "http://localhost:8000")
        lat = 11.0168
        lng = 76.9558

        intent_name = tracker.latest_message.get("intent", {}).get("name")

        previous_hours = self._slot_value(tracker, "plan_hours")
        previous_area = self._slot_value(tracker, "plan_area")
        previous_budget = self._slot_value(tracker, "plan_budget")
        previous_duration = self._slot_value(tracker, "plan_duration")
        previous_preference = self._slot_value(tracker, "plan_preference")

        hours = self._extract_hours(tracker)
        location = self._extract_location(tracker)
        budget = self._extract_constraint(tracker, ["budget", "price", "cost"])
        duration = self._extract_constraint(tracker, ["duration", "length"])
        preference = self._extract_constraint(tracker, ["preference", "style", "setting"])

        if hours is None and previous_hours:
            try:
                hours = int(float(previous_hours))
            except ValueError:
                hours = None

        if not location and previous_area:
            location = previous_area
        if not budget and previous_budget:
            budget = previous_budget
        if not duration and previous_duration:
            duration = previous_duration
        if not preference and previous_preference:
            preference = previous_preference

        if intent_name == "shorten_plan":
            duration = "short"
        elif intent_name == "extend_plan":
            duration = "long"
        elif intent_name == "modify_preference":
            if preference is None:
                preference = previous_preference

        payload: Dict[str, Any] = {"lat": lat, "lng": lng}
        if hours:
            payload["max_duration_hours"] = hours
        if budget:
            payload["budget"] = budget
        if duration:
            payload["duration"] = duration
        if preference:
            payload["preference"] = preference

        try:
            response = requests.post(
                f"{base_url}/plan-trip",
                json=payload,
                timeout=10,
            )
            response.raise_for_status()
            payload = response.json()
        except requests.RequestException:
            dispatcher.utter_message(text="Sorry, I couldn't build a trip plan right now.")
            return []

        itinerary = payload.get("itinerary", []) if isinstance(payload, dict) else []
        if not itinerary:
            dispatcher.utter_message(text="I couldn't find enough places to build a trip.")
            return []

        total_minutes = int(payload.get("total_estimated_time_min", 0))
        total_label = self._format_duration(total_minutes) if total_minutes else ""
        intro = "Here is a relaxed plan for you"
        if hours:
            intro = f"Here is a relaxed {hours}-hour plan for you"
        elif total_label:
            intro = f"Here is a relaxed {total_label} plan for you"

        lines = []
        if itinerary:
            lines.append(self._format_step("Start with", itinerary[0]))
        if len(itinerary) >= 2:
            lines.append(self._format_step("Then head to", itinerary[1]))
        if len(itinerary) >= 3:
            lines.append(self._format_step("Next, visit", itinerary[2]))
        if len(itinerary) >= 4:
            lines.append(self._format_step("Wrap up at", itinerary[-1]))
        elif len(itinerary) == 3:
            lines[-1] = self._format_step("Wrap up at", itinerary[2])
        elif len(itinerary) == 2:
            lines[-1] = self._format_step("Wrap up at", itinerary[1])

        follow_ups = [
            "Want to adjust this plan?",
            "Try a shorter version",
            "Focus only on museums",
            "Add more food stops",
        ]

        message = f"{intro}:\n" + "\n".join(lines) + "\n" + "\n".join(follow_ups)
        dispatcher.utter_message(text=message)
        return [
            SlotSet("plan_hours", hours),
            SlotSet("plan_area", location),
            SlotSet("plan_budget", budget),
            SlotSet("plan_duration", duration),
            SlotSet("plan_preference", preference),
        ]
