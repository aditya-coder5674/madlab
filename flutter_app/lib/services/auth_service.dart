import 'package:dio/dio.dart';

import 'api_client.dart';

class AuthUser {
  final String id;
  final String username;
  final String email;
  final String? joinedAt;

  const AuthUser(
      {required this.id,
      required this.username,
      required this.email,
      this.joinedAt});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id']?.toString() ?? '',
        username: json['username'] as String? ?? 'CodeArena user',
        email: json['email'] as String? ?? '',
        joinedAt: json['joinedAt'] as String?,
      );
}

class AuthService {
  final ApiClient _client;

  const AuthService(this._client);

  Future<AuthUser?> currentUser() async {
    _client.ensureConfigured();
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/auth/me');
      final data = response.data ?? const <String, dynamic>{};
      if (data['authenticated'] != true ||
          data['user'] is! Map<String, dynamic>) {
        return null;
      }
      return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _client.clearSessionCookie();
        return null;
      }
      throw ApiClient.fromDio(error);
    }
  }

  Future<AuthUser> login(String identifier, String password) =>
      _authenticate('/api/auth/login', {
        'username': identifier,
        'email': identifier,
        'password': password,
      });

  Future<AuthUser> register(String username, String email, String password) =>
      _authenticate('/api/auth/register', {
        'username': username,
        'email': email,
        'password': password,
      });

  Future<AuthUser> _authenticate(String path, Map<String, dynamic> body) async {
    _client.ensureConfigured();
    try {
      final response =
          await _client.dio.post<Map<String, dynamic>>(path, data: body);
      final user = response.data?['user'];
      if (user is! Map<String, dynamic>) {
        throw const ApiException(
            'Authentication response did not include a user.');
      }
      return AuthUser.fromJson(user);
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    }
  }

  Future<void> logout() async {
    _client.ensureConfigured();
    try {
      await _client.dio.post<void>('/api/auth/logout');
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    } finally {
      await _client.clearSessionCookie();
    }
  }
}
