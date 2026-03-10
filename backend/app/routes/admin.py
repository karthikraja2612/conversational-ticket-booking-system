from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.analytics_service import get_event_summary
from app.routes.admin_auth import get_current_admin

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/events/{event_id}/analytics")
def event_analytics(event_id: int, db: Session = Depends(get_db), admin=Depends(get_current_admin)):
    return get_event_summary(db, event_id)