from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..schemas import LockSeatsRequest, ConfirmBookingRequest, SeatResponse, SeatStatusResponse
from ..security import get_current_user
from .. import crud

router = APIRouter()


@router.get("/events/{event_id}/available-seats", response_model=List[SeatResponse])
def get_available_seats(event_id: int, db: Session = Depends(get_db)):
    return crud.get_available_seats(db, event_id)


@router.get("/events/{event_id}/seats-status", response_model=List[SeatStatusResponse])
def get_seat_status(event_id: int, db: Session = Depends(get_db)):
    result = crud.get_seat_status_for_event(db, event_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Event not found")
    return result


@router.post("/events/{event_id}/lock-seats")
def lock_seats(
    event_id: int,
    request: LockSeatsRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        expiry = crud.lock_seats(db, event_id, current_user.id, request.seat_ids)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"message": "Seats locked successfully", "expires_at": expiry}


@router.post("/events/{event_id}/confirm-booking")
def confirm_booking(
    event_id: int,
    request: ConfirmBookingRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        booking = crud.confirm_booking(db, event_id, current_user.id, request.seat_ids)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return {
        "message": "Booking confirmed",
        "booking_id": booking.id,
        "total_amount": booking.total_amount,
    }


@router.post("/events/{event_id}/process-payment")
def process_payment(
    event_id: int,
    booking_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        payment = crud.process_payment(db, event_id, current_user.id, booking_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {
        "message": "Payment successful, booking confirmed",
        "transaction_id": payment.transaction_id,
    }


@router.get("/events/{event_id}/available-seats", response_model=List[SeatResponse])
def get_available_seats(event_id: int, db: Session = Depends(get_db)):
    
    current_time = datetime.utcnow()

    # Get seats that are NOT booked
    booked_seat_ids = db.query(BookingSeat.seat_id)\
    .join(Booking, BookingSeat.booking_id == Booking.id)\
    .filter(
        Booking.event_id == event_id,
        Booking.status == "confirmed"
    ).all()
    booked_seat_ids = [seat[0] for seat in booked_seat_ids]

    # Get seats that are locked and NOT expired
    locked_seat_ids = db.query(SeatLock.seat_id).filter(
        and_(
            SeatLock.event_id == event_id,
            SeatLock.status == "locked",
            SeatLock.expires_at > current_time
        )
    ).all()
    locked_seat_ids = [seat[0] for seat in locked_seat_ids]

    # Get available seats
    available_seats = db.query(Seat).filter(
        ~Seat.id.in_(booked_seat_ids + locked_seat_ids)
    ).all()

    db.query(SeatLock).filter(
    SeatLock.status == "locked",
    SeatLock.expires_at < current_time
    ).update({"status": "released"})
    db.commit()


    return available_seats


@router.post("/events/{event_id}/lock-seats")
def lock_seats(event_id: int, request: LockSeatsRequest, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    user_id=current_user.id
    current_time = datetime.utcnow()
    expiry_time = current_time + timedelta(minutes=5)

    # Check active locks
    existing_locks = db.query(SeatLock).filter(
        SeatLock.event_id == event_id,
        SeatLock.seat_id.in_(request.seat_ids),
        SeatLock.status == "locked",
        SeatLock.expires_at > current_time
    ).all()

    if existing_locks:
        raise HTTPException(status_code=400, detail="One or more seats already locked")

    # Lock seats
    for seat_id in request.seat_ids:
        new_lock = SeatLock(
            seat_id=seat_id,
            event_id=event_id,
            user_id=current_user.id,
            locked_at=current_time,
            expires_at=expiry_time,
            status="locked"
        )
        db.add(new_lock)
    db.commit()

    db.query(SeatLock).filter(
    SeatLock.status == "locked",
    SeatLock.expires_at < current_time
    ).update({"status": "released"})
    db.commit()


    return {
        "message": "Seats locked successfully",
        "expires_at": expiry_time
    }

@router.post("/events/{event_id}/confirm-booking")
def confirm_booking(event_id: int, request: ConfirmBookingRequest, db: Session = Depends(get_db), current_user=Depends(get_current_user)):

    current_time = datetime.utcnow()

    try:
        # 1️⃣ Validate locks
        locks = db.query(SeatLock).filter(
            SeatLock.event_id == event_id,
            SeatLock.seat_id.in_(request.seat_ids),
            SeatLock.user_id == current_user.id,
            SeatLock.status == "locked",
            SeatLock.expires_at > current_time
        ).all()

        if len(locks) != len(request.seat_ids):
            raise HTTPException(status_code=400, detail="Invalid or expired lock")

        # 2️⃣ Get event price
        event = db.query(Event).filter(Event.id == event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        total_amount = event.base_price * len(request.seat_ids)

        # 3️⃣ Create booking
        new_booking = Booking(
            user_id=current_user.id,
            event_id=event_id,
            total_amount=total_amount,
            status="pending"
        )
        db.add(new_booking)
        db.flush()  # get booking ID before commit

        # 4️⃣ Insert booking_seats
        for seat_id in request.seat_ids:
            booking_seat = BookingSeat(
                booking_id=new_booking.id,
                seat_id=seat_id
            )
            db.add(booking_seat)

        # 5️⃣ Update locks to confirmed
        for lock in locks:
            lock.status = "pending"

        db.commit()

        return {
            "message": "Booking confirmed",
            "booking_id": new_booking.id,
            "total_amount": total_amount
        }

    except Exception as e:
        db.rollback()
        raise e
    
@router.post("/events/{event_id}/process-payment")
def process_payment(event_id: int, booking_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    try:
        # 1️⃣ Get booking
        booking = db.query(Booking).filter(
            Booking.id == booking_id,
            Booking.event_id == event_id,
            Booking.user_id == current_user.id,
            Booking.status == "pending"
        ).first()

        if not booking:
            raise HTTPException(status_code=400, detail="Invalid booking")

        # 2️⃣ Simulate payment success
        payment = Payment(
            booking_id=booking_id,
            payment_status="success",
            transaction_id=f"TXN-{uuid.uuid4().hex[:12].upper()}",
            paid_at=datetime.utcnow()
        )
        db.add(payment)

        # 3️⃣ Confirm booking
        booking.status = "confirmed"

        # 4️⃣ Update seat locks to confirmed
        locks = db.query(SeatLock).filter(
            SeatLock.event_id == event_id,
            SeatLock.user_id == booking.user_id,
            SeatLock.status == "pending"
        ).all()

        for lock in locks:
            lock.status = "confirmed"

        db.commit()

        return {"message": "Payment successful, booking confirmed"}

    except Exception as e:
        db.rollback()
        raise e
    
@router.get("/events/{event_id}/seats-status", response_model=List[SeatStatusResponse])
def get_seat_status(event_id: int, db: Session = Depends(get_db)):

    current_time = datetime.utcnow()

    # 1️⃣ Release expired locks
    db.query(SeatLock).filter(
        SeatLock.status == "locked",
        SeatLock.expires_at < current_time
    ).update({"status": "released"})
    db.commit()

    # 2️⃣ Only fetch seats that belong to this event's venue
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Event not found")

    # Deduplicate by (row_number, seat_number) — pick lowest id per position
    from sqlalchemy import func as sqlfunc
    subq = (
        db.query(sqlfunc.min(Seat.id).label("min_id"))
        .filter(Seat.venue_id == event.venue_id)
        .group_by(Seat.row_number, Seat.seat_number)
        .subquery()
    )
    seats = db.query(Seat).filter(Seat.id.in_(subq)).order_by(Seat.row_number, Seat.seat_number).all()

    result = []

    for seat in seats:

        # Check if booked
        booked = db.query(BookingSeat)\
            .join(Booking, BookingSeat.booking_id == Booking.id)\
            .filter(
                Booking.event_id == event_id,
                Booking.status == "confirmed",
                BookingSeat.seat_id == seat.id
            ).first()

        if booked:
            status = "booked"
        else:
            # Check if locked
            locked = db.query(SeatLock).filter(
                SeatLock.event_id == event_id,
                SeatLock.seat_id == seat.id,
                SeatLock.status == "locked",
                SeatLock.expires_at > current_time
            ).first()

            if locked:
                status = "locked"
            else:
                status = "available"

        result.append({
            "id": seat.id,
            "row_number": seat.row_number,
            "seat_number": seat.seat_number,
            "status": status
        })

    return result