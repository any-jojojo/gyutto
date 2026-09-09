import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_routes.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: const [SettingsButton()],
      ),
      body: _HomeBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              const _BrandMark(),
              const SizedBox(height: 28),
              Text(
                AppStrings.homeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppConstants.inkColor,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.login);
                },
                icon: const Icon(Icons.group_outlined),
                label: const Text(AppStrings.createFamily),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.login);
                },
                icon: const Icon(Icons.location_on_outlined),
                label: const Text(AppStrings.joinFamily),
              ),
              const SizedBox(height: 28),
              const _HomeFeatureTile(
                icon: Icons.security_outlined,
                title: AppStrings.safeFamily,
                description: AppStrings.safeFamilyDescription,
              ),
              const SizedBox(height: 12),
              const _HomeFeatureTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: AppStrings.familyChat,
                description: AppStrings.familyChatDescription,
              ),
              const SizedBox(height: 12),
              const _HomeFeatureTile(
                icon: Icons.favorite_border_rounded,
                title: AppStrings.readReceipts,
                description: AppStrings.readReceiptsDescription,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppConstants.inkColor.withValues(alpha: 0.06),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Image.asset(
            AppConstants.logoAssetPath,
            width: 184,
            fit: BoxFit.contain,
            semanticLabel: AppStrings.appName,
          ),
        ),
      ),
    );
  }
}

class _HomeFeatureTile extends StatelessWidget {
  const _HomeFeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = switch (icon) {
      Icons.security_outlined => const _FeatureTileStyle(
        iconColor: Color(0xFFFF9AA5),
        backgroundColor: Color(0xFFFFF3EE),
      ),
      Icons.chat_bubble_outline_rounded => const _FeatureTileStyle(
        iconColor: Color(0xFFFF8F72),
        backgroundColor: Color(0xFFFFF1F5),
      ),
      Icons.favorite_border_rounded => const _FeatureTileStyle(
        iconColor: Color(0xFFFF8FA3),
        backgroundColor: Color(0xFFEFF7FF),
      ),
      _ => _FeatureTileStyle(
        iconColor: colorScheme.primary,
        backgroundColor: AppConstants.hopeColor,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppConstants.inkColor.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PastelIcon(icon: icon, color: style.iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppConstants.inkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppConstants.inkColor.withValues(alpha: 0.86),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTileStyle {
  const _FeatureTileStyle({
    required this.iconColor,
    required this.backgroundColor,
  });

  final Color iconColor;
  final Color backgroundColor;
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
      child: child,
    );
  }
}

class _PastelIcon extends StatelessWidget {
  const _PastelIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
