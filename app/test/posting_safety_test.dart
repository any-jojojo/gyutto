import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/safety/posting_safety.dart';

void main() {
  for (final choice in ['同意しない', '規約に同意する']) {
    testWidgets('posting consent: $choice', (tester) async {
      bool? allowed;
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  allowed = await ensurePostingConsent(
                    context,
                    'f',
                    'child',
                    loadVersion: () async => null,
                    accept: () async {
                      writes++;
                    },
                  );
                },
                child: const Text('投稿'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('投稿'));
      await tester.pumpAndSettle();
      expect(allowed, isNull);
      expect(writes, 0);
      expect(find.text(postingTermsText), findsOneWidget);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      expect(allowed, choice == '規約に同意する');
      expect(writes, choice == '規約に同意する' ? 1 : 0);
    });
  }
  testWidgets(
    'report sends selected reason and details after explicit action',
    (tester) async {
      String? reason, details;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportDialog(
              familyId: 'f',
              targetId: 'm',
              kind: 'message',
              submit: (r, d) async {
                reason = r;
                details = d;
              },
            ),
          ),
        ),
      );
      expect(reason, isNull);
      await tester.enterText(find.byType(TextField), '困っています');
      await tester.tap(find.text('運営に通報する'));
      await tester.pumpAndSettle();
      expect(reason, 'bullying');
      expect(details, '困っています');
    },
  );
  testWidgets('failed report keeps details and offers retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportDialog(
            familyId: 'f',
            targetId: 'u',
            kind: 'user',
            submit: (_, _) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '補足');
    await tester.tap(find.text('運営に通報する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('送信できませんでした'), findsOneWidget);
    expect(find.text('補足'), findsOneWidget);
    expect(find.text('運営に通報する'), findsOneWidget);
  });
}
