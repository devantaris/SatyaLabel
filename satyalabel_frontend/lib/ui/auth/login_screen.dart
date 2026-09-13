import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../state/app_state.dart';
import '../theme.dart';

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

  int _accountTypeIndex = 0; // 0: Inspector / Officer, 1: Citizen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_registerMode
            ? 'Create Citizen Account'
            : (_accountTypeIndex == 0 ? 'Enforcement Officer Login' : 'Citizen Auditor Sign In')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Role Selector Tabs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _accountTypeIndex = 0;
                            _registerMode = false;
                            _error = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _accountTypeIndex == 0 ? AppColors.navy : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield,
                                  size: 16,
                                  color: _accountTypeIndex == 0 ? Colors.white : AppColors.slate,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Officer / Inspector',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _accountTypeIndex == 0 ? Colors.white : AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _accountTypeIndex = 1;
                            _error = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _accountTypeIndex == 1 ? AppColors.citizenPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 16,
                                  color: _accountTypeIndex == 1 ? Colors.white : AppColors.slate,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Citizen Auditor',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _accountTypeIndex == 1 ? Colors.white : AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accountTypeIndex == 0
                      ? AppColors.navy.withValues(alpha: 0.05)
                      : AppColors.citizenBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _accountTypeIndex == 0 ? AppColors.border : AppColors.citizenBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _accountTypeIndex == 0 ? Icons.admin_panel_settings : Icons.info_outline,
                      size: 18,
                      color: _accountTypeIndex == 0 ? AppColors.navy : AppColors.citizenPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _accountTypeIndex == 0
                            ? 'Inspector credentials are provisioned by Department of Consumer Affairs administrators. Grants access to Batch Raids and Digital Seizure Dossiers.'
                            : (_registerMode
                                ? 'Citizens can self-register to save audits, record crowdsourced violations, and generate e-Daakhil court evidence.'
                                : 'Sign in to access your saved citizen audits and evidence dossiers.'),
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: _accountTypeIndex == 0 ? AppColors.navy : AppColors.citizenPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_registerMode && _accountTypeIndex == 1) ...[
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
                decoration: InputDecoration(
                  labelText: _accountTypeIndex == 0 ? 'Officer Official Email' : 'Email Address',
                  prefixIcon: const Icon(Icons.email),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.nonCompliantBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.nonCompliantBorder),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.nonCompliant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _accountTypeIndex == 0 ? AppColors.navy : AppColors.citizenPrimary,
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_registerMode ? 'Create Citizen Account' : 'Sign In'),
              ),
              const SizedBox(height: 12),
              if (_accountTypeIndex == 1) ...[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _registerMode = !_registerMode;
                            _error = null;
                          }),
                  child: Text(_registerMode
                      ? 'Already have an account? Sign in'
                      : 'New citizen? Create an account'),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.consumerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.consumerBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: AppColors.consumerPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Using SatyaLabel as a Consumer / Shopper?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.consumerPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No login is required! You can freely scan packages, verify MRP, check expiry dates, and file 1915 helpline grievances.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.consumerPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
