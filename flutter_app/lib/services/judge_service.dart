import 'dart:async';

import 'package:dio/dio.dart';

import '../models/problem.dart';
import 'api_client.dart';

class JudgeService {
  final ApiClient _client;

  const JudgeService(this._client);

  Future<Map<String, dynamic>> submit({
    required String sourceCode,
    required String language,
    required List<ProblemTestCase> tests,
  }) async {
    _client.ensureConfigured();
    if (tests.isEmpty) {
      throw const ApiException('No test cases are available for this item.');
    }
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/judge',
        options: Options(headers: {
          'Idempotency-Key': DateTime.now().microsecondsSinceEpoch.toString()
        }),
        data: {
          'sourceCode': sourceCode,
          'language': language,
          'tests': tests
              .map((test) => {
                    'stdin': test.input,
                    'expected': test.expected,
                    if (test.unordered) 'unordered': true,
                  })
              .toList(),
        },
      );
      var job = response.data ?? <String, dynamic>{};
      final executionId = job['executionId'] as String?;
      if (executionId == null || executionId.isEmpty) {
        throw const ApiException('Judge API did not return an execution ID.');
      }
      final deadline = DateTime.now().add(const Duration(seconds: 65));
      while (job['state'] != 'completed' && job['state'] != 'failed') {
        if (DateTime.now().isAfter(deadline)) {
          throw const ApiException(
              'Judging timed out while waiting for the result.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final poll = await _client.dio.get<Map<String, dynamic>>(
          '/api/judge',
          queryParameters: {'id': executionId},
        );
        job = poll.data ?? <String, dynamic>{};
      }
      return job;
    } on DioException catch (error) {
      throw ApiClient.fromDio(error);
    }
  }
}
