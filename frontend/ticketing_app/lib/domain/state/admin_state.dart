import 'package:flutter/foundation.dart';
import '../../../data/models/venue_model.dart';
import '../../../data/models/admin_event_model.dart';
import '../../../data/services/admin_service.dart';

class AdminState extends ChangeNotifier {
  final AdminService _service;

  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  List<VenueModel> _venues = [];
  List<AdminEventModel> _events = [];
  Map<int, Map<String, dynamic>> _analyticsCache = {};

  AdminState({AdminService? service})
      : _service = service ?? AdminService();

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  List<VenueModel> get venues => List.unmodifiable(_venues);
  List<AdminEventModel> get events => List.unmodifiable(_events);
  AdminService get service => _service;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> register({required String email, required String password}) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.register(email: email, password: password);
      _isAuthenticated = true;
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _isAuthenticated = false;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Unexpected error: $e';
      _isAuthenticated = false;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.login(email: email, password: password);
      _isAuthenticated = true;
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _isAuthenticated = false;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Unexpected error: $e';
      _isAuthenticated = false;
      _setLoading(false);
      return false;
    }
  }

  void logout() {
    _service.logout();
    _isAuthenticated = false;
    _venues = [];
    _events = [];
    _analyticsCache = {};
    notifyListeners();
  }

  // ── Venues ────────────────────────────────────────────────────────────────

  Future<void> loadVenues() async {
    _setLoading(true);
    _error = null;
    try {
      _venues = await _service.listVenues();
    } on AdminException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load venues: $e';
    }
    _setLoading(false);
  }

  Future<bool> createVenue({
    required String name,
    required String location,
    required int totalRows,
    required int seatsPerRow,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final venue = await _service.createVenue(
        name: name,
        location: location,
        totalRows: totalRows,
        seatsPerRow: seatsPerRow,
      );
      _venues = [..._venues, venue];
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to create venue: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateVenue(
    int venueId, {
    String? name,
    String? location,
    int? totalRows,
    int? seatsPerRow,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _service.updateVenue(
        venueId,
        name: name,
        location: location,
        totalRows: totalRows,
        seatsPerRow: seatsPerRow,
      );
      _venues = [
        for (final v in _venues)
          if (v.id == venueId) updated else v
      ];
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to update venue: $e';
      _setLoading(false);
      return false;
    }
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> loadEvents() async {
    _setLoading(true);
    _error = null;
    try {
      _events = await _service.listEvents();
    } on AdminException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load events: $e';
    }
    _setLoading(false);
  }

  Future<bool> createEvent({
    required String name,
    required int venueId,
    required DateTime eventDate,
    required double basePrice,
    String? imageUrl,
    String? eventType,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final event = await _service.createEvent(
        name: name,
        venueId: venueId,
        eventDate: eventDate,
        basePrice: basePrice,
        imageUrl: imageUrl,
        eventType: eventType,
      );
      _events = [..._events, event];
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to create event: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateEvent(
    int eventId, {
    String? name,
    DateTime? eventDate,
    double? basePrice,
    String? imageUrl,
    String? eventType,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _service.updateEvent(
        eventId,
        name: name,
        eventDate: eventDate,
        basePrice: basePrice,
        imageUrl: imageUrl,
        eventType: eventType,
      );
      _events = [
        for (final e in _events)
          if (e.id == eventId) updated else e
      ];
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to update event: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> togglePublish(AdminEventModel event) async {
    _error = null;
    try {
      if (event.eventType == 'movie') {
        if (event.isPublished) {
          await _service.unpublishMovieConfig(event.id);
        } else {
          await _service.publishMovieConfig(event.id);
        }
      } else {
        if (event.isPublished) {
          await _service.unpublishEvent(event.id);
        } else {
          await _service.publishEvent(event.id);
        }
      }
      _events = [
        for (final e in _events)
          if (e.id == event.id)
            AdminEventModel(
              id: e.id,
              name: e.name,
              venueId: e.venueId,
              eventDate: e.eventDate,
              basePrice: e.basePrice,
              status: event.isPublished ? 'draft' : 'published',
              imageUrl: e.imageUrl,
              createdAt: e.createdAt,
              eventType: e.eventType,
              showTimes: e.showTimes,
              startDate: e.startDate,
              endDate: e.endDate,
              isDynamic: e.isDynamic,
            )
          else
            e
      ];
      notifyListeners();
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update event status: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createMovieConfig({
    required String movieTitle,
    int? movieId,
    required int venueId,
    required String theatreName,
    String? theatreLocation,
    required List<String> showTimes,
    required DateTime startDate,
    required DateTime endDate,
    required double basePrice,
    Map<String, double>? pricingOverrides,
    String? imageUrl,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final config = await _service.createMovieConfig(
        movieTitle: movieTitle,
        movieId: movieId,
        venueId: venueId,
        theatreName: theatreName,
        theatreLocation: theatreLocation,
        showTimes: showTimes,
        startDate: startDate,
        endDate: endDate,
        basePrice: basePrice,
        pricingOverrides: pricingOverrides,
        imageUrl: imageUrl,
      );
      _events = [..._events, config];
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to create movie config: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateMovieConfig(
    int configId, {
    String? movieTitle,
    int? movieId,
    int? venueId,
    String? theatreName,
    String? theatreLocation,
    List<String>? showTimes,
    DateTime? startDate,
    DateTime? endDate,
    double? basePrice,
    Map<String, double>? pricingOverrides,
    String? imageUrl,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _service.updateMovieConfig(
        configId,
        movieTitle: movieTitle,
        movieId: movieId,
        venueId: venueId,
        theatreName: theatreName,
        theatreLocation: theatreLocation,
        showTimes: showTimes,
        startDate: startDate,
        endDate: endDate,
        basePrice: basePrice,
        pricingOverrides: pricingOverrides,
        imageUrl: imageUrl,
      );
      _events = [
        for (final e in _events)
          if (e.id == configId) updated else e
      ];
      _setLoading(false);
      return true;
    } on AdminException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to update movie config: $e';
      _setLoading(false);
      return false;
    }
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAnalytics(int eventId) async {
    if (_analyticsCache.containsKey(eventId)) {
      return _analyticsCache[eventId];
    }
    _error = null;
    try {
      final data = await _service.getEventAnalytics(eventId);
      _analyticsCache[eventId] = data;
      notifyListeners();
      return data;
    } on AdminException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to load analytics: $e';
      notifyListeners();
      return null;
    }
  }

  Map<String, dynamic>? getCachedAnalytics(int eventId) =>
      _analyticsCache[eventId];
}
