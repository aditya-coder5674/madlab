import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/problem.dart';
import '../services/problem_repository.dart';
import '../state/auth_controller.dart';
import '../widgets/arena_widgets.dart';

class HomeScreen extends StatelessWidget {
  final ProblemRepository repository;
  final AuthController authController;
  final VoidCallback onProblems;
  final VoidCallback onEditor;
  final VoidCallback onDebugging;
  final VoidCallback onLeaderboard;
  final VoidCallback onProfile;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.authController,
    required this.onProblems,
    required this.onEditor,
    required this.onDebugging,
    required this.onLeaderboard,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: authController,
        builder: (context, _) => FutureBuilder<List<Problem>>(
          future: repository.loadProblems(),
          builder: (context, snapshot) {
            final problems = snapshot.data ?? const <Problem>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10232F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF294350)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: const Color(0xFF183B45),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.terminal,
                                color: Color(0xFF55DCE5)),
                          ),
                          const SizedBox(width: 12),
                          const Text('CODEARENA',
                              style: TextStyle(
                                  color: Color(0xFF55DCE5),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4)),
                        ]),
                        const SizedBox(height: 22),
                        Text(
                          authController.user == null
                              ? 'Practice with purpose.'
                              : 'Welcome back, ${authController.user!.username}.',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Work through the problem bank, edit code, and send real runs to a configured CodeArena backend.',
                          style:
                              TextStyle(color: Color(0xFFA8BBC5), height: 1.45),
                        ),
                        const SizedBox(height: 18),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          FilledButton.icon(
                            key: const ValueKey('home-problems'),
                            onPressed: onProblems,
                            icon: const Icon(Icons.code),
                            label: const Text('Problems'),
                          ),
                          OutlinedButton.icon(
                              onPressed: onEditor,
                              icon: const Icon(Icons.terminal),
                              label: const Text('Compiler')),
                        ]),
                      ]),
                ),
                const SizedBox(height: 14),
                if (ApiConfig.configurationError() != null)
                  const ApiNotice(
                      message:
                          'Backend URL is not set. Browse bundled content; sign-in, Run, and Submit need API_BASE_URL.'),
                const SizedBox(height: 18),
                const SectionHeading(
                    title: 'Your workspace', trailing: 'Native app'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _Metric(
                          label: 'Problems',
                          value: snapshot.hasData ? '${problems.length}' : '…',
                          icon: Icons.code)),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: _Metric(
                          label: 'Languages',
                          value: '5',
                          icon: Icons.data_object)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _ActionTile(
                          title: 'Debugging Arena',
                          subtitle: 'Find the bug',
                          icon: Icons.bug_report_outlined,
                          onTap: onDebugging)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _ActionTile(
                          title: 'Leaderboard',
                          subtitle: 'Data status',
                          icon: Icons.leaderboard_outlined,
                          onTap: onLeaderboard)),
                ]),
                const SizedBox(height: 10),
                _ActionTile(
                    title: 'Profile & account',
                    subtitle: 'Sign in or view local progress',
                    icon: Icons.person_outline,
                    onTap: onProfile),
                const SizedBox(height: 24),
                SectionHeading(
                    title: 'From the problem bank',
                    trailing: '${problems.length} entries'),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const LoadingPane(label: 'Loading bundled problems')
                else if (snapshot.hasError)
                  const ApiNotice(
                      message: 'Bundled problem data could not be loaded.',
                      error: true)
                else
                  ...problems.take(3).map((problem) =>
                      _FeaturedProblem(problem: problem, onTap: onProblems)),
                const SizedBox(height: 6),
                TextButton.icon(
                    onPressed: onProblems,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Browse all problems')),
              ],
            );
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF55DCE5), size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 20)),
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFFA8BBC5), fontSize: 12)),
                ])),
          ]),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: const Color(0xFF55DCE5)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFFA8BBC5), fontSize: 12)),
                  ])),
              const Icon(Icons.chevron_right, size: 18),
            ]),
          ),
        ),
      );
}

class _FeaturedProblem extends StatelessWidget {
  final Problem problem;
  final VoidCallback onTap;

  const _FeaturedProblem({required this.problem, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: Text('#${problem.id}',
              style: const TextStyle(
                  color: Color(0xFF55DCE5), fontWeight: FontWeight.w700)),
          title:
              Text(problem.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(problem.tags.take(2).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: DifficultyBadge(problem.difficulty),
        ),
      );
}
