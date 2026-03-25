from __future__ import annotations

from typing import Optional


def categorize_event_type(name: Optional[str], theatre_name: Optional[str] = None) -> str:
    """Return a normalized event category based on the event name/theatre."""
    if theatre_name:
        return "movie"

    normalized = (name or "").strip().lower()
    if not normalized:
        return "others"

    if any(k in normalized for k in ("concert", "music", "jazz", "live", "gig")):
        return "concert"
    if "festival" in normalized or "fest" in normalized:
        return "festival"
    if any(k in normalized for k in ("sports", "match", "tournament", "league", "cup", "stadium")):
        return "sports"
    if any(k in normalized for k in ("comedy", "standup", "stand-up", "stand up")):
        return "comedy"

    return "others"
