import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../services/interactive_run_service.dart';
import '../services/judge_service.dart';
import '../services/progress_store.dart';
import '../widgets/arena_widgets.dart';
import 'editor_screen.dart';

class ProblemDetailScreen extends StatelessWidget {
  final Problem problem;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore progressStore;

  const ProblemDetailScreen({
    super.key,
    required this.problem,
    required this.judgeService,
    required this.runService,
    required this.progressStore,
  });

  void _openEditor(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          problem: problem,
          judgeService: judgeService,
          runService: runService,
          progressStore: progressStore,
        ),
      ));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('#${problem.id} ${problem.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DifficultyBadge(problem.difficulty),
                    ...problem.tags.map((tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact)),
                  ]),
              const SizedBox(height: 16),
              Text(problem.description,
                  style: const TextStyle(fontSize: 16, height: 1.5)),
              if (problem.examples.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionHeading(title: 'Examples'),
                const SizedBox(height: 8),
                ...problem.examples.asMap().entries.map((entry) =>
                    _ExampleBlock(index: entry.key + 1, example: entry.value)),
              ],
              if (problem.constraints.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionHeading(title: 'Constraints'),
                const SizedBox(height: 6),
                ...problem.constraints.map((constraint) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ',
                                style: TextStyle(color: Color(0xFF55DCE5))),
                            Expanded(
                                child: Text(constraint,
                                    style: const TextStyle(
                                        color: Color(0xFFA8BBC5)))),
                          ]),
                    )),
              ],
              const SizedBox(height: 18),
              const ApiNotice(
                  message:
                      'Problem text and test cases are copied from the repository. Its README notes that some cases are incomplete or not independently verified.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Open in editor')),
            ]),
      );
}

class _ExampleBlock extends StatelessWidget {
  final int index;
  final ProblemExample example;

  const _ExampleBlock({required this.index, required this.example});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF10232F),
            borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Example $index',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _DataLine(label: 'Input', value: example.input),
          const SizedBox(height: 7),
          _DataLine(label: 'Output', value: example.output),
          if (example.explanation != null) ...[
            const SizedBox(height: 7),
            _DataLine(label: 'Note', value: example.explanation!),
          ],
        ]),
      );
}

class _DataLine extends StatelessWidget {
  final String label;
  final String value;

  const _DataLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 54,
            child: Text(label,
                style:
                    const TextStyle(color: Color(0xFF55DCE5), fontSize: 12))),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, height: 1.4))),
      ]);
}
