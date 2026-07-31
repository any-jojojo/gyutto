import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/invite_repository.dart';
import '../../../repositories/user_repository.dart';

class InviteParentScreen extends StatefulWidget {
  const InviteParentScreen({
    super.key,
    this.authRepository,
    this.inviteRepository,
    this.userRepository,
  });

  final AuthRepository? authRepository;
  final InviteRepository? inviteRepository;
  final UserRepository? userRepository;

  @override
  State<InviteParentScreen> createState() {
    return _InviteParentScreenState();
  }
}

class _InviteParentScreenState extends State<InviteParentScreen> {
  CreateInviteResult? _invite;
  var _isSubmitting = false;
  String? _errorMessage;

  Future<void> _createInvite() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authRepository = widget.authRepository ?? AuthRepository();
      final userRepository = widget.userRepository ?? UserRepository();
      final inviteRepository = widget.inviteRepository ?? InviteRepository();
      final currentUser = authRepository.currentUser;

      if (currentUser == null) {
        setState(() {
          _errorMessage = AppStrings.joinParentInviteLoginRequired;
        });
        return;
      }

      final appUser = await userRepository.fetchUser(currentUser.uid);
      final familyId = appUser?.familyId;
      if (familyId == null || familyId.isEmpty) {
        setState(() {
          _errorMessage = AppStrings.createFamilyLoginRequired;
        });
        return;
      }

      final invite = await inviteRepository.createParentInvite(
        familyId: familyId,
        createdBy: currentUser.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invite = invite;
      });
    } on FirebaseException catch (error) {
      setState(() {
        _errorMessage =
            '${AppStrings.createInviteUnknownError} (${error.code})';
      });
    } catch (_) {
      setState(() {
        _errorMessage = AppStrings.createInviteUnknownError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _copyInviteEmail() async {
    final invite = _invite;
    if (invite == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _buildEmailBody(invite.token)));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.parentInviteEmailBodyCopied)),
    );
  }

  String _buildEmailBody(String code) {
    return '''
ぎゅっとに親アカウントとして招待されました。

アプリでログインまたは新規登録したあと、以下の招待コードを入力してください。

招待コード: $code

有効期限は発行から1時間です。
''';
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.inviteParentPageTitle)),
      body: _InviteGradientBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const _InviteHeader(
              title: AppStrings.inviteParentPageTitle,
              description: AppStrings.inviteParentPageDescription,
              icon: Icons.group_add_outlined,
            ),
            const SizedBox(height: 32),
            if (invite == null)
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _createInvite,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_outlined),
                label: Text(
                  _isSubmitting
                      ? AppStrings.creatingInviteCode
                      : AppStrings.createParentInviteCode,
                ),
              )
            else ...[
              _InviteCodePanel(code: invite.token),
              const SizedBox(height: 16),
              Text(
                _formatInviteExpiry(invite.expiresAt),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.parentInviteEmailTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.parentInviteEmailDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                _buildEmailBody(invite.token),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copyInviteEmail,
                icon: const Icon(Icons.copy_outlined),
                label: const Text(AppStrings.copyParentInviteEmail),
              ),
            ],
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
          ],
        ),
      ),
    );
  }

  String _formatInviteExpiry(DateTime? expiresAt) {
    if (expiresAt == null) {
      return '';
    }

    final year = expiresAt.year.toString().padLeft(4, '0');
    final month = expiresAt.month.toString().padLeft(2, '0');
    final day = expiresAt.day.toString().padLeft(2, '0');
    final hour = expiresAt.hour.toString().padLeft(2, '0');
    final minute = expiresAt.minute.toString().padLeft(2, '0');

    return 'あと1時間有効  $year/$month/$day $hour:$minuteまで';
  }
}

class _InviteGradientBody extends StatelessWidget {
  const _InviteGradientBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
        child: ListView(padding: const EdgeInsets.all(24), children: [child]),
      ),
    );
  }
}

class _InviteHeader extends StatelessWidget {
  const _InviteHeader({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppConstants.inkColor, size: 40),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppConstants.inkColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppConstants.inkColor.withValues(alpha: 0.78),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _InviteCodePanel extends StatelessWidget {
  const _InviteCodePanel({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              AppStrings.inviteParentCodeLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppConstants.inkColor.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppConstants.inkColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
