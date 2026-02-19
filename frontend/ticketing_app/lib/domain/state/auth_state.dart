import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthPhase { idle, loading, authenticated, error }

class AuthState extends ChangeNotifier {
  AuthPhase _phase = AuthPhase.idle;
  String? _errorMessage;
  String? _userName;
  String? _userEmail;
  bool _sessionChecked = false;

  AuthPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isAuthenticated => _phase == AuthPhase.authenticated;
  bool get isLoading => _phase == AuthPhase.loading;
  bool get sessionChecked => _sessionChecked;

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final name = prefs.getString('user_name');
    if (email != null && name != null) {
      _userEmail = email;
      _userName = name;
      _phase = AuthPhase.authenticated;
    }
    _sessionChecked = true;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    if (!_validateEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      _phase = AuthPhase.error;
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters.';
      _phase = AuthPhase.error;
      notifyListeners();
      return false;
    }

    _phase = AuthPhase.loading;
    _errorMessage = null;
    notifyListeners();

    // Simulate auth — backend has no auth endpoints; use mock session
    await Future.delayed(const Duration(milliseconds: 1200));

    final name = email.split('@').first;
    _userName = name[0].toUpperCase() + name.substring(1);
    _userEmail = email;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', _userName!);

    _phase = AuthPhase.authenticated;
    notifyListeners();
    return true;
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().length < 2) {
      _errorMessage = 'Name must be at least 2 characters.';
      _phase = AuthPhase.error;
      notifyListeners();
      return false;
    }
    if (!_validateEmail(email)) {
      _errorMessage = 'Please enter a valid email address.';
      _phase = AuthPhase.error;
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters.';
      _phase = AuthPhase.error;
      notifyListeners();
      return false;
    }
    if (password != confirmPassword) {
      _errorMessage = 'Passwords do not match.';
      _phase = AuthPhase.error;
      notifyListeners();
      return false;
    }

    _phase = AuthPhase.loading;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1400));

    _userName = name.trim();
    _userEmail = email.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', _userEmail!);
    await prefs.setString('user_name', _userName!);

    _phase = AuthPhase.authenticated;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    _userName = null;
    _userEmail = null;
    _phase = AuthPhase.idle;
    notifyListeners();
  }

  void clearError() {
    if (_phase == AuthPhase.error) _phase = AuthPhase.idle;
    _errorMessage = null;
    notifyListeners();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email.trim());
  }
}
