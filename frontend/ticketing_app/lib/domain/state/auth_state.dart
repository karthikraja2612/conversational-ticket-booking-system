import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class AuthState extends ChangeNotifier {
  // ── TODO 6 (DONE): Single AuthService instance, not re-created per call ──
  final AuthService _authService;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthState({AuthService? authService})
      : _authService = authService ?? AuthService();

  // ── Getters ──────────────────────────────────────────────────────────────
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _user!.token.isNotEmpty;
  String? get errorMessage => _errorMessage;
  String? get token => _user?.token;
  int? get userId => _user?.id;
  String get userName => _user?.name ?? '';

  /// First word of name, digits stripped, first letter capitalised.
  /// e.g. "Navanee34 Kumar" → "Navanee", "navanee34" → "Navanee"
  String get displayName {
    final raw = (_user?.name ?? '').trim();
    if (raw.isEmpty) return '';
    final firstWord = raw.split(RegExp(r'\s+')).first;
    final stripped = firstWord.replaceAll(RegExp(r'[0-9]'), '').trim();
    if (stripped.isEmpty) return '';
    return stripped[0].toUpperCase() + stripped.substring(1).toLowerCase();
  }

  // ── TODO 7 (DONE): signup validates passwords before calling API ─────────
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    // Client-side validation — avoids unnecessary network call
    if (password != confirmPassword) {
      _errorMessage = 'Passwords do not match';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }
    if (name.trim().length < 2) {
      _errorMessage = 'Name must be at least 2 characters';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      _user = user;
      await _persistSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── TODO 8 (DONE): login uses form-encoded body via AuthService ──────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Email and password are required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(
        email: email.trim(),
        password: password,
      );
      _user = user;
      await _persistSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── TODO 9 (DONE): Persist session to SharedPreferences ─────────────────
  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', user.token);
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
  }

  // ── TODO 10 (DONE): checkSession restores persisted login on app start ───
  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final id = prefs.getInt('user_id');
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');

    if (token != null && token.isNotEmpty && id != null) {
      _user = UserModel(
        id: id,
        name: name ?? '',
        email: email ?? '',
        token: token,
      );
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    notifyListeners();
  }
}