import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool validClientConfiguration(String url, String key) {
  final uri = Uri.tryParse(url);
  var publicKey = key.startsWith('sb_publishable_') && key.length > 20;
  if (!publicKey) {
    try {
      final pieces = key.split('.');
      publicKey =
          pieces.length == 3 &&
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(pieces[1]))),
              )['role'] ==
              'anon';
    } catch (_) {
      publicKey = false;
    }
  }
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      publicKey;
}

/// Fail closed on protected-storage failures; never fall back to preferences.
class ProtectedAuthStorage extends LocalStorage {
  ProtectedAuthStorage(this.key, {FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  final String key;
  final FlutterSecureStorage storage;
  @override
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getString(key);
    if (legacy != null) {
      if (await storage.read(key: key) == null) {
        await storage.write(key: key, value: legacy);
      }
      await preferences.remove(key);
    }
  }

  @override
  Future<bool> hasAccessToken() async => await storage.read(key: key) != null;
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() async {
    await storage.delete(key: key);
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

class ProtectedPkceStorage extends GotrueAsyncStorage {
  ProtectedPkceStorage(this.project, {FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  final String project;
  final FlutterSecureStorage storage;
  String scoped(String key) => '$project-pkce-$key';
  @override
  Future<String?> getItem({required String key}) async {
    // Pending legacy sign-ins must restart rather than reuse plaintext proofs.
    await (await SharedPreferences.getInstance()).remove(key);
    return storage.read(key: scoped(key));
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await storage.write(key: scoped(key), value: value);
    await (await SharedPreferences.getInstance()).remove(key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await storage.delete(key: scoped(key));
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
