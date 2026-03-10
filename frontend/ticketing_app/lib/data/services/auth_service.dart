import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final String baseUrl;
  final http.Client _client;

  AuthService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.baseUrl,
        _client = client ?? http.Client();

  // ── TODO 1 (DONE): Register sends JSON body matching UserRegister schema ──
  // Backend schema.UserRegister expects: { name, email, password }
  // Backend register route returns: { access_token, token_type }
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw AuthException('Connection timed out. Check your network.'),
        );

    // ── TODO 2 (DONE): Proper error parsing to avoid FormatException ──
    // If backend returns non-JSON (HTML error page), catch it gracefully.
    return _parseAuthResponse(response, name: name, email: email);
  }

  // ── TODO 3 (DONE): Login sends JSON body { email, password } ──
  // Backend login route accepts OAuth2PasswordRequestForm (form-encoded)
  // username = email, password = password
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    // OAuth2PasswordRequestForm requires application/x-www-form-urlencoded
    // with field "username" (not "email")
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'username': email,
            'password': password,
          },
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw AuthException('Connection timed out. Check your network.'),
        );

    return _parseAuthResponse(response, email: email);
  }

  // ── TODO 4 (DONE): Central response parser — never throws FormatException ──
  UserModel _parseAuthResponse(
    http.Response response, {
    String? name,
    String? email,
  }) {
    // Try to decode JSON; if it fails, show a meaningful message
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Server returned non-JSON (HTML 500 page, nginx error, etc.)
      throw AuthException(
        'Server error (${response.statusCode}). Please try again later.',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Backend returns: { access_token, token_type }
      // Construct UserModel from available data
      return UserModel(
        id: data['user_id'] as int? ?? 0,
        name: data['name'] as String? ?? name ?? '',
        email: data['email'] as String? ?? email ?? '',
        token: data['access_token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String?,
      );
    }

    // ── TODO 5 (DONE): Extract readable error from FastAPI detail field ──
    final detail = data['detail'];
    final message = detail is String
        ? detail
        : detail is List && detail.isNotEmpty
            ? (detail.first['msg'] as String? ?? 'Unknown error')
            : 'Unknown error (${response.statusCode})';

    throw AuthException(message);
  }

  Future<String> refreshAccessToken(String refreshToken) async {
    final uri = Uri.parse('$baseUrl/auth/refresh');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw AuthException('Connection timed out.'),
        );
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException('Server error (${response.statusCode})');
    }
    if (response.statusCode == 200) {
      return data['access_token'] as String;
    }
    final detail = data['detail'];
    throw AuthException(detail is String ? detail : 'Token refresh failed');
  }
}