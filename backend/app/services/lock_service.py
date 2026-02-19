from datetime import datetime, timedelta
from ..models import SeatLock

def extend_lock(db, user_id, event_id):

    current_time = datetime.utcnow()

    locks = db.query(SeatLock).filter(
        SeatLock.user_id == user_id,
        SeatLock.event_id == event_id,
        SeatLock.status == "locked",
        SeatLock.expires_at > current_time
    ).all()

    if not locks:
        return {"success": False, "reason": "No active lock"}

    for lock in locks:
        if lock.extension_used:
            return {"success": False, "reason": "Extension already used"}

    for lock in locks:
        lock.expires_at += timedelta(seconds=60)
        lock.extension_used = True

    db.commit()

    return {
        "success": True,
        "new_expiry": locks[0].expires_at
    }
