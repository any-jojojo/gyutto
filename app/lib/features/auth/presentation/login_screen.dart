import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  var _authMode = _AuthMode.login;
  var _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authRepository = widget.authRepository ?? AuthRepository();
      if (_authMode == _AuthMode.login) {
        await authRepository.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await authRepository.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      setState(() {
        _successMessage = _authMode == _AuthMode.login
            ? AppStrings.loginSuccess
            : AppStrings.signUpSuccess;
      });
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _firebaseAuthErrorMessage(error);
      });
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = _authMode == _AuthMode.login
            ? AppStrings.loginUnknownError
            : AppStrings.signUpUnknownError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _firebaseAuthErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => AppStrings.loginInvalidEmail,
      'user-disabled' => AppStrings.loginUserDisabled,
      'email-already-in-use' => AppStrings.signUpEmailAlreadyInUse,
      'weak-password' => AppStrings.signUpWeakPassword,
      'password-does-not-meet-requirements' =>
        AppStrings.authPasswordPolicyError,
      'operation-not-allowed' => AppStrings.authOperationNotAllowed,
      'unauthorized-domain' => AppStrings.authUnauthorizedDomain,
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => AppStrings.loginInvalidCredential,
      _ =>
        '${_authMode == _AuthMode.login ? AppStrings.loginUnknownError : AppStrings.signUpUnknownError} (${error.code})',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [
              AppConstants.warmColor,
              AppConstants.kindnessColor,
              AppConstants.trustColor,
              AppConstants.connectionColor,
              AppConstants.hopeColor,
            ],
            stops: [0, 0.24, 0.52, 0.76, 1],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  AppConstants.logoAssetPath,
                  width: 148,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _pageTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pageDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment<_AuthMode>(
                    value: _AuthMode.login,
                    label: Text(AppStrings.loginTab),
                    icon: Icon(Icons.login_rounded),
                  ),
                  ButtonSegment<_AuthMode>(
                    value: _AuthMode.signUp,
                    label: Text(AppStrings.signUpTab),
                    icon: Icon(Icons.person_add_alt_rounded),
                  ),
                ],
                selected: {_authMode},
                onSelectionChanged: _isSubmitting
                    ? null
                    : (selection) {
                        setState(() {
                          _authMode = selection.first;
                          _errorMessage = null;
                          _successMessage = null;
                        });
                      },
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: AppConstants.inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return AppStrings.emailRequired;
                        }
                        if (!email.contains('@')) {
                          return AppStrings.loginInvalidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        color: AppConstants.inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.passwordRequired;
                        }
                        if (_authMode == _AuthMode.signUp && value.length < 6) {
                          return AppStrings.passwordTooShort;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _AuthErrorMessage(message: _errorMessage!),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                _AuthSuccessMessage(message: _successMessage!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_submitIcon),
                label: Text(_isSubmitting ? _submittingLabel : _submitLabel),
              ),
              const SizedBox(height: 18),
              Text(
                AppStrings.childLoginQrNotice,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.68),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _pageTitle {
    return switch (_authMode) {
      _AuthMode.login => AppStrings.loginTitle,
      _AuthMode.signUp => AppStrings.signUpTitle,
    };
  }

  String get _pageDescription {
    return switch (_authMode) {
      _AuthMode.login => AppStrings.loginDescription,
      _AuthMode.signUp => AppStrings.signUpDescription,
    };
  }

  String get _submitLabel {
    return switch (_authMode) {
      _AuthMode.login => AppStrings.loginAction,
      _AuthMode.signUp => AppStrings.signUpAction,
    };
  }

  String get _submittingLabel {
    return switch (_authMode) {
      _AuthMode.login => AppStrings.loggingIn,
      _AuthMode.signUp => AppStrings.signingUp,
    };
  }

  IconData get _submitIcon {
    return switch (_authMode) {
      _AuthMode.login => Icons.login_rounded,
      _AuthMode.signUp => Icons.person_add_alt_rounded,
    };
  }
}

enum _AuthMode { login, signUp }

class _AuthErrorMessage extends StatelessWidget {
  const _AuthErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        message,
        style: const TextStyle(
          color: AppConstants.errorColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AuthSuccessMessage extends StatelessWidget {
  const _AuthSuccessMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppConstants.trustColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppConstants.inkColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppConstants.inkColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
