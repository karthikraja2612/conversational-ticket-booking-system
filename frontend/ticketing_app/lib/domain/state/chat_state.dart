import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/services/api_service.dart';
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
  final ApiService _apiService;

  final List<ChatMessageModel> _messages = [];
  bool _isTyping = false;
  ChatFlowStep _step = ChatFlowStep.welcome;
  bool _initialized = false;
  String? _authToken;
  bool _historyLoaded = false;
  bool _greetingQueued = false;
  bool _resumeChecked = false;
  Map<String, dynamic>? _resumeOffer;
  String? _lastErrorMessage;
  String? _lastFailedMessage;

  // ── Track recommended seats from backend ──
  List<int> _recommendedSeats = [];
  int? _pendingEventId;
  int? _pendingQuantity;

  ChatState({ChatRepository? repository, ApiService? apiService})
      : _repository = repository ?? ChatRepository(),
        _apiService = apiService ?? ApiService();

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  ChatFlowStep get step => _step;
  List<int> get recommendedSeats => List.unmodifiable(_recommendedSeats);
  int? get pendingEventId => _pendingEventId;
  int? get pendingQuantity => _pendingQuantity;
  bool get shouldNavigateToSeats => _shouldNavigateToSeats;
  Map<String, dynamic>? get resumeOffer => _resumeOffer;
  bool get hasResumeOffer => _resumeOffer != null;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get hasLastError => _lastErrorMessage != null;

  bool _shouldNavigateToSeats = false;

  void setAuthToken(String? token) {
    _authToken = token;
    _apiService.setAuthToken(token);
    if (token != null) {
      loadHistory(showGreetingIfEmpty: _initialized && _messages.isEmpty);
      checkResumeOffer();
    }
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (_messages.isNotEmpty) return;
    if (_authToken != null) {
      loadHistory(showGreetingIfEmpty: true);
      checkResumeOffer();
      return;
    }
    _queueGreeting();
  }

  Future<void> checkResumeOffer() async {
    if (_resumeChecked || _authToken == null) return;
    _resumeChecked = true;
    try {
      final data = await _apiService.fetchActiveBooking();
      if (data != null) {
        _resumeOffer = data;
        notifyListeners();
      }
    } catch (_) {
      // Ignore resume errors to keep chat usable.
    }
  }

  void consumeResumeOffer() {
    _resumeOffer = null;
    notifyListeners();
  }

  Future<void> loadHistory({bool showGreetingIfEmpty = false}) async {
    if (_historyLoaded || _authToken == null) return;
    _historyLoaded = true;
    try {
      final raw = await _repository.fetchHistory(_authToken!, limit: 20);
      final items = raw.map(ChatMessageModel.fromHistory).toList();
      if (items.isNotEmpty) {
        _messages
          ..clear()
          ..addAll(items);
        notifyListeners();
      } else if (showGreetingIfEmpty) {
        _queueGreeting();
      }
    } catch (_) {
      // Ignore history errors to keep chat usable.
    }
  }

  void _queueGreeting() {
    if (_greetingQueued) return;
    _greetingQueued = true;
    _queueBot(
      "Hi! I am TicketBot, your AI booking assistant.",
      delay: 200,
    );
    _queueBot(
      "Type 'show events' to see available events, or tell me what you'd like to book!",
      delay: 1600,
    );
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    _addUser(message.trim());
    _lastFailedMessage = message.trim();
    _lastErrorMessage = null;

    if (_authToken == null) {
      _queueBot("Please log in to use the chat.", delay: 400);
      return;
    }

    _isTyping = true;
    notifyListeners();

    try {
      debugPrint('[Chat] sending: ${message.trim()}');
      final response =
          await _repository.sendMessage(message.trim(), _authToken!);
      debugPrint('[Chat] response: $response');
      _isTyping = false;
      _lastErrorMessage = null;
      await _handleBotResponse(response);
    } on ChatException catch (e) {
      _isTyping = false;
      _lastErrorMessage = e.message;
      _queueBot("Sorry, I encountered an error: ${e.message}", delay: 0);
      notifyListeners();
    } catch (e) {
      _isTyping = false;
      _lastErrorMessage = "Something went wrong. Please try again.";
      _queueBot("Sorry, something went wrong. Please try again.", delay: 0);
      notifyListeners();
    }
  }

  Future<void> retryLastMessage() async {
    final msg = _lastFailedMessage;
    if (msg == null || msg.trim().isEmpty) return;
    _lastErrorMessage = null;
    notifyListeners();
    await sendMessage(msg);
  }

  Future<void> _handleBotResponse(Map<String, dynamic> response) async {
    final intent = response['intent'] as String? ?? 'unknown';
    final message = response['message'] as String?;
    final itinerary = response['itinerary'];

    if (itinerary is List) {
      _messages.add(ChatMessageModel(
        content: message ?? 'Here is a trip plan for you:',
        sender: MessageSender.bot,
        timestamp: DateTime.now(),
        messageType: MessageType.itinerary,
        extraData: {
          'itinerary': itinerary,
          'total_estimated_time_min': response['total_estimated_time_min'],
          'plan_summary': response['plan_summary'],
        },
      ));
      notifyListeners();
      return;
    }

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

      case 'ask_places':
        if (message != null && message.isNotEmpty) {
          _addBotNow(message);
        }
        _isTyping = true;
        notifyListeners();
        try {
          final placeIntent = response['place_intent'] as String?;
          final filters = response['place_filters'] as Map<String, dynamic>?;
          final distanceKm = (filters?['distance_km'] as num?)?.toDouble();
          final area = filters?['area'] as String?;
          final position = await _resolveLocation();
          final lat = position?.latitude ?? 11.0168;
          final lng = position?.longitude ?? 76.9558;
          final places = await _apiService.fetchNearbyPlaces(
            lat,
            lng,
            intent: placeIntent,
            distanceKm: distanceKm,
            area: area,
          );
          if (places.isEmpty) {
            _addBotNow(
              'I could not find places with those filters. Try a larger distance or another area.',
            );
          } else {
            _addBotNow(_formatPlacesMessage(places));
            _addBotNow(
              'Want to filter by distance (e.g., within 2 km) or area (e.g., RS Puram)?',
            );
          }
        } on ApiException catch (e) {
          _addBotNow("Sorry, I couldn't fetch nearby places: ${e.message}");
        } catch (_) {
          _addBotNow("Sorry, I couldn't fetch nearby places right now.");
        } finally {
          _isTyping = false;
        }
        break;

      case 'ask_theatres':
        final theatres = response['theatres'] as List<dynamic>?;
        if (theatres != null && theatres.isNotEmpty) {
          _messages.add(ChatMessageModel(
            content: message ?? 'Here are nearby theatres:',
            sender: MessageSender.bot,
            timestamp: DateTime.now(),
            messageType: MessageType.theatreList,
            extraData: {'theatres': theatres},
          ));
        } else if (message != null && message.isNotEmpty) {
          _addBotNow(message);
        } else {
          _addBotNow('I could not find nearby theatres.');
        }
        break;

      case 'ask_movies':
        final movies = response['movies'] as List<dynamic>?;
        if (movies != null && movies.isNotEmpty) {
          _messages.add(ChatMessageModel(
            content: message ?? 'Here are movies playing:',
            sender: MessageSender.bot,
            timestamp: DateTime.now(),
            messageType: MessageType.movieList,
            extraData: {
              'movies': movies,
              'theatre_name': response['theatre_name'],
            },
          ));
        } else if (message != null && message.isNotEmpty) {
          _addBotNow(message);
        } else {
          _addBotNow('No movies available right now.');
        }
        break;

      case 'ask_movie_showtimes':
        final showTimes = response['show_times'] as List<dynamic>?;
        if (showTimes != null && showTimes.isNotEmpty) {
          _messages.add(ChatMessageModel(
            content: message ?? 'Showtimes:',
            sender: MessageSender.bot,
            timestamp: DateTime.now(),
            messageType: MessageType.showtimeList,
            extraData: {
              'show_times': showTimes,
              'movie_title': response['movie_title'],
              'theatre_name': response['theatre_name'],
            },
          ));
        } else if (message != null && message.isNotEmpty) {
          _addBotNow(message);
        } else {
          _addBotNow('No showtimes available right now.');
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

  String _formatPlacesMessage(List<Map<String, dynamic>> places) {
    if (places.isEmpty) {
      return "I couldn't find places nearby.";
    }

    final topPlaces = places.take(3).toList();
    final icons = {
      'Mall': '🏬',
      'Museum': '🏛',
      'Park': '🌳',
      'Restaurant': '🍴',
      'Entertainment': '🎭',
    };

    final lines = <String>[];
    for (var i = 0; i < topPlaces.length; i++) {
      final place = topPlaces[i];
      final name = place['name'] as String? ?? 'Unknown';
      final category = place['category'] as String? ?? 'Place';
      final distance = place['distance'] as String? ?? '';
      final icon = icons[category] ?? '📍';
      final suffix = distance.isNotEmpty ? ' ($distance)' : '';
      lines.add('${i + 1}. $icon $name$suffix');
    }

    return 'Here are some places near you:\n${lines.join('\n')}';
  }

  Future<Position?> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (_) {
      return null;
    }
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
    _queueBot(
      "Want me to plan a trip around this event? Just say: plan my trip.",
      delay: 900,
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
    _historyLoaded = false;
    _greetingQueued = false;
    _resumeChecked = false;
    _resumeOffer = null;
    _lastErrorMessage = null;
    _lastFailedMessage = null;
    _recommendedSeats = [];
    _pendingEventId = null;
    _pendingQuantity = null;
    _shouldNavigateToSeats = false;
    notifyListeners();
  }

  void clearError() {
    notifyListeners();
  }

  Future<void> clearMessages() async {
    _messages.clear();
    _lastErrorMessage = null;
    _lastFailedMessage = null;
    _historyLoaded = true;
    notifyListeners();

    if (_authToken == null) return;
    try {
      await _repository.clearHistory(_authToken!);
    } catch (_) {
      // Ignore delete errors to keep UI responsive.
    }
  }
}