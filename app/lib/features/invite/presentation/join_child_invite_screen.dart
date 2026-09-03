import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/invite_repository.dart';

class JoinChildInviteScreen extends StatefulWidget {
  const JoinChildInviteScreen({
    super.key,
    required this.token,
    this.familyName,
    this.authRepository,
    this.inviteRepository,
  });

  final String? token;
  final String? familyName;
  final AuthRepository? authRepository;
  final InviteRepository? inviteRepository;

  @override
  State<JoinChildInviteScreen> createState() {
    return _JoinChildInviteScreenState();
  }
}

class _JoinChildInviteScreenState extends State<JoinChildInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  var _accepted = false;
  var _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _joinFamily() async {
    final formState = _formKey.currentState;
    if (!_accepted || formState == null || !formState.validate()) {
      return;
    }

    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.childInviteTokenMissing;
      });
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
      final currentUser = await authRepository.startNewAnonymousChildSession();

      await inviteRepository.joinChildInvite(
        token: token,
        displayName: _displayNameController.text.trim(),
        userId: currentUser.uid,
      );

      if (!mounted) {
        return;
      }

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
    } on AuthException catch (error) {
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
      appBar: AppBar(title: const Text(AppStrings.joinChildInvitePageTitle)),
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
                AppStrings.joinChildInvitePageTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.joinChildInvitePageDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${widget.familyName?.trim().isNotEmpty ?? false ? widget.familyName!.trim() : 'この家族'}に参加しますか？',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('はい')),
                  ButtonSegment(value: false, label: Text('いいえ')),
                ],
                selected: {_accepted},
                onSelectionChanged: _isSubmitting || _successMessage != null
                    ? null
                    : (selection) {
                        setState(() {
                          _accepted = selection.first;
                          _errorMessage = null;
                        });
                      },
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _displayNameController,
                  enabled: _accepted,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _joinFamily(),
                  style: const TextStyle(
                    color: AppConstants.inkColor,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: AppStrings.childDisplayName,
                    prefixIcon: Icon(Icons.child_care_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.childDisplayNameRequired;
                    }
                    return null;
                  },
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
                onPressed:
                    _accepted && !_isSubmitting && _successMessage == null
                    ? _joinFamily
                    : null,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSubmitting
                      ? AppStrings.joiningFamily
                      : AppStrings.joinChildInviteAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
