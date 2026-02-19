import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
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
  final http.Client _client = http.Client();

  ApiService({this.baseUrl = AppConstants.baseUrl});

  Future<List<SeatModel>> fetchSeatsStatus(int eventId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/events/$eventId/seats-status'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SeatModel.fromJson(json)).toList();
      } else {
        throw _handleError(response);
      }
    } on TimeoutException {
      throw ApiException('Connection timed out. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<DateTime> lockSeats(int eventId, int userId, List<int> seatIds) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/events/$eventId/lock-seats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'seat_ids': seatIds,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend uses datetime.utcnow() — no timezone marker in string.
        // Append 'Z' to force UTC parsing, then convert to device local time.
        final raw = data['expires_at'] as String;
        final utcStr = raw.contains('+') || raw.endsWith('Z') ? raw : '${raw}Z';
        return DateTime.parse(utcStr).toLocal();
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to lock seats: $e');
    }
  }

  Future<BookingModel> confirmBooking(int eventId, int userId, List<int> seatIds) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/events/$eventId/confirm-booking'),
        headers: {'Content-Type': 'application/json'},
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
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Booking confirmation failed: $e');
    }
  }

  Future<void> processPayment(int eventId, int bookingId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/events/$eventId/process-payment?booking_id=$bookingId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw _handleError(response);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Payment processing failed: $e');
    }
  }

  ApiException _handleError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return ApiException(body['detail'] ?? 'Unknown error occurred', statusCode: response.statusCode);
    } catch (_) {
      return ApiException('Server error: ${response.statusCode}', statusCode: response.statusCode);
    }
  }
}