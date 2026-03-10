import 'package:flutter/foundation.dart';
import '../../data/models/event_model.dart';
import '../../data/services/api_service.dart';

enum EventLoadState { idle, loading, loaded, error }

class EventState extends ChangeNotifier {
  final ApiService _apiService;

  List<EventModel> _events = [];
  EventModel? _selectedEvent;
  EventLoadState _loadState = EventLoadState.idle;
  String? _errorMessage;

  EventState({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<EventModel> get events => List.unmodifiable(_events);
  EventLoadState get loadState => _loadState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadState == EventLoadState.loading;
  bool get hasEvents => _events.isNotEmpty;

  /// Returns the manually selected event first, then falls back to first in list.
  EventModel? get primaryEvent => _selectedEvent ?? (_events.isNotEmpty ? _events.first : null);

  /// Set the event selected by the user (e.g. from chatbot event card).
  void setSelectedEvent(EventModel event) {
    _selectedEvent = event;
    notifyListeners();
  }

  Future<void> fetchEvents() async {
    if (_loadState == EventLoadState.loading) return;
    _loadState = EventLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _apiService.fetchEvents();
      _loadState = EventLoadState.loaded;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _loadState = EventLoadState.error;
      // Keep stale data if any
    }
    notifyListeners();
  }
}
