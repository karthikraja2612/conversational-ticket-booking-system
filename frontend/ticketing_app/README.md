# TicketBot - AI-Powered Conversational Ticketing System

## 🎯 Overview

TicketBot is a production-grade Flutter frontend for an AI-powered conversational ticket booking system. It replaces traditional multi-page booking flows with a structured, chatbot-driven experience featuring real-time seat inventory, transaction-based seat locking, and secure payment processing.

## ✨ Features

### Core Functionality
- **🤖 Conversational AI Interface** - Structured state-driven chat flow
- **💺 Interactive Seat Selection** - Real-time seat grid with visual feedback
- **🔒 Real-Time Seat Locking** - Transaction-safe seat reservation with countdown timer
- **💳 Secure Payment Integration** - Sandbox payment gateway with smooth modal flow
- **🎫 QR Ticket Generation** - Instant ticket confirmation with QR code

### Design Highlights
- **Neo-Dark Glassmorphic UI** - Premium Material 3 inspired design
- **Smooth Animations** - Fluid transitions using fade, slide, and scale animations
- **Responsive Layout** - Adapts seamlessly to mobile, tablet, and larger screens
- **Real-Time Visual Feedback** - Color-coded seat states with animated indicators

## 🎨 Design System

### Color Palette
```dart
Background: #0F1115
Surface: #1A1D24
Primary: #4F8CFF
Success: #22C55E
Error: #EF4444
Warning: #F59E0B
```

### Key UI Components
- **Glass Cards** - Frosted glass morphism with backdrop blur
- **Gradient Buttons** - Smooth primary gradients with glow effects
- **Lock Timer Banner** - Animated countdown with color transitions
- **Chat Bubbles** - Distinct bot/user styled messages
- **Seat Grid** - Interactive seat visualization with animations

## 🏗️ Architecture

### Clean Architecture Structure
```
lib/
├── core/
│   ├── theme/          # App theme, colors, text styles
│   ├── constants/      # App-wide constants
│   └── utils/          # Extensions and utilities
├── data/
│   ├── models/         # Data models
│   ├── services/       # API services
│   └── repositories/   # Data repositories
├── domain/
│   └── state/          # State management (Provider)
└── presentation/
    ├── animations/     # Reusable animations
    ├── screens/        # App screens
    └── widgets/        # Reusable widgets
```

### State Management
- **Provider** for reactive state management
- **BookingState** - Manages seat selection, locking, and booking
- **ChatState** - Manages conversation flow and messages

### Key Screens
1. **HomeScreen** - Landing page with animated introduction
2. **ChatScreen** - Main conversational interface
3. **SeatSelectionScreen** - Interactive seat grid
4. **TicketConfirmationScreen** - QR ticket display

## 🔧 Technical Stack

### Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.1.1       # State management
  http: ^1.2.0           # API communication
  qr_flutter: ^4.1.0     # QR code generation
  cupertino_icons: ^1.0.8
```

### API Integration
- Base URL: `http://10.0.2.2:8000` (Android emulator)
- Endpoints:
  - `GET /events/{id}/available-seats`
  - `POST /events/{id}/lock-seats`
  - `POST /events/{id}/confirm-booking`
  - `POST /events/{id}/process-payment`

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / VS Code
- Backend API running (FastAPI)

### Installation
```bash
# Navigate to project directory
cd frontend/ticketing_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration
Update the API base URL in `lib/core/constants/app_constants.dart`:
```dart
static const String baseUrl = 'YOUR_API_URL';
```

## 📱 User Flow

1. **Welcome** → User lands on home screen
2. **Start Booking** → Chat interface initiates
3. **Select Seats** → Interactive seat grid opens
4. **Lock Seats** → 5-minute countdown timer starts
5. **Confirm Booking** → Booking is confirmed
6. **Payment** → Payment modal appears
7. **Complete** → QR ticket is generated

## 🎭 Animations

### Animation Types
- **FadeSlideTransition** - Smooth entry animations
- **ScaleTapAnimation** - Interactive button feedback
- **Shake Animation** - Invalid action feedback
- **Pulse Animation** - Timer urgency indicator

## 🔐 Concurrency Handling

- Seat locking prevents double booking
- Real-time countdown with automatic release
- Visual feedback for locked/booked seats
- Error handling for network failures

## 📊 Performance Considerations

- Efficient state updates with Provider
- Optimized widget rebuilds
- Lazy loading for seat grid
- Smooth 60fps animations

## 🎯 Future Enhancements

- [ ] Multi-event selection
- [ ] User authentication
- [ ] Booking history
- [ ] Push notifications
- [ ] Offline support
- [ ] Payment gateway integration
- [ ] Social sharing
- [ ] Multi-language support

## 📄 License

This project is part of an academic mini-project.

## 👥 Credits

Built with Flutter using Material 3 design principles and clean architecture patterns.

---

**Note**: This is a production-grade implementation designed for portfolio and evaluation purposes.
