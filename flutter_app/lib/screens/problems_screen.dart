import 'package:flutter/material.dart';

import '../models/problem.dart';
import '../services/interactive_run_service.dart';
import '../services/judge_service.dart';
import '../services/problem_repository.dart';
import '../services/progress_store.dart';
import '../widgets/arena_widgets.dart';
import 'problem_detail_screen.dart';

class ProblemsScreen extends StatefulWidget {
  final ProblemRepository repository;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore progressStore;

  const ProblemsScreen({
    super.key,
    required this.repository,
    required this.judgeService,
    required this.runService,
    required this.progressStore,
  });

  @override
  State<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends State<ProblemsScreen> {
  late final Future<List<Problem>> _problems;
  String _query = '';
  String _difficulty = 'All';

  @override
  void initState() {
    super.initState();
    _problems = widget.repository.loadProblems();
  }

  bool _matches(Problem problem) {
    final normalizedQuery = _query.trim().toLowerCase();
    final matchesText = normalizedQuery.isEmpty ||
        problem.title.toLowerCase().contains(normalizedQuery) ||
        problem.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
    final matchesDifficulty = _difficulty == 'All' ||
        (_difficulty == 'Medium' && problem.difficulty == 'Medium') ||
        problem.difficulty == _difficulty;
    return matchesText && matchesDifficulty;
  }

  void _openProblem(Problem problem) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProblemDetailScreen(
          problem: problem,
          judgeService: widget.judgeService,
          runService: widget.runService,
          progressStore: widget.progressStore,
        ),
      ));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Problem>>(
        future: _problems,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: ApiNotice(
                    message: 'Could not load the bundled problem bank.',
                    error: true));
          }
          if (!snapshot.hasData) {
            return const LoadingPane(label: 'Loading problem bank');
          }
          final problems = snapshot.data!.where(_matches).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text('Problem library',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800))),
                  Text('${problems.length} / ${snapshot.data!.length}',
                      style: const TextStyle(color: Color(0xFFA8BBC5))),
                ]),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search title or topic'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['All', 'Easy', 'Medium', 'Hard']
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
              child: problems.isEmpty
                  ? const Center(child: Text('No problems match this search.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      itemCount: problems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final problem = problems[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openProblem(problem),
                            leading: SizedBox(
                                width: 34,
                                child: Text('#${problem.id}',
                                    style: const TextStyle(
                                        color: Color(0xFF55DCE5),
                                        fontWeight: FontWeight.w700))),
                            title: Text(problem.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(problem.tags.join(' · '),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            trailing: DifficultyBadge(problem.difficulty),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      );
}
