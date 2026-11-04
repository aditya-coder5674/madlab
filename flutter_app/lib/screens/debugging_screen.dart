import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/debugging_question.dart';
import '../services/interactive_run_service.dart';
import '../services/judge_service.dart';
import '../services/problem_repository.dart';
import '../services/progress_store.dart';
import '../widgets/arena_widgets.dart';
import 'editor_screen.dart';

class DebuggingScreen extends StatefulWidget {
  final ProblemRepository repository;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore progressStore;

  const DebuggingScreen({
    super.key,
    required this.repository,
    required this.judgeService,
    required this.runService,
    required this.progressStore,
  });

  @override
  State<DebuggingScreen> createState() => _DebuggingScreenState();
}

class _DebuggingScreenState extends State<DebuggingScreen> {
  late final Future<List<DebuggingQuestion>> _questions;
  String _query = '';
  String _difficulty = 'All';

  @override
  void initState() {
    super.initState();
    _questions = widget.repository.loadDebuggingQuestions();
  }

  void _openQuestion(DebuggingQuestion question) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DebuggingDetailScreen(
          question: question,
          judgeService: widget.judgeService,
          runService: widget.runService,
          progressStore: widget.progressStore,
        ),
      ));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DebuggingQuestion>>(
        future: _questions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: ApiNotice(
                    message: 'Could not load debugging challenges.',
                    error: true));
          }
          if (!snapshot.hasData) {
            return const LoadingPane(label: 'Loading debugging arena');
          }
          final query = _query.trim().toLowerCase();
          final questions = snapshot.data!.where((question) {
            final queryMatch = query.isEmpty ||
                question.title.toLowerCase().contains(query) ||
                question.topic.toLowerCase().contains(query);
            final difficultyMatch =
                _difficulty == 'All' || question.difficulty == _difficulty;
            return queryMatch && difficultyMatch;
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Debugging Arena',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                        '${questions.length} of ${snapshot.data!.length} challenges',
                        style: const TextStyle(color: Color(0xFFA8BBC5))),
                    const SizedBox(height: 12),
                    if (ApiConfig.configurationError() != null)
                      const ApiNotice(
                          message:
                              'Challenges are bundled locally. Code execution requires a configured backend.'),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search challenge or topic'),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['All', 'Easy', 'Moderate', 'Hard']
                            .map((value) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(value),
                                    selected: _difficulty == value,
                                    onSelected: (_) =>
                                        setState(() => _difficulty = value),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _openQuestion(question),
                      leading: SizedBox(
                          width: 36,
                          child: Text('#${question.id}',
                              style: const TextStyle(
                                  color: Color(0xFF55DCE5),
                                  fontWeight: FontWeight.w700))),
                      title: Text(question.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${question.topic} · ${question.score} pts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: DifficultyBadge(question.difficulty),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      );
}

class DebuggingDetailScreen extends StatelessWidget {
  final DebuggingQuestion question;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore progressStore;

  const DebuggingDetailScreen({
    super.key,
    required this.question,
    required this.judgeService,
    required this.runService,
    required this.progressStore,
  });

  void _openEditor(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          debuggingQuestion: question,
          judgeService: judgeService,
          runService: runService,
          progressStore: progressStore,
        ),
      ));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(question.title,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                DifficultyBadge(question.difficulty),
                Chip(
                    label: Text(question.topic),
                    visualDensity: VisualDensity.compact)
              ]),
              const SizedBox(height: 16),
              Text(question.description,
                  style: const TextStyle(fontSize: 16, height: 1.5)),
              const SizedBox(height: 18),
              _BehaviorPanel(
                  title: 'Expected behavior',
                  body: question.expectedBehavior,
                  tint: const Color(0xFF72D7A5)),
              const SizedBox(height: 8),
              _BehaviorPanel(
                  title: 'Reported behavior',
                  body: question.actualBehavior,
                  tint: const Color(0xFFFFC46B)),
              const SizedBox(height: 18),
              const SectionHeading(title: 'Bundled checks'),
              const SizedBox(height: 8),
              ...question.tests.asMap().entries.map((entry) =>
                  _DebugTestCase(index: entry.key + 1, test: entry.value)),
              const SizedBox(height: 10),
              const ApiNotice(
                  message:
                      'These test cases are shipped by the repository and have not been independently verified as complete.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Inspect and fix in editor')),
            ]),
      );
}

class _BehaviorPanel extends StatelessWidget {
  final String title;
  final String body;
  final Color tint;

  const _BehaviorPanel(
      {required this.title, required this.body, required this.tint});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: tint, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(body, style: const TextStyle(height: 1.4)),
        ]),
      );
}

class _DebugTestCase extends StatelessWidget {
  final int index;
  final DebuggingTestCase test;

  const _DebugTestCase({required this.index, required this.test});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Case $index',
                style: const TextStyle(
                    color: Color(0xFF55DCE5), fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SelectableText('Input\n${test.input}\n\nExpected\n${test.expected}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, height: 1.4)),
            if (test.description.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(test.description,
                      style: const TextStyle(
                          color: Color(0xFFA8BBC5), fontSize: 12))),
          ]),
        ),
      );
}
