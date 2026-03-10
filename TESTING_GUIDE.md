# Backend API Testing Guide

## Prerequisites
1. Backend server must be running on `http://localhost:8000`
2. Database must be initialized with events and seats

## Start Backend Server
```bash
cd backend
uvicorn app.main:app --reload
```

## Test Endpoints

### 1. Get All Seats Status
```bash
curl http://localhost:8000/events/1/seats-status
```

Expected Response:
```json
[
  {
    "id": 1,
    "row_number": 1,
    "seat_number": 1,
    "status": "available"
  },
  ...
]
```

### 2. Lock Seats
```bash
curl -X POST http://localhost:8000/events/1/lock-seats \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "seat_ids": [1, 2, 3]
  }'
```

Expected Response:
```json
{
  "message": "Seats locked successfully",
  "expires_at": "2026-02-17T10:45:00"
}
```

### 3. Confirm Booking
```bash
curl -X POST http://localhost:8000/events/1/confirm-booking \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "seat_ids": [1, 2, 3]
  }'
```

Expected Response:
```json
{
  "message": "Booking confirmed",
  "booking_id": 1,
  "total_amount": 150.0
}
```

### 4. Process Payment
```bash
curl -X POST "http://localhost:8000/events/1/process-payment?booking_id=1" \
  -H "Content-Type: application/json"
```

Expected Response:
```json
{
  "message": "Payment successful, booking confirmed"
}
```

## Frontend Configuration

Update `lib/core/constants/app_constants.dart`:
- For Android Emulator: `http://10.0.2.2:8000`
- For iOS Simulator: `http://localhost:8000`
- For Physical Device: `http://YOUR_COMPUTER_IP:8000`

## Common Issues

### Issue 1: Connection Refused
**Solution**: Make sure backend is running and accessible

### Issue 2: Seats Already Locked
**Solution**: Wait for lock to expire (5 minutes) or release manually from database

### Issue 3: Invalid Booking
**Solution**: Ensure seats are locked before confirming booking

## Integration Test Flow

1. **Start Backend**
   ```bash
   cd backend
   uvicorn app.main:app --reload
   ```

2. **Run Flutter App**
   ```bash
   cd frontend/ticketing_app
   flutter run
   ```

3. **Test Flow**
   - Click "Start Booking"
   - Select seats
   - Click "Lock Seats" → Should show timer
   - Click "Confirm Booking" → Should open payment modal
   - Click "Confirm Payment" → Should show QR ticket

## Expected Backend Status Codes

- 200: Success
- 400: Bad Request (validation error)
- 404: Not Found
- 500: Server Error
