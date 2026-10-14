import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'services/chat_notification_service.dart';

class GyuttoApp extends StatelessWidget {
  const GyuttoApp({super.key, this.enableNotifications = false});
  final bool enableNotifications;

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
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
