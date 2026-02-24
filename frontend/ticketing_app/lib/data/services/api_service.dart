import 'dart:convert';
import 'dart:async';
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

  ApiService({this.baseUrl = AppConstants.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  ApiException _handleError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        data['detail'] as String? ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiException(
        'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<SeatModel>> fetchSeatsStatus(int eventId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/events/$eventId/seats-status'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SeatModel.fromJson(json)).toList();
      } else {
        throw _handleError(response);
      }
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
      final response = await _client.post(
        Uri.parse('$baseUrl/events/$eventId/lock-seats'),
        headers: _authHeaders,
        body: jsonEncode({
          'user_id': userId,
          'seat_ids': seatIds,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['expires_at'] as String;
        final utcStr = raw.contains('+') || raw.endsWith('Z') ? raw : '${raw}Z';
        return DateTime.parse(utcStr).toLocal();
      } else {
        throw _handleError(response);
      }
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
      final response = await _client.post(
        Uri.parse('$baseUrl/events/$eventId/confirm-booking'),
        headers: _authHeaders,
        body: jsonEncode({
          'user_id': userId,
          'seat_ids': seatIds,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BookingModel.fromConfirmation(data, userId, eventId, seatIds);
      } else {
        throw _handleError(response);
      }
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Booking confirmation failed: $e');
    }
  }

  Future<void> processPayment(int eventId, int bookingId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/events/$eventId/process-payment?booking_id=$bookingId'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return;
      } else {
        throw _handleError(response);
      }
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Payment failed: $e');
    }
  }

  Future<List<EventModel>> fetchEvents() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/events'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EventModel.fromJson(json)).toList();
      } else {
        throw _handleError(response);
      }
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load events: $e');
    }
  }
}