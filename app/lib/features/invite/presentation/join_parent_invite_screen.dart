import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/invite_repository.dart';

class JoinParentInviteScreen extends StatefulWidget {
  const JoinParentInviteScreen({
    super.key,
    this.authRepository,
    this.inviteRepository,
  });

  final AuthRepository? authRepository;
  final InviteRepository? inviteRepository;

  @override
  State<JoinParentInviteScreen> createState() {
    return _JoinParentInviteScreenState();
  }
}

class _JoinParentInviteScreenState extends State<JoinParentInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _displayNameController = TextEditingController();

  var _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _joinFamily() async {
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
      final inviteRepository = widget.inviteRepository ?? InviteRepository();
      final currentUser = authRepository.currentUser;

      if (currentUser == null) {
        setState(() {
          _errorMessage = AppStrings.joinParentInviteLoginRequired;
        });
        return;
      }

      await inviteRepository.joinParentInvite(
        code: _codeController.text,
        userId: currentUser.uid,
        displayName: _displayNameController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = AppStrings.joinParentInviteSuccess;
      });

      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.loggedInHome, (route) => false);
    } on InviteException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } on FirebaseException catch (error) {
      setState(() {
        _errorMessage = '${AppStrings.joinInviteUnknownError} (${error.code})';
      });
    } catch (_) {
      setState(() {
        _errorMessage = AppStrings.joinInviteUnknownError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.joinParentInvitePageTitle)),
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
              Text(
                AppStrings.joinParentInvitePageTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.joinParentInvitePageDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _codeController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        color: AppConstants.inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: AppStrings.parentInviteCode,
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.parentInviteCodeRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _joinFamily(),
                      style: const TextStyle(
                        color: AppConstants.inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: AppStrings.parentDisplayName,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.parentDisplayNameRequired;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppConstants.errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: AppConstants.inkColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting || _successMessage != null
                    ? null
                    : _joinFamily,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_outlined),
                label: Text(
                  _isSubmitting
                      ? AppStrings.joiningFamily
                      : AppStrings.joinParentInviteAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
