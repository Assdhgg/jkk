import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _options = FirebaseOptions(
  apiKey: _apiKey,
  appId: _appId,
  messagingSenderId: _senderId,
  projectId: _projectId,
);
bool get pushConfigured =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _hasExplicitOptions =>
    _apiKey.isNotEmpty &&
    _appId.isNotEmpty &&
    _projectId.isNotEmpty &&
    _senderId.isNotEmpty;
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  if (pushConfigured && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: _hasExplicitOptions ? _options : null,
    );
  }
}

class PushCoordinator {
  PushCoordinator._();
  static final instance = PushCoordinator._();
  StreamSubscription<String>? _refresh;
  String? _token;
  int _generation = 0;
  Future<void> _writes = Future.value();
  Future<void> _initialize() async {
    if (!pushConfigured) throw StateError('Push configuration unavailable.');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: _hasExplicitOptions ? _options : null,
      );
    }
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
  }

  Future<bool> enable(SupabaseClient client) async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in first.');
    await _initialize();
    final setting = await FirebaseMessaging.instance.requestPermission();
    if (setting.authorizationStatus != AuthorizationStatus.authorized &&
        setting.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await _register(client);
    if (client.auth.currentUser?.id != id) return false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('push_opt_in_$id', true);
    return true;
  }

  Future<bool> isEnabled(SupabaseClient client) async {
    final id = client.auth.currentUser?.id;
    if (id == null) return false;
    return (await SharedPreferences.getInstance()).getBool('push_opt_in_$id') ==
        true;
  }

  Future<void> disable(SupabaseClient client) async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in first.');
    ++_generation;
    await _refresh?.cancel();
    _refresh = null;
    await _writes;
    // Retain the token for retry if server cleanup fails.
    final token = _token;
    if (token != null) {
      await client.rpc('unregister_push_token', params: {'p_token': token});
    }
    if (pushConfigured) {
      await _initialize();
      await FirebaseMessaging.instance.unregister();
    }
    _token = null;
    await (await SharedPreferences.getInstance()).setBool(
      'push_opt_in_$id',
      false,
    );
  }

  Future<void> restore(SupabaseClient client) async {
    if (!pushConfigured) return;
    try {
      final id = client.auth.currentUser?.id;
      if (id == null) return;
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool('push_opt_in_$id') != true) return;
      await _initialize();
      final setting = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (setting.authorizationStatus == AuthorizationStatus.authorized ||
          setting.authorizationStatus == AuthorizationStatus.provisional) {
        await _register(client);
      }
    } catch (_) {
      /* The rest of the app works when push is unavailable. */
    }
  }

  Future<void> _register(SupabaseClient client) async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in first.');
    final generation = ++_generation;
    await _refresh?.cancel();
    if (generation != _generation) throw StateError('Registration cancelled.');
    final registered = Completer<void>();
    _refresh = FirebaseMessaging.instance.onRegistered.listen((value) {
      final write = _writes.then((_) async {
        if (generation != _generation || client.auth.currentUser?.id != id) {
          throw StateError('Registration cancelled.');
        }
        await client.rpc('register_push_token', params: {'p_token': value});
        final previous = _token;
        _token = value;
        if (previous != null && previous != value) {
          await client.rpc(
            'unregister_push_token',
            params: {'p_token': previous},
          );
        }
      });
      _writes = write.catchError((Object _) {});
      write.then(
        (_) {
          if (!registered.isCompleted) registered.complete();
        },
        onError: (Object error, StackTrace stack) {
          if (!registered.isCompleted) registered.completeError(error, stack);
        },
      );
    });
    await FirebaseMessaging.instance.register();
    await registered.future.timeout(const Duration(seconds: 20));
  }

  Future<void> stop(SupabaseClient client) async {
    ++_generation;
    final subscription = _refresh;
    _refresh = null;
    // Queue cleanup behind any registration already in flight and ahead of a
    // subsequent sign-in's registration, so logout cannot retain that token.
    final cleanup = _writes.then((_) async {
      final token = _token;
      _token = null;
      if (token == null) return;
      try {
        await client.rpc('unregister_push_token', params: {'p_token': token});
      } catch (_) {
        // Local session cleanup must continue.
      }
      try {
        await FirebaseMessaging.instance.unregister();
      } catch (_) {
        // Local session cleanup must continue.
      }
    });
    _writes = cleanup.catchError((Object _) {});
    await subscription?.cancel();
    await cleanup;
  }
}
