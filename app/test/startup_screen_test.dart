import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/core/startup/startup_screen.dart';

const readyApp = MaterialApp(home: Scaffold(body: Text('ready')));
void main() {
  testWidgets('renders while initialization waits then opens app', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      StartupScreen(initialize: () => pending.future, app: readyApp),
    );
    expect(find.text('起動しています…'), findsOneWidget);
    expect(find.text('ready'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
  });
  testWidgets('initialization failure is recoverable by retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      StartupScreen(
        initialize: () async {
          if (++attempts == 1) throw StateError('failed');
        },
        app: readyApp,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('アプリを起動できませんでした'), findsOneWidget);
    await tester.tap(find.text('もう一度試す'));
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
    expect(attempts, 2);
  });
  testWidgets(
    'timeout stays responsive and retry does not duplicate initialization',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        StartupScreen(
          initialize: () {
            calls++;
            return pending.future;
          },
          app: readyApp,
          timeout: const Duration(seconds: 2),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('アプリを起動できませんでした'), findsOneWidget);
      await tester.tap(find.text('もう一度試す'));
      await tester.pump();
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('ready'), findsOneWidget);
    },
  );
}
