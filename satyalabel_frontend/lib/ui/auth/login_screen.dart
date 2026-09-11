import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../state/app_state.dart';

/// Login (any role) + citizen self-registration.
/// Inspector/admin accounts are provisioned server-side (bootstrap admin).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _registerMode = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registerMode) {
        await app.register(
          _email.text.trim(),
          _password.text,
          fullName: _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
        );
        // Auto-login after registration.
        await app.login(_email.text.trim(), _password.text);
      } else {
        await app.login(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = switch (e.statusCode) {
            401 => 'Incorrect email or password.',
            409 => 'An account with this email already exists.',
            403 => 'This role requires server-side provisioning.',
            _ => 'Server error (${e.statusCode}): ${e.message}',
          });
    } on NetworkException catch (e) {
      setState(() => _error = 'Cannot reach the backend.\n${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registerMode ? 'Create Account' : 'Inspector Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _registerMode
                    ? 'Citizen account'
                    : 'Sign in to enable Inspector Mode,\nbatch raid sessions and badge-carrying reports.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (_registerMode) ...[
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(
                    labelText: 'Full name (optional)',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v != null && v.length >= 8
                    ? null
                    : 'Minimum 8 characters',
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_registerMode ? 'Create Account' : 'Log In'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _registerMode = !_registerMode;
                          _error = null;
                        }),
                child: Text(_registerMode
                    ? 'Already have an account? Log in'
                    : 'New citizen? Create an account'),
              ),
              const SizedBox(height: 8),
              Text(
                'Citizen scanning works without an account — login is only '
                'needed for inspector tools.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
