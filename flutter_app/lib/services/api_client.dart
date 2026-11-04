import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static const _cookieStorageKey = 'codearena_session_cookie';
  final FlutterSecureStorage _secureStorage;
  late final Dio dio;

  ApiClient({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ));
    dio.interceptors
        .add(_SessionCookieInterceptor(_secureStorage, _cookieStorageKey));
  }

  void ensureConfigured() {
    final error = ApiConfig.configurationError();
    if (error != null) throw ApiException(error);
  }

  Future<void> clearSessionCookie() =>
      _secureStorage.delete(key: _cookieStorageKey);

  static ApiException fromDio(DioException error) {
    final data = error.response?.data;
    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : error.response?.statusCode == 500
            ? 'The backend returned HTTP 500. Check the deployment logs and API configuration.'
            : error.response?.statusCode != null
                ? 'Backend request failed (HTTP ${error.response!.statusCode}).'
                : 'Could not reach the backend. Check the URL and network connection.';
    return ApiException(message, statusCode: error.response?.statusCode);
  }
}

class _SessionCookieInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final String _storageKey;

  _SessionCookieInterceptor(this._storage, this._storageKey);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final cookie = await _storage.read(key: _storageKey);
      if (cookie != null && cookie.isNotEmpty) {
        options.headers['Cookie'] = cookie;
      }
      handler.next(options);
    } catch (error) {
      handler.reject(DioException(
          requestOptions: options,
          error: error,
          message: 'Could not read the secure session cookie.'));
    }
  }

  @override
  Future<void> onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    try {
      final cookies = response.headers.map['set-cookie'] ?? const <String>[];
      for (final cookie in cookies) {
        if (!cookie.startsWith('codearena_session=')) continue;
        final pair = cookie.split(';').first.trim();
        if (RegExp(r'Max-Age=0(?:;|$)', caseSensitive: false)
            .hasMatch(cookie)) {
          await _storage.delete(key: _storageKey);
        } else {
          await _storage.write(key: _storageKey, value: pair);
        }
      }
      handler.next(response);
    } catch (error) {
      handler.reject(DioException(
          requestOptions: response.requestOptions,
          error: error,
          message: 'Could not securely save the session cookie.'));
    }
  }
}
