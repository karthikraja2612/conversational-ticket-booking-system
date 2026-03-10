import 'package:flutter/foundation.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/services/chat_service.dart';

enum ChatFlowStep {
  welcome,
  selectingSeats,
  seatsLocked,
  confirmed,
  paymentDone,
}

class ChatState extends ChangeNotifier {
  final ChatRepository _repository;

  final List<ChatMessageModel> _messages = [];
  bool _isTyping = false;
  ChatFlowStep _step = ChatFlowStep.welcome;
  bool _initialized = false;
  String? _authToken;

  // ── Track recommended seats from backend ──
  List<int> _recommendedSeats = [];
  int? _pendingEventId;
  int? _pendingQuantity;

  ChatState({ChatRepository? repository})
      : _repository = repository ?? ChatRepository();

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  ChatFlowStep get step => _step;
  List<int> get recommendedSeats => List.unmodifiable(_recommendedSeats);
  int? get pendingEventId => _pendingEventId;
  int? get pendingQuantity => _pendingQuantity;
  bool get shouldNavigateToSeats => _shouldNavigateToSeats;

  bool _shouldNavigateToSeats = false;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _queueBot(
      "Hi! I am TicketBot, your AI booking assistant.",
      delay: 400,
    );
    _queueBot(
      "Type 'show events' to see available events, or tell me what you'd like to book!",
      delay: 2000,
    );
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    _addUser(message.trim());

    if (_authToken == null) {
      _queueBot("Please log in to use the chat.", delay: 400);
      return;
    }

    _isTyping = true;
    notifyListeners();

    try {
      final response =
          await _repository.sendMessage(message.trim(), _authToken!);
      _isTyping = false;
      _handleBotResponse(response);
    } on ChatException catch (e) {
      _isTyping = false;
      _queueBot("Sorry, I encountered an error: ${e.message}", delay: 0);
      notifyListeners();
    } catch (e) {
      _isTyping = false;
      _queueBot("Sorry, something went wrong. Please try again.", delay: 0);
      notifyListeners();
    }
  }

  void _handleBotResponse(Map<String, dynamic> response) {
    final intent = response['intent'] as String? ?? 'unknown';
    final message = response['message'] as String?;

    switch (intent) {

      case 'select_seats':
        _pendingEventId = response['event_id'] as int?;
        _pendingQuantity = response['quantity'] as int?;

        // Parse recommended_seats list from backend
        final rawSeats = response['recommended_seats'];
        if (rawSeats is List && rawSeats.isNotEmpty) {
          _recommendedSeats = rawSeats.map((e) => (e as num).toInt()).toList();
          final seatList = _recommendedSeats.join(', ');
          _addBotNow(
            message ??
                'Here are your recommended seats: $seatList. '
                    'Opening seat selection...',
          );
        } else {
          _addBotNow(
            message ?? 'Opening seat selection for you...',
          );
        }
        // Transition to selectingSeats and trigger navigation
        _step = ChatFlowStep.selectingSeats;
        _shouldNavigateToSeats = true;
        break;

      // ── FIX 2: ask_quantity — just show the message (state machine in
      //    backend handles quantity parsing when user sends a digit next) ──
      case 'ask_quantity':
        _addBotNow(message ?? 'How many tickets would you like?');
        break;

      // ── FIX 3: ask_quantity_again — backend didn't recognise the digit ──
      case 'ask_quantity_again':
        _addBotNow(
            message ?? 'Please enter a number. How many tickets do you want?');
        break;

      case 'event_selected':
        _pendingEventId = response['event_id'] as int?;
        _addBotNow(
            message ?? 'Event selected! How many tickets would you like?');
        break;

      case 'ask_event':
        _addBotNow(message ?? 'Which event would you like to book?');
        break;

      case 'unknown_event':
        _addBotNow(
            message ?? "I couldn't find that event. Try typing the event name.");
        break;

      case 'list_events':
        final data = response['data'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          _messages.add(ChatMessageModel(
            content: 'Here are the available events:',
            sender: MessageSender.bot,
            timestamp: DateTime.now(),
            messageType: MessageType.eventList,
            extraData: {'events': data},
          ));
        } else {
          _addBotNow('No events available at the moment.');
        }
        break;

      case 'booking_history':
        final data = response['data'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          _messages.add(ChatMessageModel(
            content: 'Your recent bookings:',
            sender: MessageSender.bot,
            timestamp: DateTime.now(),
            messageType: MessageType.bookingHistory,
            extraData: {'bookings': data},
          ));
        } else {
          _addBotNow('You have no bookings yet.');
        }
        break;

      case 'lock_extended':
        _addBotNow(message ?? 'Lock extended by 60 seconds.');
        break;

      case 'extension_failed':
        _addBotNow(message ?? 'Could not extend lock.');
        break;

      case 'unknown':
        _addBotNow(
            message ?? "I didn't understand that. Try: 'show events' or 'book tickets'.");
        break;

      default:
        if (message != null && message.isNotEmpty) {
          _addBotNow(message);
        } else {
          _addBotNow("I'm not sure how to help with that. Try 'show events'.");
        }
    }
    notifyListeners();
  }

  void _addBotNow(String text) {
    _messages.add(ChatMessageModel(
      content: text,
      sender: MessageSender.bot,
      timestamp: DateTime.now(),
    ));
  }

  void _addUser(String text) {
    _messages.add(ChatMessageModel(
      content: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    ));
  }

  void _queueBot(String text, {int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay), () {
      _addBotNow(text);
      notifyListeners();
    });
  }

  void consumeNavigateToSeats() {
    _shouldNavigateToSeats = false;
    // No notifyListeners needed - just resets the consumed flag
  }

  void onSelectSeatsOpened() {
    if (_step != ChatFlowStep.welcome && _step != ChatFlowStep.selectingSeats) {
      return;
    }
    _step = ChatFlowStep.selectingSeats;
    _addUser("I would like to select seats.");
    _queueBot(
      "Great! Choose your preferred seats from the grid. Available seats are shown in dark grey.",
      delay: 800,
    );
    notifyListeners();
  }

  void onSeatsLocked(int count) {
    _step = ChatFlowStep.seatsLocked;
    _addUser("I have selected $count seat${count > 1 ? 's' : ''}.");
    _queueBot(
      "Seats locked for 5 minutes! Tap 'Confirm & Pay' to complete your booking.",
      delay: 600,
    );
    notifyListeners();
  }

  void onBookingConfirmed() {
    _step = ChatFlowStep.confirmed;
    _queueBot("Booking confirmed! Processing payment...", delay: 400);
    notifyListeners();
  }

  void onPaymentDone() {
    _step = ChatFlowStep.paymentDone;
    _queueBot(
      "Payment successful! 🎉 Your ticket is ready. Tap 'View My Ticket' to see your QR code.",
      delay: 400,
    );
    notifyListeners();
  }

  void onLockExpired() {
    _step = ChatFlowStep.selectingSeats;
    _recommendedSeats = [];
    _queueBot(
      "Your seat lock expired. Please select seats again.",
      delay: 0,
    );
    notifyListeners();
  }

  void reset() {
    _messages.clear();
    _step = ChatFlowStep.welcome;
    _initialized = false;
    _recommendedSeats = [];
    _pendingEventId = null;
    _pendingQuantity = null;
    _shouldNavigateToSeats = false;
    notifyListeners();
  }

  void clearError() {
    notifyListeners();
  }
}