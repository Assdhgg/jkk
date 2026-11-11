import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growth_circle/secure_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'migrates session to protected storage then removes plaintext and logs out',
    () async {
      SharedPreferences.setMockInitialValues({'session': 'synthetic-session'});
      final store = ProtectedAuthStorage('session');
      await store.initialize();
      expect(await store.accessToken(), 'synthetic-session');
      expect(
        (await SharedPreferences.getInstance()).containsKey('session'),
        false,
      );
      await store.persistSession('refreshed');
      expect(await store.accessToken(), 'refreshed');
      await store.removePersistedSession();
      expect(await store.hasAccessToken(), false);
    },
  );
  test('existing encrypted session wins during migration', () async {
    SharedPreferences.setMockInitialValues({'session': 'stale'});
    FlutterSecureStorage.setMockInitialValues({'session': 'current'});
    final store = ProtectedAuthStorage('session');
    await store.initialize();
    expect(await store.accessToken(), 'current');
    expect(
      (await SharedPreferences.getInstance()).containsKey('session'),
      false,
    );
  });
  test('PKCE proofs are protected and removed on completion', () async {
    SharedPreferences.setMockInitialValues({'verifier': 'old'});
    final store = ProtectedPkceStorage('project');
    expect(await store.getItem(key: 'verifier'), null);
    await store.setItem(key: 'verifier', value: 'synthetic-proof');
    expect(await store.getItem(key: 'verifier'), 'synthetic-proof');
    expect(
      (await SharedPreferences.getInstance()).containsKey('verifier'),
      false,
    );
    await store.removeItem(key: 'verifier');
    expect(await store.getItem(key: 'verifier'), null);
  });
  test('rejects unsafe project configuration', () {
    const key = 'sb_publishable_syntheticpublickey';
    expect(validClientConfiguration('https://example.supabase.co', key), true);
    for (final url in [
      'http://example.test',
      'https://user@example.test',
      'https://example.test/?x=1',
      'https://example.test/path',
    ]) {
      expect(validClientConfiguration(url, key), false);
    }
    expect(
      validClientConfiguration('https://example.test', 'sb_secret_synthetic'),
      false,
    );
  });
}
