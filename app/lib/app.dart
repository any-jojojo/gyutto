import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';

class GyuttoApp extends StatelessWidget {
  const GyuttoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
