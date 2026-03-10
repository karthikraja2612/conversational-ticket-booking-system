import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<UserModel> login(String email, String password) async {
    return await _authService.login(
      email: email,
      password: password,
    );
  }

  Future<UserModel> register(
    String name,
    String email,
    String password,
  ) async {
    return await _authService.register(
      name: name,
      email: email,
      password: password,
    );
  }

  // Future<UserModel> getMe(String token) async {
  //   return await _authService.getMe(token);
  // }
}