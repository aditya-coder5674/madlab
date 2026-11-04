import 'package:flutter_test/flutter_test.dart';

import 'package:codearena/services/problem_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled data preserves all source problems and debugging questions',
      () async {
    final repository = ProblemRepository();
    final problems = await repository.loadProblems();
    final debugging = await repository.loadDebuggingQuestions();

    expect(problems, hasLength(100));
    expect(problems.first.title, 'Two Sum');
    expect(problems.last.title, 'Largest Rectangle in Histogram');
    expect(problems.first.testCases, isNotEmpty);
    expect(problems.first.starterCode.keys,
        containsAll(['python', 'javascript', 'java', 'cpp', 'c']));
    expect(debugging, hasLength(100));
    expect(debugging.first.id, 101);
    expect(debugging.last.id, 200);
    expect(debugging.first.tests, isNotEmpty);
  });
}
