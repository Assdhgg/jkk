import 'dart:async';
import 'dart:convert';

import 'evidence_image.dart';
import 'admin_operations.dart';
import 'admin_app_releases.dart';
import 'admin_notifications.dart';
import 'admin_login_tools.dart';
import 'package:flutter/services.dart';
import 'admin_design.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
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
  'walletControls': ['Wallet controls', 'Wallet controls'],
  'users': ['Users', 'ഉപയോക്താക്കൾ'],
  'workspace': ['ADMIN WORKSPACE', 'ADMIN WORKSPACE'],
  'usersIntro': [
    'Find members and manage their access to Freelan Space.',
    'അംഗങ്ങളെ കണ്ടെത്തി Freelan Space-ലേക്കുള്ള access നിയന്ത്രിക്കുക.',
  ],
  'directory': ['MEMBER DIRECTORY', 'MEMBER DIRECTORY'],
  'coinSettings': ['Coin settings', 'Coin settings'],
  'sendNotifications': ['Send notification', 'Notification അയയ്ക്കുക'],
  'workspaceMenu': ['Workspace', 'Workspace'],
  'overview': ['Overview', 'അവലോകനം'],
  'activity': ['Admin activity', 'Admin പ്രവർത്തനങ്ങൾ'],
  'reports': ['Reports & CSV', 'റിപ്പോർട്ടുകളും CSV-യും'],
  'alerts': ['Alerts', 'അറിയിപ്പുകൾ'],
  'roles': ['Admin roles', 'Admin roles'],
  'details': ['Details', 'വിശദാംശങ്ങൾ'],
  'actionsLabel': ['Actions', 'പ്രവർത്തനങ്ങൾ'],
  'filterSubmissions': ['Filter submissions', 'Submissions filter ചെയ്യുക'],
  'campaignId': ['Campaign ID', 'Campaign ID'],
  'dateRange': ['Date range (UTC)', 'തീയതി പരിധി (UTC)'],
  'apply': ['Apply', 'പ്രയോഗിക്കുക'],
  'clear': ['Clear', 'മായ്ക്കുക'],
  'invalidCampaign': [
    'Enter a valid campaign ID.',
    'ശരിയായ campaign ID നൽകുക.',
  ],
  'rangeTooLong': [
    'Choose a range of at most 366 days.',
    'പരമാവധി 366 ദിവസത്തെ പരിധി തിരഞ്ഞെടുക്കുക.',
  ],
  'saveReport': ['Report saved.', 'റിപ്പോർട്ട് സേവ് ചെയ്തു.'],
  'saveFailure': [
    'Unable to save report on this device.',
    'ഈ ഉപകരണത്തിൽ റിപ്പോർട്ട് സേവ് ചെയ്യാനായില്ല.',
  ],
  'workspaceFailure': [
    'Unable to load workspace data.',
    'Workspace വിവരങ്ങൾ ലഭ്യമല്ല.',
  ],
  'activeCampaigns': ['Active campaigns', 'സജീവ campaigns'],
  'coinsCredited': ['Coins credited', 'ലഭിച്ച coins'],
  'overviewHelp': [
    'A live snapshot of Freelan Space activity.',
    'Freelan Space പ്രവർത്തനങ്ങളുടെ നിലവിലെ സ്ഥിതി.',
  ],
  'exportCsv': ['Export CSV', 'CSV എക്സ്പോർട്ട്'],
  'alertsHelp': [
    'Signals use the configured thresholds. These do not establish abuse.',
    'ക്രമീകരിച്ച thresholds അനുസരിച്ചുള്ള സൂചനകൾ. ഇവ ദുരുപയോഗത്തിന്റെ തെളിവല്ല.',
  ],
  'rolesHelp': [
    'Editors can change controls. Viewers can inspect data and evidence. The project owner provisions and changes roles in the database.',
    'Editors-ന് controls മാറ്റാം. Viewers-ന് വിവരങ്ങളും evidence-ഉം പരിശോധിക്കാം. Project owner ആണ് database-ൽ roles നൽകുന്നതും മാറ്റുന്നതും.',
  ],
  'noRecords': ['No records found.', 'വിവരങ്ങൾ കണ്ടെത്തിയില്ല.'],
  'detailsFailure': [
    'Unable to load user details.',
    'ഉപയോക്താവിന്റെ വിവരങ്ങൾ ലഭ്യമല്ല.',
  ],
  'recentRecords': [
    'The most recent 100 records in each section are shown.',
    'ഓരോ വിഭാഗത്തിലെയും ഏറ്റവും പുതിയ 100 വിവരങ്ങൾ കാണിക്കുന്നു.',
  ],
  'referrals': ['Referrals', 'Referrals'],
  'role': ['Role', 'Role'],
  'member': ['Member', 'അംഗം'],
  'referredBy': ['Referred by another member', 'മറ്റൊരു അംഗം refer ചെയ്തത്'],
  'yes': ['Yes', 'അതെ'],
  'no': ['No', 'ഇല്ല'],
  'ledger': ['Coin history', 'Coin history'],
  'submissionHistory': ['Submission history', 'Submission history'],
  'transactions': ['Transactions', 'Transactions'],
  'credited': ['Credited', 'ലഭിച്ചത്'],
  'spent': ['Spent', 'ചെലവായത്'],
  'registrations': ['Registrations', 'രജിസ്ട്രേഷനുകൾ'],
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
    this.publicId,
    required this.email,
    required this.name,
    required this.joined,
    required this.coins,
    required this.blocked,
    required this.isAdmin,
  });
  final String id, email, name, joined;
  final String? publicId;
  final int? coins;
  final bool blocked, isAdmin;
  factory AdminUser.fromJson(Map<String, dynamic> row) => AdminUser(
    id: row['id'] as String,
    publicId: row['public_id'] as String?,
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
    this.submittedAt,
  });
  final String campaignId, userId, submissionId, type, link;
  final String? submittedAt;
  factory AdminSubmission.fromJson(Map<String, dynamic> row) => AdminSubmission(
    campaignId: row['campaign_id'] as String,
    userId: row['user_id'] as String,
    submissionId: row['submission_id'] as String,
    type: row['action_type'] as String,
    link: row['campaign_link'] as String,
    submittedAt: row['submitted_at'] as String?,
  );
}

abstract class AdminGateway {
  Future<List<Map<String, dynamic>>> coinSettings();
  Future<void> setCoinSetting(String key, int amount);
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

abstract class AdminWorkspaceGateway {
  Future<String> workspaceRole();
  Future<Map<String, dynamic>> overview();
  Future<List<Map<String, dynamic>>> roles();
  Future<Map<String, dynamic>> userDetails(String userId);
  Future<List<Map<String, dynamic>>> activity(int offset);
  Future<List<Map<String, dynamic>>> dailyReport(DateTime from, DateTime to);
  Future<List<Map<String, dynamic>>> alerts();
  Future<List<AdminSubmission>> filteredSubmissions(
    String? type,
    String? campaign,
    DateTime? from,
    DateTime? to,
    int offset,
    int limit,
  );
}

class SupabaseAdminGateway implements AdminGateway, AdminWorkspaceGateway {
  SupabaseAdminGateway(this.client, {this.projectUrl, this.publicKey});
  final String? projectUrl, publicKey;
  final SupabaseClient client;
  @override
  Future<String> workspaceRole() async =>
      (await client.rpc('admin_workspace_role')) as String;
  @override
  Future<List<Map<String, dynamic>>> roles() async =>
      _rows(await client.rpc('admin_roles'));
  @override
  Future<Map<String, dynamic>> overview() async => Map<String, dynamic>.from(
    await client.rpc('admin_workspace_overview') as Map,
  );
  @override
  Future<Map<String, dynamic>> userDetails(String userId) async =>
      Map<String, dynamic>.from(
        await client.rpc('admin_user_details', params: {'p_user_id': userId})
            as Map,
      );
  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  @override
  Future<List<Map<String, dynamic>>> activity(int offset) async => _rows(
    await client.rpc(
      'admin_activity',
      params: {'p_offset': offset, 'p_limit': 50},
    ),
  );
  @override
  Future<List<Map<String, dynamic>>> dailyReport(
    DateTime from,
    DateTime to,
  ) async => _rows(
    await client.rpc(
      'admin_daily_report',
      params: {'p_from': _dateOnly(from), 'p_to': _dateOnly(to)},
    ),
  );
  @override
  Future<List<Map<String, dynamic>>> alerts() async =>
      _rows(await client.rpc('admin_alerts'));
  @override
  Future<List<AdminSubmission>> filteredSubmissions(
    String? type,
    String? campaign,
    DateTime? from,
    DateTime? to,
    int offset,
    int limit,
  ) async => _rows(
    await client.rpc(
      'admin_filtered_submissions',
      params: {
        'p_type': type,
        'p_campaign': campaign,
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
        'p_offset': offset,
        'p_limit': limit,
      },
    ),
  ).map(AdminSubmission.fromJson).toList();

  @override
  Future<List<Map<String, dynamic>>> coinSettings() async =>
      List<Map<String, dynamic>>.from(
        await client.from('coin_settings').select().order('key'),
      );
  @override
  Future<void> setCoinSetting(String key, int amount) async {
    await client.rpc(
      'admin_set_coin_setting',
      params: {'p_key': key, 'p_amount': amount},
    );
  }

  @override
  Future<void> signIn(String email, String password) async =>
      client.auth.signInWithPassword(email: email, password: password);
  @override
  Future<bool> isAdmin() async => (await client.rpc('admin_is_admin')) == true;
  @override
  Future<List<AdminUser>> users(String query, int offset, int limit) async {
    final rows = await client.rpc(
      'admin_list_users_v2',
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

class _AdminAppState extends State<AdminApp> with WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  Timer? idle;
  StreamSubscription<AuthState>? authEvents;
  Timer? accessCheck;
  bool locking = false;
  int idleMinutes = 10;
  bool lockOnBackground = true;
  Future<void> loadSessionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final saved = prefs.getInt('admin_idle_minutes');
      idleMinutes = [0, 10, 30, 60].contains(saved) ? saved! : 10;
      lockOnBackground = prefs.getBool('admin_lock_background') ?? true;
    });
    activity();
  }
  Future<void> sessionSettings(BuildContext context) async {
    var minutes = idleMinutes;
    var background = lockOnBackground;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, change) => AlertDialog(
        title: const Text('Session settings'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButton<int>(value: minutes, items: const [
            DropdownMenuItem(value: 0, child: Text('Sign out manually')),
            DropdownMenuItem(value: 10, child: Text('After 10 idle minutes')),
            DropdownMenuItem(value: 30, child: Text('After 30 idle minutes')),
            DropdownMenuItem(value: 60, child: Text('After 60 idle minutes')),
          ], onChanged: (value) => change(() => minutes = value!)),
          CheckboxListTile(title: const Text('Sign out when minimized'), value: background,
            onChanged: (value) => change(() => background = value!)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
      )));
    if (saved != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('admin_idle_minutes', minutes);
    await prefs.setBool('admin_lock_background', background);
    if (!mounted) return;
    setState(() { idleMinutes = minutes; lockOnBackground = background; });
    activity();
  }

  void connected(AdminGateway value) {
    gateway = value;
    authEvents?.cancel();
    accessCheck?.cancel();
    if (value is SupabaseAdminGateway) {
      authEvents = value.client.auth.onAuthStateChange.listen((event) {
        if (authorized && event.session == null) {
          unawaited(logout());
        }
      });
      accessCheck = Timer.periodic(const Duration(minutes: 1), (_) async {
        if (!authorized) return;
        try {
          if (!await value.isAdmin()) {
            await logout();
          }
        } catch (_) {
          // A transient connection failure does not end an administrator's session.
          // Business APIs continue to enforce access on the server.
        }
      });
    }
  }

  void activity() {
    if (!authorized) return;
    idle?.cancel();
    if (idleMinutes > 0) idle = Timer(Duration(minutes: idleMinutes), () => unawaited(logout()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (authorized && lockOnBackground &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused)) {
      unawaited(logout());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    idle?.cancel();
    accessCheck?.cancel();
    authEvents?.cancel();
    super.dispose();
  }

  Locale locale = const Locale('en');
  AdminGateway? gateway;
  bool authorized = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(loadSessionSettings().catchError((Object _) {}));
    if (widget.gateway != null) connected(widget.gateway!);
  }

  void changeLanguage() => setState(
    () => locale = Locale(locale.languageCode == 'en' ? 'ml' : 'en'),
  );
  Future<void> logout() async {
    if (locking) return;
    locking = true;
    idle?.cancel();
    navigator.currentState?.popUntil((route) => route.isFirst);
    if (mounted) setState(() => authorized = false);
    try {
      await gateway?.signOut();
    } catch (_) {
      // The SDK clears the local session before attempting remote sign-out.
    } finally {
      if (mounted) setState(() => authorized = false);
      locking = false;
    }
  }

  Future<void> changeProject() async {
    idle?.cancel();
    accessCheck?.cancel();
    await authEvents?.cancel();
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
    title: 'Freelan Space Admin',
    navigatorKey: navigator,
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ml')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: adminTheme(),
    builder: (context, child) => Listener(
      onPointerDown: (_) => activity(),
      onPointerSignal: (_) => activity(),
      child: Focus(
        onKeyEvent: (_, _) {
          activity();
          return KeyEventResult.ignored;
        },
        child: Stack(children: [
          AdminBackdrop(child: child!),
          if (authorized) Positioned(right: 16, bottom: 16,
            child: FloatingActionButton.small(tooltip: 'Session settings',
              onPressed: () => sessionSettings(navigator.currentState!.overlay!.context), child: const Icon(Icons.timer_outlined))),
        ]),
      ),
    ),
    home: gateway == null
        ? AdminSetup(
            onConnect: (value) => setState(() => connected(value)),
            onLanguage: changeLanguage,
          )
        : authorized
        ? LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 1100
                ? AdminDesktopConsole(
                    gateway: gateway!,
                    onLogout: logout,
                    onLanguage: changeLanguage,
                  )
                : AdminDashboard(
                    gateway: gateway!,
                    onLogout: logout,
                    onLanguage: changeLanguage,
                  ),
          )
        : AdminSignIn(
            gateway: gateway!,
            onSuccess: () {
              setState(() => authorized = true);
              activity();
            },
            onChangeProject: changeProject,
            onLanguage: changeLanguage,
          ),
  );
}

// A restrained palette keeps account and review information easy to scan.
const adminInk = Color(0xff160b49);
const adminMuted = Color(0xff6c5f91);
const adminViolet = Color(0xff4d16d5);
const adminCanvas = Color(0xfff6f3ff);
const adminLine = Color(0xffe2d9f5);

ThemeData adminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: adminViolet,
    primary: adminViolet,
    surface: Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Poppins',
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    dividerTheme: const DividerThemeData(color: adminLine, thickness: 1),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(const Color(0xffeae0fa)),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: adminMuted,
        fontSize: 12,
      ),
      dataTextStyle: const TextStyle(color: adminInk, fontSize: 13),
      horizontalMargin: 20,
      columnSpacing: 24,
      dividerThickness: .6,
      dataRowMinHeight: 72,
      dataRowMaxHeight: 88,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: adminInk,
      displayColor: adminInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: adminInk,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: adminLine),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xfff2f1f8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: adminViolet, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: adminLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

class AdminBrand extends StatelessWidget {
  const AdminBrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: adminViolet,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.hub_outlined, color: Colors.white, size: 21),
      ),
      if (!compact) ...[
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Freelan Space',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    ],
  );
}

class AdminNotice extends StatelessWidget {
  const AdminNotice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffefedf8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: adminViolet),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: adminInk, height: 1.4),
          ),
        ),
      ],
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
        SupabaseClient(projectUrl, publicKey), projectUrl: projectUrl, publicKey: publicKey,
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
    isSetup: true,
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
  const AdminFrame({
    super.key,
    required this.child,
    required this.onLanguage,
    this.isSetup = false,
  });
  final Widget child;
  final VoidCallback onLanguage;
  final bool isSetup;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final panel = Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wide) ...[
              const Text(
                'FREELAN SPACE  /  ADMIN',
                style: TextStyle(
                  color: adminViolet,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
            ],
            child,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const AdminBrand(),
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
            constraints: BoxConstraints(maxWidth: wide ? 1500 : 500),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isSetup)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  at(context, 'signIn'),
                                  style: const TextStyle(
                                    fontSize: 38,
                                    color: adminInk,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  Localizations.localeOf(context)
                                              .languageCode ==
                                          'ml'
                                      ? 'Freelan Space admin workspace തുറക്കുക.'
                                      : 'Access your Freelan Space admin workspace.',
                                  style: const TextStyle(
                                    color: adminMuted,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(width: isSetup ? 520 : 440, child: panel),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AdminIllustration(
                            isSetup ? 'connect' : 'signin',
                            height: 360,
                          ),
                        ),
                      ),
                    ],
                  )
                : panel,
          ),
        ),
      ),
    );
  }
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
  Map<String, String>? saved;
  bool remember = true;
  AdminSavedLogin? get savedLogin {
    final gateway = widget.gateway;
    return gateway is SupabaseAdminGateway && gateway.projectUrl != null ? AdminSavedLogin(gateway.projectUrl!) : null;
  }
  @override
  void initState() {
    super.initState();
    unawaited(loadSaved());
  }
  Future<void> loadSaved() async {
    try {
      final value = await savedLogin?.load();
      if (mounted) setState(() => saved = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Windows secure storage is unavailable. Saved login could not be loaded.');
    }
  }
  Future<void> recoverPassword() async {
    final gateway = widget.gateway;
    if (gateway is! SupabaseAdminGateway) return;
    final key = gateway.publicKey;
    final project = gateway.projectUrl;
    if (key == null || project == null || !mounted) return;
    final result = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => AdminPasswordRecovery(
        savedLogin: savedLogin!,
        createClient: () => SupabaseClient(project, key,
          authOptions: const AuthClientOptions(autoRefreshToken: false)),
      ));
    if (result == true && mounted) {
      password.clear();
      setState(() { saved = null; error = 'Password changed. Sign in with your new password.'; });
    }
  }

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
        final gateway = widget.gateway;
        if (gateway is SupabaseAdminGateway &&
            !await verifyAdminMfa(context, gateway.client)) {
          await gateway.signOut();
          if (mounted) setState(() => error = at(context, 'loginError'));
          return;
        }
        if (!mounted) return;
        try {
          if (remember) {
            await savedLogin?.save(email.text.trim(), password.text);
          } else {
            await savedLogin?.forget();
          }
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Signed in, but Windows could not save the login securely.')));
        }
        if (!mounted) return;
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
        if (MediaQuery.sizeOf(context).width >= 1100) ...[
          const Center(
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xffede6ff),
                  child: Icon(Icons.hub, color: adminViolet),
                ),
                SizedBox(height: 8),
                Text(
                  'Freelan Space',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: adminInk,
                  ),
                ),
                Text(
                  'ADMIN PORTAL',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: adminMuted,
                  ),
                ),
              ],
            ),
          ),
        ] else
          Text(
            at(context, 'signIn'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('admin_email'),
          controller: email,
          onTap: () {
            if (saved != null && (email.text.isEmpty || email.text == saved!['email'])) {
              email.text = saved!['email']!;
              password.text = saved!['password']!;
            }
          },
          autofillHints: const [AutofillHints.username],
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: at(context, 'email'),
            prefixIcon: const Icon(Icons.mail_outline),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('admin_password'),
          controller: password,
          autofillHints: const [AutofillHints.password],
          enabled: !busy,
          obscureText: !visible,
          decoration: InputDecoration(
            labelText: at(context, 'password'),
            prefixIcon: const Icon(Icons.lock_outline),
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
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: remember,
          title: const Text('Save login securely on this Windows account'),
          onChanged: busy ? null : (value) => setState(() => remember = value!)),
        if (saved != null) TextButton(onPressed: busy ? null : () async {
          try {
            await savedLogin?.forget();
            password.clear();
            if (mounted) setState(() => saved = null);
          } catch (_) { if (mounted) setState(() => error = 'Could not remove saved login.'); }
        }, child: const Text('Forget saved login')),
        TextButton(onPressed: busy ? null : recoverPassword, child: const Text('Forgot password?')),
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
    this.embedded = false,
  });
  final bool embedded;
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
  bool canEdit = false;
  static const pageSize = 50;
  @override
  void initState() {
    super.initState();
    results = widget.gateway.users(search, offset, pageSize);
    final gateway = widget.gateway;
    if (gateway is AdminWorkspaceGateway) {
      (gateway as AdminWorkspaceGateway)
          .workspaceRole()
          .then((role) {
            if (mounted) setState(() => canEdit = role == 'editor');
          })
          .catchError((_) {});
    } else {
      canEdit = true;
    }
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

  Widget _navigationAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    if (MediaQuery.sizeOf(context).width >= 1100) {
      return Tooltip(
        message: at(context, label),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          label: Text(at(context, label)),
        ),
      );
    }
    return IconButton(
      tooltip: at(context, label),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            titleSpacing: 8,
            title: AdminBrand(compact: MediaQuery.sizeOf(context).width < 650),
            actions: [
              _navigationAction(
                context,
                'submissions',
                Icons.fact_check_outlined,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminSubmissions(gateway: widget.gateway),
                  ),
                ),
              ),
              _navigationAction(
                context,
                'campaigns',
                Icons.campaign_outlined,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminCampaigns(gateway: widget.gateway),
                  ),
                ),
              ),
              _navigationAction(
                context,
                'actionControls',
                Icons.tune,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminActionControls(
                      gateway: widget.gateway,
                      canEdit: canEdit,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onLanguage,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ml'
                      ? 'English'
                      : 'മലയാളം',
                ),
              ),
              TextButton(
                onPressed: changing ? null : widget.onLogout,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(at(context, 'logout')),
              ),
              const SizedBox(width: 8),
            ],
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.embedded ? 1600 : 1050),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            12,
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.embedded)
                AdminHeading(
                  title: at(context, 'users'),
                  icon: Icons.people_rounded,
                  eyebrow: at(context, 'directory'),
                  subtitle: at(context, 'usersIntro'),
                  art: 'users',
                )
              else ...[
                Text(
                  at(context, 'directory'),
                  style: const TextStyle(
                    color: adminViolet,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            at(context, 'users'),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            at(context, 'usersIntro'),
                            style: const TextStyle(
                              color: adminMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.embedded)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.toll_outlined, size: 18),
                        label: Text(at(context, 'coinSettings')),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AdminCoinSettings(
                              gateway: widget.gateway,
                              canEdit: canEdit,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                at(context, 'accessInfo'),
                style: const TextStyle(
                  color: adminMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (widget.gateway is SupabaseAdminGateway && canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: Text(at(context, 'sendNotifications')),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AdminSendNotificationPage(
                          gateway: SupabaseAdminNotificationGateway(
                            (widget.gateway as SupabaseAdminGateway).client,
                          ),
                          canEdit: canEdit,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('admin_search'),
                      controller: query,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: at(context, 'search'),
                        prefixIcon: const Icon(Icons.search, size: 20),
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
              if (!widget.embedded && widget.gateway is AdminWorkspaceGateway)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    tooltip: at(context, 'workspaceMenu'),
                    onSelected: (page) => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            page == 'updates' &&
                                widget.gateway is SupabaseAdminGateway
                            ? AdminAppReleasesPage(
                                client: (widget.gateway as SupabaseAdminGateway)
                                    .client,
                                canEdit: canEdit,
                              )
                            : page == 'operations' &&
                                  widget.gateway is SupabaseAdminGateway
                            ? AdminOperationsPage(
                                client: (widget.gateway as SupabaseAdminGateway)
                                    .client,
                                canEdit: canEdit,
                              )
                            : AdminWorkspacePage(
                                gateway:
                                    widget.gateway as AdminWorkspaceGateway,
                                page: page,
                              ),
                      ),
                    ),
                    itemBuilder: (_) => [
                      if (widget.gateway is SupabaseAdminGateway)
                        const PopupMenuItem(
                          value: 'updates',
                          child: Text('App releases'),
                        ),
                      if (widget.gateway is SupabaseAdminGateway)
                        PopupMenuItem(
                          value: 'operations',
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'ml'
                                ? 'Admin പ്രവർത്തനങ്ങൾ'
                                : 'Admin operations',
                          ),
                        ),
                      PopupMenuItem(
                        value: 'overview',
                        child: Text(at(context, 'overview')),
                      ),
                      PopupMenuItem(
                        value: 'activity',
                        child: Text(at(context, 'activity')),
                      ),
                      PopupMenuItem(
                        value: 'reports',
                        child: Text(at(context, 'reports')),
                      ),
                      PopupMenuItem(
                        value: 'alerts',
                        child: Text(at(context, 'alerts')),
                      ),
                      PopupMenuItem(
                        value: 'roles',
                        child: Text(at(context, 'roles')),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: adminViolet,
                          ),
                          SizedBox(width: 8),
                          Text(
                            at(context, 'workspaceMenu'),
                            style: const TextStyle(
                              color: adminViolet,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: adminViolet),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.gateway is SupabaseAdminGateway)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AdminNotificationButton(
                    client: (widget.gateway as SupabaseAdminGateway).client,
                    canEdit: canEdit,
                  ),
                ),
              const SizedBox(height: 8),
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
                              : widget.embedded
                              ? SingleChildScrollView(
                                  child: Card(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) => SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth,
                                          ),
                                          child: DataTable(
                                            columns: [
                                              const DataColumn(label: Text('Name')),
                                              const DataColumn(label: Text('Email')),
                                              const DataColumn(label: Text('User ID (8 digits)')),
                                              DataColumn(
                                                label: Text(
                                                  at(context, 'joined'),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  at(context, 'coins'),
                                                ),
                                                numeric: true,
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  at(context, 'role'),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  at(context, 'details'),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  at(context, 'actionsLabel'),
                                                ),
                                              ),
                                            ],
                                            rows: [
                                              for (final user in users)
                                                DataRow(
                                                  cells: [
                                                    DataCell(AdminCopyField(label: 'Name', value: user.name)),
                                                    DataCell(AdminCopyField(label: 'Email', value: user.email)),
                                                    DataCell(AdminCopyField(label: 'User ID', value: user.publicId ?? '—')),
                                                    DataCell(
                                                      Text(
                                                        user.joined.length >= 10
                                                            ? user.joined
                                                                  .substring(
                                                                    0,
                                                                    10,
                                                                  )
                                                            : user.joined,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        '${user.coins ?? '—'}',
                                                      ),
                                                    ),
                                                    DataCell(
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
                                                        side: BorderSide.none,
                                                        backgroundColor:
                                                            user.blocked
                                                            ? const Color(
                                                                0xffffeceb,
                                                              )
                                                            : const Color(
                                                                0xffeaf5f0,
                                                              ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      widget.gateway
                                                              is AdminWorkspaceGateway
                                                          ? TextButton.icon(
                                                              onPressed: () => Navigator.push(
                                                                context,
                                                                MaterialPageRoute<
                                                                  void
                                                                >(
                                                                  builder: (_) =>
                                                                      AdminUserDetails(
                                                                        gateway:
                                                                            widget.gateway
                                                                                as AdminWorkspaceGateway,
                                                                        user:
                                                                            user,
                                                                      ),
                                                                ),
                                                              ),
                                                              icon: const Icon(
                                                                Icons
                                                                    .visibility_outlined,
                                                                size: 18,
                                                              ),
                                                              label: Text(
                                                                at(
                                                                  context,
                                                                  'details',
                                                                ),
                                                              ),
                                                            )
                                                          : const Text('—'),
                                                    ),
                                                    DataCell(
                                                      !user.isAdmin
                                                          ? OutlinedButton(
                                                              onPressed:
                                                                  changing ||
                                                                      !canEdit
                                                                  ? null
                                                                  : () =>
                                                                        change(
                                                                          user,
                                                                        ),
                                                              child: Text(
                                                                at(
                                                                  context,
                                                                  user.blocked
                                                                      ? 'unblock'
                                                                      : 'block',
                                                                ),
                                                              ),
                                                            )
                                                          : const Text('—'),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
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
                                      changing: changing || !canEdit,
                                      onChange: () => change(user),
                                      onDetails:
                                          widget.gateway
                                              is AdminWorkspaceGateway
                                          ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) => AdminUserDetails(
                                                  gateway:
                                                      widget.gateway
                                                          as AdminWorkspaceGateway,
                                                  user: user,
                                                ),
                                              ),
                                            )
                                          : null,
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
                            Text(
                              '${offset + (users.isEmpty ? 0 : 1)}–${offset + users.length}',
                              style: const TextStyle(color: adminMuted),
                            ),
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
    this.onDetails,
  });
  final AdminUser user;
  final String joined;
  final bool changing;
  final VoidCallback onChange;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final status = user.isAdmin
              ? 'admin'
              : user.blocked
              ? 'blocked'
              : 'active';
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xffefedf8),
                foregroundColor: adminViolet,
                child: Icon(
                  user.blocked ? Icons.block : Icons.person_outline,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminCopyField(label: 'Name', value: user.name),
                    AdminCopyField(label: 'Email', value: user.email),
                    AdminCopyField(label: 'User ID', value: user.publicId ?? '—'),
                    const SizedBox(height: 6),
                    Text(
                      '${at(context, 'coins')}: ${user.coins ?? '—'}  ·  ${at(context, 'joined')}: $joined',
                      style: const TextStyle(color: adminMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: user.blocked
                      ? const Color(0xfffff0ed)
                      : const Color(0xfff0eef9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  at(context, status),
                  style: TextStyle(
                    color: user.blocked ? const Color(0xffa44739) : adminViolet,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onDetails != null)
                TextButton(
                  onPressed: onDetails,
                  child: Text(at(context, 'details')),
                ),
              if (!user.isAdmin)
                OutlinedButton(
                  onPressed: changing ? null : onChange,
                  child: Text(at(context, user.blocked ? 'unblock' : 'block')),
                ),
            ],
          );
          if (constraints.maxWidth < 650) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 12), controls],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              controls,
            ],
          );
        },
      ),
    ),
  );
}

class AdminActionControls extends StatefulWidget {
  const AdminActionControls({
    super.key,
    required this.gateway,
    this.canEdit = true,
  });
  final AdminGateway gateway;
  final bool canEdit;
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
    appBar: AdminPageBar(
      title: at(context, 'actionControls'),
      icon: Icons.tune,
      desktop: MediaQuery.sizeOf(context).width >= 1100,
      subtitle: Localizations.localeOf(context).languageCode == 'ml'
          ? 'User പ്രവർത്തനങ്ങൾ ഓൺ അല്ലെങ്കിൽ ഓഫ് ചെയ്യുക.'
          : 'Enable or disable user actions.',
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 650,
        ),
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
                AdminNotice(text: at(context, 'actionHelp'), icon: Icons.tune),
                const SizedBox(height: 16),
                for (final type in ['follow', 'like', 'share', 'comment'])
                  Card(
                    child: SwitchListTile(
                      key: Key('action_$type'),
                      secondary: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xffeee6fc),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(switch (type) {
                          'follow' => Icons.person_add_alt_1,
                          'like' => Icons.thumb_up_alt,
                          'share' => Icons.share,
                          _ => Icons.chat_bubble,
                        }, color: adminViolet),
                      ),
                      title: Text(at(context, type)),
                      subtitle: Text(
                        at(
                          context,
                          values[type] == true ? 'enabled' : 'disabled',
                        ),
                      ),
                      value: values[type] == true,
                      onChanged:
                          changing ||
                              !widget.canEdit ||
                              !values.containsKey(type)
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
    appBar: AdminPageBar(
      title: at(context, 'campaigns'),
      icon: Icons.campaign,
      desktop: MediaQuery.sizeOf(context).width >= 1100,
      subtitle: Localizations.localeOf(context).languageCode == 'ml'
          ? 'Campaign-കൾ കാണുകയും നിയന്ത്രിക്കുകയും ചെയ്യുക.'
          : 'View and manage campaigns.',
      art: 'campaigns',
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 850,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminNotice(
                text: at(context, 'campaignInfo'),
                icon: Icons.campaign_outlined,
              ),
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
                              ? AdminEmptyState(
                                  title: at(context, 'campaignEmpty'),
                                  art: 'campaigns_empty',
                                )
                              : ListView.builder(
                                  itemCount: campaigns.length,
                                  itemBuilder: (context, index) {
                                    final campaign = campaigns[index];
                                    final completed =
                                        campaign.requested - campaign.remaining;
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.campaign_outlined,
                                                  color: adminViolet,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '${at(context, campaign.type)} · ${at(context, campaign.status)}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            SelectableText(
                                              'Campaign ID: ${campaign.id}',
                                              style: const TextStyle(
                                                color: adminMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              campaign.link,
                                              style: const TextStyle(
                                                color: adminMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              '${at(context, 'owner')}: ${campaign.ownerEmail.isEmpty ? campaign.ownerId : campaign.ownerEmail}',
                                              style: const TextStyle(
                                                color: adminMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              '${at(context, 'progress')}: $completed/${campaign.requested}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: campaign.requested > 0
                                                    ? (completed /
                                                              campaign
                                                                  .requested)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                minHeight: 6,
                                                backgroundColor: const Color(
                                                  0xffefedf8,
                                                ),
                                              ),
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
  String? type;
  final campaign = TextEditingController();
  DateTimeRange? range;
  late Future<List<AdminSubmission>> result;
  Future<List<AdminSubmission>> fetch() {
    final gateway = widget.gateway;
    if (gateway is AdminWorkspaceGateway) {
      return (gateway as AdminWorkspaceGateway).filteredSubmissions(
        type,
        campaign.text.trim().isEmpty ? null : campaign.text.trim(),
        range == null
            ? null
            : DateTime.utc(
                range!.start.year,
                range!.start.month,
                range!.start.day,
              ),
        range == null
            ? null
            : DateTime.utc(
                range!.end.year,
                range!.end.month,
                range!.end.day + 1,
              ),
        offset,
        pageSize,
      );
    }
    return gateway.submissions(offset, pageSize);
  }

  @override
  void dispose() {
    campaign.dispose();
    super.dispose();
  }

  Future<void> chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: range,
    );
    if (selected != null && mounted) setState(() => range = selected);
  }

  void applyFilters() {
    final value = campaign.text.trim();
    if (value.isNotEmpty &&
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(at(context, 'invalidCampaign'))));
      return;
    }
    offset = 0;
    reload();
  }

  @override
  void initState() {
    super.initState();
    result = fetch();
  }

  void reload() => setState(() {
    result = fetch();
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
    appBar: AdminPageBar(
      title: at(context, 'submissions'),
      icon: Icons.fact_check,
      desktop: MediaQuery.sizeOf(context).width >= 1100,
      subtitle: Localizations.localeOf(context).languageCode == 'ml'
          ? 'പരിശോധിക്കാനുള്ള submissions കാണുക.'
          : 'Review pending submissions.',
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 850,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              AdminNotice(
                text: at(context, 'reviewNotice'),
                icon: Icons.fact_check_outlined,
              ),
              if (widget.gateway is AdminWorkspaceGateway)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    at(context, 'filterSubmissions'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: type,
                          hint: Text(at(context, 'allActions')),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(at(context, 'allActions')),
                            ),
                            for (final item in [
                              'follow',
                              'like',
                              'share',
                              'comment',
                            ])
                              DropdownMenuItem(
                                value: item,
                                child: Text(at(context, item)),
                              ),
                          ],
                          onChanged: (value) => setState(() => type = value),
                        ),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: campaign,
                            decoration: InputDecoration(
                              labelText: at(context, 'campaignId'),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: chooseRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            range == null
                                ? at(context, 'dateRange')
                                : '${_dateOnly(range!.start)} – ${_dateOnly(range!.end)}',
                          ),
                        ),
                        FilledButton(
                          onPressed: applyFilters,
                          child: Text(at(context, 'apply')),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              type = null;
                              range = null;
                              campaign.clear();
                              offset = 0;
                            });
                            reload();
                          },
                          child: Text(at(context, 'clear')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              const SizedBox(height: 16),
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
                              ? AdminEmptyState(
                                  title: at(context, 'submissionEmpty'),
                                  art: 'submissions_empty',
                                )
                              : ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return Card(
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xffefedf8),
                                          foregroundColor: adminViolet,
                                          child: Icon(
                                            Icons.fact_check_outlined,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          at(context, item.type),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${item.link}${item.submittedAt == null ? '' : '\n${item.submittedAt}'}',
                                          maxLines: 3,
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
      final image = await decodeEvidenceImage(value['data'] as String);
      if (!mounted) return;
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
              cacheWidth: 1024,
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

class AdminCoinSettings extends StatefulWidget {
  const AdminCoinSettings({
    super.key,
    required this.gateway,
    this.canEdit = true,
  });
  final AdminGateway gateway;
  final bool canEdit;
  @override
  State<AdminCoinSettings> createState() => _AdminCoinSettingsState();
}

class _AdminCoinSettingsState extends State<AdminCoinSettings> {
  late Future<List<Map<String, dynamic>>> data = widget.gateway.coinSettings();
  bool busy = false;
  String label(String key) {
    final ml = Localizations.localeOf(context).languageCode == 'ml';
    return switch (key) {
      'registration' => ml ? 'Registration bonus' : 'Registration bonus',
      'invite' => ml ? 'ഓരോ invite-നും' : 'Each referral',
      'milestone_5' => ml ? '5 invites അധിക bonus' : '5 referrals: extra bonus',
      'milestone_10' =>
        ml ? '10 invites അധിക bonus' : '10 referrals: extra bonus',
      'milestone_15' =>
        ml ? '15 invites അധിക bonus' : '15 referrals: extra bonus',
      _ => at(context, key),
    };
  }

  Future<void> edit(Map<String, dynamic> row) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => CoinAmountDialog(
        title: label(row['key']),
        value: row['amount'],
        minimum: ['follow', 'like', 'comment', 'share'].contains(row['key'])
            ? 1
            : 0,
      ),
    );
    if (amount == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.gateway.setCoinSetting(row['key'], amount);
      if (mounted) {
        setState(() {
          data = widget.gateway.coinSettings();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(at(context, 'actionFailure'))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminPageBar(
      title: at(context, 'coinSettings'),
      icon: Icons.toll,
      desktop: MediaQuery.sizeOf(context).width >= 1100,
      subtitle: Localizations.localeOf(context).languageCode == 'ml'
          ? 'Reward coin മൂല്യങ്ങൾ ക്രമീകരിക്കുക.'
          : 'Configure reward coin values.',
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 650,
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(at(context, 'actionFailure')),
                    TextButton(
                      onPressed: () => setState(() {
                        data = widget.gateway.coinSettings();
                      }),
                      child: Text(at(context, 'refresh')),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const AdminNotice(
                  icon: Icons.toll_outlined,
                  text: 'Changes apply to future registrations, new campaigns and future referral events. Existing campaign rewards stay fixed. Referral rewards require an initialized inviter wallet.',
                ),
                const SizedBox(height: 16),
                for (final row in snapshot.data!)
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xffeee6fc),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.toll, color: adminViolet),
                      ),
                      title: Text(label(row['key'])),
                      subtitle: Text("${row['amount']} coins"),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: busy || !widget.canEdit ? null : () => edit(row),
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

class CoinAmountDialog extends StatefulWidget {
  const CoinAmountDialog({
    super.key,
    required this.title,
    required this.value,
    required this.minimum,
  });
  final String title;
  final int value, minimum;
  @override
  State<CoinAmountDialog> createState() => _CoinAmountDialogState();
}

class _CoinAmountDialogState extends State<CoinAmountDialog> {
  late final controller = TextEditingController(text: widget.value.toString());
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Coins (${widget.minimum}–10000)',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = int.tryParse(controller.text);
          if (value == null || value < widget.minimum || value > 10000) {
            setState(() => error = 'Enter a valid amount');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String adminReportCsv(List<Map<String, dynamic>> rows) {
  const keys = [
    'day',
    'registrations',
    'campaigns',
    'coin_transactions',
    'coins_credited',
    'coins_spent',
  ];
  return [
    keys.join(','),
    ...rows.map(
      (row) => keys
          .map(
            (key) => '"${(row[key] ?? '').toString().replaceAll('"', '""')}"',
          )
          .join(','),
    ),
  ].join('\r\n');
}

// The workspace keeps metrics and operational lists separate from account edits.
class AdminWorkspacePage extends StatefulWidget {
  const AdminWorkspacePage({
    super.key,
    required this.gateway,
    required this.page,
  });
  final AdminWorkspaceGateway gateway;
  final String page;
  @override
  State<AdminWorkspacePage> createState() => _AdminWorkspacePageState();
}

class _AdminWorkspacePageState extends State<AdminWorkspacePage> {
  late Future<dynamic> data;
  int offset = 0;
  DateTime end = DateTime.now().toUtc();
  late DateTime start = end.subtract(const Duration(days: 29));
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = switch (widget.page) {
      'overview' => widget.gateway.overview(),
      'activity' => widget.gateway.activity(offset),
      'reports' => widget.gateway.dailyReport(start, end),
      'alerts' => widget.gateway.alerts(),
      _ => widget.gateway.roles(),
    };
  }

  void reload() => setState(load);
  Future<void> dateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (result == null || !mounted) return;
    if (result.end.difference(result.start).inDays > 365) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(at(context, 'rangeTooLong'))));
      return;
    }
    setState(() {
      start = result.start;
      end = result.end;
      load();
    });
  }

  Future<void> export(List<Map<String, dynamic>> rows) async {
    try {
      final location = await getSaveLocation(
        suggestedName:
            'freelan-space-report-${_dateOnly(start)}-${_dateOnly(end)}.csv',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      final csv = adminReportCsv(rows);
      await XFile.fromData(
        Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(at(context, 'saveReport'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(at(context, 'saveFailure'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.page) {
      'overview' => at(context, 'overview'),
      'activity' => at(context, 'activity'),
      'reports' => at(context, 'reports'),
      'alerts' => at(context, 'alerts'),
      _ => at(context, 'roles'),
    };
    return Scaffold(
      appBar: AdminPageBar(
        title: title,
        desktop: MediaQuery.sizeOf(context).width >= 1100,
        icon: switch (widget.page) {
          'overview' => Icons.dashboard,
          'activity' => Icons.history,
          'reports' => Icons.bar_chart,
          'alerts' => Icons.notifications,
          _ => Icons.admin_panel_settings,
        },
        subtitle: widget.page == 'overview'
            ? at(context, 'overviewHelp')
            : null,
        art: widget.page == 'overview'
            ? 'overview'
            : widget.page == 'roles'
            ? 'roles'
            : null,
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 1600 : 900,
          ),
          child: FutureBuilder<dynamic>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(at(context, 'workspaceFailure')),
                      TextButton(
                        onPressed: reload,
                        child: Text(at(context, 'refresh')),
                      ),
                    ],
                  ),
                );
              }
              if (widget.page == 'overview') {
                final values = snapshot.data as Map<String, dynamic>;
                final metrics = <(String, String, IconData)>[
                  (at(context, 'users'), 'users', Icons.people_outline),
                  (
                    at(context, 'activeCampaigns'),
                    'active_campaigns',
                    Icons.campaign_outlined,
                  ),
                  (
                    at(context, 'submissions'),
                    'pending_submissions',
                    Icons.fact_check_outlined,
                  ),
                  (
                    at(context, 'coinsCredited'),
                    'coins_credited',
                    Icons.toll_outlined,
                  ),
                ];
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final metric in metrics)
                            SizedBox(
                              width: constraints.maxWidth >= 800
                                  ? (constraints.maxWidth - 36) / 4
                                  : 190,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: const Color(
                                          0xffeee6fc,
                                        ),
                                        child: Icon(
                                          metric.$3,
                                          color: adminViolet,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '${values[metric.$2] ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        metric.$1,
                                        style: const TextStyle(
                                          color: adminMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              final rows = (snapshot.data as List).cast<Map<String, dynamic>>();
              return Column(
                children: [
                  if (widget.page == 'reports')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: dateRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              '${_dateOnly(start)} – ${_dateOnly(end)} (UTC)',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => export(rows),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(at(context, 'exportCsv')),
                          ),
                        ],
                      ),
                    ),
                  if (widget.page == 'alerts')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: AdminNotice(text: at(context, 'alertsHelp')),
                    ),
                  if (widget.page == 'roles')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: AdminNotice(text: at(context, 'rolesHelp')),
                    ),
                  Expanded(
                    child: rows.isEmpty
                        ? AdminEmptyState(
                            title: at(context, 'noRecords'),
                            art: widget.page == 'alerts'
                                ? 'alerts_empty'
                                : null,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              final (heading, detail) = switch (widget.page) {
                                'activity' => (
                                  '${r['action']} · ${r['actor']}',
                                  '${r['details']}\n${r['event_at']}',
                                ),
                                'reports' => (
                                  '${r['day']}',
                                  "${at(context, 'registrations')}: ${r['registrations']}  ·  ${at(context, 'campaigns')}: ${r['campaigns']}\n${at(context, 'transactions')}: ${r['coin_transactions']}  ·  ${at(context, 'credited')}: ${r['coins_credited']}  ·  ${at(context, 'spent')}: ${r['coins_spent']}",
                                ),
                                'alerts' => (
                                  '${r['kind']} · ${r['subject']}',
                                  'Activity: ${r['activity']}  ·  ${r['observed_at']}',
                                ),
                                _ => (
                                  '${r['email']}',
                                  '${r['role']}  ·  ${r['created_at']}',
                                ),
                              };
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xffeee6fc),
                                    child: Icon(switch (widget.page) {
                                      'activity' => Icons.history,
                                      'reports' => Icons.bar_chart,
                                      'alerts' => Icons.notifications_outlined,
                                      _ => Icons.admin_panel_settings_outlined,
                                    }, color: adminViolet),
                                  ),
                                  title: Text(
                                    heading,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(detail),
                                ),
                              );
                            },
                          ),
                  ),
                  if (widget.page == 'activity')
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
                          child: Text(at(context, 'previous')),
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
                          child: Text(at(context, 'next')),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AdminUserDetails extends StatelessWidget {
  const AdminUserDetails({
    super.key,
    required this.gateway,
    required this.user,
  });
  final AdminWorkspaceGateway gateway;
  final AdminUser user;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(user.name.isEmpty ? user.email : user.name)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: gateway.userDetails(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text(at(context, 'detailsFailure')));
        }
        final data = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AdminCopyField(label: 'Name', value: user.name),
                AdminCopyField(label: 'Email', value: user.email),
                AdminCopyField(label: 'User ID', value: user.publicId ?? '—'),
                SelectableText(
                  'User ID: ${user.publicId ?? '—'}',
                  style: const TextStyle(color: adminMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  '${at(context, 'coins')}: ${user.coins ?? '—'}  ·  ${at(context, 'referrals')}: ${data['referrals']}  ·  ${at(context, 'role')}: ${data['role'] ?? at(context, 'member')}',
                ),
                const SizedBox(height: 8),
                Text(
                  "${at(context, 'referredBy')}: ${at(context, data['referred'] == true ? 'yes' : 'no')}",
                  style: const TextStyle(color: adminMuted),
                ),
                const SizedBox(height: 16),
                AdminNotice(text: at(context, 'recentRecords')),
                for (final section in [
                  'campaigns',
                  'submissions',
                  'ledger',
                ]) ...[
                  const SizedBox(height: 24),
                  Text(
                    at(
                      context,
                      section == 'submissions' ? 'submissionHistory' : section,
                    ).toUpperCase(),
                    style: const TextStyle(
                      color: adminViolet,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if ((data[section] as List).isEmpty)
                    Text(at(context, 'noRecords')),
                  for (final item in data[section] as List)
                    Card(
                      child: ListTile(
                        title: Text(
                          section == 'ledger'
                              ? '${item['reason']} · ${item['amount']} coins'
                              : '${item['type']} · ${item['status']}',
                        ),
                        subtitle: Text(
                          section == 'campaigns'
                              ? '${item['link']}\nCompleted: ${item['requested'] - item['remaining']}/${item['requested']} · ${item['created_at']}'
                              : section == 'submissions'
                              ? '${item['link']}\n${item['created_at']}'
                              : '${item['created_at']}',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Desktop navigation owns its Navigator so detail routes keep the sidebar.
class AdminDesktopConsole extends StatefulWidget {
  const AdminDesktopConsole({
    super.key,
    required this.gateway,
    required this.onLogout,
    required this.onLanguage,
  });
  final AdminGateway gateway;
  final Future<void> Function() onLogout;
  final VoidCallback onLanguage;
  @override
  State<AdminDesktopConsole> createState() => _AdminDesktopConsoleState();
}

class _AdminDesktopConsoleState extends State<AdminDesktopConsole> {
  final navigator = GlobalKey<NavigatorState>();
  String selected = 'users';
  String? role;
  @override
  void initState() {
    super.initState();
    if (widget.gateway is AdminWorkspaceGateway) {
      (widget.gateway as AdminWorkspaceGateway)
          .workspaceRole()
          .then((value) {
            if (mounted) setState(() => role = value);
          })
          .catchError((Object _) {});
    } else {
      role = 'editor';
    }
  }

  Widget page(String key) => switch (key) {
    'users' => AdminDashboard(
      gateway: widget.gateway,
      onLogout: widget.onLogout,
      onLanguage: widget.onLanguage,
      embedded: true,
    ),
    'campaigns' => AdminCampaigns(gateway: widget.gateway),
    'submissions' => AdminSubmissions(gateway: widget.gateway),
    'actionControls' => AdminActionControls(
      gateway: widget.gateway,
      canEdit: role == 'editor',
    ),
    'coinSettings' => AdminCoinSettings(
      gateway: widget.gateway,
      canEdit: role == 'editor',
    ),
    'updates' => AdminAppReleasesPage(
      client: (widget.gateway as SupabaseAdminGateway).client,
      canEdit: role == 'editor',
    ),
    'sendNotifications' => AdminSendNotificationPage(
      gateway: SupabaseAdminNotificationGateway(
        (widget.gateway as SupabaseAdminGateway).client,
      ),
      canEdit: role == 'editor',
    ),
    'walletControls' => AdminOperationsPage(
      client: (widget.gateway as SupabaseAdminGateway).client,
      canEdit: role == 'editor', initialPage: 'coins',
    ),
    'operations' => AdminOperationsPage(
      client: (widget.gateway as SupabaseAdminGateway).client,
      canEdit: role == 'editor',
    ),
    _ => AdminWorkspacePage(
      gateway: widget.gateway as AdminWorkspaceGateway,
      page: key,
    ),
  };

  void select(String key) {
    setState(() => selected = key);
    navigator.currentState!.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => page(key)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(String, IconData)>[
      if (widget.gateway is AdminWorkspaceGateway)
        ('overview', Icons.dashboard_outlined),
      ('users', Icons.people_outline),
      ('campaigns', Icons.campaign_outlined),
      ('submissions', Icons.fact_check_outlined),
      if (widget.gateway is AdminWorkspaceGateway) ...[
        ('activity', Icons.history),
        ('reports', Icons.bar_chart_outlined),
        ('alerts', Icons.notifications_outlined),
        ('roles', Icons.admin_panel_settings_outlined),
      ],
      ('actionControls', Icons.tune),
      ('coinSettings', Icons.toll_outlined),
      if (widget.gateway is SupabaseAdminGateway) ...[
        ('sendNotifications', Icons.send_outlined),
        ('updates', Icons.system_update),
        ('walletControls', Icons.account_balance_wallet_outlined),
        ('operations', Icons.settings_outlined),
      ],
    ];
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 230,
            child: Material(
              color: const Color(0xff180d38),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 26, 24, 4),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hub_rounded,
                            color: Color(0xffa88bff),
                            size: 54,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Freelan Space',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      child: Text(
                        at(context, 'workspace'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff9895b5),
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final entry in entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: selected == entry.$1
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xff873cff),
                                            Color(0xff4521bf),
                                          ],
                                        )
                                      : null,
                                  boxShadow: selected == entry.$1
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xff6a34f1)
                                                .withValues(alpha: .3),
                                            blurRadius: 16,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    selected: selected == entry.$1,
                                    selectedTileColor: Colors.transparent,
                                    leading: Icon(
                                      entry.$2,
                                      size: 20,
                                      color: selected == entry.$1
                                          ? Colors.white
                                          : const Color(0xffa6a3bf),
                                    ),
                                    title: Text(
                                      entry.$1 == 'updates'
                                          ? 'App releases'
                                          : entry.$1 == 'operations'
                                          ? 'Admin operations'
                                          : at(context, entry.$1),
                                      style: TextStyle(
                                        color: selected == entry.$1
                                            ? Colors.white
                                            : const Color(0xffc4c1d5),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onTap: () => select(entry.$1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: Color(0xff343147),
                      indent: 24,
                      endIndent: 24,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xff35314e),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xffcec4ff),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  at(context, 'admin'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  role ?? '…',
                                  style: const TextStyle(
                                    color: Color(0xffa6a3bf),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .65),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.space_dashboard_outlined,
                        color: adminViolet,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        at(context, 'workspaceMenu'),
                        style: const TextStyle(color: adminMuted),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: adminMuted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          selected == 'operations'
                              ? 'Admin operations'
                              : selected == 'updates'
                              ? 'App releases'
                              : at(context, selected),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onLanguage,
                        icon: const Icon(Icons.language, size: 18),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'ml'
                              ? 'English'
                              : 'മലയാളം',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout, size: 16),
                        label: Text(at(context, 'logout')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Navigator(
                    key: navigator,
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => page('users')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminCopyField extends StatelessWidget {
  const AdminCopyField({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Flexible(child: SelectableText(value.isEmpty ? '—' : value)),
    IconButton(tooltip: 'Copy $label', icon: const Icon(Icons.copy, size: 16),
      onPressed: value.isEmpty || value == '—' ? null : () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
      }),
  ]);
}
