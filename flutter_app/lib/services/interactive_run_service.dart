import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/run_event.dart';
import 'api_client.dart';

class InteractiveRunService {
  final ApiClient _client;

  const InteractiveRunService(this._client);

  Future<InteractiveRunSession> start(
      {required String sourceCode, required String language}) async {
    _client.ensureConfigured();
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/run',
        data: {'sourceCode': sourceCode, 'language': language},
      );
      final runId = response.data?['runId'] as String?;
      if (runId == null || runId.isEmpty) {
        throw const ApiException('Run API did not return a session ID.');
      }
      return InteractiveRunSession(id: runId, events: _events(runId));
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    }
  }

  Stream<RunEvent> _events(String runId) async* {
    _client.ensureConfigured();
    try {
      final response = await _client.dio.get<ResponseBody>(
        '/api/run/$runId/events',
        options: Options(
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(minutes: 3)),
      );
      final body = response.data;
      if (body == null) throw const ApiException('Run event stream was empty.');
      var event = 'message';
      final dataLines = <String>[];
      await for (final line in body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            final decoded = jsonDecode(dataLines.join('\n'));
            yield RunEvent(event,
                decoded is Map<String, dynamic> ? decoded : {'data': decoded});
          }
          event = 'message';
          dataLines.clear();
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }
      if (dataLines.isNotEmpty) {
        final decoded = jsonDecode(dataLines.join('\n'));
        yield RunEvent(event,
            decoded is Map<String, dynamic> ? decoded : {'data': decoded});
      }
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    }
  }

  Future<void> sendInput(String runId, String data) async {
    _client.ensureConfigured();
    try {
      await _client.dio
          .post<void>('/api/run/$runId/input', data: {'data': data});
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    }
  }

  Future<void> stop(String runId) async {
    _client.ensureConfigured();
    try {
      await _client.dio.post<void>('/api/run/$runId/stop');
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    }
  }
}
