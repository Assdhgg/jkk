import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';
import 'design.dart';

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
    this.downloadUrl,
  });
  final int versionCode, size;
  final String versionName, path, hash, notes;
  final String? downloadUrl;
  factory AppRelease.fromJson(Map<String, dynamic> row) {
    final result = AppRelease(
      versionCode: row['version_code'] as int,
      versionName: row['version_name'] as String,
      path: row['apk_path'] as String,
      hash: row['sha256'] as String,
      size: row['size_bytes'] as int,
      notes: row['notes'] as String? ?? '',
      downloadUrl: row['download_url'] as String?,
    );
    final provider = row['storage_provider'] as String? ?? 'supabase';
    final url = result.downloadUrl == null
        ? null
        : Uri.tryParse(result.downloadUrl!);
    if ((provider == 'supabase' && url != null) ||
        (provider == 'r2' &&
            (url == null ||
                url.scheme != 'https' ||
                url.host.isEmpty ||
                url.userInfo.isNotEmpty ||
                url.hasQuery ||
                url.hasFragment)) ||
        (provider != 'supabase' && provider != 'r2') ||
        result.versionCode < 1 ||
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

/// Sits above the Navigator so pushed pages and dialogs cannot cover the gate.
/// Checks run silently; only a confirmed newer release blocks access.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.client,
    this.releaseLoader,
    this.versionLoader,
    this.installer,
    this.signedIn,
    this.authChanges,
    this.pollInterval = const Duration(minutes: 1),
  });
  final Widget child;
  final SupabaseClient? client;
  final Stream<List<Map<String, dynamic>>> Function()? releaseLoader;
  final Future<int?> Function()? versionLoader;
  final Future<String?> Function(AppRelease)? installer;
  final bool? signedIn;
  final Stream<bool>? authChanges;
  final Duration pollInterval;
  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? auth;
  StreamSubscription<List<Map<String, dynamic>>>? releases;
  Timer? timer, checkTimeout;
  AppRelease? latest;
  int? installed;
  bool checking = true, failed = false, active = false;
  int generation = 0;
  bool get supported =>
      widget.versionLoader != null ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  SupabaseClient get client => widget.client ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!supported) {
      checking = false;
      return;
    }
    active = widget.signedIn ?? (client.auth.currentSession != null);
    auth =
        (widget.authChanges ??
                (widget.signedIn != null
                    ? const Stream<bool>.empty()
                    : client.auth.onAuthStateChange.map(
                        (event) => event.session != null,
                      )))
            .listen((value) {
              if (value == active) return;
              setState(() {
                active = value;
                latest = null;
                installed = null;
              });
              refresh();
            });
    timer = Timer.periodic(
      widget.pollInterval,
      (_) => refresh(background: true),
    );
    refresh();
  }

  Future<void> refresh({bool background = false}) async {
    if (!mounted || !supported) return;
    final request = ++generation;
    checkTimeout?.cancel();
    final previous = releases;
    releases = null;
    unawaited(previous?.cancel());
    if (!active) {
      setState(() {
        checking = false;
        failed = false;
      });
      return;
    }
    setState(() {
      checking = !background || installed == null;
      // Keep an existing failure blocked until a successful response.
    });
    try {
      final version =
          await (widget.versionLoader?.call() ??
                  updateChannel.invokeMethod<int>('installedVersion'))
              .timeout(const Duration(seconds: 15));
      if (!mounted || request != generation) return;
      if (version == null) throw StateError('Installed version unavailable');
      installed = version;
      final stream =
          widget.releaseLoader?.call() ??
          client
              .from('app_releases')
              .stream(primaryKey: ['id'])
              .order('version_code', ascending: false)
              .limit(1);
      checkTimeout = Timer(const Duration(seconds: 20), () => fail(request));
      releases = stream.listen(
        (rows) {
          if (!mounted || request != generation) return;
          try {
            final release = rows.isEmpty
                ? null
                : AppRelease.fromJson(rows.first);
            checkTimeout?.cancel();
            setState(() {
              // Never unlock on disappearance or rollback of a known newer release.
              if (release != null &&
                  (latest == null ||
                      release.versionCode >= latest!.versionCode)) {
                latest = release;
              }
              checking = false;
              failed = false;
            });
          } catch (_) {
            fail(request);
          }
        },
        onError: (Object _) => fail(request),
        onDone: () {
          if (checking) fail(request);
        },
      );
    } catch (_) {
      fail(request);
    }
  }

  void fail(int request) {
    if (mounted && request == generation) {
      checkTimeout?.cancel();
      setState(() {
        failed = true;
        checking = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    checkTimeout?.cancel();
    auth?.cancel();
    releases?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final required =
        latest != null && installed != null && latest!.versionCode > installed!;
    final blocked = supported && active && required;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: blocked,
          child: Offstage(offstage: blocked, child: widget.child),
        ),
        if (blocked)
          Positioned.fill(
            child: Material(
              color: const Color(0xfff6f3ff),
              child: GrowthBackdrop(
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    supportText(
                                      context,
                                      'Update required',
                                      'App update ചെയ്യണം',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: growthInk,
                                    ),
                                  ),
                                ),
                                const GrowthArt(
                                  'mandatory_reference',
                                  height: 145,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              supportText(
                                context,
                                'Install the latest version to continue using Freelan Space.',
                                'Freelan Space ഉപയോഗിക്കാൻ പുതിയ version install ചെയ്യുക.',
                              ),
                            ),
                            const SizedBox(height: 18),
                            AppUpdateView(
                              key: ValueKey(latest!.versionCode),
                              client: widget.client,
                              releaseLoader: () => Stream.value([
                                {
                                  'version_code': latest!.versionCode,
                                  'version_name': latest!.versionName,
                                  'apk_path': latest!.path,
                                  'sha256': latest!.hash,
                                  'size_bytes': latest!.size,
                                  'notes': latest!.notes,
                                  'download_url': latest!.downloadUrl,
                                  'storage_provider':
                                      latest!.downloadUrl == null
                                      ? 'supabase'
                                      : 'r2',
                                },
                              ]),
                              versionLoader: () async => installed,
                              installer: widget.installer,
                            ),
                            if (failed)
                              Text(
                                supportText(
                                  context,
                                  'Connect to the internet to check for updates, then retry.',
                                  'Updates പരിശോധിക്കാൻ internet connect ചെയ്ത് വീണ്ടും ശ്രമിക്കുക.',
                                ),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                supportText(
                                  context,
                                  'Check again',
                                  'വീണ്ടും പരിശോധിക്കുക',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
    this.versionNameLoader,
    this.installer,
  });
  final bool compact;
  final SupabaseClient? client;
  final Stream<List<Map<String, dynamic>>> Function()? releaseLoader;
  final Future<int?> Function()? versionLoader;
  final Future<String?> Function()? versionNameLoader;
  final Future<String?> Function(AppRelease)? installer;
  @override
  State<AppUpdateView> createState() => _AppUpdateViewState();
}

class _AppUpdateViewState extends State<AppUpdateView>
    with WidgetsBindingObserver {
  late Future<int?> installed;
  late Future<String?> installedName;
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
    installedName = readVersionName();
  }

  Future<String?> readVersionName() async {
    try {
      if (widget.versionNameLoader != null) {
        return await widget.versionNameLoader!();
      }
      if (widget.versionLoader == null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        return await updateChannel.invokeMethod<String>('installedVersionName');
      }
    } catch (_) {
      // The installed build code remains available on older native clients.
    }
    return null;
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
              'url':
                  release.downloadUrl ??
                  (widget.client ?? Supabase.instance.client).storage
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
                  'Allow installation from Freelan Space in Android settings, then tap Update app again.',
                  'Android settings-ൽ Freelan Space-ന് installation അനുവദിച്ച ശേഷം Update app വീണ്ടും അമർത്തുക.',
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
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 25),
                      const GrowthArt('update_reference', height: 205),
                      const SizedBox(height: 20),
                      Text(
                        supportText(
                          context,
                          'Your app is up to date.',
                          'നിങ്ങളുടെ app ഏറ്റവും പുതിയ പതിപ്പാണ്.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: growthInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        supportText(
                          context,
                          'You’re all set with the latest version!',
                          'നിങ്ങൾ ഏറ്റവും പുതിയ പതിപ്പാണ് ഉപയോഗിക്കുന്നത്!',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 25),
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.check)),
                          title: Text(
                            supportText(
                              context,
                              'Current version',
                              'നിലവിലെ പതിപ്പ്',
                            ),
                          ),
                          subtitle: FutureBuilder<String?>(
                            future: installedName,
                            builder: (context, name) => Text(
                              name.data?.trim().isNotEmpty == true
                                  ? name.data!
                                  : '${version.data}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          trailing: Text(
                            supportText(
                              context,
                              'Up to date',
                              'ഏറ്റവും പുതിയത്',
                            ),
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      GrowthPrimaryButton(
                        onPressed: () => setState(load),
                        label: supportText(
                          context,
                          'Check for updates',
                          'Updates പരിശോധിക്കുക',
                        ),
                        icon: Icons.refresh,
                      ),
                    ],
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
                      const GrowthIcon(Icons.system_update),
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
                    Container(
                      margin: const EdgeInsets.only(left: 54),
                      padding: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: growthPurple, width: 3),
                        ),
                      ),
                      child: Text(
                        release.notes,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  GrowthPrimaryButton(
                    onPressed: busy ? null : () => install(release),
                    icon: Icons.download,
                    label: busy
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
