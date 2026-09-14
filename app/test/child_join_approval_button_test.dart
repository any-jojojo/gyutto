import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/invite/presentation/child_join_approval_button.dart';

void main() {
  testWidgets('waits for actual approval and prevents duplicate submission', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    var approved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChildJoinApprovalButton(
            approve: () {
              calls++;
              return completion.future;
            },
            onApproved: () {
              approved = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(approved, isFalse);
    expect(find.text('参加を許可しています…'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(approved, isTrue);
  });

  for (final error in [StateError('承認待ち申請はありません。'), Exception('offline')]) {
    testWidgets('failure does not show success and allows retry: $error', (
      tester,
    ) async {
      var calls = 0;
      var approved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildJoinApprovalButton(
              approve: () async {
                calls++;
                if (calls == 1) throw error;
              },
              onApproved: () {
                approved = true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(approved, isFalse);
      expect(
        find.textContaining(error is StateError ? '承認待ち申請はありません' : '通信状態'),
        findsOneWidget,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
      expect(calls, 2);
    });
  }

  testWidgets(
    'leaving during approval does not navigate from disposed screen',
    (tester) async {
      final completion = Completer<void>();
      var approved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildJoinApprovalButton(
              approve: () => completion.future,
              onApproved: () {
                approved = true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpWidget(const SizedBox());
      completion.complete();
      await tester.pumpAndSettle();
      expect(approved, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
