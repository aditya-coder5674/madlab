import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProgressStore {
  static const _problemKey = 'codearena_local_accepted_problem_ids';
  static const _debugKey = 'codearena_local_accepted_debugging_ids';
  final FlutterSecureStorage _storage;

  const ProgressStore([this._storage = const FlutterSecureStorage()]);

  Future<Set<int>> acceptedProblemIds() async {
    final raw = await _storage.read(key: _problemKey);
    return _decodeIds(raw);
  }

  Future<Set<int>> acceptedDebuggingIds() async {
    final raw = await _storage.read(key: _debugKey);
    return _decodeIds(raw);
  }

  Future<Set<int>> _decodeIds(String? raw) async {
    if (raw == null) return <int>{};
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<int>().toSet();
    } on FormatException {
      return <int>{};
    } on TypeError {
      return <int>{};
    }
  }

  Future<void> markAccepted(int problemId) async {
    final ids = await acceptedProblemIds()
      ..add(problemId);
    await _storage.write(
        key: _problemKey, value: jsonEncode(ids.toList()..sort()));
  }

  Future<void> markDebuggingAccepted(int questionId) async {
    final ids = await acceptedDebuggingIds()
      ..add(questionId);
    await _storage.write(
        key: _debugKey, value: jsonEncode(ids.toList()..sort()));
  }
}
