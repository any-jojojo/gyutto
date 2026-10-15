import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../repositories/auth_repository.dart';
import '../../home/home_screen.dart';
import '../../home/logged_in_home_screen.dart';

/// Waits for Firebase to restore the device session before choosing a home.
class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    this.authRepository,
    this.authStateStream,
    this.signedInBuilder,
  });

  final AuthRepository? authRepository;
  final Stream<AppUser?>? authStateStream;
  final Widget Function(BuildContext, AppUser)? signedInBuilder;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  AuthRepository? _repository;
  late Stream<AppUser?> _session;

  @override
  void initState() {
    super.initState();
    _repository = widget.authRepository;
    _watchSession();
  }

  void _watchSession() {
    _session =
        widget.authStateStream ??
        (_repository ??= AuthRepository()).authStateChanges();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
    stream: _session,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ログイン状態を確認できませんでした。もう一度お試しください。'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(_watchSession),
                      child: const Text('もう一度試す'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting ||
          snapshot.connectionState == ConnectionState.none) {
        return const Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('ログイン状態を確認しています…'),
                ],
              ),
            ),
          ),
        );
      }
      final user = snapshot.data;
      if (user == null) return const HomeScreen();
      return KeyedSubtree(
        key: ValueKey(user.uid),
        child:
            widget.signedInBuilder?.call(context, user) ??
            LoggedInHomeScreen(authRepository: _repository),
      );
    },
  );
}
