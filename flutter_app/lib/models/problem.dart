class ProblemExample {
  final String input;
  final String output;
  final String? explanation;

  const ProblemExample(
      {required this.input, required this.output, this.explanation});

  factory ProblemExample.fromJson(Map<String, dynamic> json) => ProblemExample(
        input: json['i'] as String? ?? '',
        output: json['o'] as String? ?? '',
        explanation: json['e'] as String?,
      );
}

class ProblemTestCase {
  final String input;
  final String expected;
  final bool unordered;

  const ProblemTestCase(
      {required this.input, required this.expected, this.unordered = false});

  factory ProblemTestCase.fromJson(Map<String, dynamic> json) =>
      ProblemTestCase(
        input: json['i'] as String? ?? '',
        expected: json['o'] as String? ?? '',
        unordered: json['unordered'] == true,
      );
}

class Problem {
  final int id;
  final String title;
  final String difficulty;
  final List<String> tags;
  final int? acceptanceRatePercent;
  final String description;
  final List<ProblemExample> examples;
  final List<String> constraints;
  final List<ProblemTestCase> testCases;
  final Map<String, String> starterCode;

  const Problem({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.tags,
    required this.description,
    required this.examples,
    required this.constraints,
    required this.testCases,
    required this.starterCode,
    this.acceptanceRatePercent,
  });

  factory Problem.fromJson(Map<String, dynamic> json) => Problem(
        id: json['id'] as int,
        title: json['title'] as String? ?? 'Untitled problem',
        difficulty: json['difficulty'] as String? ?? 'Unknown',
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        acceptanceRatePercent: json['acceptanceRatePercent'] as int?,
        description: json['description'] as String? ?? '',
        examples: (json['examples'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ProblemExample.fromJson)
            .toList(),
        constraints: (json['constraints'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        testCases: (json['testCases'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ProblemTestCase.fromJson)
            .toList(),
        starterCode:
            (json['starterCode'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
}
