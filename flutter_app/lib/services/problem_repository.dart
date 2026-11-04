import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/debugging_question.dart';
import '../models/problem.dart';

class ProblemRepository {
  Future<List<Problem>> loadProblems() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/data/problems.json'))
            as List<dynamic>;
    return json
        .map((item) => Problem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DebuggingQuestion>> loadDebuggingQuestions() async {
    final json = jsonDecode(
            await rootBundle.loadString('assets/data/debugging_questions.json'))
        as List<dynamic>;
    return json
        .map((item) => DebuggingQuestion.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
