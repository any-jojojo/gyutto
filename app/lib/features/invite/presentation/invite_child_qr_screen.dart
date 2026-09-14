import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/invite_repository.dart';
import '../../../repositories/join_request_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../home/logged_in_home_screen.dart';
import 'child_join_approval_button.dart';

class InviteChildQrScreen extends StatefulWidget {
  const InviteChildQrScreen({
    super.key,
    this.authRepository,
    this.inviteRepository,
    this.userRepository,
  });

  final AuthRepository? authRepository;
  final InviteRepository? inviteRepository;
  final UserRepository? userRepository;

  @override
  State<InviteChildQrScreen> createState() {
    return _InviteChildQrScreenState();
  }
}

class _InviteChildQrScreenState extends State<InviteChildQrScreen> {
  CreateInviteResult? _invite;
  String? _familyId;
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

      final invite = await inviteRepository.createChildQrInvite(
        familyId: familyId,
        createdBy: currentUser.uid,
        baseUri: Uri.base,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invite = invite;
        _familyId = familyId;
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

  Future<void> _copyInviteUrl() async {
    final inviteUrl = _invite?.inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: inviteUrl));
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.inviteChildPageTitle)),
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
              const Icon(
                Icons.child_care_outlined,
                color: AppConstants.inkColor,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.inviteChildPageTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.inviteChildPageDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
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
                      : const Icon(Icons.qr_code_2_outlined),
                  label: Text(
                    _isSubmitting
                        ? AppStrings.creatingInviteCode
                        : AppStrings.createChildQrInvite,
                  ),
                )
              else ...[
                const Text(
                  '子どもが参加を申請したら、下のボタンで参加を許可してください。承認後に家族チャットを利用できます。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ChildJoinApprovalButton(
                  approve: () => JoinRequestRepository().approveForInvite(
                    familyId: _familyId!,
                    inviteId: invite.inviteId,
                  ),
                  onApproved: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const LoggedInHomeScreen(notice: 'こども参加申請を許可しました！'),
                    ),
                    (_) => false,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: QrImageView(
                        data: invite.inviteUrl,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppConstants.inkColor,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppConstants.inkColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppStrings.inviteChildQrLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppConstants.inkColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatInviteExpiry(invite.expiresAt),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppConstants.inkColor.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppStrings.childInviteUrlLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppConstants.inkColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  invite.inviteUrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppConstants.inkColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _copyInviteUrl,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text(AppStrings.childInviteUrlLabel),
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
