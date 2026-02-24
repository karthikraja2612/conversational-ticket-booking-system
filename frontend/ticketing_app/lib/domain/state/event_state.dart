import 'package:flutter/foundation.dart';
import '../../data/models/event_model.dart';
import '../../data/services/api_service.dart';

enum EventLoadState { idle, loading, loaded, error }

class EventState extends ChangeNotifier {
  final ApiService _apiService;

  List<EventModel> _events = [];
  EventLoadState _loadState = EventLoadState.idle;
  String? _errorMessage;

  EventState({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<EventModel> get events => List.unmodifiable(_events);
  EventLoadState get loadState => _loadState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadState == EventLoadState.loading;
  bool get hasEvents => _events.isNotEmpty;

  /// The first/primary event for display on home screen.
  EventModel? get primaryEvent => _events.isNotEmpty ? _events.first : null;

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
