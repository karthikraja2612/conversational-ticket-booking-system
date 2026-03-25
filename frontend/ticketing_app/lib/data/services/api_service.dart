import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/event_model.dart';
import '../models/seat_model.dart';
import '../models/booking_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.baseUrl,
        _client = client ?? http.Client();

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Runs [fn] once; on SocketException or TimeoutException retries once after
  /// a 600 ms back-off so a single dropped packet doesn't surface as an error.
  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on SocketException {
      await Future.delayed(const Duration(milliseconds: 600));
      return await fn();
    } on TimeoutException {
      await Future.delayed(const Duration(milliseconds: 600));
      return await fn();
    }
  }

  ApiException _handleError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      String message;
      if (data is Map<String, dynamic>) {
        final backendMessage = data['message'];
        final detail = data['detail'];
        if (backendMessage is String && backendMessage.isNotEmpty) {
          message = backendMessage;
        } else if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          // Pydantic 422 returns detail as list of validation errors
          final first = detail.first;
          if (first is Map) {
            message = first['msg'] as String? ?? 'Validation error (${response.statusCode})';
          } else {
            message = 'Validation error (${response.statusCode})';
          }
        } else {
          message = 'Request failed (${response.statusCode})';
        }
      } else {
        message = 'Request failed (${response.statusCode})';
      }
      if (response.statusCode == 401) {
        message = 'Session expired. Please log in again.';
      }
      return ApiException(message, statusCode: response.statusCode);
    } catch (_) {
      final fallback = response.statusCode == 401
          ? 'Session expired. Please log in again.'
          : 'Request failed (${response.statusCode})';
      return ApiException(
        fallback,
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<SeatModel>> fetchSeatsStatus(int eventId) async {
    try {
      final response = await _withRetry(() => _client
          .get(
            Uri.parse('$baseUrl/events/$eventId/seats-status'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SeatModel.fromJson(json)).toList();
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchActiveBooking() async {
    try {
      final response = await _withRetry(() => _client
          .get(
            Uri.parse('$baseUrl/bookings/active'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['active'] == true) return data;
        return null;
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<DateTime> lockSeats(int eventId, int userId, List<int> seatIds) async {
    try {
      final response = await _withRetry(() => _client.post(
        Uri.parse('$baseUrl/events/$eventId/lock-seats'),
        headers: _authHeaders,
        body: jsonEncode({
          'seat_ids': seatIds,
        }),
      ).timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['expires_at'] as String;
        final utcStr = raw.contains('+') || raw.endsWith('Z') ? raw : '${raw}Z';
        return DateTime.parse(utcStr).toLocal();
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to lock seats: $e');
    }
  }

  Future<BookingModel> confirmBooking(int eventId, int userId, List<int> seatIds) async {
    try {
      final response = await _withRetry(() => _client.post(
        Uri.parse('$baseUrl/events/$eventId/confirm-booking'),
        headers: _authHeaders,
        body: jsonEncode({
          'seat_ids': seatIds,
        }),
      ).timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BookingModel.fromConfirmation(data, userId, eventId, seatIds);
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Booking confirmation failed: $e');
    }
  }

  Future<void> processPayment(int bookingId, {bool forceFail = false}) async {
    try {
      final uri = Uri.parse('$baseUrl/bookings/$bookingId/process-payment').replace(
        queryParameters: forceFail ? {'force_fail': 'true'} : null,
      );
      final response = await _withRetry(() => _client.post(
        uri,
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        return;
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Payment failed: $e');
    }
  }

  Future<BookingModel> cancelBooking(int bookingId) async {
    try {
      final response = await _withRetry(() => _client.post(
        Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BookingModel.fromJson(data);
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Cancellation failed: $e');
    }
  }

  Future<List<EventModel>> fetchEvents() async {
    try {
      final response = await _withRetry(() => _client
          .get(
            Uri.parse('$baseUrl/events'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EventModel.fromJson(json)).toList();
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load events: $e');
    }
  }

  Future<Map<String, dynamic>> createMovieEventInstance({
    required int configId,
    required DateTime showDate,
    required String showTime,
  }) async {
    try {
      final response = await _withRetry(() => _client
          .post(
            Uri.parse('$baseUrl/movies/event-instance'),
            headers: _authHeaders,
            body: jsonEncode({
              'config_id': configId,
              'show_date': showDate.toIso8601String(),
              'show_time': showTime,
            }),
          )
          .timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw _handleError(response);
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to create movie event: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchNearbyPlaces(
    double lat,
    double lng, {
    String? intent,
    double? distanceKm,
    String? area,
  }) async {
    try {
      final params = {
        'lat': lat.toString(),
        'lng': lng.toString(),
      };
      if (intent != null && intent.isNotEmpty) {
        params['intent'] = intent;
      }
      if (distanceKm != null) {
        params['distance_km'] = distanceKm.toString();
      }
      if (area != null && area.isNotEmpty) {
        params['area'] = area;
      }

      final uri = Uri.parse('$baseUrl/places/nearby').replace(
        queryParameters: params,
      );

      final response = await _withRetry(() => _client
          .get(
            uri,
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load nearby places: $e');
    }
  }

  Future<Map<String, dynamic>> planTripFromBooking(
    int bookingId, {
    String? intent,
    bool refresh = false,
  }) async {
    try {
      final response = await _withRetry(() => _client
          .post(
            Uri.parse('$baseUrl/trip/plan-from-booking'),
            headers: _authHeaders,
            body: jsonEncode({
              'booking_id': bookingId,
              'intent': intent,
              'refresh': refresh,
            }),
          )
          .timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        return {};
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to plan trip: $e');
    }
  }

  Future<List<BookingModel>> fetchMyBookings({int limit = 50}) async {
    try {
      final uri = Uri.parse('$baseUrl/users/me/bookings').replace(
        queryParameters: {'limit': limit.toString()},
      );
      final response = await _withRetry(() => _client
          .get(
            uri,
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw _handleError(response);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load bookings: $e');
    }
  }
}