class DebuggingTestCase {
  final String input;
  final String expected;
  final String description;

  const DebuggingTestCase(
      {required this.input, required this.expected, required this.description});

  factory DebuggingTestCase.fromJson(Map<String, dynamic> json) =>
      DebuggingTestCase(
        input: json['input'] as String? ?? '',
        expected: json['expected'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

class DebuggingQuestion {
  final int id;
  final String title;
  final String difficulty;
  final String topic;
  final String description;
  final String buggyCode;
  final String expectedBehavior;
  final String actualBehavior;
  final List<DebuggingTestCase> tests;
  final Map<String, String> starterCode;
  final int score;

  const DebuggingQuestion({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.topic,
    required this.description,
    required this.buggyCode,
    required this.expectedBehavior,
    required this.actualBehavior,
    required this.tests,
    required this.starterCode,
    required this.score,
  });

  factory DebuggingQuestion.fromJson(Map<String, dynamic> json) =>
      DebuggingQuestion(
        id: json['id'] as int,
        title: json['title'] as String? ?? 'Debugging challenge',
        difficulty: json['difficulty'] as String? ?? 'Unknown',
        topic: json['topic'] as String? ?? 'General',
        description: json['description'] as String? ?? '',
        buggyCode: json['buggyCode'] as String? ?? '',
        expectedBehavior: json['expectedBehavior'] as String? ?? '',
        actualBehavior: json['actualBehavior'] as String? ?? '',
        tests: (json['tests'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DebuggingTestCase.fromJson)
            .toList(),
        starterCode:
            (json['starterCode'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, value.toString()),
        ),
        score: json['score'] as int? ?? 0,
      );
}
