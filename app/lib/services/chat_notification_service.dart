import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/chat/presentation/family_chat_screen.dart';
import '../repositories/user_repository.dart';

final chatRouteObserver = RouteObserver<ModalRoute<void>>();

class ChatNotificationService with WidgetsBindingObserver {
  ChatNotificationService._();
  static final instance = ChatNotificationService._();
  static const _channel = MethodChannel('gyutto/chat_notifications');
  final navigatorKey = GlobalKey<NavigatorState>();
  bool _started = false;
  bool _signingOut = false;
  String? _token;
  String? _registeredUid;
  String? visibleFamilyId;
  Future<void> _syncQueue = Future.value();

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void start() {
    if (_started || !supported) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openChat') {
        await _openChat(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) _signingOut = false;
      _queueSync();
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _queueSync());
    FirebaseMessaging.onMessage.listen((message) => unawaited(_show(message)));
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openChat(message.data)),
    );
    unawaited(_initialMessage());
  }

  void _queueSync() {
    _syncQueue = _syncQueue.then((_) => _sync()).catchError((Object error) {
      // Push setup must never prevent login or chat. Resume retries setup.
      debugPrint(
        'Chat notification registration failed (${error.runtimeType}).',
      );
    });
  }

  Future<void> _sync() async {
    if (_signingOut) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (_registeredUid != null) {
        await FirebaseMessaging.instance.deleteToken();
      }
      _token = null;
      _registeredUid = null;
      await clear();
      return;
    }
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (_signingOut ||
        token == null ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    await FirebaseFunctions.instance
        .httpsCallable('registerChatPushDevice')
        .call({'token': token});
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      await FirebaseMessaging.instance.deleteToken();
      return;
    }
    if (_token != null && _token != token && _registeredUid == uid) {
      await FirebaseFunctions.instance
          .httpsCallable('unregisterChatPushDevice')
          .call({'token': _token});
    }
    _token = token;
    _registeredUid = uid;
  }

  Future<void> unregisterBeforeSignOut() async {
    if (!supported || !_started) return;
    _signingOut = true;
    await _syncQueue;
    try {
      final token = _token;
      if (token != null) {
        // Do not silently leave a shared device subscribed to the previous user.
        await FirebaseFunctions.instance
            .httpsCallable('unregisterChatPushDevice')
            .call({'token': token});
      }
      await FirebaseMessaging.instance.deleteToken();
      _registeredUid = null;
      _token = null;
      await clear();
    } catch (_) {
      _signingOut = false;
      rethrow;
    }
  }

  Future<void> _initialMessage() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      final local = await _channel.invokeMapMethod<String, dynamic>(
        'initialMessage',
      );
      final data = message?.data ?? local;
      if (data != null) await _openChat(data);
    } catch (error) {
      debugPrint('Chat notification open failed (${error.runtimeType}).');
    }
  }

  Future<void> _show(RemoteMessage remote) async {
    try {
      final data = remote.data, uid = FirebaseAuth.instance.currentUser?.uid;
      if (data['type'] != 'family_chat' ||
          uid == null ||
          data['recipientUid'] != uid) {
        return;
      }
      if (visibleFamilyId == data['familyId'] &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        return;
      }
      final message = await FirebaseFirestore.instance
          .doc('families/${data['familyId']}/messages/${data['messageId']}')
          .get();
      final readBy = message.data()?['readBy'] as Map<String, dynamic>?;
      if (!message.exists ||
          readBy?.containsKey(uid) == true ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      await _channel.invokeMethod<void>('show', {
        ...data,
        'title': remote.notification?.title ?? 'ぎゅっと',
        'body': remote.notification?.body ?? '新しいメッセージが届きました',
      });
    } catch (error) {
      debugPrint('Chat notification display failed (${error.runtimeType}).');
    }
  }

  Future<void> _openChat(Map<String, dynamic> data) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (data['type'] != 'family_chat' ||
          uid == null ||
          data['recipientUid'] != uid) {
        return;
      }
      final user = await UserRepository().fetchUser(uid);
      if (user == null ||
          user.familyId != data['familyId'] ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      // Wait for MaterialApp to mount when launched from a notification.
      if (navigatorKey.currentState == null) {
        await WidgetsBinding.instance.endOfFrame;
      }
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      await clear();
      if (visibleFamilyId != user.familyId) {
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => FamilyChatScreen(user: user),
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Chat notification open failed (${error.runtimeType}).');
    }
  }

  Future<void> clear() async {
    if (!_started || !supported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      // Notifications may already have been removed by Android.
    }
  }

  Future<void> openSettings() async {
    if (!supported) return;
    await _channel.invokeMethod<void>('settings');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queueSync();
  }
}
