import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/interactive_run_service.dart';
import 'services/judge_service.dart';
import 'services/problem_repository.dart';
import 'services/progress_store.dart';
import 'state/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  final authController = AuthController(AuthService(apiClient));
  runApp(CodeArenaApp(
    apiClient: apiClient,
    authController: authController,
    problemRepository: ProblemRepository(),
    judgeService: JudgeService(apiClient),
    runService: InteractiveRunService(apiClient),
    progressStore: const ProgressStore(),
  ));
}

class CodeArenaApp extends StatelessWidget {
  final ApiClient apiClient;
  final AuthController authController;
  final ProblemRepository problemRepository;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore progressStore;

  const CodeArenaApp({
    super.key,
    required this.apiClient,
    required this.authController,
    required this.problemRepository,
    required this.judgeService,
    required this.runService,
    required this.progressStore,
  });

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFF07131B);
    const panel = Color(0xFF10232F);
    const cyan = Color(0xFF55DCE5);
    final scheme = ColorScheme.fromSeed(
        seedColor: cyan, brightness: Brightness.dark, surface: panel);
    return MaterialApp(
      title: 'CodeArena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(
            backgroundColor: canvas, surfaceTintColor: Colors.transparent),
        cardTheme: CardThemeData(
          color: panel,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF263D4A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: cyan),
          ),
        ),
        snackBarTheme:
            const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: AppShell(
        apiClient: apiClient,
        authController: authController,
        problemRepository: problemRepository,
        judgeService: judgeService,
        runService: runService,
        progressStore: progressStore,
      ),
    );
  }
}
