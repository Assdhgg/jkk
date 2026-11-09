import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';
import 'design.dart';

String uf(BuildContext c, String en, String ml) => supportText(c, en, ml);

String submissionStatus(BuildContext context, String status) =>
    switch (status) {
      'pending' => uf(context, 'Pending', 'പരിശോധനയിൽ'),
      'approved' => uf(context, 'Approved', 'അംഗീകരിച്ചു'),
      'rejected' => uf(context, 'Rejected', 'നിരസിച്ചു'),
      'withdrawn' => uf(context, 'Withdrawn', 'പിൻവലിച്ചു'),
      'cancelled' => uf(context, 'Cancelled', 'റദ്ദാക്കി'),
      _ => uf(context, 'Earlier submission', 'പഴയ submission'),
    };

class SubmissionHistoryPage extends StatefulWidget {
  const SubmissionHistoryPage({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<SubmissionHistoryPage> createState() => _SubmissionHistoryPageState();
}

class _SubmissionHistoryPageState extends State<SubmissionHistoryPage> {
  final query = TextEditingController();
  String? status;
  DateTimeRange? range;
  int offset = 0;
  late Future<List<dynamic>> data;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void load() {
    data = widget.client
        .rpc(
          'user_submission_history',
          params: {
            'p_status': status,
            'p_query': query.text.trim(),
            'p_from': range == null
                ? null
                : DateTime.utc(
                    range!.start.year,
                    range!.start.month,
                    range!.start.day,
                  ).toIso8601String(),
            'p_to': range == null
                ? null
                : DateTime.utc(
                    range!.end.year,
                    range!.end.month,
                    range!.end.day + 1,
                  ).toIso8601String(),
            'p_offset': offset,
            'p_limit': 50,
          },
        )
        .then((v) => v as List<dynamic>);
  }

  void refresh({bool reset = false}) => setState(() {
    if (reset) offset = 0;
    load();
  });
  Future<void> chooseDates() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: range,
    );
    if (value != null && mounted) {
      setState(() {
        range = value;
        offset = 0;
        load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uf(context, 'Submission history', 'Submission ചരിത്രം')),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: uf(context, 'Refresh', 'പുതുക്കുക'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: query,
                    maxLength: 100,
                    onSubmitted: (_) => refresh(reset: true),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: uf(
                        context,
                        'Search action or link',
                        'Action അല്ലെങ്കിൽ link തിരയുക',
                      ),
                      counterText: '',
                      suffixIcon: IconButton(
                        onPressed: () => refresh(reset: true),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: status,
                        hint: Text(
                          uf(context, 'All statuses', 'എല്ലാ നിലകളും'),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              uf(context, 'All statuses', 'എല്ലാ നിലകളും'),
                            ),
                          ),
                          for (final v in [
                            'pending',
                            'approved',
                            'rejected',
                            'withdrawn',
                            'cancelled',
                            'legacy',
                          ])
                            DropdownMenuItem(
                              value: v,
                              child: Text(submissionStatus(context, v)),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          status = v;
                          offset = 0;
                          load();
                        }),
                      ),
                      OutlinedButton.icon(
                        onPressed: chooseDates,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          range == null
                              ? uf(
                                  context,
                                  'Date range (UTC)',
                                  'തീയതി പരിധി (UTC)',
                                )
                              : '${range!.start.toIso8601String().substring(0, 10)} – ${range!.end.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                      if (range != null)
                        TextButton(
                          onPressed: () => setState(() {
                            range = null;
                            offset = 0;
                            load();
                          }),
                          child: Text(
                            uf(context, 'Clear dates', 'തീയതി മായ്ക്കുക'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
                        uf(c, 'Unable to load history.', 'ചരിത്രം ലഭ്യമല്ല.'),
                      ),
                    );
                  }
                  final rows = s.data ?? [];
                  return Column(
                    children: [
                      Expanded(
                        child: rows.isEmpty
                            ? Center(
                                child: Text(
                                  uf(
                                    c,
                                    'No submissions found.',
                                    'Submissions കണ്ടെത്തിയില്ല.',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: rows.length,
                                itemBuilder: (c, i) {
                                  final r = rows[i] as Map;
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                        '${r['action_type']} · ${submissionStatus(c, r['status'] as String)}',
                                      ),
                                      subtitle: Text(
                                        '${r['campaign_link']}\n${r['submitted_at']}${r['rejection_reason'] == null ? '' : '\n${uf(c, 'Reason', 'കാരണം')}: ${r['rejection_reason']}'}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: offset > 0
                                ? () => setState(() {
                                    offset -= 50;
                                    load();
                                  })
                                : null,
                            child: Text(uf(c, 'Previous', 'മുമ്പത്തെ')),
                          ),
                          Text(
                            '${offset + (rows.isEmpty ? 0 : 1)}–${offset + rows.length}',
                          ),
                          TextButton(
                            onPressed: rows.length == 50
                                ? () => setState(() {
                                    offset += 50;
                                    load();
                                  })
                                : null,
                            child: Text(uf(c, 'Next', 'അടുത്തത്')),
                          ),
                        ],
                      ),
                    ],
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

class UserHelpPage extends StatelessWidget {
  const UserHelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final items = <String, String>{
      uf(context, 'Coins and campaigns', 'Coins, campaigns'): uf(
        context,
        'Coins are reserved when you create a campaign. Unused coins are refunded when it is cancelled.',
        'Campaign തുടങ്ങുമ്പോൾ coins മാറ്റിവയ്ക്കും. റദ്ദാക്കുമ്പോൾ ഉപയോഗിക്കാത്ത coins തിരികെ ലഭിക്കും.',
      ),
      uf(context, 'Submit a task', 'Task സമർപ്പിക്കുക'): uf(
        context,
        'Complete the action, enter your Instagram username and provide the relevant screenshot. The campaign owner reviews it.',
        'Action പൂർത്തിയാക്കി Instagram username-ഉം അനുയോജ്യമായ screenshot-ഉം നൽകുക. Campaign ഉടമ പരിശോധിക്കും.',
      ),
      uf(context, 'PIN and approval', 'PIN, approval'): uf(
        context,
        'Set your coin release PIN in Profile using email OTP. The PIN is required when approving submissions.',
        'Profile-ൽ email OTP ഉപയോഗിച്ച് coin release PIN സജ്ജമാക്കുക. Submission approve ചെയ്യാൻ PIN ആവശ്യമാണ്.',
      ),
      uf(context, 'Saved tasks', 'Saved tasks'): uf(
        context,
        'Saving a task helps you find it later. It does not reserve the task.',
        'Task save ചെയ്താൽ പിന്നീട് കണ്ടെത്താം. അത് task reserve ചെയ്യില്ല.',
      ),
      uf(context, 'Need help?', 'സഹായം വേണോ?'): uf(
        context,
        'Open Support in Profile to send a ticket to the administrators.',
        'Administrators-നെ ബന്ധപ്പെടാൻ Profile-ലെ Support തുറക്കുക.',
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(uf(context, 'Help & guide', 'സഹായവും മാർഗ്ഗനിർദ്ദേശവും')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GrowthHero(
                title: uf(context, 'Need Help?', 'സഹായം വേണോ?'),
                subtitle: uf(
                  context,
                  'We are here to help you!',
                  'നിങ്ങളെ സഹായിക്കാൻ ഞങ്ങൾ ഇവിടെയുണ്ട്!',
                ),
                icon: Icons.support_agent_rounded,
              ),
              const SizedBox(height: 16),
              for (final item in items.entries)
                Card(
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: growthPurple,
                    ),
                    title: Text(
                      item.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(item.value),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
