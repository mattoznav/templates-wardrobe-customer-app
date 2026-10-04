import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_controller.dart';

/// Sign in or create an account. Pops with `true` once the user is signed in,
/// so flows like checkout can carry on where they left off.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.reason});

  final String? reason;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _first, _last]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (_register) {
        await auth.register(email: _email.text.trim(), password: _password.text, firstName: _first.text.trim(), lastName: _last.text.trim());
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() => _error = !_register && statusOf(e) == 401 ? 'Email or password is not right.' : errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(_register ? 'Create your account' : 'Welcome back', style: display(40)),
              const SizedBox(height: 10),
              Text(
                widget.reason ?? 'Follow your orders, cancel before they ship and send pieces back from your account.',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
              ),
              const SizedBox(height: 28),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Sign in')),
                  ButtonSegment(value: true, label: Text('Create account')),
                ],
                selected: {_register},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() {
                  _register = v.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 24),
              if (_register) ...[
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name'), textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.givenName])),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name'), textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.familyName])),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => v != null && v.contains('@') ? null : 'Enter your email.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(labelText: 'Password', helperText: _register ? 'At least 8 characters.' : null),
                obscureText: true,
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                validator: (v) => (v ?? '').length >= (_register ? 8 : 1) ? null : (_register ? 'Use at least 8 characters.' : 'Enter your password.'),
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.accent)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper))
                    : Text(_register ? 'Create account' : 'Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
