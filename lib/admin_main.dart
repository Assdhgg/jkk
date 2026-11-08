import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

const labels = <String, List<String>>{
  'setup': ['Connect project', 'Project ബന്ധിപ്പിക്കുക'],
  'url': ['Supabase project URL', 'Supabase project URL'],
  'key': ['Publishable or anon key', 'Publishable അല്ലെങ്കിൽ anon key'],
  'connect': ['Connect', 'ബന്ധിപ്പിക്കുക'],
  'configHelp': [
    'Use the project URL and public key. Never enter a service-role or secret key.',
    'Project URL-ഉം public key-ഉം നൽകുക. Service-role അല്ലെങ്കിൽ secret key നൽകരുത്.',
  ],
  'invalidConfig': [
    'Enter an HTTPS project URL and a publishable or anon key.',
    'HTTPS project URL-ഉം publishable അല്ലെങ്കിൽ anon key-ഉം നൽകുക.',
  ],
  'signIn': ['Administrator sign in', 'Administrator ലോഗിൻ'],
  'email': ['Email', 'ഇമെയിൽ'],
  'password': ['Password', 'പാസ്‌വേഡ്'],
  'login': ['Sign in', 'ലോഗിൻ'],
  'changeProject': ['Change project', 'Project മാറ്റുക'],
  'unauthorized': [
    'This account does not have administrator access.',
    'ഈ അക്കൗണ്ടിന് administrator access ഇല്ല.',
  ],
  'loginError': [
    'Sign in failed. Check your credentials and connection.',
    'ലോഗിൻ പരാജയപ്പെട്ടു. വിവരങ്ങളും internet-ഉം പരിശോധിക്കുക.',
  ],
  'users': ['Users', 'ഉപയോക്താക്കൾ'],
  'campaigns': ['Campaigns', 'Campaign-ുകൾ'],
  'submissions': ['Pending submissions', 'പരിശോധിക്കാനുള്ള submissions'],
  'inspect': ['Inspect', 'പരിശോധിക്കുക'],
  'inspecting': ['Inspect submission', 'Submission പരിശോധിക്കുക'],
  'reviewNotice': [
    'The participant sees when an administrator is checking. The campaign owner makes the decision.',
    'Administrator പരിശോധിക്കുമ്പോൾ participant-ന് കാണാം. തീരുമാനം campaign ഉടമയാണ് എടുക്കുന്നത്.',
  ],
  'submissionEmpty': [
    'No pending submissions.',
    'പരിശോധിക്കാനുള്ള submissions ഇല്ല.',
  ],
  'submissionFailure': [
    'Unable to load the submission. It may no longer be pending.',
    'Submission ലഭ്യമല്ല. അത് പരിശോധിച്ചു കഴിഞ്ഞിരിക്കാം.',
  ],
  'close': ['Close', 'അടയ്ക്കുക'],
  'instagramUsername': ['Instagram username', 'Instagram username'],
  'allActions': ['All actions', 'എല്ലാ actions'],
  'allStatuses': ['All statuses', 'എല്ലാ നിലകളും'],
  'completed': ['Completed', 'പൂർത്തിയായി'],
  'cancelled': ['Cancelled', 'റദ്ദാക്കി'],
  'campaignEmpty': ['No campaigns found.', 'Campaign-ുകൾ കണ്ടെത്തിയില്ല.'],
  'campaignFailure': [
    'Unable to load campaigns.',
    'Campaign-ുകൾ ലഭ്യമാക്കാനായില്ല.',
  ],
  'owner': ['Owner', 'ഉടമ'],
  'progress': ['Tasks completed', 'പൂർത്തിയായ tasks'],
  'campaignInfo': [
    'Campaign activity is self-reported and is not verified by Instagram.',
    'Campaign പ്രവർത്തനങ്ങൾ സ്വയം റിപ്പോർട്ട് ചെയ്തതാണ്; Instagram പരിശോധിച്ചിട്ടില്ല.',
  ],
  'actionControls': ['Action controls', 'Action നിയന്ത്രണങ്ങൾ'],
  'actionHelp': [
    'Disable an action to pause new campaigns and submissions. Existing submissions can still be reviewed, withdrawn or cancelled.',
    'Action തടഞ്ഞാൽ പുതിയ campaigns-ഉം submissions-ഉം നിർത്തും. നിലവിലുള്ള submissions പരിശോധിക്കാനും പിൻവലിക്കാനും റദ്ദാക്കാനും കഴിയും.',
  ],
  'follow': ['Follow', 'Follow'],
  'like': ['Like', 'Like'],
  'share': ['Share', 'Share'],
  'comment': ['Comment', 'Comment'],
  'enabled': ['Enabled', 'പ്രവർത്തനക്ഷമം'],
  'disabled': ['Disabled', 'തടഞ്ഞു'],
  'actionFailure': [
    'Unable to load or update action controls.',
    'Action നിയന്ത്രണങ്ങൾ ലഭ്യമാക്കാനോ മാറ്റാനോ കഴിഞ്ഞില്ല.',
  ],
  'search': ['Search email or name', 'ഇമെയിൽ അല്ലെങ്കിൽ പേര് തിരയുക'],
  'searchButton': ['Search', 'തിരയുക'],
  'refresh': ['Refresh', 'പുതുക്കുക'],
  'logout': ['Sign out', 'ലോഗൗട്ട്'],
  'blocked': ['Blocked', 'തടഞ്ഞു'],
  'active': ['Active', 'സജീവം'],
  'admin': ['Administrator', 'Administrator'],
  'block': ['Block app access', 'App access തടയുക'],
  'unblock': ['Restore app access', 'App access പുനഃസ്ഥാപിക്കുക'],
  'confirmBlock': [
    'Block this user’s app access?',
    'ഈ ഉപയോക്താവിന്റെ app access തടയണോ?',
  ],
  'confirmUnblock': [
    'Restore this user’s app access?',
    'ഈ ഉപയോക്താവിന്റെ app access പുനഃസ്ഥാപിക്കണോ?',
  ],
  'blockNote': [
    'Access to campaign and coin data will be blocked. Supabase sign-in itself remains available.',
    'Campaign, coin വിവരങ്ങളിലേക്കുള്ള access തടയും. Supabase sign-in ലഭ്യമായി തുടരും.',
  ],
  'cancel': ['Cancel', 'റദ്ദാക്കുക'],
  'confirm': ['Confirm', 'സ്ഥിരീകരിക്കുക'],
  'failure': [
    'Unable to load or update users. Check your access and connection.',
    'Users ലഭിക്കുകയോ മാറ്റം സേവ് ചെയ്യുകയോ ചെയ്തില്ല. Access-ഉം internet-ഉം പരിശോധിക്കുക.',
  ],
  'empty': ['No users found.', 'ഉപയോക്താക്കളെ കണ്ടെത്തിയില്ല.'],
  'coins': ['Coins', 'Coins'],
  'joined': ['Joined', 'ചേർന്നത്'],
  'previous': ['Previous', 'മുമ്പത്തെ'],
  'next': ['Next', 'അടുത്തത്'],
  'accessInfo': [
    'Account controls apply to app data and actions. Previously cached information may remain visible.',
    'Account controls app data-ക്കും actions-നും ബാധകമാണ്. മുമ്പ് cache ചെയ്ത വിവരങ്ങൾ കാണാൻ ഇടയുണ്ട്.',
  ],
};
String at(BuildContext context, String key) =>
    labels[key]![Localizations.localeOf(context).languageCode == 'ml' ? 1 : 0];

// Accept only public client credentials. A service key must never enter the app.
bool validAdminConfig(String url, String key) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  final value = key.trim();
  if (value.startsWith('sb_publishable_') && value.length > 20) return true;
  final parts = value.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map && payload['role'] == 'anon';
  } catch (_) {
    return false;
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.joined,
    required this.coins,
    required this.blocked,
    required this.isAdmin,
  });
  final String id, email, name, joined;
  final int? coins;
  final bool blocked, isAdmin;
  factory AdminUser.fromJson(Map<String, dynamic> row) => AdminUser(
    id: row['id'] as String,
    email: row['email'] as String? ?? '',
    name: row['display_name'] as String? ?? '',
    joined: row['created_at'] as String? ?? '',
    coins: row['coins'] as int?,
    blocked: row['blocked'] as bool? ?? false,
    isAdmin: row['is_admin'] as bool? ?? false,
  );
}

class AdminCampaign {
  const AdminCampaign({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.type,
    required this.link,
    required this.status,
    required this.requested,
    required this.remaining,
  });
  final String id, ownerId, ownerEmail, type, link, status;
  final int requested, remaining;
  factory AdminCampaign.fromJson(Map<String, dynamic> row) => AdminCampaign(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    ownerEmail: row['owner_email'] as String? ?? '',
    type: row['type'] as String,
    link: row['link'] as String,
    status: row['status'] as String,
    requested: row['requested'] as int,
    remaining: row['remaining'] as int,
  );
}

class AdminSubmission {
  const AdminSubmission({
    required this.campaignId,
    required this.userId,
    required this.submissionId,
    required this.type,
    required this.link,
  });
  final String campaignId, userId, submissionId, type, link;
  factory AdminSubmission.fromJson(Map<String, dynamic> row) => AdminSubmission(
    campaignId: row['campaign_id'] as String,
    userId: row['user_id'] as String,
    submissionId: row['submission_id'] as String,
    type: row['action_type'] as String,
    link: row['campaign_link'] as String,
  );
}

abstract class AdminGateway {
  Future<void> signIn(String email, String password);
  Future<bool> isAdmin();
  Future<List<AdminUser>> users(String query, int offset, int limit);
  Future<void> setBlocked(String userId, bool blocked);
  Future<List<AdminSubmission>> submissions(int offset, int limit);
  Future<Map<String, dynamic>> beginReview(AdminSubmission submission);
  Future<bool> renewReview(String sessionId);
  Future<void> endReview(String sessionId);
  Future<List<AdminCampaign>> campaigns(
    String? type,
    String? status,
    int offset,
    int limit,
  );
  Future<Map<String, bool>> actions();
  Future<void> setActionEnabled(String type, bool enabled);
  Future<void> signOut();
  Future<void> dispose();
}

class SupabaseAdminGateway implements AdminGateway {
  SupabaseAdminGateway(this.client);
  final SupabaseClient client;
  @override
  Future<void> signIn(String email, String password) async =>
      client.auth.signInWithPassword(email: email, password: password);
  @override
  Future<bool> isAdmin() async => (await client.rpc('admin_is_admin')) == true;
  @override
  Future<List<AdminUser>> users(String query, int offset, int limit) async {
    final rows = await client.rpc(
      'admin_list_users',
      params: {'p_query': query, 'p_offset': offset, 'p_limit': limit},
    ) as List;
    return rows
        .map((row) => AdminUser.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<List<AdminCampaign>> campaigns(
    String? type,
    String? status,
    int offset,
    int limit,
  ) async {
    final rows = await client.rpc(
      'admin_list_campaigns',
      params: {
        'p_type': type,
        'p_status': status,
        'p_offset': offset,
        'p_limit': limit,
      },
    ) as List;
    return rows
        .map(
          (row) =>
              AdminCampaign.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<List<AdminSubmission>> submissions(int offset, int limit) async {
    final rows = await client.rpc(
      'admin_pending_submissions',
      params: {'p_offset': offset, 'p_limit': limit},
    ) as List;
    return rows
        .map(
          (row) =>
              AdminSubmission.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> beginReview(AdminSubmission submission) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'admin_begin_submission_review',
          params: {
            'p_campaign_id': submission.campaignId,
            'p_user_id': submission.userId,
            'p_submission_id': submission.submissionId,
          },
        ) as Map,
      );
  @override
  Future<bool> renewReview(String sessionId) async =>
      (await client.rpc(
        'admin_renew_submission_review',
        params: {'p_session_id': sessionId},
      )) ==
      true;
  @override
  Future<void> endReview(String sessionId) async => client.rpc(
    'admin_end_submission_review',
    params: {'p_session_id': sessionId},
  );

  @override
  Future<void> setBlocked(String userId, bool blocked) async => client.rpc(
    'admin_set_blocked',
    params: {'p_user_id': userId, 'p_blocked': blocked},
  );
  @override
  Future<Map<String, bool>> actions() async {
    final rows =
        await client.from('action_controls').select('action_type,enabled')
            as List;
    return {
      for (final row in rows)
        row['action_type'] as String: row['enabled'] as bool,
    };
  }

  @override
  Future<void> setActionEnabled(String type, bool enabled) async => client.rpc(
    'admin_set_action_enabled',
    params: {'p_type': type, 'p_enabled': enabled},
  );
  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<void> dispose() => client.dispose();
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key, this.gateway});
  final AdminGateway? gateway;
  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  Locale locale = const Locale('en');
  AdminGateway? gateway;
  bool authorized = false;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway;
  }

  void changeLanguage() => setState(
    () => locale = Locale(locale.languageCode == 'en' ? 'ml' : 'en'),
  );
  Future<void> logout() async {
    try {
      await gateway?.signOut();
    } catch (_) {
      // The SDK clears the local session before attempting remote sign-out.
    } finally {
      if (mounted) setState(() => authorized = false);
    }
  }

  Future<void> changeProject() async {
    final old = gateway;
    try {
      await old?.signOut();
    } catch (_) {
      /* Local cleanup must still happen. */
    }
    await old?.dispose();
    if (mounted) {
      setState(() {
        gateway = null;
        authorized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Growth Circle Admin',
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ml')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff5b43c2),
        surface: const Color(0xfffaf9fe),
      ),
    ),
    home: gateway == null
        ? AdminSetup(
            onConnect: (value) => setState(() => gateway = value),
            onLanguage: changeLanguage,
          )
        : authorized
        ? AdminDashboard(
            gateway: gateway!,
            onLogout: logout,
            onLanguage: changeLanguage,
          )
        : AdminSignIn(
            gateway: gateway!,
            onSuccess: () => setState(() => authorized = true),
            onChangeProject: changeProject,
            onLanguage: changeLanguage,
          ),
  );
}

class AdminSetup extends StatefulWidget {
  const AdminSetup({
    super.key,
    required this.onConnect,
    required this.onLanguage,
  });
  final void Function(AdminGateway) onConnect;
  final VoidCallback onLanguage;
  @override
  State<AdminSetup> createState() => _AdminSetupState();
}

class _AdminSetupState extends State<AdminSetup> {
  final url = TextEditingController();
  final key = TextEditingController();
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      url.text = prefs.getString('admin_project_url') ?? '';
      key.text = prefs.getString('admin_public_key') ?? '';
    } catch (_) {
      /* Configuration can still be entered manually. */
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    url.dispose();
    key.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    if (!validAdminConfig(url.text, key.text)) {
      setState(() => error = at(context, 'invalidConfig'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final projectUrl = url.text.trim().replaceFirst(RegExp(r'/$'), '');
    final publicKey = key.text.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_project_url', projectUrl);
      await prefs.setString('admin_public_key', publicKey);
      final gateway = SupabaseAdminGateway(
        SupabaseClient(projectUrl, publicKey),
      );
      if (mounted) {
        widget.onConnect(gateway);
      } else {
        await gateway.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = at(context, 'failure');
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminFrame(
    onLanguage: widget.onLanguage,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          at(context, 'setup'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(at(context, 'configHelp')),
        const SizedBox(height: 20),
        TextField(
          controller: url,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: at(context, 'url'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: key,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: at(context, 'key'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: busy ? null : connect,
          child: Text(at(context, 'connect')),
        ),
      ],
    ),
  );
}

class AdminFrame extends StatelessWidget {
  const AdminFrame({super.key, required this.child, required this.onLanguage});
  final Widget child;
  final VoidCallback onLanguage;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Growth Circle Admin'),
      actions: [
        TextButton(
          onPressed: onLanguage,
          child: Text(
            Localizations.localeOf(context).languageCode == 'ml'
                ? 'English'
                : 'മലയാളം',
          ),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(padding: const EdgeInsets.all(28), child: child),
          ),
        ),
      ),
    ),
  );
}

class AdminSignIn extends StatefulWidget {
  const AdminSignIn({
    super.key,
    required this.gateway,
    required this.onSuccess,
    required this.onChangeProject,
    required this.onLanguage,
  });
  final AdminGateway gateway;
  final VoidCallback onSuccess, onLanguage;
  final Future<void> Function() onChangeProject;
  @override
  State<AdminSignIn> createState() => _AdminSignInState();
}

class _AdminSignInState extends State<AdminSignIn> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, visible = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.gateway.signIn(email.text.trim(), password.text);
      if (!await widget.gateway.isAdmin()) {
        await widget.gateway.signOut();
        if (mounted) setState(() => error = at(context, 'unauthorized'));
      } else if (mounted) {
        password.clear();
        widget.onSuccess();
      }
    } catch (_) {
      try {
        await widget.gateway.signOut();
      } catch (_) {
        /* Keep failure generic. */
      }
      if (mounted) setState(() => error = at(context, 'loginError'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminFrame(
    onLanguage: widget.onLanguage,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          at(context, 'signIn'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('admin_email'),
          controller: email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: at(context, 'email'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('admin_password'),
          controller: password,
          enabled: !busy,
          obscureText: !visible,
          decoration: InputDecoration(
            labelText: at(context, 'password'),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => visible = !visible),
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(at(context, 'login')),
        ),
        TextButton(
          onPressed: busy ? null : widget.onChangeProject,
          child: Text(at(context, 'changeProject')),
        ),
      ],
    ),
  );
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.gateway,
    required this.onLogout,
    required this.onLanguage,
  });
  final AdminGateway gateway;
  final Future<void> Function() onLogout;
  final VoidCallback onLanguage;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final query = TextEditingController();
  late Future<List<AdminUser>> results;
  int offset = 0;
  String search = '';
  bool changing = false;
  static const pageSize = 50;
  @override
  void initState() {
    super.initState();
    results = widget.gateway.users(search, offset, pageSize);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void reload({int? page, bool newSearch = false}) => setState(() {
    if (newSearch) {
      search = query.text.trim();
      offset = 0;
    }
    if (page != null) offset = page;
    results = widget.gateway.users(search, offset, pageSize);
  });
  Future<void> change(AdminUser user) async {
    final block = !user.blocked;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(at(context, block ? 'confirmBlock' : 'confirmUnblock')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 12),
            Text(at(context, 'blockNote')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(at(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(at(context, 'confirm')),
          ),
        ],
      ),
    );
    if (accept != true || !mounted || changing) return;
    setState(() => changing = true);
    try {
      await widget.gateway.setBlocked(user.id, block);
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(at(context, 'failure'))));
      }
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Growth Circle Admin'),
      actions: [
        IconButton(
          tooltip: at(context, 'submissions'),
          icon: const Icon(Icons.fact_check_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminSubmissions(gateway: widget.gateway),
            ),
          ),
        ),
        IconButton(
          tooltip: at(context, 'campaigns'),
          icon: const Icon(Icons.campaign_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminCampaigns(gateway: widget.gateway),
            ),
          ),
        ),
        IconButton(
          tooltip: at(context, 'actionControls'),
          icon: const Icon(Icons.tune),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminActionControls(gateway: widget.gateway),
            ),
          ),
        ),
        TextButton(
          onPressed: widget.onLanguage,
          child: Text(
            Localizations.localeOf(context).languageCode == 'ml'
                ? 'English'
                : 'മലയാളം',
          ),
        ),
        TextButton(
          onPressed: changing ? null : widget.onLogout,
          child: Text(at(context, 'logout')),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                at(context, 'users'),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(at(context, 'accessInfo')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('admin_search'),
                      controller: query,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: at(context, 'search'),
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      onSubmitted: (_) => reload(newSearch: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => reload(newSearch: true),
                    child: Text(at(context, 'searchButton')),
                  ),
                  IconButton(
                    onPressed: reload,
                    tooltip: at(context, 'refresh'),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<AdminUser>>(
                  future: results,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(at(context, 'failure')));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!;
                    return Column(
                      children: [
                        Expanded(
                          child: users.isEmpty
                              ? Center(child: Text(at(context, 'empty')))
                              : ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, i) {
                                    final user = users[i];
                                    final joined = user.joined.length >= 10
                                        ? user.joined.substring(0, 10)
                                        : user.joined;
                                    return AdminUserCard(
                                      user: user,
                                      joined: joined,
                                      changing: changing,
                                      onChange: () => change(user),
                                    );
                                  },
                                ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: offset > 0
                                  ? () => reload(page: offset - pageSize)
                                  : null,
                              child: Text(at(context, 'previous')),
                            ),
                            Text('${offset + 1}–${offset + users.length}'),
                            TextButton(
                              onPressed: users.length == pageSize
                                  ? () => reload(page: offset + pageSize)
                                  : null,
                              child: Text(at(context, 'next')),
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
    ),
  );
}

class AdminUserCard extends StatelessWidget {
  const AdminUserCard({
    super.key,
    required this.user,
    required this.joined,
    required this.changing,
    required this.onChange,
  });
  final AdminUser user;
  final String joined;
  final bool changing;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(user.blocked ? Icons.block : Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? user.email : user.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(user.email),
                    Text(
                      '${at(context, 'coins')}: ${user.coins ?? '—'}  •  ${at(context, 'joined')}: $joined',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(
                  at(
                    context,
                    user.isAdmin
                        ? 'admin'
                        : user.blocked
                        ? 'blocked'
                        : 'active',
                  ),
                ),
              ),
              if (!user.isAdmin)
                OutlinedButton(
                  onPressed: changing ? null : onChange,
                  child: Text(at(context, user.blocked ? 'unblock' : 'block')),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class AdminActionControls extends StatefulWidget {
  const AdminActionControls({super.key, required this.gateway});
  final AdminGateway gateway;
  @override
  State<AdminActionControls> createState() => _AdminActionControlsState();
}

class _AdminActionControlsState extends State<AdminActionControls> {
  late Future<Map<String, bool>> result;
  bool changing = false;
  @override
  void initState() {
    super.initState();
    result = widget.gateway.actions();
  }

  void reload() => setState(() {
    result = widget.gateway.actions();
  });
  Future<void> change(String type, bool enabled) async {
    if (changing) return;
    setState(() => changing = true);
    try {
      await widget.gateway.setActionEnabled(type, enabled);
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(at(context, 'actionFailure'))));
      }
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(at(context, 'actionControls'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: FutureBuilder<Map<String, bool>>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(at(context, 'actionFailure')),
                  TextButton(
                    onPressed: reload,
                    child: Text(at(context, 'refresh')),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final values = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(at(context, 'actionHelp')),
                const SizedBox(height: 16),
                for (final type in ['follow', 'like', 'share', 'comment'])
                  Card(
                    child: SwitchListTile(
                      key: Key('action_$type'),
                      title: Text(at(context, type)),
                      subtitle: Text(
                        at(
                          context,
                          values[type] == true ? 'enabled' : 'disabled',
                        ),
                      ),
                      value: values[type] == true,
                      onChanged: changing || !values.containsKey(type)
                          ? null
                          : (enabled) => change(type, enabled),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class AdminCampaigns extends StatefulWidget {
  const AdminCampaigns({super.key, required this.gateway});
  final AdminGateway gateway;
  @override
  State<AdminCampaigns> createState() => _AdminCampaignsState();
}

class _AdminCampaignsState extends State<AdminCampaigns> {
  String? type, status;
  int offset = 0;
  static const pageSize = 30;
  late Future<List<AdminCampaign>> result;
  @override
  void initState() {
    super.initState();
    result = widget.gateway.campaigns(type, status, offset, pageSize);
  }

  void reload({bool reset = false}) => setState(() {
    if (reset) offset = 0;
    result = widget.gateway.campaigns(type, status, offset, pageSize);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(at(context, 'campaigns')),
      actions: [
        IconButton(
          onPressed: reload,
          tooltip: at(context, 'refresh'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(at(context, 'campaignInfo')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  DropdownButton<String>(
                    key: const Key('campaign_type'),
                    value: type,
                    hint: Text(at(context, 'allActions')),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(at(context, 'allActions')),
                      ),
                      for (final item in ['follow', 'like', 'share', 'comment'])
                        DropdownMenuItem(
                          value: item,
                          child: Text(at(context, item)),
                        ),
                    ],
                    onChanged: (value) {
                      type = value;
                      reload(reset: true);
                    },
                  ),
                  DropdownButton<String>(
                    key: const Key('campaign_status'),
                    value: status,
                    hint: Text(at(context, 'allStatuses')),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(at(context, 'allStatuses')),
                      ),
                      for (final item in ['active', 'completed', 'cancelled'])
                        DropdownMenuItem(
                          value: item,
                          child: Text(at(context, item)),
                        ),
                    ],
                    onChanged: (value) {
                      status = value;
                      reload(reset: true);
                    },
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder<List<AdminCampaign>>(
                  future: result,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(at(context, 'campaignFailure')),
                            TextButton(
                              onPressed: reload,
                              child: Text(at(context, 'refresh')),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final campaigns = snapshot.data!;
                    return Column(
                      children: [
                        Expanded(
                          child: campaigns.isEmpty
                              ? Center(
                                  child: Text(at(context, 'campaignEmpty')),
                                )
                              : ListView.builder(
                                  itemCount: campaigns.length,
                                  itemBuilder: (context, index) {
                                    final campaign = campaigns[index];
                                    return Card(
                                      child: ListTile(
                                        title: Text(
                                          '${at(context, campaign.type)} · ${at(context, campaign.status)}',
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SelectableText(campaign.link),
                                            SelectableText(
                                              '${at(context, 'owner')}: ${campaign.ownerEmail.isEmpty ? campaign.ownerId : campaign.ownerEmail}',
                                            ),
                                            Text(
                                              '${at(context, 'progress')}: ${campaign.requested - campaign.remaining}/${campaign.requested}',
                                            ),
                                          ],
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
                                  ? () {
                                      offset -= pageSize;
                                      reload();
                                    }
                                  : null,
                              child: Text(at(context, 'previous')),
                            ),
                            Text(
                              '${offset + (campaigns.isEmpty ? 0 : 1)}–${offset + campaigns.length}',
                            ),
                            TextButton(
                              onPressed: campaigns.length == pageSize
                                  ? () {
                                      offset += pageSize;
                                      reload();
                                    }
                                  : null,
                              child: Text(at(context, 'next')),
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
    ),
  );
}

class AdminSubmissions extends StatefulWidget {
  const AdminSubmissions({super.key, required this.gateway});
  final AdminGateway gateway;
  @override
  State<AdminSubmissions> createState() => _AdminSubmissionsState();
}

class _AdminSubmissionsState extends State<AdminSubmissions> {
  static const pageSize = 30;
  int offset = 0;
  late Future<List<AdminSubmission>> result;
  @override
  void initState() {
    super.initState();
    result = widget.gateway.submissions(offset, pageSize);
  }

  void reload() => setState(() {
    result = widget.gateway.submissions(offset, pageSize);
  });
  Future<void> inspect(AdminSubmission submission) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AdminInspectionDialog(
        gateway: widget.gateway,
        submission: submission,
      ),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(at(context, 'submissions')),
      actions: [
        IconButton(
          onPressed: reload,
          tooltip: at(context, 'refresh'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(at(context, 'reviewNotice')),
              Expanded(
                child: FutureBuilder<List<AdminSubmission>>(
                  future: result,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Text(at(context, 'submissionFailure')),
                      );
                    }
                    final items = snapshot.data!;
                    return Column(
                      children: [
                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text(at(context, 'submissionEmpty')),
                                )
                              : ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return Card(
                                      child: ListTile(
                                        title: Text(at(context, item.type)),
                                        subtitle: Text(
                                          item.link,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: OutlinedButton(
                                          onPressed: () => inspect(item),
                                          child: Text(at(context, 'inspect')),
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
                                  ? () {
                                      offset -= pageSize;
                                      reload();
                                    }
                                  : null,
                              child: Text(at(context, 'previous')),
                            ),
                            Text(
                              '${offset + (items.isEmpty ? 0 : 1)}–${offset + items.length}',
                            ),
                            TextButton(
                              onPressed: items.length == pageSize
                                  ? () {
                                      offset += pageSize;
                                      reload();
                                    }
                                  : null,
                              child: Text(at(context, 'next')),
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
    ),
  );
}

class AdminInspectionDialog extends StatefulWidget {
  const AdminInspectionDialog({
    super.key,
    required this.gateway,
    required this.submission,
  });
  final AdminGateway gateway;
  final AdminSubmission submission;
  @override
  State<AdminInspectionDialog> createState() => _AdminInspectionDialogState();
}

class _AdminInspectionDialogState extends State<AdminInspectionDialog> {
  String? session, username, error;
  Uint8List? bytes;
  Timer? heartbeat;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.gateway.beginReview(widget.submission);
      final id = value['session_id'] as String;
      if (!mounted) {
        await widget.gateway.endReview(id);
        return;
      }
      session = id;
      final image = base64Decode(value['data'] as String);
      if (image.isEmpty || image.length > 524288) {
        throw const FormatException('Invalid image');
      }
      setState(() {
        username = value['username'] as String;
        bytes = image;
      });
      heartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
        try {
          if (!await widget.gateway.renewReview(id) && mounted) {
            failInspection();
          }
        } catch (_) {
          if (mounted) failInspection();
        }
      });
    } catch (_) {
      if (mounted) failInspection();
    }
  }

  void stopSession() {
    heartbeat?.cancel();
    final id = session;
    session = null;
    if (id != null) unawaited(widget.gateway.endReview(id).catchError((_) {}));
  }

  void failInspection() {
    stopSession();
    setState(() {
      username = null;
      bytes = null;
      error = at(context, 'submissionFailure');
    });
  }

  @override
  void dispose() {
    stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(at(context, 'inspecting')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(at(context, 'reviewNotice')),
          if (error != null) Text(error!),
          if (bytes == null && error == null)
            const Center(child: CircularProgressIndicator()),
          if (username != null)
            Text('${at(context, 'instagramUsername')}: @$username'),
          if (bytes != null)
            Image.memory(
              bytes!,
              height: 300,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(at(context, 'submissionFailure')),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(at(context, 'close')),
      ),
    ],
  );
}
