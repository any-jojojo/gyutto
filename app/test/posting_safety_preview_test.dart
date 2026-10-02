import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/preview/posting_safety_preview.dart';

void main() {
  testWidgets('preview consent and both reports stay local', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PostingSafetyPreview());
    await tester.tap(find.text('投稿する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意しない'));
    await tester.pumpAndSettle();
    expect(find.text('同意記録：未同意'), findsOneWidget);
    await tester.tap(find.text('投稿する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('規約に同意する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('同意記録：第1版に同意済み'), findsOneWidget);
    expect(find.text('ただいま！'), findsOneWidget);
    for (final label in ['投稿を通報', 'ユーザーを通報']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '確認をお願いします');
      await tester.tap(find.text('運営に通報する'));
      await tester.pumpAndSettle();
    }
    expect(find.text('プレビュー内の受付記録：2件'), findsOneWidget);
    await tester.tap(find.text('記録をリセットして最初から'));
    await tester.pumpAndSettle();
    expect(find.text('同意記録：未同意'), findsOneWidget);
    expect(find.text('プレビュー内の受付記録：0件'), findsOneWidget);
  });
}
