import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codearena/main.dart';
import 'package:codearena/services/api_client.dart';
import 'package:codearena/services/auth_service.dart';
import 'package:codearena/services/interactive_run_service.dart';
import 'package:codearena/services/judge_service.dart';
import 'package:codearena/services/problem_repository.dart';
import 'package:codearena/services/progress_store.dart';
import 'package:codearena/state/auth_controller.dart';

void main() {
  testWidgets('dashboard shows branding and navigation controls',
      (tester) async {
    final apiClient = ApiClient();
    final authController = AuthController(AuthService(apiClient));
    await tester.pumpWidget(CodeArenaApp(
      apiClient: apiClient,
      authController: authController,
      problemRepository: ProblemRepository(),
      judgeService: JudgeService(apiClient),
      runService: InteractiveRunService(apiClient),
      progressStore: const ProgressStore(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Practice with purpose.'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-problems')), findsOneWidget);
  });
}
