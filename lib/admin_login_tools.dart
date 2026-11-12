import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One saved login per project, encrypted by the operating system's secure store.
class AdminSavedLogin {
  AdminSavedLogin(this.project, {FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();
  final String project;
  final FlutterSecureStorage storage;
  String get key => 'admin-login-${Uri.parse(project).host}';
  Future<Map<String, String>?> load() async {
    final raw = await storage.read(key: key);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return {'email': data['email'] as String, 'password': data['password'] as String};
  }
  Future<void> save(String email, String password) => storage.write(
    key: key, value: jsonEncode({'email': email, 'password': password}));
  Future<void> forget() => storage.delete(key: key);
}

class AdminPasswordRecovery extends StatefulWidget {
  const AdminPasswordRecovery({super.key, required this.createClient, required this.savedLogin});
  final SupabaseClient Function() createClient;
  final AdminSavedLogin savedLogin;
  @override
  State<AdminPasswordRecovery> createState() => _AdminPasswordRecoveryState();
}

class _AdminPasswordRecoveryState extends State<AdminPasswordRecovery> {
  late final SupabaseClient client = widget.createClient();
  final email = TextEditingController(), code = TextEditingController(),
      password = TextEditingController(), confirm = TextEditingController();
  int step = 0;
  bool busy = false;
  String? error;
  DateTime? sentAt;
  @override
  void dispose() {
    email.dispose(); code.dispose(); password.dispose(); confirm.dispose();
    client.auth.signOut().catchError((Object _) {}).whenComplete(client.dispose);
    super.dispose();
  }
  Future<void> submit() async {
    if (busy) return;
    if (step == 0 && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() => error = 'Enter a valid email address.'); return;
    }
    if (step == 1 && !RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'Enter the six-digit code.'); return;
    }
    if (step == 2 && (password.text.length < 8 || password.text != confirm.text)) {
      setState(() => error = 'Enter matching passwords with at least 8 characters.'); return;
    }
    setState(() { busy = true; error = null; });
    try {
      if (step == 0) {
        await client.auth.resetPasswordForEmail(email.text.trim());
        sentAt = DateTime.now();
      } else if (step == 1) {
        final result = await client.auth.verifyOTP(email: email.text.trim(), token: code.text.trim(), type: OtpType.recovery);
        if (result.session == null || result.user?.email?.toLowerCase() != email.text.trim().toLowerCase()) {
          throw const AuthException('Recovery verification failed.');
        }
      } else {
        await client.auth.updateUser(UserAttributes(password: password.text));
        await widget.savedLogin.forget();
        await client.auth.signOut();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (mounted) setState(() => step++);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to continue. Check your details or code and try again.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset administrator password'),
    content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (step == 0) TextField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email')),
      if (step == 1) ...[
        Text('Enter the code sent to ${email.text.trim()}.'),
        TextField(controller: code, enabled: !busy, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: const InputDecoration(labelText: 'Email OTP')),
        TextButton(onPressed: busy ? null : () async {
          if (sentAt != null && DateTime.now().difference(sentAt!).inSeconds < 60) {
            setState(() => error = 'Wait 60 seconds before requesting another code.'); return;
          }
          setState(() => step = 0);
        }, child: const Text('Request another code')),
      ],
      if (step == 2) ...[
        TextField(controller: password, enabled: !busy, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
        TextField(controller: confirm, enabled: !busy, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
      ],
      if (error != null) Text(error!),
      if (busy) const LinearProgressIndicator(),
    ])),
    actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: busy ? null : submit, child: Text(step == 0 ? 'Send OTP' : step == 1 ? 'Verify OTP' : 'Save password'))],
  );
}
