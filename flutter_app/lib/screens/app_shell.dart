import 'package:flutter/material.dart';

import '../config/api_config.dart';
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
  String? _backendError;
  bool _checkingBackend = true;

  @override
  void initState() {
    super.initState();
    _authRestore = widget.authController.restore();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() {
      _checkingBackend = true;
      _backendError = null;
    });
    try {
      await widget.apiClient.checkHealth();
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _backendError = 'Could not reach ${ApiConfig.healthUrl}: $exception';
      });
    } finally {
      if (mounted) setState(() => _checkingBackend = false);
    }
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
      body: Column(
        children: [
          if (_checkingBackend || _backendError != null)
            _BackendStatus(
              checking: _checkingBackend,
              error: _backendError,
              onRetry: _checkBackend,
            ),
          Expanded(
            child: FutureBuilder<void>(
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
          ),
        ],
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

class _BackendStatus extends StatelessWidget {
  final bool checking;
  final String? error;
  final VoidCallback onRetry;

  const _BackendStatus({
    required this.checking,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF10232F),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (checking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.cloud_off, color: Colors.orangeAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  checking ? 'Checking backend…' : error!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (!checking)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
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
