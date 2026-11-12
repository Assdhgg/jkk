// FCM HTTP v1 delivery requires token compatibility APIs, not FIDs.
// ignore_for_file: deprecated_member_use

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

class PushPermissionDenied implements Exception {
  const PushPermissionDenied();
}

class PushCoordinator {
  PushCoordinator._();
  PushCoordinator.forTesting({
    required Future<void> Function() initialize,
    required Future<bool> Function() permission,
    required Future<String?> Function() tokenLoader,
    required Stream<String> tokenChanges,
  }) : _testInitialize = initialize,
       _testPermission = permission,
       _testTokenLoader = tokenLoader,
       _testTokenChanges = tokenChanges;
  Future<void> Function()? _testInitialize;
  Future<bool> Function()? _testPermission;
  Future<String?> Function()? _testTokenLoader;
  Stream<String>? _testTokenChanges;
  static final instance = PushCoordinator._();
  StreamSubscription<String>? _refresh;
  String? _token;
  int _generation = 0;
  Future<void> _writes = Future.value();
  Future<void> _initialize() async {
    if (_testInitialize != null) return _testInitialize!();
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
    final granted = _testPermission != null
        ? await _testPermission!()
        : await _requestPermission();
    if (!granted) return false;
    await _register(client);
    if (client.auth.currentUser?.id != id) return false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('push_opt_in_$id', true);
    return true;
  }

  Future<bool> isEnabled(SupabaseClient client) async {
    final id = client.auth.currentUser?.id;
    if (id == null) return false;
    if ((await SharedPreferences.getInstance()).getBool('push_opt_in_$id') !=
        true) {
      return false;
    }
    await _initialize();
    final granted = _testPermission != null
        ? await _testPermission!() : await _hasPermission();
    if (!granted) return false;
    // Permission and saved preference alone do not prove server registration.
    await _register(client);
    return client.auth.currentUser?.id == id;
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

  Future<void>? _restoring;

  Future<void> restore(SupabaseClient client) {
    // Resume and connectivity retries must not replace each other's listeners.
    return _restoring ??= _restore(client).whenComplete(() => _restoring = null);
  }

  Future<void> _restore(SupabaseClient client) async {
    if (!pushConfigured && _testInitialize == null) return;
    final generation = _generation;
    try {
      final id = client.auth.currentUser?.id;
      if (id == null) return;
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool('push_opt_in_$id') != true) return;
      await _initialize();
      final granted = _testPermission != null
          ? await _testPermission!()
          : await _hasPermission();
      if (generation != _generation || client.auth.currentUser?.id != id) return;
      if (granted) await _register(client);
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
    Future<void> writeToken(String value) {
      final write = _writes.then((_) async {
        if (generation != _generation || client.auth.currentUser?.id != id) {
          throw StateError('Registration cancelled.');
        }
        if (value.isEmpty) throw StateError('No messaging token.');
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
      return write;
    }

    // The HTTP v1 worker requires an FCM token, not the Installation ID
    // emitted by onRegistered. Fetch the cached token as well as future changes.
    final changes =
        _testTokenChanges ?? FirebaseMessaging.instance.onTokenRefresh;
    _refresh = changes.listen((value) {
      unawaited(writeToken(value).catchError((Object _) {}));
    }, onError: (Object _) {});
    try {
      final token =
          await (_testTokenLoader?.call() ??
                  FirebaseMessaging.instance.getToken())
              .timeout(const Duration(seconds: 20));
      if (token == null || token.isEmpty) {
        throw StateError('No messaging token.');
      }
      await writeToken(token);
    } catch (_) {
      if (generation == _generation) {
        ++_generation;
        await _refresh?.cancel();
        _refresh = null;
      }
      rethrow;
    }
  }

  Future<bool> _hasPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> detach() async {
    ++_generation;
    final subscription = _refresh;
    _refresh = null;
    await subscription?.cancel();
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
