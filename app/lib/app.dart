import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'services/chat_notification_service.dart';
import 'features/auth/presentation/session_gate.dart';
import 'models/app_user.dart';

class GyuttoApp extends StatelessWidget {
  const GyuttoApp({
    super.key,
    this.enableNotifications = false,
    this.authStateStream,
  });
  final bool enableNotifications;
  final Stream<AppUser?>? authStateStream;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      navigatorKey: enableNotifications
          ? ChatNotificationService.instance.navigatorKey
          : null,
      navigatorObservers: [chatRouteObserver],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(
        settings,
        home: SessionGate(authStateStream: authStateStream),
      ),
    );
  }
}
