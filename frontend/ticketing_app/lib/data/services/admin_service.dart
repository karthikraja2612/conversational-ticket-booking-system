import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/venue_model.dart';
import '../models/admin_event_model.dart';

class AdminException implements Exception {
  final String message;
  final int? statusCode;
  AdminException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class AdminService {
  final String baseUrl;
  final http.Client _client;
  String? _adminToken;

  AdminService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.baseUrl,
        _client = client ?? http.Client();

  void setToken(String? token) => _adminToken = token;
  String? get token => _adminToken;
  bool get isLoggedIn => _adminToken != null && _adminToken!.isNotEmpty;

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_adminToken != null) 'Authorization': 'Bearer $_adminToken',
      };

  AdminException _handleError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminException(
        data['detail'] as String? ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return AdminException(
        'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String> register({
    required String email,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/admin/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      _adminToken = token;
      return token;
    }
    throw _handleError(response);
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/admin/login'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': email, 'password': password},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      _adminToken = token;
      return token;
    }
    throw _handleError(response);
  }

  void logout() => _adminToken = null;

  // ── Venues ────────────────────────────────────────────────────────────────

  Future<List<VenueModel>> listVenues() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/admin/venues'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => VenueModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw _handleError(response);
  }

  Future<VenueModel> createVenue({
    required String name,
    required String location,
    required int totalRows,
    required int seatsPerRow,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/admin/venues'),
          headers: _authHeaders,
          body: jsonEncode({
            'name': name,
            'location': location,
            'total_rows': totalRows,
            'seats_per_row': seatsPerRow,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return VenueModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _handleError(response);
  }

  Future<VenueModel> updateVenue(
    int venueId, {
    String? name,
    String? location,
    int? totalRows,
    int? seatsPerRow,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (location != null) body['location'] = location;
    if (totalRows != null) body['total_rows'] = totalRows;
    if (seatsPerRow != null) body['seats_per_row'] = seatsPerRow;

    final response = await _client
        .put(
          Uri.parse('$baseUrl/admin/venues/$venueId'),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return VenueModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _handleError(response);
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<List<AdminEventModel>> listEvents() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/admin/events'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((j) => AdminEventModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(response);
  }

  Future<AdminEventModel> createEvent({
    required String name,
    required int venueId,
    required DateTime eventDate,
    required double basePrice,
    String? imageUrl,
    String? eventType,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'venue_id': venueId,
      'event_date': eventDate.toIso8601String(),
      'base_price': basePrice,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) body['image_url'] = imageUrl;
    if (eventType != null && eventType.isNotEmpty) body['event_type'] = eventType;

    final response = await _client
        .post(
          Uri.parse('$baseUrl/admin/events'),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AdminEventModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _handleError(response);
  }

  Future<AdminEventModel> updateEvent(
    int eventId, {
    String? name,
    DateTime? eventDate,
    double? basePrice,
    String? imageUrl,
    String? eventType,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (eventDate != null) body['event_date'] = eventDate.toIso8601String();
    if (basePrice != null) body['base_price'] = basePrice;
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (eventType != null && eventType.isNotEmpty) body['event_type'] = eventType;

    final response = await _client
        .put(
          Uri.parse('$baseUrl/admin/events/$eventId'),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return AdminEventModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _handleError(response);
  }

  Future<void> publishEvent(int eventId) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/admin/events/$eventId/publish'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) throw _handleError(response);
  }

  Future<void> unpublishEvent(int eventId) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/admin/events/$eventId/unpublish'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) throw _handleError(response);
  }

  Future<AdminEventModel> createMovieConfig({
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
    final body = <String, dynamic>{
      'movie_title': movieTitle,
      'venue_id': venueId,
      'theatre_name': theatreName,
      'show_times': showTimes,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'base_price': basePrice,
    };
    if (movieId != null) body['movie_id'] = movieId;
    if (theatreLocation != null) body['theatre_location'] = theatreLocation;
    if (pricingOverrides != null && pricingOverrides.isNotEmpty) {
      body['pricing_overrides'] = pricingOverrides;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) body['image_url'] = imageUrl;

    final response = await _client
        .post(
          Uri.parse('$baseUrl/admin/events/movie-configs'),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AdminEventModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _handleError(response);
  }

  Future<AdminEventModel> updateMovieConfig(
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
    final body = <String, dynamic>{};
    if (movieTitle != null) body['movie_title'] = movieTitle;
    if (movieId != null) body['movie_id'] = movieId;
    if (venueId != null) body['venue_id'] = venueId;
    if (theatreName != null) body['theatre_name'] = theatreName;
    if (theatreLocation != null) body['theatre_location'] = theatreLocation;
    if (showTimes != null) body['show_times'] = showTimes;
    if (startDate != null) body['start_date'] = startDate.toIso8601String();
    if (endDate != null) body['end_date'] = endDate.toIso8601String();
    if (basePrice != null) body['base_price'] = basePrice;
    if (pricingOverrides != null) body['pricing_overrides'] = pricingOverrides;
    if (imageUrl != null) body['image_url'] = imageUrl;

    final response = await _client
        .put(
          Uri.parse('$baseUrl/admin/events/movie-configs/$configId'),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return AdminEventModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _handleError(response);
  }

  Future<void> publishMovieConfig(int configId) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/admin/events/movie-configs/$configId/publish'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) throw _handleError(response);
  }

  Future<void> unpublishMovieConfig(int configId) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/admin/events/movie-configs/$configId/unpublish'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) throw _handleError(response);
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEventAnalytics(int eventId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/admin/events/$eventId/analytics'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _handleError(response);
  }
}
