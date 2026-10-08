import 'package:flutter/material.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:triage_client/triage_client.dart';
import 'theme.dart';

enum AuthFlow { login, signup, verify, reset, resetVerify }

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.client});
  final Client client;
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _code = TextEditingController();
  final _emailFocus = FocusNode(),
      _codeFocus = FocusNode(),
      _passwordFocus = FocusNode();
  AuthFlow _flow = AuthFlow.login;
  UuidValue? _request;
  String _error = '';
  bool _busy = false, _hidden = true;
  String get _title => switch (_flow) {
    AuthFlow.login => 'A little less on your mind.',
    AuthFlow.signup => 'Make room for your thoughts.',
    AuthFlow.verify => 'Check your email.',
    AuthFlow.reset => 'Reset your password.',
    AuthFlow.resetVerify => 'Choose a new password.',
  };
  String get _action => switch (_flow) {
    AuthFlow.login => 'Sign in',
    AuthFlow.signup => 'Create account',
    AuthFlow.verify => 'Verify and sign in',
    AuthFlow.reset => 'Send reset code',
    AuthFlow.resetVerify => 'Reset password',
  };
  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      if (_flow == AuthFlow.verify || _flow == AuthFlow.resetVerify) {
        (_code.text.trim().isEmpty ? _codeFocus : _passwordFocus)
            .requestFocus();
      } else {
        (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())
                ? _passwordFocus
                : _emailFocus)
            .requestFocus();
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final email = _email.text.trim();
      switch (_flow) {
        case AuthFlow.login:
          final auth = await widget.client.emailIdp.login(
            email: email,
            password: _password.text,
          );
          await widget.client.auth.updateSignedInUser(auth);
        case AuthFlow.signup:
          _request = await widget.client.emailIdp.startRegistration(
            email: email,
          );
          if (mounted) setState(() => _flow = AuthFlow.verify);
        case AuthFlow.verify:
          final token = await widget.client.emailIdp.verifyRegistrationCode(
            accountRequestId: _request!,
            verificationCode: _code.text.trim(),
          );
          final auth = await widget.client.emailIdp.finishRegistration(
            registrationToken: token,
            password: _password.text,
          );
          await widget.client.auth.updateSignedInUser(auth);
        case AuthFlow.reset:
          _request = await widget.client.emailIdp.startPasswordReset(
            email: email,
          );
          if (mounted) setState(() => _flow = AuthFlow.resetVerify);
        case AuthFlow.resetVerify:
          final token = await widget.client.emailIdp.verifyPasswordResetCode(
            passwordResetRequestId: _request!,
            verificationCode: _code.text.trim(),
          );
          await widget.client.emailIdp.finishPasswordReset(
            finishPasswordResetToken: token,
            newPassword: _password.text,
          );
          _password.clear();
          _code.clear();
          if (mounted) setState(() => _flow = AuthFlow.login);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              (_flow == AuthFlow.verify || _flow == AuthFlow.resetVerify)
              ? 'Code or password could not be accepted. Check your code, password policy, and connection.'
              : 'Couldn’t sign in or send email. Check your details and connection, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _change(AuthFlow flow) {
    setState(() {
      _flow = flow;
      _error = '';
      _code.clear();
      _request = null;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verifying = _flow == AuthFlow.verify || _flow == AuthFlow.resetVerify;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 392),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Brand(),
                      const SizedBox(height: 48),
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.8,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        verifying
                            ? 'Enter the verification code sent to ${_email.text.trim()}.'
                            : 'Tasks, notes, and the things you don’t want to forget.',
                        style: const TextStyle(
                          color: TriageColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!verifying) ...[
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 12,
                            color: TriageColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const Key('auth-email'),
                          controller: _email,
                          focusNode: _emailFocus,
                          style: const TextStyle(fontSize: 16),
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: _flow == AuthFlow.reset
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: (_) {
                            if (_flow == AuthFlow.reset) {
                              _submit();
                            } else {
                              _passwordFocus.requestFocus();
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                          ),
                          validator: (v) =>
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch((v ?? '').trim())
                              ? null
                              : 'Enter a valid email address.',
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const Text(
                          'Verification code',
                          style: TextStyle(
                            fontSize: 12,
                            color: TriageColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const Key('auth-code'),
                          controller: _code,
                          focusNode: _codeFocus,
                          style: const TextStyle(fontSize: 16),
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            if (_flow == AuthFlow.verify) {
                              _submit();
                            } else {
                              _passwordFocus.requestFocus();
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Code from your email',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter the verification code.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_flow != AuthFlow.reset) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _flow == AuthFlow.resetVerify
                                    ? 'New password'
                                    : 'Password',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: TriageColors.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_flow == AuthFlow.login)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _change(AuthFlow.reset),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: TriageColors.muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const Key('auth-password'),
                          controller: _password,
                          focusNode: _passwordFocus,
                          obscureText: _hidden,
                          style: const TextStyle(fontSize: 16),
                          autofillHints: [
                            _flow == AuthFlow.login
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: _flow == AuthFlow.login
                                ? 'Your password'
                                : 'At least 8 characters',
                            suffixIcon: IconButton(
                              tooltip: _hidden
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: TriageColors.muted,
                              ),
                            ),
                          ),
                          validator: (v) => (v ?? '').isEmpty
                              ? 'Enter a password.'
                              : _flow != AuthFlow.login && (v ?? '').length < 8
                              ? 'Use at least 8 characters.'
                              : null,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_error.isNotEmpty) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: TriageColors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ActionButton(
                          _action,
                          primary: true,
                          busy: _busy,
                          onPressed: _submit,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_flow == AuthFlow.signup)
                        const Text(
                          'Next: verify your email with a short code.',
                          style: TextStyle(
                            color: TriageColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _change(
                                _flow == AuthFlow.login
                                    ? AuthFlow.signup
                                    : AuthFlow.login,
                              ),
                        child: Text(
                          _flow == AuthFlow.login
                              ? 'New here? Create an account'
                              : 'Back to sign in',
                          style: const TextStyle(
                            color: TriageColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: TriageColors.dim,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Speech is processed on your device. Raw transcripts stay here.',
                              style: TextStyle(
                                color: TriageColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
