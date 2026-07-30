import 'package:flutter/material.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../constants/app_strings.dart';
import 'app_routes.dart';

class AppRouter {
  const AppRouter._();

  static Route<void> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        return switch (settings.name) {
          AppRoutes.home || null => const HomeScreen(),
          AppRoutes.login => const LoginScreen(),
          _ => const _UnknownRouteScreen(),
        };
      },
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.unknownRouteTitle)),
      body: const SafeArea(
        child: Center(child: Text(AppStrings.unknownRouteMessage)),
      ),
    );
  }
}
