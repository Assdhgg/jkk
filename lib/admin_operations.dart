import 'dart:async';

import 'admin_design.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';

String op(BuildContext c, String en, String ml) => supportText(c, en, ml);
Future<bool> verifyAdminMfa(BuildContext context, SupabaseClient client) async {
  final factors = await client.auth.mfa.listFactors();
  final available = [...factors.totp, ...factors.phone];
  if (available.isEmpty) return factors.webauthn.isEmpty;
  final challenge = await client.auth.mfa.challenge(
    factorId: available.first.id,
  );
  if (!context.mounted) return false;
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(op(c, 'Verify administrator', 'Admin verification')),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        obscureText: true,
        decoration: InputDecoration(
          labelText: op(c, 'Authenticator code', 'Authenticator code'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(op(c, 'Cancel', 'റദ്ദാക്കുക')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: Text(op(c, 'Verify', 'സ്ഥിരീകരിക്കുക')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (code == null || code.isEmpty) return false;
  await client.auth.mfa.verify(
    factorId: available.first.id,
    challengeId: challenge.id,
    code: code,
  );
  return true;
}

class AdminOperationsPage extends StatefulWidget {
  const AdminOperationsPage({
    super.key,
    required this.client,
    required this.canEdit,
    this.initialPage = 'tickets',
  });
  final SupabaseClient client;
  final bool canEdit;
  final String initialPage;
  @override
  State<AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<AdminOperationsPage> {
  String page = 'tickets';
  String metric = 'registrations';
  late Future<List<dynamic>> data;
  bool busy = false;
  final noteId = TextEditingController();
  String noteType = 'user';
  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    load();
  }

  @override
  void dispose() {
    noteId.dispose();
    super.dispose();
  }

  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void load() {
    final now = DateTime.now().toUtc();
    final rpc = switch (page) {
      'tickets' => 'admin_support_tickets',
      'inbox' => 'admin_event_feed',
      'reports' => 'admin_campaign_reports',
      'coins' => 'admin_adjustments',
      'alerts' => 'admin_alert_settings',
      'trends' => 'admin_daily_report',
      'notes' => 'admin_notes',
      _ => '',
    };
    if (page == 'security' || (page == 'notes' && noteId.text.trim().isEmpty)) {
      data = Future.value([]);
      return;
    }
    final params = page == 'trends'
        ? {
            'p_from': day(now.subtract(const Duration(days: 29))),
            'p_to': day(now),
          }
        : page == 'notes'
        ? {'p_type': noteType, 'p_id': noteId.text.trim()}
        : <String, dynamic>{};
    if (page == 'inbox') {
      data =
          Future.wait([
            widget.client.rpc('admin_event_feed'),
            widget.client.rpc('admin_alerts'),
          ]).then(
            (values) => [
              ...(values[1] as List).map(
                (a) => {
                  'kind': 'alert: ${a['kind']}',
                  'subject_id': a['subject'],
                  'created_at': a['observed_at'],
                  'read': true,
                },
              ),
              ...(values[0] as List),
            ],
          );
    } else {
      data = widget.client
          .rpc(rpc, params: params)
          .then((v) => v as List<dynamic>);
    }
  }

  void refresh() => setState(load);
  void select(String value) => setState(() {
    page = value;
    load();
  });
  Future<void> call(String rpc, Map<String, dynamic> params) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.client.rpc(rpc, params: params);
      if (mounted) refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              op(
                context,
                'Unable to complete action. Check access and try again.',
                'പ്രവർത്തനം പൂർത്തിയാക്കാനായില്ല. Access പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(op(c, 'Cancel', 'റദ്ദാക്കുക')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(op(c, 'Confirm', 'സ്ഥിരീകരിക്കുക')),
            ),
          ],
        ),
      ) ??
      false;
  Future<List<String>?> fields(
    String title,
    List<String> labels, {
    List<String>? initial,
  }) async {
    final controllers = List.generate(
      labels.length,
      (i) => TextEditingController(text: initial == null ? '' : initial[i]),
    );
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                TextField(
                  controller: controllers[i],
                  maxLength: i == labels.length - 1 ? 1000 : 100,
                  decoration: InputDecoration(labelText: labels[i]),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(op(c, 'Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () {
              final vals = controllers.map((x) => x.text.trim()).toList();
              if (vals.every((v) => v.isNotEmpty)) Navigator.pop(c, vals);
            },
            child: Text(op(c, 'Continue', 'തുടരുക')),
          ),
        ],
      ),
    );
    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }

  Future<void> requestCoin() async {
    final v = await fields(
      op(context, 'Request coin correction', 'Coin correction അപേക്ഷ'),
      [
        op(context, 'User ID', 'User ID'),
        op(context, 'Amount (+ or -)', 'Amount (+ or -)'),
        op(context, 'Reason', 'കാരണം'),
      ],
    );
    if (v == null || !mounted) return;
    final amount = int.tryParse(v[1]);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            op(context, 'Enter a valid amount.', 'ശരിയായ amount നൽകുക.'),
          ),
        ),
      );
      return;
    }
    await call('admin_request_adjustment', {
      'p_user': v[0],
      'p_amount': amount,
      'p_reason': v[2],
    });
  }

  Future<void> setThreshold(Map r) async {
    final v = await fields(
      op(context, 'Edit threshold', 'Threshold മാറ്റുക'),
      [op(context, 'Value', 'Value')],
      initial: ['${r['value']}'],
    );
    if (v == null || !mounted) return;
    final value = int.tryParse(v[0]);
    if (value == null) return;
    await call('admin_set_alert_setting', {
      'p_key': r['key'],
      'p_value': value,
    });
  }

  Future<void> addNote() async {
    final id = noteId.text.trim();
    if (id.isEmpty) return;
    final v = await fields(
      op(context, 'Add admin note', 'Admin note ചേർക്കുക'),
      [op(context, 'Note', 'കുറിപ്പ്')],
    );
    if (v != null && mounted) {
      await call('admin_add_note', {
        'p_type': noteType,
        'p_id': id,
        'p_body': v[0],
      });
    }
  }

  Future<void> enroll() async {
    String? pendingFactor;
    try {
      final result = await widget.client.auth.mfa.enroll(
        friendlyName: 'Freelan Space admin',
      );
      pendingFactor = result.id;
      if (!mounted) {
        await widget.client.auth.mfa.unenroll(result.id);
        return;
      }
      final code = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(
            op(c, 'Set up authenticator', 'Authenticator സജ്ജമാക്കുക'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op(
                    c,
                    'Add this secret to your authenticator app. Keep it private.',
                    'ഈ secret authenticator app-ൽ ചേർക്കുക. ഇത് സ്വകാര്യമായി സൂക്ഷിക്കുക.',
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(result.totp?.secret ?? ''),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: op(
                      c,
                      'Authenticator code',
                      'Authenticator code',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(op(c, 'Cancel', 'റദ്ദാക്കുക')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, code.text.trim()),
              child: Text(op(c, 'Verify', 'സ്ഥിരീകരിക്കുക')),
            ),
          ],
        ),
      );
      code.dispose();
      if (entered == null || entered.isEmpty) {
        await widget.client.auth.mfa.unenroll(result.id);
        pendingFactor = null;
        return;
      }
      await widget.client.auth.mfa.challengeAndVerify(
        factorId: result.id,
        code: entered,
      );
      pendingFactor = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              op(
                context,
                'Authenticator enabled.',
                'Authenticator പ്രവർത്തനക്ഷമമാക്കി.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (pendingFactor != null) {
        try {
          await widget.client.auth.mfa.unenroll(pendingFactor);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              op(
                context,
                'Authenticator setup failed.',
                'Authenticator setup പരാജയപ്പെട്ടു.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = <String, String>{
      'tickets': op(context, 'Support', 'സഹായം'),
      'inbox': op(context, 'Notifications', 'അറിയിപ്പുകൾ'),
      'reports': op(context, 'Campaign reports', 'Campaign reports'),
      'coins': op(context, 'Coin requests', 'Coin അപേക്ഷകൾ'),
      'alerts': op(context, 'Alert settings', 'Alert settings'),
      'trends': op(context, 'Analytics', 'Analytics'),
      'notes': op(context, 'Admin notes', 'Admin notes'),
      'security': op(context, 'Security', 'സുരക്ഷ'),
    };
    return Scaffold(
      appBar: AdminPageBar(
        title: op(context, 'Admin operations', 'Admin പ്രവർത്തനങ്ങൾ'),
        icon: Icons.settings,
        desktop: MediaQuery.sizeOf(context).width >= 1100,
        subtitle: op(
          context,
          'Manage platform operations and configurations.',
          'Platform operations നിയന്ത്രിക്കുക.',
        ),
        actions: [
          IconButton(
            onPressed: refresh,
            tooltip: op(context, 'Refresh', 'പുതുക്കുക'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 1000,
          ),
          child: Column(
            children: [
              if (MediaQuery.sizeOf(context).width >= 1100)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final (index, e) in labels.entries.indexed)
                          SizedBox(
                            width: (constraints.maxWidth - 36) / 4,
                            child: Card(
                              child: ListTile(
                                selected: page == e.key,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xffeee6fc),
                                  child: Icon(
                                    [
                                      Icons.support_agent,
                                      Icons.notifications,
                                      Icons.bar_chart,
                                      Icons.toll,
                                      Icons.notification_important,
                                      Icons.show_chart,
                                      Icons.note,
                                      Icons.lock,
                                    ][index],
                                    color: adminAccent,
                                  ),
                                ),
                                title: Text(
                                  e.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: adminAccent,
                                ),
                                onTap: () => select(e.key),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final e in labels.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: page == e.key,
                            onSelected: (_) => select(e.key),
                          ),
                        ),
                    ],
                  ),
                ),
              if (page == 'trends')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButton<String>(
                    value: metric,
                    items: [
                      DropdownMenuItem(
                        value: 'registrations',
                        child: Text(
                          op(context, 'Registrations', 'രജിസ്ട്രേഷനുകൾ'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'campaigns',
                        child: Text(op(context, 'Campaigns', 'Campaigns')),
                      ),
                      DropdownMenuItem(
                        value: 'coins_credited',
                        child: Text(
                          op(context, 'Coins credited', 'ലഭിച്ച coins'),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => metric = value ?? 'registrations'),
                  ),
                ),
              if (page == 'notes')
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: noteType,
                        items: [
                          DropdownMenuItem(
                            value: 'user',
                            child: Text(op(context, 'User', 'User')),
                          ),
                          DropdownMenuItem(
                            value: 'campaign',
                            child: Text(op(context, 'Campaign', 'Campaign')),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          noteType = v ?? 'user';
                          load();
                        }),
                      ),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: noteId,
                          decoration: InputDecoration(
                            labelText: op(
                              context,
                              'User or campaign ID',
                              'User അല്ലെങ്കിൽ campaign ID',
                            ),
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: refresh,
                        child: Text(op(context, 'Load', 'കാണുക')),
                      ),
                      if (widget.canEdit)
                        FilledButton(
                          onPressed: addNote,
                          child: Text(op(context, 'Add note', 'Note ചേർക്കുക')),
                        ),
                    ],
                  ),
                ),
              if (page == 'coins' && widget.canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: requestCoin,
                      icon: const Icon(Icons.add),
                      label: Text(
                        op(context, 'Request correction', 'Correction അപേക്ഷ'),
                      ),
                    ),
                  ),
                ),
              if (page == 'security')
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        op(
                          context,
                          'Authenticator verification',
                          'Authenticator verification',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        op(
                          context,
                          'Enroll an authenticator to require a code for administrator access.',
                          'Admin access-ന് code ആവശ്യമായി വരാൻ authenticator ചേർക്കുക.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: busy ? null : enroll,
                        child: Text(
                          op(
                            context,
                            'Set up authenticator',
                            'Authenticator സജ്ജമാക്കുക',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () async {
                          if (await confirm(
                            op(
                              context,
                              'Sign out other sessions?',
                              'മറ്റ് sessions sign out ചെയ്യണോ?',
                            ),
                          )) {
                            try {
                              await widget.client.auth.signOut(
                                scope: SignOutScope.others,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      op(
                                        context,
                                        'Other sessions signed out.',
                                        'മറ്റ് sessions sign out ചെയ്തു.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      op(
                                        context,
                                        'Unable to sign out sessions.',
                                        'Sessions sign out ചെയ്യാനായില്ല.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Text(
                          op(
                            context,
                            'Sign out other sessions',
                            'മറ്റ് sessions sign out ചെയ്യുക',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: data,
                    builder: (c, s) {
                      if (s.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (s.hasError) {
                        return Center(
                          child: Text(
                            op(c, 'Unable to load data.', 'വിവരങ്ങൾ ലഭ്യമല്ല.'),
                          ),
                        );
                      }
                      final rows = s.data ?? [];
                      if (rows.isEmpty) {
                        return AdminEmptyState(
                          title: op(
                            c,
                            'No records found.',
                            'വിവരങ്ങൾ കണ്ടെത്തിയില്ല.',
                          ),
                          art: 'operations_empty',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (c, i) {
                          final r = rows[i] as Map;
                          if (page == 'tickets') {
                            return Card(
                              child: ListTile(
                                title: Text('${r['subject']}'),
                                subtitle: Text(
                                  '${r['email']} · ${r['status']}',
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    c,
                                    MaterialPageRoute<void>(
                                      builder: (_) => SupportConversation(
                                        client: widget.client,
                                        id: r['id'],
                                        subject: r['subject'],
                                        open:
                                            r['status'] == 'open' &&
                                            widget.canEdit,
                                        admin: true,
                                      ),
                                    ),
                                  );
                                  if (mounted) refresh();
                                },
                                trailing:
                                    widget.canEdit && r['status'] == 'open'
                                    ? IconButton(
                                        tooltip: op(
                                          c,
                                          'Close ticket',
                                          'Ticket അടയ്ക്കുക',
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        onPressed: () async {
                                          if (await confirm(
                                            op(
                                              context,
                                              'Close this ticket?',
                                              'Ticket അടയ്ക്കണോ?',
                                            ),
                                          )) {
                                            await call('admin_close_ticket', {
                                              'p_ticket': r['id'],
                                            });
                                          }
                                        },
                                      )
                                    : null,
                              ),
                            );
                          }
                          if (page == 'inbox') {
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  r['read'] == true
                                      ? Icons.notifications_none
                                      : Icons.notifications_active_outlined,
                                ),
                                title: Text('${r['kind']}'),
                                subtitle: Text(
                                  '${r['subject_id']} · ${r['created_at']}',
                                ),
                                trailing: r['read'] == true
                                    ? null
                                    : TextButton(
                                        onPressed: () => call(
                                          'admin_mark_event_read',
                                          {'p_id': r['id']},
                                        ),
                                        child: Text(
                                          op(c, 'Mark read', 'വായിച്ചു'),
                                        ),
                                      ),
                              ),
                            );
                          }
                          if (page == 'reports') {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r['reason']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Campaign: ${r['campaign_id']} · ${r['status']}',
                                    ),
                                    if (widget.canEdit && r['status'] == 'open')
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              if (await confirm(
                                                op(
                                                  context,
                                                  'Dismiss report?',
                                                  'Report ഒഴിവാക്കണോ?',
                                                ),
                                              )) {
                                                await call(
                                                  'admin_resolve_report',
                                                  {
                                                    'p_report': r['id'],
                                                    'p_cancel': false,
                                                  },
                                                );
                                              }
                                            },
                                            child: Text(
                                              op(c, 'Dismiss', 'ഒഴിവാക്കുക'),
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () async {
                                              if (await confirm(
                                                op(
                                                  context,
                                                  'Cancel campaign and refund remaining coins?',
                                                  'Campaign റദ്ദാക്കി ബാക്കി coins തിരികെ നൽകണോ?',
                                                ),
                                              )) {
                                                await call(
                                                  'admin_resolve_report',
                                                  {
                                                    'p_report': r['id'],
                                                    'p_cancel': true,
                                                  },
                                                );
                                              }
                                            },
                                            child: Text(
                                              op(
                                                c,
                                                'Cancel & refund',
                                                'റദ്ദാക്കി refund ചെയ്യുക',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (page == 'coins') {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r['amount']} coins · ${r['status']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'User: ${r['user_id']}\n${r['reason']}\nRequested: ${r['requester_id']}',
                                    ),
                                    if (widget.canEdit &&
                                        r['status'] == 'pending' &&
                                        r['requester_id'] !=
                                            widget.client.auth.currentUser?.id)
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              if (await confirm(
                                                op(
                                                  context,
                                                  'Reject correction?',
                                                  'Correction നിരസിക്കണോ?',
                                                ),
                                              )) {
                                                await call(
                                                  'admin_decide_adjustment',
                                                  {
                                                    'p_id': r['id'],
                                                    'p_approve': false,
                                                  },
                                                );
                                              }
                                            },
                                            child: Text(
                                              op(c, 'Reject', 'നിരസിക്കുക'),
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () async {
                                              if (await confirm(
                                                op(
                                                  context,
                                                  'Approve coin correction?',
                                                  'Coin correction അനുവദിക്കണോ?',
                                                ),
                                              )) {
                                                await call(
                                                  'admin_decide_adjustment',
                                                  {
                                                    'p_id': r['id'],
                                                    'p_approve': true,
                                                  },
                                                );
                                              }
                                            },
                                            child: Text(
                                              op(c, 'Approve', 'അനുവദിക്കുക'),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (page == 'alerts') {
                            return Card(
                              child: ListTile(
                                title: Text(switch (r['key']) {
                                  'pending_hours' => op(
                                    c,
                                    'Pending submission hours',
                                    'Pending submission മണിക്കൂറുകൾ',
                                  ),
                                  'coins_24h' => op(
                                    c,
                                    'Coins credited in 24 hours',
                                    '24 മണിക്കൂറിൽ ലഭിച്ച coins',
                                  ),
                                  'referrals_24h' => op(
                                    c,
                                    'Referrals in 24 hours',
                                    '24 മണിക്കൂറിലെ referrals',
                                  ),
                                  _ => '${r['key']}',
                                }),
                                subtitle: Text('${r['value']}'),
                                trailing: widget.canEdit
                                    ? IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: op(c, 'Edit', 'മാറ്റുക'),
                                        onPressed: () => setThreshold(r),
                                      )
                                    : null,
                              ),
                            );
                          }
                          if (page == 'notes') {
                            return Card(
                              child: ListTile(
                                title: Text('${r['body']}'),
                                subtitle: Text(
                                  '${r['author']} · ${r['created_at']}',
                                ),
                              ),
                            );
                          }
                          final maximum = rows.fold<int>(1, (a, b) {
                            final n = (b[metric] as num).toInt();
                            return n > a ? n : a;
                          });
                          final amount = (r[metric] as num).toInt();
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r['day']} · $amount',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: amount / maximum,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${op(c, 'Campaigns', 'Campaigns')}: ${r['campaigns']} · ${op(c, 'Coins credited', 'ലഭിച്ച coins')}: ${r['coins_credited']}',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminNotificationButton extends StatefulWidget {
  const AdminNotificationButton({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminNotificationButton> createState() =>
      _AdminNotificationButtonState();
}

class _AdminNotificationButtonState extends State<AdminNotificationButton> {
  Timer? timer;
  int count = 0;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        widget.client.rpc('admin_event_feed'),
        widget.client.rpc('admin_alerts'),
      ]);
      final events = results[0] as List;
      final alerts = results[1] as List;
      final total =
          events.where((e) => e['read'] != true).length + alerts.length;
      if (mounted) setState(() => count = total);
    } catch (_) {
      if (mounted) setState(() => count = 0);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AdminOperationsPage(
            client: widget.client,
            canEdit: widget.canEdit,
            initialPage: 'inbox',
          ),
        ),
      );
      if (mounted) refresh();
    },
    icon: Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: const Icon(Icons.notifications_outlined),
    ),
    label: Text(op(context, 'Notifications', 'അറിയിപ്പുകൾ')),
  );
}
