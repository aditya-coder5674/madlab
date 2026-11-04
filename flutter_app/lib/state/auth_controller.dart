import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _service;
  AuthUser? user;
  bool loading = false;
  String? error;

  AuthController(this._service);

  Future<void> restore() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _service.currentUser();
    } catch (exception) {
      user = null;
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String identifier, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _service.login(identifier, password);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _service.register(username, email, password);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _service.logout();
    } finally {
      user = null;
      loading = false;
      notifyListeners();
    }
  }
}
