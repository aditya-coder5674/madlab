import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/progress_store.dart';
import '../state/auth_controller.dart';
import '../widgets/arena_widgets.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AuthController authController;
  final ProgressStore progressStore;

  const ProfileScreen(
      {super.key, required this.authController, required this.progressStore});

  void _openAuth(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AuthScreen(authController: authController),
      ));

  Future<void> _logout(BuildContext context) async {
    try {
      await authController.logout();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: AnimatedBuilder(
          animation: authController,
          builder: (context, _) =>
              ListView(padding: const EdgeInsets.all(16), children: [
            if (ApiConfig.configurationError() != null)
              const ApiNotice(
                  message:
                      'Authentication and server-side progress require a configured backend URL.'),
            if (authController.error != null &&
                ApiConfig.configurationError() == null)
              ApiNotice(message: authController.error!, error: true),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFF183B45),
                    child: Text(
                      (authController.user?.username.isNotEmpty == true
                              ? authController.user!.username[0]
                              : 'C')
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF55DCE5),
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(authController.user?.username ?? 'Guest',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(authController.user?.email ?? 'Not signed in',
                            style: const TextStyle(color: Color(0xFFA8BBC5))),
                      ])),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeading(title: 'Progress on this device'),
            const SizedBox(height: 8),
            FutureBuilder<Set<int>>(
              future: progressStore.acceptedProblemIds(),
              builder: (context, snapshot) => Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_outlined,
                      color: Color(0xFF72D7A5)),
                  title: Text(snapshot.hasData
                      ? '${snapshot.data!.length} accepted problems'
                      : 'Loading progress'),
                  subtitle: const Text(
                      'Saved locally after accepted submissions. Not synced to an account.'),
                ),
              ),
            ),
            FutureBuilder<Set<int>>(
              future: progressStore.acceptedDebuggingIds(),
              builder: (context, snapshot) => Card(
                child: ListTile(
                  leading: const Icon(Icons.bug_report_outlined,
                      color: Color(0xFFFFC46B)),
                  title: Text(snapshot.hasData
                      ? '${snapshot.data!.length} accepted debugging tasks'
                      : 'Loading debugging progress'),
                  subtitle: const Text(
                      'Saved locally after accepted submissions. Not synced to an account.'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const ApiNotice(
                message:
                    'The current backend does not expose a server-side solved count, submission history, or account progress endpoint.'),
            if (authController.user == null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => _openAuth(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in or register')),
            ] else ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed:
                    authController.loading ? null : () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ]),
        ),
      );
}
