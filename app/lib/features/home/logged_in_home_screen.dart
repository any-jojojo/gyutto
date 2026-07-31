import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_routes.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';

class LoggedInHomeScreen extends StatefulWidget {
  const LoggedInHomeScreen({
    super.key,
    this.authRepository,
    this.userRepository,
    this.userStream,
  });

  final AuthRepository? authRepository;
  final UserRepository? userRepository;
  final Stream<AppUser?>? userStream;

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
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
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
          child: StreamBuilder<AppUser?>(
            stream: _userStream,
            builder: (context, snapshot) {
              final appUser = snapshot.data;
              final hasFamily = appUser?.familyId?.isNotEmpty ?? false;
              final canCreateFamily = !hasFamily;
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppConstants.inkColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFamily
                        ? AppStrings.loggedInHomeDescription
                        : AppStrings.noFamilyDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppConstants.inkColor.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.loadingFamilyStatus,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppConstants.inkColor.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (canCreateFamily) ...[
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.createFamily);
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
                  if (canAddParent) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.inviteParent);
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text(AppStrings.inviteParentAccount),
                    ),
                  ],
                  if (canAddChild) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.inviteChild);
                      },
                      icon: const Icon(Icons.child_care_outlined),
                      label: const Text(AppStrings.inviteChildAccount),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
