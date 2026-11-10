import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_operations.dart';
import 'app_updates.dart';

class AdminAppReleasesPage extends StatefulWidget {
  const AdminAppReleasesPage({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminAppReleasesPage> createState() => _AdminAppReleasesPageState();
}

class _AdminAppReleasesPageState extends State<AdminAppReleasesPage> {
  final code = TextEditingController(),
      name = TextEditingController(),
      notes = TextEditingController();
  XFile? apk;
  bool busy = false;
  String? error;
  late Future<List<Map<String, dynamic>>> releases;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    releases = widget.client
        .from('app_releases')
        .select()
        .order('version_code', ascending: false)
        .limit(20);
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Android APK', extensions: ['apk']),
        ],
      );
      if (file == null) return;
      if (await file.length() > maxApkBytes) {
        if (mounted) setState(() => error = 'APK must be at most 200 MiB.');
        return;
      }
      if (mounted) {
        setState(() {
          apk = file;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to read the APK. Choose the file again.',
        );
      }
    }
  }

  Future<void> publish() async {
    final version = int.tryParse(code.text.trim());
    final versionName = name.text.trim();
    final releaseNotes = notes.text.trim();
    if (version == null ||
        version < 1 ||
        version > 2100000000 ||
        versionName.isEmpty ||
        versionName.length > 60 ||
        releaseNotes.length > 4000 ||
        apk == null) {
      setState(
        () => error = 'Choose a signed APK and enter its version code, version name and release notes.',
      );
      return;
    }
    final file = apk!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Publish app update?'),
        content: Text(
          'Version $versionName (build $version) will be offered to all users. Use the same signing key as the installed app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await verifyAdminMfa(context, widget.client)) return;
      final bytes = await file.readAsBytes();
      if (bytes.length < 4 ||
          bytes.length > maxApkBytes ||
          bytes[0] != 0x50 ||
          bytes[1] != 0x4b) {
        throw const FormatException('Invalid APK');
      }
      final random = Random.secure();
      final hex = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final path =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}.apk';
      await widget.client.storage
          .from('app-releases')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/vnd.android.package-archive',
              upsert: false,
            ),
          );
      await widget.client.rpc(
        'admin_publish_app_release',
        params: {
          'p_version_code': version,
          'p_version_name': versionName,
          'p_path': path,
          'p_sha256': sha256.convert(bytes).toString(),
          'p_size': bytes.length,
          'p_notes': releaseNotes,
        },
      );
      if (mounted) {
        setState(() {
          apk = null;
          code.clear();
          name.clear();
          notes.clear();
          load();
        });
      }
    } catch (_) {
      // A response can be lost after publication committed; never delete its APK.
      if (mounted) {
        setState(() {
          error = 'Unable to confirm publication. Refresh releases before retrying. Check increasing version code, editor access, storage upload limit and connection.';
          load();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('App releases'),
      actions: [
        IconButton(
          onPressed: busy ? null : () => setState(load),
          tooltip: 'Refresh releases',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Distribute Android updates',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a signed universal APK with a higher version code. Users receive an update notification and confirm installation in Android.',
            ),
            const SizedBox(height: 20),
            if (widget.canEdit)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: code,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'APK version code (build number)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: name,
                        enabled: !busy,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Version name',
                        ),
                      ),
                      TextField(
                        controller: notes,
                        enabled: !busy,
                        maxLength: 4000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'What is new?',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : pick,
                        icon: const Icon(Icons.upload_file),
                        label: Text(apk?.name ?? 'Choose signed APK'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: busy ? null : publish,
                        icon: const Icon(Icons.publish),
                        label: Text(
                          busy ? 'Uploading & publishing…' : 'Publish update',
                        ),
                      ),
                      if (busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Published releases',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: releases,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load releases. Check migration and access.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No releases published yet.'),
                  );
                }
                return Column(
                  children: [
                    for (final row in snapshot.data!)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.android),
                          title: Text(
                            '${row['version_name']} · build ${row['version_code']}',
                          ),
                          subtitle: Text(
                            '${row['notes']}\n${row['created_at']}',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
