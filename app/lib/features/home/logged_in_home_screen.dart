import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_routes.dart';
import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../chat/presentation/family_chat_screen.dart';
import '../family/presentation/join_request_review_screen.dart';
import '../settings/settings_screen.dart';

class LoggedInHomeScreen extends StatefulWidget {
  const LoggedInHomeScreen({
    super.key,
    this.authRepository,
    this.userRepository,
    this.userStream,
    this.chatMessagesStream,
  });

  final AuthRepository? authRepository;
  final UserRepository? userRepository;
  final Stream<AppUser?>? userStream;
  final Stream<List<ChatMessage>>? chatMessagesStream;

  @override
  State<LoggedInHomeScreen> createState() {
    return _LoggedInHomeScreenState();
  }
}

class _LoggedInHomeScreenState extends State<LoggedInHomeScreen> {
  late final Stream<AppUser?> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = widget.userStream ?? _buildUserStream();
  }

  Stream<AppUser?> _buildUserStream() {
    final authRepository = widget.authRepository ?? AuthRepository();
    final currentUser = authRepository.currentUser;

    if (currentUser == null) {
      return Stream<AppUser?>.value(null);
    }

    final userRepository = widget.userRepository ?? UserRepository();
    return userRepository.watchUser(currentUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final hasFamily = appUser?.familyId?.isNotEmpty ?? false;
        final hasPendingRequest = appUser?.pendingFamilyId?.isNotEmpty ?? false;

        if (hasFamily && appUser?.role == AppUserRole.child) {
          return FamilyChatScreen(
            user: appUser!,
            messagesStream: widget.chatMessagesStream,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.appName),
            actions: const [SettingsButton()],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
              child: Builder(
                builder: (context) {
                  final canCreateFamily = !hasFamily && !hasPendingRequest;
                  final canAddParent =
                      hasFamily && (appUser?.role.canAddParent ?? false);
                  final canAddChild =
                      hasFamily && (appUser?.role.canAddChild ?? false);

                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Image.asset(
                          AppConstants.logoAssetPath,
                          width: 172,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        AppStrings.loggedInHomeTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppConstants.inkColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hasFamily
                            ? AppStrings.loggedInHomeDescription
                            : hasPendingRequest
                            ? appUser?.pendingJoinRequestStatus == 'rejected'
                                  ? '参加申請は拒否されました。新しい招待を家族管理者へ依頼してください。'
                                  : '子アカウントの参加申請は承認待ちです。'
                            : AppStrings.noFamilyDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppConstants.inkColor.withValues(alpha: 0.78),
                          height: 1.45,
                        ),
                      ),
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) ...[
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.loadingFamilyStatus,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppConstants.inkColor.withValues(
                                  alpha: 0.72,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (canCreateFamily) ...[
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.createFamily);
                          },
                          icon: const Icon(Icons.add_home_outlined),
                          label: const Text(AppStrings.createFamilyPageTitle),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.joinParentInvite);
                          },
                          icon: const Icon(Icons.key_outlined),
                          label: const Text(AppStrings.joinFamily),
                        ),
                      ],
                      if (hasFamily) ...[
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(88),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FamilyChatScreen(
                                  user: appUser!,
                                  messagesStream: widget.chatMessagesStream,
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded, size: 30),
                              SizedBox(width: 12),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.familyChat,
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '家族みんなでメッセージ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (canAddParent || canAddChild)
                        Row(
                          children: [
                            if (canAddParent)
                              Expanded(
                                child: _CompactInviteButton(
                                  icon: Icons.group_add_outlined,
                                  label: AppStrings.inviteParentAccount,
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.inviteParent),
                                ),
                              ),
                            if (canAddParent && canAddChild)
                              const SizedBox(width: 10),
                            if (canAddChild)
                              Expanded(
                                child: _CompactInviteButton(
                                  icon: Icons.child_care_outlined,
                                  label: AppStrings.inviteChildAccount,
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.inviteChild),
                                ),
                              ),
                          ],
                        ),
                      if (hasFamily &&
                          appUser?.role == AppUserRole.familyAdmin) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => JoinRequestReviewScreen(
                                  familyId: appUser!.familyId!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.approval_outlined),
                          label: const Text('子アカウントの参加申請'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompactInviteButton extends StatelessWidget {
  const _CompactInviteButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
