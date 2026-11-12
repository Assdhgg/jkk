import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _t(BuildContext context, String en, String ml) =>
    Localizations.localeOf(context).languageCode == 'ml' ? ml : en;

abstract class AdminNotificationGateway {
  Future<List<Map<String, dynamic>>> search(String query, int offset);
  Future<int> send(String requestId, String? target, String title, String body, {bool inApp = true, bool push = true});
}

class SupabaseAdminNotificationGateway implements AdminNotificationGateway {
  const SupabaseAdminNotificationGateway(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> search(String query, int offset) async =>
      (await client.rpc(
        'admin_notification_users',
        params: {'p_query': query, 'p_offset': offset},
      ) as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  @override
  Future<int> send(
    String requestId,
    String? target,
    String title,
    String body, {
    bool inApp = true, bool push = true,
  }) async => await client.rpc(
    'admin_send_notification_v2',
    params: {
      'p_request_id': requestId,
      'p_target_user': target,
      'p_title': title,
      'p_body': body,
      'p_in_app': inApp, 'p_push': push,
    },
  ) as int;
}

String _requestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 0x40;
  bytes[8] = (bytes[8] & 63) | 0x80;
  final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class AdminSendNotificationPage extends StatefulWidget {
  const AdminSendNotificationPage({
    super.key,
    required this.gateway,
    required this.canEdit,
  });
  final AdminNotificationGateway gateway;
  final bool canEdit;
  @override
  State<AdminSendNotificationPage> createState() =>
      _AdminSendNotificationPageState();
}

class _AdminSendNotificationPageState extends State<AdminSendNotificationPage> {
  final query = TextEditingController(),
      title = TextEditingController(),
      body = TextEditingController();
  bool allUsers = false, loading = false, sending = false;
  bool inApp = true, push = true;
  int offset = 0;
  String search = '';
  List<Map<String, dynamic>> users = [];
  Map<String, dynamic>? selected;
  String? error, requestId, lastPayload;
  @override
  void dispose() {
    query.dispose();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> findUsers({int nextOffset = 0, bool newSearch = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      if (newSearch) {
        search = query.text.trim();
        selected = null;
      }
    });
    try {
      final result = await widget.gateway.search(search, nextOffset);
      if (mounted) {
        setState(() {
          users = result;
          offset = nextOffset;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = _t(
            context,
            'Unable to find users.',
            'Users-നെ കണ്ടെത്താനായില്ല.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final heading = title.text.trim(), message = body.text.trim();
    if ((!inApp && !push) || !widget.canEdit ||
        (!allUsers && selected == null) ||
        heading.isEmpty ||
        message.isEmpty ||
        heading.runes.length > 80 ||
        message.runes.length > 500) {
      setState(
        () => error = _t(
          context,
          'Choose a recipient and enter a title and message.',
          'Recipient തിരഞ്ഞെടുത്ത് title-ഉം message-ഉം നൽകുക.',
        ),
      );
      return;
    }
    final destination = allUsers
        ? _t(context, 'all active users', 'എല്ലാ active users')
        : (selected!['email'] as String? ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t(context, 'Send notification?', 'Notification അയയ്ക്കണോ?'),
        ),
        content: Text(
          _t(context, 'Send to $destination?', '$destination-ന് അയയ്ക്കണോ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t(context, 'Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t(context, 'Send', 'അയയ്ക്കുക')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || sending) return;
    final target = allUsers ? null : selected!['id'] as String;
    final payload = jsonEncode([target, heading, message, inApp, push]);
    if (lastPayload != payload) {
      lastPayload = payload;
      requestId = _requestId();
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final count = await widget.gateway.send(
        requestId!,
        target,
        heading,
        message, inApp: inApp, push: push,
      );
      if (!mounted) return;
      setState(() {
        title.clear();
        body.clear();
        requestId = null;
        lastPayload = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'Queued for $count users.',
              '$count users-ന് അയയ്ക്കാൻ തയ്യാറാക്കി.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = _t(
            context,
            'Could not confirm sending. Retry without changing the message.',
            'അയച്ചത് സ്ഥിരീകരിക്കാനായില്ല. Message മാറ്റാതെ വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t(context, 'Send notification', 'Notification അയയ്ക്കുക')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _t(
                context,
                'Choose one user or all active users. Push notifications reach devices that have enabled them.',
                'ഒരു user-നെയോ എല്ലാ active users-നെയോ തിരഞ്ഞെടുക്കുക. Push enable ചെയ്ത devices-ലാണ് notification ലഭിക്കുക.',
              ),
            ),
            CheckboxListTile(title: const Text('In-app notification'), value: inApp,
              onChanged: sending || !widget.canEdit ? null : (v) => setState(() => inApp = v!)),
            CheckboxListTile(title: const Text('Push notification'), value: push,
              onChanged: sending || !widget.canEdit ? null : (v) => setState(() => push = v!)),
            SwitchListTile(
              title: Text(_t(context, 'All users', 'എല്ലാ users')),
              value: allUsers,
              onChanged: sending || !widget.canEdit
                  ? null
                  : (value) => setState(() {
                      allUsers = value;
                      selected = null;
                    }),
            ),
            if (!allUsers) ...[
              if (selected != null)
                Text(
                  _t(
                    context,
                    'Selected: ${selected!['email']}',
                    'തിരഞ്ഞെടുത്തത്: ${selected!['email']}',
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('notification_user_search'),
                      controller: query,
                      maxLength: 100,
                      enabled: !sending && widget.canEdit,
                      onSubmitted: (_) => findUsers(newSearch: true),
                      decoration: InputDecoration(
                        labelText: _t(
                          context,
                          'Name, email or user ID',
                          'പേര്, email അല്ലെങ്കിൽ user ID',
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _t(context, 'Search', 'തിരയുക'),
                    onPressed: loading || sending || !widget.canEdit
                        ? null
                        : () => findUsers(newSearch: true),
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              if (loading) const LinearProgressIndicator(),
              for (final user in users)
                ListTile(
                  selected: selected?['id'] == user['id'],
                  leading: Icon(
                    selected?['id'] == user['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: sending || !widget.canEdit
                      ? null
                      : () => setState(() => selected = user),
                  title: Text(
                    (user['display_name'] as String?)?.isNotEmpty == true
                        ? user['display_name'] as String
                        : user['email'] as String? ?? '',
                  ),
                  subtitle: Text(
                    '${user['email'] ?? ''} · ${user['public_id'] ?? ''}',
                  ),
                ),
              Row(
                children: [
                  TextButton(
                    onPressed: offset > 0 && !loading
                        ? () => findUsers(nextOffset: offset - 25)
                        : null,
                    child: Text(_t(context, 'Previous', 'മുമ്പത്തെ')),
                  ),
                  TextButton(
                    onPressed: users.length == 25 && !loading
                        ? () => findUsers(nextOffset: offset + 25)
                        : null,
                    child: Text(_t(context, 'Next', 'അടുത്തത്')),
                  ),
                ],
              ),
            ],
            TextField(
              key: const Key('notification_title'),
              controller: title,
              enabled: widget.canEdit && !sending,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _t(context, 'Title', 'Title'),
              ),
            ),
            TextField(
              key: const Key('notification_body'),
              controller: body,
              enabled: widget.canEdit && !sending,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: _t(context, 'Message', 'Message'),
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('submit_notification'),
              onPressed: widget.canEdit && !sending ? send : null,
              child: Text(
                _t(context, 'Send notification', 'Notification അയയ്ക്കുക'),
              ),
            ),
            if (sending) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}
