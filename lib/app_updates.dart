import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';

const updateChannel = MethodChannel('growth_circle/app_updates');
const maxApkBytes = 209715200;

class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.path,
    required this.hash,
    required this.size,
    required this.notes,
  });
  final int versionCode, size;
  final String versionName, path, hash, notes;
  factory AppRelease.fromJson(Map<String, dynamic> row) {
    final result = AppRelease(
      versionCode: row['version_code'] as int,
      versionName: row['version_name'] as String,
      path: row['apk_path'] as String,
      hash: row['sha256'] as String,
      size: row['size_bytes'] as int,
      notes: row['notes'] as String? ?? '',
    );
    if (result.versionCode < 1 ||
        result.versionCode > 2100000000 ||
        result.size < 1 ||
        result.size > maxApkBytes ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(result.hash) ||
        !RegExp(r'^[a-f0-9-]{36}\.apk$').hasMatch(result.path)) {
      throw const FormatException('Invalid release');
    }
    return result;
  }
}

class AppUpdatePage extends StatelessWidget {
  const AppUpdatePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(supportText(context, 'App updates', 'App updates')),
    ),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: AppUpdateView(),
    ),
  );
}

class AppUpdateView extends StatefulWidget {
  const AppUpdateView({
    super.key,
    this.compact = false,
    this.client,
    this.releaseLoader,
    this.versionLoader,
    this.installer,
  });
  final bool compact;
  final SupabaseClient? client;
  final Stream<List<Map<String, dynamic>>> Function()? releaseLoader;
  final Future<int?> Function()? versionLoader;
  final Future<String?> Function(AppRelease)? installer;
  @override
  State<AppUpdateView> createState() => _AppUpdateViewState();
}

class _AppUpdateViewState extends State<AppUpdateView>
    with WidgetsBindingObserver {
  late Future<int?> installed;
  Stream<List<Map<String, dynamic>>>? releases;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  void load() {
    releases = null;
    installed =
        widget.versionLoader?.call() ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? updateChannel.invokeMethod<int>('installedVersion')
            : Future.value(null));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(load);
  }

  Future<void> install(AppRelease release) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = widget.installer != null
          ? await widget.installer!(release)
          : await updateChannel.invokeMethod<String>('installUpdate', {
              'url': (widget.client ?? Supabase.instance.client).storage
                  .from('app-releases')
                  .getPublicUrl(release.path),
              'sha256': release.hash,
              'sizeBytes': release.size,
              'versionCode': release.versionCode,
            });
      if (result != 'permission_required' && result != 'installer_opened') {
        throw StateError('Installer did not confirm opening.');
      }
      if (mounted) {
        setState(
          () => message = result == 'permission_required'
              ? supportText(
                  context,
                  'Allow installation from Growth Circle in Android settings, then tap Update app again.',
                  'Android settings-ൽ Growth Circle-ന് installation അനുവദിച്ച ശേഷം Update app വീണ്ടും അമർത്തുക.',
                )
              : supportText(
                  context,
                  'Complete installation in the Android installer.',
                  'Android installer-ൽ installation പൂർത്തിയാക്കുക.',
                ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = supportText(
            context,
            'Update failed. Check your connection and retry. The APK must use the same signing key.',
            'Update പരാജയപ്പെട്ടു. Connection പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക. APK-ക്ക് അതേ signing key വേണം.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget problem() => widget.compact
      ? const SizedBox.shrink()
      : TextButton(
          onPressed: () => setState(() {
            releases = null;
            load();
          }),
          child: Text(
            supportText(
              context,
              'Unable to check updates. Retry',
              'Updates പരിശോധിക്കാനായില്ല. വീണ്ടും ശ്രമിക്കുക',
            ),
          ),
        );
  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: installed,
    builder: (context, version) {
      if (version.hasError) return problem();
      if (version.connectionState != ConnectionState.done) {
        return widget.compact
            ? const SizedBox.shrink()
            : const LinearProgressIndicator();
      }
      if (version.data == null) {
        return widget.compact
            ? const SizedBox.shrink()
            : Text(
                supportText(
                  context,
                  'APK updates are available in the Android app.',
                  'APK updates Android app-ൽ ലഭ്യമാണ്.',
                ),
              );
      }
      releases ??=
          widget.releaseLoader?.call() ??
          (widget.client ?? Supabase.instance.client)
              .from('app_releases')
              .stream(primaryKey: ['id'])
              .order('version_code', ascending: false)
              .limit(1);
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: releases,
        builder: (context, snapshot) {
          if (snapshot.hasError) return problem();
          if (!snapshot.hasData) {
            return widget.compact
                ? const SizedBox.shrink()
                : const LinearProgressIndicator();
          }
          AppRelease? latest;
          try {
            if (snapshot.data!.isNotEmpty) {
              latest = AppRelease.fromJson(snapshot.data!.first);
            }
          } catch (_) {
            return problem();
          }
          if (latest == null || latest.versionCode <= version.data!) {
            return widget.compact
                ? const SizedBox.shrink()
                : Text(
                    supportText(
                      context,
                      'Your app is up to date.',
                      'നിങ്ങളുടെ app ഏറ്റവും പുതിയ പതിപ്പാണ്.',
                    ),
                  );
          }
          final release = latest;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update, color: Colors.deepPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${supportText(context, 'App update available', 'പുതിയ app update ലഭ്യമാണ്')} · ${release.versionName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.compact && release.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(release.notes),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: busy ? null : () => install(release),
                    icon: const Icon(Icons.download),
                    label: Text(
                      busy
                          ? supportText(
                              context,
                              'Downloading & verifying…',
                              'Download പരിശോധിക്കുന്നു…',
                            )
                          : supportText(
                              context,
                              'Update app',
                              'App update ചെയ്യുക',
                            ),
                    ),
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(message!),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
