import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growth_circle/admin_login_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('saved admin login is scoped to the project and never uses preferences', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final first = AdminSavedLogin('https://one.supabase.co');
    final second = AdminSavedLogin('https://two.supabase.co');
    await first.save('admin@example.test', 'synthetic-password');
    expect((await first.load())!['email'], 'admin@example.test');
    expect((await first.load())!['password'], 'synthetic-password');
    expect(await second.load(), isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    await first.forget();
    expect(await first.load(), isNull);
  });
}
