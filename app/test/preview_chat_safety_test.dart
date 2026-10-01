import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/preview/chat_safety_preview.dart';
import 'package:gyutto/core/theme/app_theme.dart';

void main() {
  testWidgets('preview allows confirmation permission pause and resume', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final name in ['Roboto', 'Ahem', 'PreviewJapanese']) {
      final font = FontLoader(name);
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/meiryo.ttc').readAsBytesSync(),
          ),
        ),
      );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(
        ByteData.sublistView(
          File(
            'C:/Users/any/Development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
    await icons.load();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ChatSafetyPreview(
          theme: AppTheme.light().copyWith(
            textTheme: AppTheme.light().textTheme.apply(
              fontFamily: 'PreviewJapanese',
            ),
            appBarTheme: AppTheme.light().appBarTheme.copyWith(
              titleTextStyle: const TextStyle(
                fontFamily: 'PreviewJapanese',
                fontSize: 20,
                color: Color(0xFF143458),
                fontWeight: FontWeight.w700,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: AppTheme.light().filledButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'PreviewJapanese',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: AppTheme.light().outlinedButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'PreviewJapanese',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final output = Directory('build/preview/chat-safety')
      ..createSync(recursive: true);
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('01-safety-and-adult-confirmation');
    await tester.tap(find.text('読んで確認しました'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'preview');
    await tester.tap(find.text('保護者として確認する'));
    await tester.pumpAndSettle();
    expect(find.text('利用を許可する'), findsOneWidget);
    await capture('02-awaiting-permission');
    await tester.tap(find.text('利用を許可する'));
    await tester.pumpAndSettle();
    await capture('03-permission-dialog');
    await tester.enterText(find.byType(TextField), 'preview');
    await tester.tap(find.text('同意して許可する'));
    await tester.pumpAndSettle();
    expect(find.text('チャットを利用できる状態です。'), findsOneWidget);
    await capture('04-chat-allowed');
    await tester.tap(find.text('利用を停止する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'preview');
    await tester.tap(find.text('停止する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('お休み中です'), findsOneWidget);
    await capture('05-chat-paused');
    await tester.tap(find.text('利用を再開する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'preview');
    await tester.tap(find.text('同意して許可する'));
    await tester.pumpAndSettle();
    expect(find.text('チャットを利用できる状態です。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
