import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';

class AuthScreen extends StatefulWidget {
  final AuthController authController;

  const AuthScreen({super.key, required this.authController});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_register) {
        await widget.authController.register(
            _username.text.trim(), _email.text.trim(), _password.text);
      } else {
        await widget.authController.login(_email.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Authentication failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_register ? 'Create account' : 'Sign in')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.terminal,
                            color: Color(0xFF55DCE5), size: 42),
                        const SizedBox(height: 12),
                        Text(_register ? 'Join CodeArena' : 'Welcome back',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 22),
                        if (_register) ...[
                          TextFormField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline)),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter a username.'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText:
                                _register ? 'Email' : 'Username or email',
                            prefixIcon: const Icon(Icons.alternate_email),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'This field is required.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a password.';
                            }
                            if (_register && value.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        AnimatedBuilder(
                          animation: widget.authController,
                          builder: (context, _) => FilledButton(
                            onPressed:
                                widget.authController.loading ? null : _submit,
                            child: widget.authController.loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(
                                    _register ? 'Create account' : 'Sign in'),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _register = !_register),
                          child: Text(_register
                              ? 'Already have an account? Sign in'
                              : 'New to CodeArena? Create an account'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Passwords are sent only to the configured backend. The app persists its session cookie using Android secure storage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFFA8BBC5),
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
}
