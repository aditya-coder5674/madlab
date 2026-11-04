import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/interactive_run_service.dart';
import '../services/judge_service.dart';
import '../services/problem_repository.dart';
import '../services/progress_store.dart';
import '../state/auth_controller.dart';
import 'debugging_screen.dart';
import 'editor_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'problems_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  final ApiClient apiClient;
  final AuthController authController;
  final ProblemRepository problemRepository;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore progressStore;

  const AppShell({
    super.key,
    required this.apiClient,
    required this.authController,
    required this.problemRepository,
    required this.judgeService,
    required this.runService,
    required this.progressStore,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final Future<void> _authRestore;

  @override
  void initState() {
    super.initState();
    _authRestore = widget.authController.restore();
  }

  void _openProfile() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          authController: widget.authController,
          progressStore: widget.progressStore,
        ),
      ));

  void _openLeaderboard() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LeaderboardScreen(),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 2
          ? null
          : AppBar(
              title: const _BrandTitle(),
              actions: [
                IconButton(
                    tooltip: 'Leaderboard',
                    onPressed: _openLeaderboard,
                    icon: const Icon(Icons.leaderboard_outlined)),
                IconButton(
                    tooltip: 'Profile and sign in',
                    onPressed: _openProfile,
                    icon: const Icon(Icons.account_circle_outlined)),
              ],
            ),
      body: FutureBuilder<void>(
        future: _authRestore,
        builder: (context, snapshot) => IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              repository: widget.problemRepository,
              authController: widget.authController,
              onProblems: () => setState(() => _selectedIndex = 1),
              onEditor: () => setState(() => _selectedIndex = 2),
              onDebugging: () => setState(() => _selectedIndex = 3),
              onLeaderboard: _openLeaderboard,
              onProfile: _openProfile,
            ),
            ProblemsScreen(
                repository: widget.problemRepository,
                judgeService: widget.judgeService,
                runService: widget.runService,
                progressStore: widget.progressStore),
            EditorScreen(
                judgeService: widget.judgeService,
                runService: widget.runService),
            DebuggingScreen(
                repository: widget.problemRepository,
                judgeService: widget.judgeService,
                runService: widget.runService,
                progressStore: widget.progressStore),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.code_outlined),
              selectedIcon: Icon(Icons.code),
              label: 'Problems'),
          NavigationDestination(
              icon: Icon(Icons.terminal_outlined),
              selectedIcon: Icon(Icons.terminal),
              label: 'Editor'),
          NavigationDestination(
              icon: Icon(Icons.bug_report_outlined),
              selectedIcon: Icon(Icons.bug_report),
              label: 'Debug'),
        ],
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) => RichText(
        text: const TextSpan(
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          children: [
            TextSpan(text: 'Code'),
            TextSpan(text: 'Arena', style: TextStyle(color: Color(0xFF55DCE5)))
          ],
        ),
      );
}
