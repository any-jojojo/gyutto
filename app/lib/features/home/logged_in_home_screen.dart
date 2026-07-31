import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_routes.dart';

class LoggedInHomeScreen extends StatelessWidget {
  const LoggedInHomeScreen({super.key});

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
          child: ListView(
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
                AppStrings.loggedInHomeDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppConstants.inkColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.createFamily);
                },
                icon: const Icon(Icons.add_home_outlined),
                label: const Text(AppStrings.createFamilyPageTitle),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.inviteParentComingSoon),
                    ),
                  );
                },
                icon: const Icon(Icons.group_add_outlined),
                label: const Text(AppStrings.inviteParentAccount),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.inviteChildComingSoon),
                    ),
                  );
                },
                icon: const Icon(Icons.child_care_outlined),
                label: const Text(AppStrings.inviteChildAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
