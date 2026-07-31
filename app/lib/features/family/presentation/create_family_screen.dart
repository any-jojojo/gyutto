import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/family_repository.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({
    super.key,
    this.authRepository,
    this.familyRepository,
  });

  final AuthRepository? authRepository;
  final FamilyRepository? familyRepository;

  @override
  State<CreateFamilyScreen> createState() {
    return _CreateFamilyScreenState();
  }
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _displayNameController = TextEditingController();

  var _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _familyNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
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
      final familyRepository = widget.familyRepository ?? FamilyRepository();
      final currentUser = authRepository.currentUser;

      if (currentUser == null) {
        setState(() {
          _errorMessage = AppStrings.createFamilyLoginRequired;
        });
        return;
      }

      await familyRepository.createFamily(
        name: _familyNameController.text.trim(),
        adminUserId: currentUser.uid,
        adminDisplayName: _displayNameController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = AppStrings.createFamilySuccess;
      });

      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.loggedInHome, (route) => false);
    } on FirebaseException catch (error) {
      setState(() {
        _errorMessage =
            '${AppStrings.createFamilyUnknownError} (${error.code})';
      });
    } catch (_) {
      setState(() {
        _errorMessage = AppStrings.createFamilyUnknownError;
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
      appBar: AppBar(title: const Text(AppStrings.createFamilyPageTitle)),
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
                AppStrings.createFamilyPageTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.createFamilyPageDescription,
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
                      controller: _familyNameController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: AppConstants.inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: AppStrings.familyName,
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.familyNameRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _createFamily(),
                      style: const TextStyle(
                        color: AppConstants.inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: AppStrings.adminDisplayName,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.adminDisplayNameRequired;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _CreateFamilyMessage(
                  message: _errorMessage!,
                  color: AppConstants.errorColor,
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                _CreateFamilyMessage(
                  message: _successMessage!,
                  color: AppConstants.inkColor,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting || _successMessage != null
                    ? null
                    : _createFamily,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_home_outlined),
                label: Text(
                  _isSubmitting
                      ? AppStrings.creatingFamily
                      : AppStrings.createFamilyAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateFamilyMessage extends StatelessWidget {
  const _CreateFamilyMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}
