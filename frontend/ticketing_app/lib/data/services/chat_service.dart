import 'dart:convert';
import 'dart:async';
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
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw ChatException(data['detail'] as String? ?? 'Chat request failed');
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