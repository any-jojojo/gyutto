import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/core/theme/app_theme.dart';
import 'package:gyutto/features/home/home_screen.dart';
import 'package:gyutto/features/home/logged_in_home_screen.dart';
import 'package:gyutto/features/chat/presentation/family_chat_screen.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/models/chat_message.dart';

void main() {
  testWidgets('export store screenshots with fictional family data', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    final font = FontLoader('StoreJapanese');
    font.addFont(Future.value(ByteData.sublistView(File('C:/Windows/Fonts/meiryo.ttc').readAsBytesSync())));
    await font.load();
    for (final family in ['Roboto', 'Ahem']) {
      final fallback = FontLoader(family);
      fallback.addFont(Future.value(ByteData.sublistView(File('C:/Windows/Fonts/meiryo.ttc').readAsBytesSync())));
      await fallback.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(File('C:/Users/any/Development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
    const user = AppUser(uid: 'demo-mother', displayName: 'お母さん', email: null, familyId: 'demo', role: AppUserRole.familyAdmin);
    final now = DateTime(2026, 9, 7, 16, 30);
    final reads = {'demo-mother': ReadReceipt(displayName: 'お母さん', readAt: now), 'demo-child': ReadReceipt(displayName: 'はる', readAt: now), 'demo-father': ReadReceipt(displayName: 'お父さん', readAt: now)};
    final messages = <ChatMessage>[
      ChatMessage(id: '4', senderUserId: 'demo-mother', senderDisplayName: 'お母さん', text: 'ありがとう！ 気をつけて帰ってきてね。', readBy: reads, createdAt: now),
      ChatMessage(id: '3', senderUserId: 'demo-father', senderDisplayName: 'お父さん', text: '今日は18時ごろに帰るよ。', readBy: reads, createdAt: now.subtract(const Duration(minutes: 2))),
      ChatMessage(id: '2', senderUserId: 'demo-child', senderDisplayName: 'はる', text: '宿題おわったよ！', readBy: reads, createdAt: now.subtract(const Duration(minutes: 5))),
      ChatMessage(id: '1', senderUserId: 'demo-mother', senderDisplayName: 'お母さん', text: 'おかえり。おやつは冷蔵庫にあるよ。', readBy: reads, createdAt: now.subtract(const Duration(minutes: 10))),
    ];
    final screens = <String, Widget>{
      '01-family-chat': FamilyChatScreen(user: user, messagesStream: Stream.value(messages)),
      '02-family-home': LoggedInHomeScreen(joinRequestsStream: Stream.value(const []), userStream: Stream.value(user)),
      '03-welcome': const HomeScreen(),
    };
    final out = Directory('../assets/store/google-play/ja-JP/phone');
    out.createSync(recursive: true);
    for (final entry in screens.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light().copyWith(filledButtonTheme: FilledButtonThemeData(style: AppTheme.light().filledButtonTheme.style!.copyWith(textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'StoreJapanese', fontSize: 16, fontWeight: FontWeight.w700)))), outlinedButtonTheme: OutlinedButtonThemeData(style: AppTheme.light().outlinedButtonTheme.style!.copyWith(textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'StoreJapanese', fontSize: 16, fontWeight: FontWeight.w700)))), appBarTheme: AppTheme.light().appBarTheme.copyWith(titleTextStyle: const TextStyle(fontFamily: 'StoreJapanese', fontSize: 20, color: Color(0xFF143458), fontWeight: FontWeight.w700)), textTheme: AppTheme.light().textTheme.apply(fontFamily: 'StoreJapanese')), home: entry.value)));
      await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 500)); });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${out.path}/${entry.key}.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
