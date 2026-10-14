import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/startup/startup_screen.dart';
import 'services/chat_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    StartupScreen(
      initialize: () async {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        ChatNotificationService.instance.start();
      },
      app: const GyuttoApp(enableNotifications: true),
    ),
  );
}
