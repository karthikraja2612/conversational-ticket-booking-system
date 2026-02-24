import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<String> login(String email, String password) async {
    return await _authService.login(email, password);
  }

  Future<void> register(String name, String email, String password) async {
    await _authService.register(name, email, password);
  }

  Future<UserModel> getMe(String token) async {
    return await _authService.getMe(token);
  }
}