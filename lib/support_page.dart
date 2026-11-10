import 'package:flutter/material.dart';

import 'design.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

String supportText(BuildContext c, String en, String ml) =>
    Localizations.localeOf(c).languageCode == 'ml' ? ml : en;

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.client, this.loadTickets});
  final SupabaseClient client;
  final Future<List<dynamic>> Function()? loadTickets;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late Future<List<dynamic>> tickets;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    tickets =
        widget.loadTickets?.call() ??
        widget.client.rpc('support_my_tickets').then((v) => v as List<dynamic>);
  }

  void refresh() => setState(load);
  Future<void> create() async {
    final subject = TextEditingController(), message = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          supportText(c, 'New support ticket', 'പുതിയ support ticket'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subject,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: supportText(c, 'Subject', 'വിഷയം'),
              ),
            ),
            TextField(
              controller: message,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: supportText(c, 'Message', 'സന്ദേശം'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(supportText(c, 'Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () {
              if (subject.text.trim().isNotEmpty &&
                  message.text.trim().isNotEmpty) {
                Navigator.pop(c, [subject.text.trim(), message.text.trim()]);
              }
            },
            child: Text(supportText(c, 'Send', 'അയയ്ക്കുക')),
          ),
        ],
      ),
    );
    subject.dispose();
    message.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.client.rpc(
        'support_create_ticket',
        params: {'p_subject': result[0], 'p_body': result[1]},
      );
      if (mounted) refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supportText(
                context,
                'Unable to send ticket.',
                'Ticket അയയ്ക്കാനായില്ല.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(supportText(context, 'Support', 'സഹായം')),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: supportText(context, 'Refresh', 'പുതുക്കുക'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: create,
      icon: const Icon(Icons.add),
      label: Text(supportText(context, 'New ticket', 'പുതിയ ticket')),
    ),
    body: FutureBuilder<List<dynamic>>(
      future: tickets,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Text(
              supportText(c, 'Unable to load tickets.', 'Tickets ലഭ്യമല്ല.'),
            ),
          );
        }
        final rows = s.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: GrowthEmpty(
                art: 'support',
                artHeight: 220,
                title: supportText(
                  c,
                  'No support tickets yet.',
                  'ഇതുവരെ support tickets ഇല്ല.',
                ),
                subtitle: supportText(
                  c,
                  'Create a new support ticket if you need any assistance.',
                  'സഹായത്തിനായി ഒരു പുതിയ ticket സൃഷ്ടിക്കുക.',
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          itemBuilder: (c, i) {
            final r = rows[i] as Map;
            return Card(
              child: ListTile(
                title: Text('${r['subject']}'),
                subtitle: Text('${r['status']} · ${r['updated_at']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    c,
                    MaterialPageRoute<void>(
                      builder: (_) => SupportConversation(
                        client: widget.client,
                        id: r['id'] as String,
                        subject: r['subject'] as String,
                        open: r['status'] == 'open',
                      ),
                    ),
                  );
                  if (mounted) refresh();
                },
              ),
            );
          },
        );
      },
    ),
  );
}

class SupportConversation extends StatefulWidget {
  const SupportConversation({
    super.key,
    required this.client,
    required this.id,
    required this.subject,
    required this.open,
    this.admin = false,
  });
  final SupabaseClient client;
  final String id, subject;
  final bool open, admin;
  @override
  State<SupportConversation> createState() => _SupportConversationState();
}

class _SupportConversationState extends State<SupportConversation> {
  final message = TextEditingController();
  late Future<List<dynamic>> data;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = widget.client
        .rpc('support_messages', params: {'p_ticket': widget.id})
        .then((v) => v as List<dynamic>);
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || message.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'support_reply',
        params: {'p_ticket': widget.id, 'p_body': message.text.trim()},
      );
      message.clear();
      if (mounted) setState(load);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supportText(
                context,
                'Unable to send message.',
                'സന്ദേശം അയയ്ക്കാനായില്ല.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.subject),
      actions: [
        IconButton(
          onPressed: () => setState(load),
          icon: const Icon(Icons.refresh),
          tooltip: supportText(context, 'Refresh', 'പുതുക്കുക'),
        ),
      ],
    ),
    body: Column(
      children: [
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
                    supportText(
                      c,
                      'Unable to load messages.',
                      'സന്ദേശങ്ങൾ ലഭ്യമല്ല.',
                    ),
                  ),
                );
              }
              return ListView(
                children: [
                  for (final item in s.data ?? [])
                    Card(
                      child: ListTile(
                        title: Text('${item['body']}'),
                        subtitle: Text(
                          '${item['is_admin'] == true ? supportText(c, 'Admin', 'Admin') : supportText(c, 'Member', 'അംഗം')} · ${item['created_at']}',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (widget.open)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: supportText(context, 'Reply', 'മറുപടി'),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : send,
                  child: Text(supportText(context, 'Send', 'അയയ്ക്കുക')),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
