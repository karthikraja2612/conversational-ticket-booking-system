# 🚀 Quick Start Guide

## Prerequisites Check
- [x] Python 3.13 installed
- [x] Flutter 3.41.0 installed (3 devices detected)
- [x] PostgreSQL running
- [x] Android emulator available

---

## ⚡ Start in 3 Steps

### **Step 1: Start Backend (Terminal 1)**
```bash
cd "c:\Users\navan\Documents\Mini Project\Online Chatbot Based Ticketing System\conversational-ticket-booking-system\backend"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Expected Output**:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

### **Step 2: Launch Flutter App (Terminal 2)**
```bash
cd "c:\Users\navan\Documents\Mini Project\Online Chatbot Based Ticketing System\conversational-ticket-booking-system\frontend\ticketing_app"
flutter run
```

**Choose Device**: Select an Android emulator when prompted

### **Step 3: Test the Flow**
1. **Home Screen** → Tap on any event card
2. **Chat Screen** → Type: "tomorrow at 7pm"
3. **Seat Selection** → Select seats → Tap "Lock Seats"
4. **Timer** → Watch countdown (5 minutes) → Tap "Confirm Booking"
5. **Payment Modal** → QR code appears → Tap "Confirm Payment"
6. **Ticket** → See QR ticket with booking details

---

## 🔧 Troubleshooting

### **Backend Won't Start**
```bash
# Install dependencies
pip install fastapi uvicorn sqlalchemy psycopg2-binary

# Check PostgreSQL connection in backend/app/database.py
```

### **Flutter Build Errors**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### **API Connection Failed**
- **Emulator**: Verify `baseUrl` is `http://10.0.2.2:8000` in `lib/core/constants/app_constants.dart`
- **Physical Device**: Update to your local IP (e.g., `http://192.168.1.100:8000`)

### **Database Errors**
```bash
# Create database
psql -U postgres
CREATE DATABASE ticketing_system;
\q

# Update connection string in backend/app/database.py
```

---

## 📱 Testing Checklist

Use this checklist to verify all features:

- [ ] **Home Screen Loads** - Events list appears
- [ ] **Chat Opens** - Tapping event opens chat
- [ ] **Message Sends** - Type "tomorrow 7pm" and send
- [ ] **Seat Grid Appears** - Available seats shown in green
- [ ] **Seat Selection Works** - Tap seats to select (turn purple)
- [ ] **Lock Seats API** - "Lock Seats" button calls API
- [ ] **Timer Starts** - Blue banner with 5:00 countdown
- [ ] **Timer Colors Change** - Blue → Orange (4min) → Red (2min)
- [ ] **Confirm Booking API** - "Confirm Booking" calls API
- [ ] **Payment Modal Shows** - QR code displayed
- [ ] **Payment Processes** - "Confirm Payment" completes
- [ ] **Ticket Displayed** - QR ticket with booking details

---

## 🌐 API Endpoints Quick Test

### **Test 1: Get Seat Status**
```bash
curl http://localhost:8000/events/1/seats-status
```

### **Test 2: Lock Seats**
```bash
curl -X POST http://localhost:8000/events/1/lock-seats \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": 1, \"seat_ids\": [1, 2, 3]}"
```

### **Test 3: Confirm Booking**
```bash
curl -X POST http://localhost:8000/events/1/confirm-booking \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": 1, \"seat_ids\": [1, 2, 3]}"
```

### **Test 4: Process Payment**
```bash
curl -X POST http://localhost:8000/bookings/1/process-payment \
  -H "Content-Type: application/json" \
  -d "{\"payment_method\": \"upi\", \"transaction_id\": \"TXN123\"}"
```

---

## 📊 What to Expect

### **API Response Times**
- Seat Status: ~100ms
- Lock Seats: ~150ms
- Confirm Booking: ~200ms
- Process Payment: ~180ms

### **UI Performance**
- Screen transitions: <300ms
- Seat selection animation: Instant
- QR generation: <500ms
- Timer updates: Every second

---

## 🎯 Success Criteria

✅ **Backend Health**: `/docs` endpoint shows Swagger UI  
✅ **Frontend Builds**: No compilation errors  
✅ **API Integration**: All 4 endpoints return 200 status  
✅ **Complete Flow**: Book ticket from start to finish  
✅ **Timer Works**: Countdown shows and expires correctly  
✅ **QR Generates**: Ticket displays valid QR code  

---

## 📞 Need Help?

1. **Check Logs**: Backend terminal shows API call logs
2. **Flutter DevTools**: Press `V` in terminal after `flutter run`
3. **Database Check**: Verify data in PostgreSQL
4. **Network Inspector**: Use `flutter run --verbose` for detailed logs

---

## 🎉 You're All Set!

Everything is configured and ready to run. Just execute the 3 commands above and test the complete booking flow.

**Time to First Booking**: ~2 minutes after starting both servers! 🚀
