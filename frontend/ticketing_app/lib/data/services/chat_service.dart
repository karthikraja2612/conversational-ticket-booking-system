import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class ChatException implements Exception {
  final String message;
  ChatException(this.message);
  @override
  String toString() => message;
}

class ChatService {
  final String baseUrl;
  final http.Client _client;

  ChatService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.baseUrl,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> sendMessage(String message, String token) async {
    try {
      debugPrint('[ChatService] POST /chat message length=${message.length}');
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[ChatService] response ok');
        return decoded;
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as String? ?? data['detail'] as String? ?? 'Chat request failed';
        final finalMessage = response.statusCode == 401
            ? 'Session expired. Please log in again.'
            : message;
        throw ChatException(finalMessage);
      }
    } on ChatException {
      rethrow;
    } on TimeoutException {
      throw ChatException('Request timed out.');
    } catch (e) {
      throw ChatException('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String token, {int limit = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl/chat/history').replace(
        queryParameters: {'limit': limit.toString()},
      );
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as String? ?? data['detail'] as String? ?? 'History request failed';
        final finalMessage = response.statusCode == 401
            ? 'Session expired. Please log in again.'
            : message;
        throw ChatException(finalMessage);
      }
    } on ChatException {
      rethrow;
    } on TimeoutException {
      throw ChatException('Request timed out.');
    } catch (e) {
      throw ChatException('Network error: $e');
    }
  }

  Future<void> clearHistory(String token) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/chat/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return;
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as String? ?? data['detail'] as String? ?? 'Clear chat failed';
        throw ChatException(message);
      }
    } on ChatException {
      rethrow;
    } on TimeoutException {
      throw ChatException('Request timed out.');
    } catch (e) {
      throw ChatException('Network error: $e');
    }
  }
}