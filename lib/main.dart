import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const authRedirect = 'io.supabase.growthcircle://login-callback/';
final language = ValueNotifier<Locale>(const Locale('en'));
SupabaseClient get db => Supabase.instance.client;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  }
  runApp(GrowthApp(configured: configured));
}

const words = <String, List<String>>{
  'otpTitle': ['Verify your email', 'ഇമെയിൽ സ്ഥിരീകരിക്കുക'],
  'otpHint': ['Enter the 6-digit code sent to', '6 അക്ക കോഡ് അയച്ച ഇമെയിൽ'],
  'otp': ['6-digit code', '6 അക്ക കോഡ്'],
  'verifyOtp': ['Verify email', 'ഇമെയിൽ സ്ഥിരീകരിക്കുക'],
  'resendOtp': ['Resend code', 'കോഡ് വീണ്ടും അയയ്ക്കുക'],
  'receivedOtp': [
    'Already received a code? Verify email',
    'കോഡ് ലഭിച്ചോ? ഇമെയിൽ സ്ഥിരീകരിക്കുക',
  ],
  'changeEmail': [
    'Change email / Back to sign in',
    'ഇമെയിൽ മാറ്റുക / ലോഗിനിലേക്ക് മടങ്ങുക',
  ],
  'invalidOtp': ['Enter a valid 6-digit code.', 'ശരിയായ 6 അക്ക കോഡ് നൽകുക.'],
  'expiredOtp': [
    'Code is invalid or expired. Check it or request a new code.',
    'കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ കാലാവധി കഴിഞ്ഞു. പരിശോധിക്കുക അല്ലെങ്കിൽ പുതിയ കോഡ് ആവശ്യപ്പെടുക.',
  ],
  'signupComplete': [
    'Email verified. Sign in with your password to continue.',
    'ഇമെയിൽ സ്ഥിരീകരിച്ചു. തുടരാൻ പാസ്‌വേഡ് ഉപയോഗിച്ച് ലോഗിൻ ചെയ്യുക.',
  ],
  'confirmationRequired': [
    'Email confirmation must be enabled by the app owner before signup.',
    'Signup-ന് മുമ്പ് ആപ്പ് ഉടമ email confirmation പ്രവർത്തനക്ഷമമാക്കണം.',
  ],
  'checkEmail': [
    'Check your email to confirm your account.',
    'അക്കൗണ്ട് സ്ഥിരീകരിക്കാൻ ഇമെയിൽ പരിശോധിക്കുക.',
  ],
  'newPassword': ['New password', 'പുതിയ പാസ്‌വേഡ്'],
  'updatePassword': ['Update password', 'പാസ്‌വേഡ് പുതുക്കുക'],
  'passwordUpdated': ['Password updated.', 'പാസ്‌വേഡ് പുതുക്കി.'],
  'tagline': [
    'Grow together, one connection at a time.',
    'ഒരുമിച്ച് വളരാം, ഓരോ ബന്ധത്തിലൂടെയും.',
  ],
  'email': ['Email', 'ഇമെയിൽ'],
  'authWelcome': ['Welcome back', 'വീണ്ടും സ്വാഗതം'],
  'authWelcomeDesc': [
    'Sign in to continue growing together.',
    'ഒരുമിച്ച് വളരാൻ ലോഗിൻ ചെയ്യുക.',
  ],
  'authSignupDesc': [
    'Join your community today.',
    'നമ്മുടെ കൂട്ടായ്മയിൽ ചേരൂ.',
  ],
  'authName': ['Name · optional', 'പേര് · നിർബന്ധമില്ല'],
  'authNameHint': ['Your name', 'നിങ്ങളുടെ പേര്'],
  'authEmailHint': ['you@example.com', 'you@example.com'],
  'authPasswordHint': ['Enter your password', 'പാസ്‌വേഡ് നൽകുക'],
  'authNewPasswordHint': ['At least 6 characters', 'കുറഞ്ഞത് 6 അക്ഷരങ്ങൾ'],
  'authSignupHelp': [
    'Verify your email with a 6-digit code, then sign in with your password.',
    '6 അക്ക കോഡ് ഉപയോഗിച്ച് ഇമെയിൽ സ്ഥിരീകരിച്ച് പാസ്‌വേഡ് നൽകി ലോഗിൻ ചെയ്യുക.',
  ],
  'showPassword': ['Show password', 'പാസ്‌വേഡ് കാണിക്കുക'],
  'hidePassword': ['Hide password', 'പാസ്‌വേഡ് മറയ്ക്കുക'],
  'password': ['Password', 'പാസ്‌വേഡ്'],
  'login': ['Sign in', 'ലോഗിൻ'],
  'register': ['Create account', 'അക്കൗണ്ട് തുറക്കുക'],
  'forgot': ['Forgot password?', 'പാസ്‌വേഡ് മറന്നോ?'],
  'resetSent': [
    'Password reset email sent.',
    'പാസ്‌വേഡ് മാറ്റാനുള്ള ഇമെയിൽ അയച്ചു.',
  ],
  'enterEmail': ['Enter your email first.', 'ആദ്യം ഇമെയിൽ നൽകുക.'],
  'noAccount': [
    'New here? Create account',
    'പുതിയ ഉപയോക്താവാണോ? അക്കൗണ്ട് തുറക്കുക',
  ],
  'haveAccount': [
    'Already have an account? Sign in',
    'അക്കൗണ്ട് ഉണ്ടോ? ലോഗിൻ ചെയ്യുക',
  ],
  'home': ['Home', 'ഹോം'],
  'earn': ['Earn', 'നേടുക'],
  'campaigns': ['Campaigns', 'ക്യാമ്പെയ്‌നുകൾ'],
  'profile': ['Profile', 'പ്രൊഫൈൽ'],
  'balance': ['Your coin balance', 'നിങ്ങളുടെ coin ബാലൻസ്'],
  'coins': ['coins', 'coins'],
  'welcome': [
    'Small actions. Shared momentum.',
    'ചെറിയ പ്രവർത്തനങ്ങൾ. ഒരുമിച്ചുള്ള വളർച്ച.',
  ],
  'homeDesc': [
    'Discover community posts, earn coins and create your own campaign.',
    'മറ്റുള്ളവരുടെ പോസ്റ്റുകൾ കണ്ടെത്തി coins നേടൂ; നിങ്ങളുടെ campaign ആരംഭിക്കൂ.',
  ],
  'browse': ['Browse tasks', 'Task-ുകൾ കാണുക'],
  'create': ['Create campaign', 'Campaign തുടങ്ങുക'],
  'disclaimer': [
    'Tasks are reviewed by campaign owners. Instagram activity is not automatically verified or guaranteed.',
    'Task campaign ഉടമ പരിശോധിക്കും. Instagram പ്രവർത്തനം സ്വയമേവ പരിശോധിക്കുകയോ ഉറപ്പുനൽകുകയോ ചെയ്യുന്നില്ല.',
  ],
  'earnTitle': ['Explore tasks', 'Task-ുകൾ കണ്ടെത്തുക'],
  'submitProof': ['Submit for review', 'പരിശോധനയ്ക്ക് അയയ്ക്കുക'],
  'proofTitle': ['Submit your task', 'Task പരിശോധനയ്ക്ക് അയയ്ക്കുക'],
  'proofInfo': [
    'Enter your Instagram username and choose a screenshot. The campaign owner will review it before you earn a coin.',
    'Instagram username-ഉം screenshot-ഉം നൽകുക. Campaign ഉടമ പരിശോധിച്ച ശേഷമേ coin ലഭിക്കൂ.',
  ],
  'proofHandle': ['Instagram username', 'Instagram username'],
  'proofSelect': ['Choose screenshot', 'Screenshot തിരഞ്ഞെടുക്കുക'],
  'proofChange': ['Change screenshot', 'Screenshot മാറ്റുക'],
  'proofRequired': [
    'Choose a JPEG or PNG screenshot under 512 KB.',
    '512 KB-ൽ താഴെയുള്ള JPEG അല്ലെങ്കിൽ PNG screenshot തിരഞ്ഞെടുക്കുക.',
  ],
  'proofBadHandle': [
    'Enter a valid Instagram username.',
    'ശരിയായ Instagram username നൽകുക.',
  ],
  'proofSubmitted': [
    'Submitted. Your coin is awarded after owner approval.',
    'അയച്ചു. ഉടമ അംഗീകരിച്ച ശേഷം coin ലഭിക്കും.',
  ],
  'pending': ['Awaiting review', 'പരിശോധനയ്ക്കായി കാത്തിരിക്കുന്നു'],
  'approved': ['Approved', 'അംഗീകരിച്ചു'],
  'rejected': ['Rejected · you can resubmit', 'നിരസിച്ചു · വീണ്ടും അയയ്ക്കാം'],
  'reviewCancelled': ['Campaign cancelled', 'Campaign റദ്ദാക്കി'],
  'reviewTitle': ['Review submission', 'Task പരിശോധിക്കുക'],
  'enlargeProof': ['Enlarge screenshot', 'Screenshot വലുതാക്കുക'],
  'reviewHelp': [
    'Check the screenshot and Instagram activity before deciding. Screenshots can be misleading.',
    'തീരുമാനിക്കുന്നതിന് മുമ്പ് screenshot-ഉം Instagram പ്രവർത്തനവും പരിശോധിക്കുക. Screenshot തെറ്റിദ്ധരിപ്പിക്കുന്നതാകാം.',
  ],
  'approve': ['Approve', 'അംഗീകരിക്കുക'],
  'reject': ['Reject', 'നിരസിക്കുക'],
  'reviewDone': ['Decision saved.', 'തീരുമാനം സേവ് ചെയ്തു.'],
  'reviewEmpty': ['Evidence unavailable.', 'തെളിവ് ലഭ്യമല്ല.'],
  'reviewCapacity': [
    'All remaining tasks are awaiting review.',
    'ബാക്കിയുള്ള task-ുകൾ പരിശോധനയ്ക്കായി കാത്തിരിക്കുന്നു.',
  ],
  'reviewedCount': ['approved', 'അംഗീകരിച്ചത്'],
  'mySubmissions': ['Your submissions', 'നിങ്ങൾ അയച്ചവ'],
  'withdraw': ['Withdraw submission', 'സമർപ്പിച്ചത് പിൻവലിക്കുക'],
  'withdrawn': [
    'Withdrawn · you can resubmit',
    'പിൻവലിച്ചു · വീണ്ടും അയയ്ക്കാം',
  ],
  'withdrawDone': ['Submission withdrawn.', 'സമർപ്പിച്ചത് പിൻവലിച്ചു.'],
  'proofNoPrivate': [
    'Share only the relevant screenshot. It is visible to you and the campaign owner until review.',
    'ആവശ്യമായ screenshot മാത്രം നൽകുക. പരിശോധന വരെ അത് നിങ്ങൾക്കും campaign ഉടമയ്ക്കും കാണാം.',
  ],
  'earnDesc': [
    'Open Instagram, complete an action and submit it for review.',
    'Instagram തുറന്ന് പ്രവർത്തനം പൂർത്തിയാക്കി പരിശോധനയ്ക്ക് അയയ്ക്കുക.',
  ],
  'emptyTasks': ['No tasks available yet.', 'ഇപ്പോൾ task-ുകൾ ലഭ്യമല്ല.'],
  'open': ['Open Instagram', 'Instagram തുറക്കുക'],
  'confirm': ['I completed this', 'ഇത് പൂർത്തിയാക്കി'],
  'confirmTitle': ['Confirm your action', 'പ്രവർത്തനം സ്ഥിരീകരിക്കുക'],
  'confirmBody': [
    'Only confirm after completing the action. This app cannot verify Instagram activity.',
    'പ്രവർത്തനം പൂർത്തിയാക്കിയ ശേഷം മാത്രം സ്ഥിരീകരിക്കുക. ഇത് ആപ്പിന് പരിശോധിക്കാനാവില്ല.',
  ],
  'cancel': ['Cancel', 'റദ്ദാക്കുക'],
  'yesConfirm': ['Confirm', 'സ്ഥിരീകരിക്കുക'],
  'claimed': [
    'Claim recorded. You earned 1 coin.',
    'സ്ഥിരീകരിച്ചു. നിങ്ങൾക്ക് ഒരു coin ലഭിച്ചു.',
  ],
  'type': ['Action', 'പ്രവർത്തനം'],
  'follow': ['Follow', 'Follow'],
  'like': ['Like', 'Like'],
  'comment': ['Comment', 'Comment'],
  'share': ['Share', 'Share'],
  'link': ['Instagram link', 'Instagram ലിങ്ക്'],
  'profileHint': [
    'https://www.instagram.com/username/',
    'https://www.instagram.com/username/',
  ],
  'postHint': [
    'https://www.instagram.com/p/.../',
    'https://www.instagram.com/p/.../',
  ],
  'count': ['Number of tasks', 'Task എണ്ണം'],
  'cost': [
    '1 coin per task · 1–100 tasks',
    'ഓരോ task-നും 1 coin · 1–100 task-ുകൾ',
  ],
  'submit': ['Create campaign', 'Campaign തുടങ്ങുക'],
  'created': ['Campaign created.', 'Campaign ആരംഭിച്ചു.'],
  'myCampaigns': ['Your campaigns', 'നിങ്ങളുടെ campaign-ുകൾ'],
  'emptyCampaigns': ['You have no campaigns yet.', 'ഇതുവരെ campaign-ുകൾ ഇല്ല.'],
  'claims': ['counted', 'രേഖപ്പെടുത്തിയവ'],
  'legacy': [
    'Previously self-reported · already paid',
    'മുൻപ് സ്വയം അറിയിച്ചത് · coin നൽകിയിട്ടുണ്ട്',
  ],
  'legacyCount': ['Previously self-reported', 'മുൻപ് സ്വയം അറിയിച്ചത്'],
  'remaining': ['remaining', 'ബാക്കി'],
  'active': ['Active', 'സജീവം'],
  'completed': ['Completed', 'പൂർത്തിയായി'],
  'cancelled': ['Cancelled', 'റദ്ദാക്കി'],
  'cancelCampaign': ['Cancel campaign', 'Campaign റദ്ദാക്കുക'],
  'cancelTitle': ['Cancel this campaign?', 'Campaign റദ്ദാക്കണോ?'],
  'cancelBody': [
    'Unapproved tasks, including pending submissions, will be cancelled and their coins returned.',
    'പരിശോധനയിലുള്ളവ ഉൾപ്പെടെ അംഗീകരിക്കാത്ത task-ുകൾ റദ്ദാക്കി coins തിരികെ നൽകും.',
  ],
  'cancelledMessage': [
    'Campaign cancelled and unused coins refunded.',
    'Campaign റദ്ദാക്കി; ബാക്കി coins തിരികെ നൽകി.',
  ],
  'history': ['Coin history', 'Coin ചരിത്രം'],
  'emptyHistory': ['No transactions yet.', 'ഇതുവരെ ഇടപാടുകളില്ല.'],
  'welcomeReason': ['Welcome coins', 'സ്വാഗത coins'],
  'campaignReason': ['Campaign budget', 'Campaign ബജറ്റ്'],
  'taskReason': ['Task claim', 'Task സ്ഥിരീകരണം'],
  'refundReason': ['Campaign refund', 'Campaign refund'],
  'signout': ['Sign out', 'ലോഗൗട്ട്'],
  'language': ['മലയാളം', 'English'],
  'emailNotAuthorized': [
    'Email delivery is restricted. Ask the app owner to configure email service.',
    'ഇമെയിൽ അയയ്ക്കുന്നതിന് നിയന്ത്രണമുണ്ട്. Email service ക്രമീകരിക്കാൻ ആപ്പ് ഉടമയോട് പറയുക.',
  ],
  'emailNotConfirmed': [
    'Confirm your email before signing in. Check your inbox.',
    'ലോഗിൻ ചെയ്യുന്നതിന് മുമ്പ് ഇമെയിൽ സ്ഥിരീകരിക്കുക. Inbox പരിശോധിക്കുക.',
  ],
  'tooManyRequests': [
    'Too many attempts. Wait a while and try again.',
    'വളരെയധികം ശ്രമങ്ങൾ നടന്നു. കുറച്ച് കഴിഞ്ഞ് വീണ്ടും ശ്രമിക്കുക.',
  ],
  'signupUnavailable': [
    'Account registration is unavailable. Contact the app owner.',
    'അക്കൗണ്ട് തുറക്കാനാവുന്നില്ല. ആപ്പ് ഉടമയെ ബന്ധപ്പെടുക.',
  ],
  'connectionError': [
    'Could not connect. Check your internet and try again.',
    'ബന്ധിപ്പിക്കാൻ കഴിഞ്ഞില്ല. Internet പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
  ],
  'confirmationEmailFailed': [
    'The server could not send your verification email. Contact app support to check email delivery settings.',
    'Verification email അയയ്ക്കാൻ server-ന് കഴിഞ്ഞില്ല. Email delivery settings പരിശോധിക്കാൻ app support-നെ ബന്ധപ്പെടുക.',
  ],
  'accountCreationFailed': [
    'The server could not save your account. Contact app support.',
    'നിങ്ങളുടെ അക്കൗണ്ട് server-ൽ സേവ് ചെയ്യാൻ കഴിഞ്ഞില്ല. App support-നെ ബന്ധപ്പെടുക.',
  ],
  'serviceUnavailable': [
    'The sign-in service is temporarily unavailable. Try again later.',
    'ലോഗിൻ സേവനം ഇപ്പോൾ ലഭ്യമല്ല. കുറച്ച് കഴിഞ്ഞ് ശ്രമിക്കുക.',
  ],
  'passwordRequirements': [
    'Password does not meet the requirements. Try a stronger password.',
    'പാസ്‌വേഡ് നിബന്ധനകൾ പാലിക്കുന്നില്ല. കൂടുതൽ ശക്തമായ പാസ്‌വേഡ് നൽകുക.',
  ],
  'error': [
    'Something went wrong. Please try again.',
    'പ്രശ്നം സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കുക.',
  ],
  'required': ['This field is required.', 'ഈ വിവരങ്ങൾ നൽകുക.'],
  'validCount': [
    'Enter a number from 1 to 100.',
    '1 മുതൽ 100 വരെയുള്ള സംഖ്യ നൽകുക.',
  ],
  'openError': ['Could not open Instagram.', 'Instagram തുറക്കാൻ കഴിഞ്ഞില്ല.'],
  'loading': ['Loading…', 'ലോഡ് ചെയ്യുന്നു…'],
  'retry': ['Retry', 'വീണ്ടും ശ്രമിക്കുക'],
  'notEnough': ['Not enough coins.', 'ആവശ്യത്തിന് coins ഇല്ല.'],
  'already': [
    'You already claimed this task.',
    'ഈ task നിങ്ങൾ ഇതിനകം സ്ഥിരീകരിച്ചു.',
  ],
  'inactive': [
    'This campaign is no longer active.',
    'ഈ campaign ഇപ്പോൾ സജീവമല്ല.',
  ],
  'invalidLink': [
    'Check the Instagram link for this action.',
    'ഈ പ്രവർത്തനത്തിനുള്ള Instagram ലിങ്ക് പരിശോധിക്കുക.',
  ],
  'invalidLogin': [
    'Check your email and password. If you have no account, create one below.',
    'ഇമെയിലും പാസ്‌വേഡും പരിശോധിക്കുക. അക്കൗണ്ട് ഇല്ലെങ്കിൽ താഴെ Sign up ചെയ്യുക.',
  ],
  'emailInUse': [
    'This email is already registered.',
    'ഈ ഇമെയിൽ ഇതിനകം രജിസ്റ്റർ ചെയ്തിട്ടുണ്ട്.',
  ],
  'weakPassword': [
    'Password must be at least 6 characters.',
    'പാസ്‌വേഡിൽ കുറഞ്ഞത് 6 അക്ഷരങ്ങൾ വേണം.',
  ],
};
String tr(BuildContext context, String key) =>
    words[key]?[Localizations.localeOf(context).languageCode == 'ml' ? 1 : 0] ??
    key;
String? authErrorKey(AuthException e) {
  switch (e.code) {
    case 'otp_expired':
      return 'expiredOtp';
    case 'confirmation_required':
      return 'confirmationRequired';
    case 'email_address_not_authorized':
      return 'emailNotAuthorized';
    case 'email_not_confirmed':
      return 'emailNotConfirmed';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'tooManyRequests';
    case 'email_exists':
    case 'user_already_exists':
      return 'emailInUse';
    case 'signup_disabled':
    case 'email_provider_disabled':
      return 'signupUnavailable';
    case 'weak_password':
      return 'passwordRequirements';
    case 'invalid_credentials':
      return 'invalidLogin';
  }
  var message = e.message.toLowerCase();
  // GoTrue wraps HTTP 5xx bodies in AuthRetryableFetchException without
  // parsing their JSON error code. Read known fields, never display raw text.
  if (e is AuthRetryableFetchException && e.statusCode != null) {
    try {
      final body = jsonDecode(e.message);
      if (body is Map<String, dynamic>) {
        message =
            (body['msg'] ?? body['message'] ?? body['error_description'] ?? '')
                .toString()
                .toLowerCase();
      }
    } on FormatException {
      // Proxy HTML or other non-JSON responses retain the generic fallback.
    }
    if (message.contains('error sending confirmation email') ||
        message.contains('error sending recovery email') ||
        message.contains('error sending magic link email')) {
      return 'confirmationEmailFailed';
    }
    if (message.contains('database error saving new user')) {
      return 'accountCreationFailed';
    }
  }
  if (message.contains('already registered')) return 'emailInUse';
  if (message.contains('password') && message.contains('least')) {
    return 'passwordRequirements';
  }
  if (message.contains('invalid login credentials')) return 'invalidLogin';
  if (message.contains('email') && message.contains('not authorized')) {
    return 'emailNotAuthorized';
  }
  if (e.statusCode == '429') return 'tooManyRequests';
  if (e is AuthRetryableFetchException) {
    return e.statusCode == null ? 'connectionError' : 'serviceUnavailable';
  }
  return null;
}

String friendlyError(BuildContext context, Object e) {
  if (e is AuthException) {
    final key = authErrorKey(e);
    if (key != null) {
      final status = e.statusCode;
      final diagnostic =
          e is AuthRetryableFetchException &&
              status != null &&
              RegExp(r'^5\d{2}$').hasMatch(status)
          ? ' (HTTP $status)'
          : '';
      return '${tr(context, key)}$diagnostic';
    }
    // Error codes help diagnose failures without exposing server messages or user data.
    final code = e.code;
    if (code != null && RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(code)) {
      return '${tr(context, 'error')} ($code)';
    }
    final status = e.statusCode;
    if (status != null && RegExp(r'^\d{3}$').hasMatch(status)) {
      return '${tr(context, 'error')} (HTTP $status)';
    }
    return tr(context, 'error');
  }
  if (e is TimeoutException) return tr(context, 'connectionError');
  if (e is PostgrestException) {
    if (e.message.contains('already claimed') ||
        e.message.contains('already submitted')) {
      return tr(context, 'already');
    }
    if (e.message.contains('awaiting review')) {
      return tr(context, 'reviewCapacity');
    }
    if (e.message.contains('Instagram username')) {
      return tr(context, 'proofBadHandle');
    }
    if (e.message.contains('JPEG') || e.message.contains('Invalid image')) {
      return tr(context, 'proofRequired');
    }
    if (e.message.contains('Invalid Instagram')) {
      return tr(context, 'invalidLink');
    }
    if (e.message.contains('Not enough coins')) return tr(context, 'notEnough');
    if (e.message.contains('no longer active')) return tr(context, 'inactive');
  }
  return tr(context, 'error');
}

void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
  );
}

void toggleLanguage() =>
    language.value = Locale(language.value.languageCode == 'en' ? 'ml' : 'en');

class GrowthApp extends StatelessWidget {
  const GrowthApp({super.key, required this.configured});
  final bool configured;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (_, locale, _) => MaterialApp(
      title: 'Growth Circle',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ml')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff6554c0),
          surface: const Color(0xfffaf9ff),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: configured ? const AuthGate() : const SetupScreen(),
    ),
  );
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Supabase is not configured. See the project setup instructions to build this app with a Supabase project.',
        ),
      ),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> subscription;
  bool recovery = false;
  @override
  void initState() {
    super.initState();
    subscription = db.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          if (state.event == AuthChangeEvent.passwordRecovery) recovery = true;
          if (state.event == AuthChangeEvent.signedOut) recovery = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) toast(context, friendlyError(context, error));
      },
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (recovery) {
      return RecoveryScreen(onDone: () => setState(() => recovery = false));
    }
    final user = db.auth.currentUser;
    return user == null
        ? const AuthScreen()
        : AccountGate(key: ValueKey(user.id), user: user);
  }
}

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (password.text.length < 6) {
      toast(context, tr(context, 'weakPassword'));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: password.text));
      if (mounted) {
        toast(context, tr(context, 'passwordUpdated'));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'newPassword'))),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(labelText: tr(context, 'newPassword')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(tr(context, 'updatePassword')),
          ),
        ],
      ),
    ),
  );
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key, required this.user});
  final User user;
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late Future<void> initialize;
  @override
  void initState() {
    super.initState();
    initialize = load();
  }

  Future<void> load() async {
    await db.rpc('initialize_wallet');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialize,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'error')),
                TextButton(
                  onPressed: () => setState(() => initialize = load()),
                  child: Text(tr(context, 'retry')),
                ),
                TextButton(
                  onPressed: () => db.auth.signOut(),
                  child: Text(tr(context, 'signout')),
                ),
              ],
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return HomeShell(user: widget.user);
    },
  );
}

// Signup verification uses an isolated in-memory client. Its temporary session
// never reaches AuthGate or persistent storage; only password login opens Home.
class AuthActions {
  GoTrueClient signupClient() => GoTrueClient(
    url: '$supabaseUrl/auth/v1',
    headers: {'apikey': supabaseKey},
    autoRefreshToken: false,
    flowType: AuthFlowType.implicit,
  );

  Future<void> signup(String email, String password, {String? name}) async {
    final client = signupClient();
    try {
      final response = await client.signUp(
        email: email,
        password: password,
        data: name == null || name.trim().isEmpty
            ? null
            : {'full_name': name.trim()},
      );
      if (response.session != null) {
        throw const AuthException(
          'Confirmation required',
          code: 'confirmation_required',
        );
      }
      if (response.user?.identities?.isEmpty ?? false) {
        throw const AuthException('Registered', code: 'email_exists');
      }
    } finally {
      client.dispose();
    }
  }

  Future<void> verify(String email, String code) async {
    final client = signupClient();
    try {
      await client.verifyOTP(email: email, token: code, type: OtpType.signup);
    } finally {
      client.dispose();
    }
  }

  Future<void> resend(String email) async {
    final client = signupClient();
    try {
      await client.resend(email: email, type: OtpType.signup);
    } finally {
      client.dispose();
    }
  }

  Future<void> login(String email, String password) async {
    await db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> reset(String email) async {
    await db.auth.resetPasswordForEmail(email, redirectTo: authRedirect);
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.actions});
  final AuthActions? actions;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final otp = TextEditingController();
  late final AuthActions actions = widget.actions ?? AuthActions();
  bool registering = false, busy = false, showPassword = false;
  String? pendingEmail;
  int cooldown = 0;
  Timer? timer;

  void startCooldown() {
    timer?.cancel();
    setState(() => cooldown = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => cooldown--);
      if (cooldown == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    password.dispose();
    name.dispose();
    otp.dispose();
    super.dispose();
  }

  bool validEmail() {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      toast(context, tr(context, 'enterEmail'));
      return false;
    }
    return true;
  }

  Future<void> perform(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        if (e is AuthException && authErrorKey(e) == 'tooManyRequests') {
          startCooldown();
        }
        toast(context, friendlyError(context, e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!validEmail()) return;
    if (password.text.isEmpty) {
      toast(context, tr(context, 'required'));
      return;
    }
    if (registering && password.text.length < 6) {
      toast(context, tr(context, 'weakPassword'));
      return;
    }
    final address = email.text.trim();
    await perform(() async {
      if (registering) {
        await actions.signup(address, password.text, name: name.text);
        if (!mounted) return;
        password.clear();
        name.clear();
        setState(() => pendingEmail = address);
        startCooldown();
      } else {
        await actions.login(address, password.text);
      }
    });
  }

  Future<void> verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(otp.text.trim())) {
      toast(context, tr(context, 'invalidOtp'));
      return;
    }
    await perform(() async {
      await actions.verify(pendingEmail!, otp.text.trim());
      if (!mounted) return;
      otp.clear();
      password.clear();
      timer?.cancel();
      setState(() {
        cooldown = 0;
        pendingEmail = null;
        registering = false;
      });
      toast(context, tr(context, 'signupComplete'));
    });
  }

  Future<void> resend() => perform(() async {
    await actions.resend(pendingEmail!);
    if (mounted) startCooldown();
  });

  Future<void> reset() async {
    if (!validEmail()) return;
    await perform(() async {
      await actions.reset(email.text.trim());
      if (!mounted) return;
      startCooldown();
      toast(context, tr(context, 'resetSent'));
    });
  }

  InputDecoration fieldDecoration(
    String label,
    String hint, {
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xff6d6b7c)),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffd9d8e4)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xff5b43c2);
    return Scaffold(
      backgroundColor: const Color(0xfffaf9fe),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Growth Circle',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff201d2d),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: toggleLanguage,
                        child: Text(tr(context, 'language')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 42),
                  Text(
                    tr(
                      context,
                      pendingEmail != null
                          ? 'otpTitle'
                          : registering
                          ? 'register'
                          : 'authWelcome',
                    ),
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff201d2d),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pendingEmail != null
                        ? '${tr(context, 'otpHint')} $pendingEmail'
                        : tr(
                            context,
                            registering ? 'authSignupDesc' : 'authWelcomeDesc',
                          ),
                    style: const TextStyle(
                      color: Color(0xff5f5d6c),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 34),
                  if (pendingEmail != null) ...[
                    TextField(
                      key: const Key('otp'),
                      controller: otp,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: fieldDecoration(tr(context, 'otp'), '000000'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy ? null : verify,
                      child: Text(tr(context, 'verifyOtp')),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: busy || cooldown > 0 ? null : resend,
                      child: Text(
                        '${tr(context, 'resendOtp')}${cooldown > 0 ? ' ($cooldown)' : ''}',
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              pendingEmail = null;
                              registering = false;
                              otp.clear();
                              password.clear();
                            }),
                      child: Text(tr(context, 'changeEmail')),
                    ),
                  ] else ...[
                    if (registering) ...[
                      TextField(
                        key: const Key('name'),
                        controller: name,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        inputFormatters: [LengthLimitingTextInputFormatter(80)],
                        decoration: fieldDecoration(
                          tr(context, 'authName'),
                          tr(context, 'authNameHint'),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    TextField(
                      key: const Key('email'),
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: fieldDecoration(
                        tr(context, 'email'),
                        tr(context, 'authEmailHint'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      key: const Key('password'),
                      controller: password,
                      enabled: !busy,
                      obscureText: !showPassword,
                      autofillHints: [
                        registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: fieldDecoration(
                        tr(context, 'password'),
                        tr(
                          context,
                          registering
                              ? 'authNewPasswordHint'
                              : 'authPasswordHint',
                        ),
                        suffix: IconButton(
                          tooltip: tr(
                            context,
                            showPassword ? 'hidePassword' : 'showPassword',
                          ),
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => showPassword = !showPassword,
                                ),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (!registering)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy || cooldown > 0 ? null : reset,
                          child: Text(tr(context, 'forgot')),
                        ),
                      )
                    else
                      const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy || cooldown > 0 ? null : submit,
                      child: Text(
                        tr(context, registering ? 'register' : 'login'),
                      ),
                    ),
                    if (registering) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'authSignupHelp'),
                        style: const TextStyle(
                          color: Color(0xff5f5d6c),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              registering = !registering;
                              password.clear();
                              showPassword = false;
                            }),
                      child: Text(
                        tr(context, registering ? 'haveAccount' : 'noAccount'),
                      ),
                    ),
                    if (registering)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (validEmail()) {
                                  setState(
                                    () => pendingEmail = email.text.trim(),
                                  );
                                }
                              },
                        child: Text(tr(context, 'receivedOtp')),
                      ),
                  ],
                  if (busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xff6554c0),
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 29,
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final User user;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(
        onBrowse: () => setState(() => selected = 1),
        onCreate: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const CreateCampaign()),
        ),
        uid: widget.user.id,
      ),
      TaskList(uid: widget.user.id),
      Campaigns(uid: widget.user.id),
      Profile(user: widget.user),
    ];
    final labels = ['home', 'earn', 'campaigns', 'profile'];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Growth Circle',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: toggleLanguage,
            child: Text(tr(context, 'language')),
          ),
        ],
      ),
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: tr(context, labels[0]),
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: tr(context, labels[1]),
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign_outlined),
            selectedIcon: const Icon(Icons.campaign),
            label: tr(context, labels[2]),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: tr(context, labels[3]),
          ),
        ],
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.uid});
  final String uid;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.from('wallets').stream(primaryKey: ['id']).eq('id', uid),
    builder: (context, snapshot) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff6554c0), Color(0xff9b78d7)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'balance'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.hasError
                      ? '—'
                      : '${(snapshot.data?.isNotEmpty == true ? snapshot.data!.first['balance'] : null) ?? '…'} ${tr(context, 'coins')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.toll_rounded, color: Colors.white, size: 45),
        ],
      ),
    ),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.onBrowse,
    required this.onCreate,
    required this.uid,
  });
  final VoidCallback onBrowse, onCreate;
  final String uid;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      BalanceCard(uid: uid),
      const SizedBox(height: 28),
      Text(
        tr(context, 'welcome'),
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      Text(
        tr(context, 'homeDesc'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: onBrowse,
        icon: const Icon(Icons.explore_outlined),
        label: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(tr(context, 'browse')),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(tr(context, 'create')),
        ),
      ),
      const SizedBox(height: 24),
      Notice(),
    ],
  );
}

class Notice extends StatelessWidget {
  const Notice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfff1eefb),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(tr(context, 'disclaimer'))),
      ],
    ),
  );
}

IconData actionIcon(String type) => switch (type) {
  'follow' => Icons.person_add_alt_1,
  'like' => Icons.favorite_border,
  'comment' => Icons.chat_bubble_outline,
  'share' => Icons.ios_share,
  _ => Icons.circle_outlined,
};

Future<void> openInstagram(BuildContext context, String link) async {
  try {
    if (!await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.externalApplication,
        ) &&
        context.mounted) {
      toast(context, tr(context, 'openError'));
    }
  } catch (_) {
    if (context.mounted) toast(context, tr(context, 'openError'));
  }
}

class ClaimProof {
  const ClaimProof(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

typedef ProofPicker = Future<ClaimProof?> Function();

Future<ClaimProof?> pickScreenshot() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 60,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  if (await file.length() > 524288) {
    throw const FormatException('Image too large');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length < 16 || bytes.length > 524288) {
    throw const FormatException('Invalid image');
  }
  final png =
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final jpg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
  if (!png && !jpg) throw const FormatException('Invalid image');
  return ClaimProof(bytes, png ? 'image/png' : 'image/jpeg');
}

class ClaimSubmissionDialog extends StatefulWidget {
  const ClaimSubmissionDialog({super.key, required this.onSubmit, this.picker});
  final Future<void> Function(String handle, ClaimProof proof) onSubmit;
  final ProofPicker? picker;
  @override
  State<ClaimSubmissionDialog> createState() => _ClaimSubmissionDialogState();
}

class _ClaimSubmissionDialogState extends State<ClaimSubmissionDialog> {
  final handle = TextEditingController();
  ClaimProof? proof;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    handle.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await (widget.picker ?? pickScreenshot)();
      if (mounted && selected != null) setState(() => proof = selected);
    } catch (_) {
      if (mounted) setState(() => error = tr(context, 'proofRequired'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final value = handle.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(value)) {
      setState(() => error = tr(context, 'proofBadHandle'));
      return;
    }
    if (proof == null) {
      setState(() => error = tr(context, 'proofRequired'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(value, proof!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'proofTitle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'proofInfo')),
          const SizedBox(height: 16),
          TextField(
            key: const Key('proof_handle'),
            controller: handle,
            enabled: !busy,
            maxLength: 31,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: tr(context, 'proofHandle'),
              hintText: '@username',
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              tr(context, proof == null ? 'proofSelect' : 'proofChange'),
            ),
          ),
          if (proof != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.memory(
                proof!.bytes,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(tr(context, 'proofRequired')),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'proofNoPrivate'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(tr(context, 'submitProof')),
      ),
    ],
  );
}

class ClaimReviewDialog extends StatefulWidget {
  const ClaimReviewDialog({
    super.key,
    required this.handle,
    required this.loadEvidence,
    required this.onDecision,
  });
  final String handle;
  final Future<Map<String, dynamic>> Function() loadEvidence;
  final Future<void> Function(bool approve) onDecision;
  @override
  State<ClaimReviewDialog> createState() => _ClaimReviewDialogState();
}

class _ClaimReviewDialogState extends State<ClaimReviewDialog> {
  late final Future<Uint8List> evidence = load();
  bool busy = false;
  String? error;
  Future<Uint8List> load() async {
    final value = await widget.loadEvidence();
    final data = value['data'];
    if (data is! String) throw const FormatException('Missing evidence');
    final bytes = base64Decode(data);
    if (bytes.isEmpty || bytes.length > 524288) {
      throw const FormatException('Invalid evidence');
    }
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1024,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    return bytes;
  }

  Future<void> decide(bool approve) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onDecision(approve);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'reviewTitle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@${widget.handle}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(tr(context, 'reviewHelp')),
          const SizedBox(height: 12),
          FutureBuilder<Uint8List>(
            future: evidence,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(tr(context, 'reviewEmpty'));
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final bytes = snapshot.data!;
              return Column(
                children: [
                  Image.memory(
                    bytes,
                    height: 220,
                    fit: BoxFit.contain,
                    cacheWidth: 1024,
                    errorBuilder: (_, _, _) => Text(tr(context, 'reviewEmpty')),
                  ),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog.fullscreen(
                        child: Scaffold(
                          appBar: AppBar(
                            title: Text(tr(context, 'reviewTitle')),
                          ),
                          body: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Center(
                              child: Image.memory(
                                bytes,
                                cacheWidth: 2048,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.zoom_in),
                    label: Text(tr(context, 'enlargeProof')),
                  ),
                ],
              );
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: Text(tr(context, 'cancel')),
      ),
      FutureBuilder<Uint8List>(
        future: evidence,
        builder: (context, snapshot) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed:
                  busy || snapshot.connectionState != ConnectionState.done
                  ? null
                  : () => decide(false),
              child: Text(tr(context, 'reject')),
            ),
            FilledButton(
              onPressed: busy || !snapshot.hasData ? null : () => decide(true),
              child: Text(tr(context, 'approve')),
            ),
          ],
        ),
      ),
    ],
  );
}

class ReviewApi {
  const ReviewApi(this.client);
  final SupabaseClient client;
  Future<void> submit(String campaign, String handle, ClaimProof proof) async {
    await client.rpc(
      'submit_claim',
      params: {
        'p_campaign_id': campaign,
        'p_instagram_handle': handle,
        'p_mime': proof.mime,
        'p_evidence': base64Encode(proof.bytes),
      },
    );
  }

  Future<void> withdraw(String campaign) async {
    await client.rpc('withdraw_claim', params: {'p_campaign_id': campaign});
  }

  Future<Map<String, dynamic>> evidence(
    String campaign,
    String participant,
    String submission,
  ) async {
    return Map<String, dynamic>.from(
      await client.rpc(
        'get_claim_evidence',
        params: {
          'p_campaign_id': campaign,
          'p_user_id': participant,
          'p_submission_id': submission,
        },
      ) as Map,
    );
  }

  Future<void> decide(
    String campaign,
    String participant,
    String submission,
    bool approve,
  ) async {
    await client.rpc(
      'review_claim',
      params: {
        'p_campaign_id': campaign,
        'p_user_id': participant,
        'p_submission_id': submission,
        'p_approve': approve,
      },
    );
  }
}

class TaskList extends StatelessWidget {
  const TaskList({super.key, required this.uid});
  final String uid;
  Future<void> claim(BuildContext context, String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClaimSubmissionDialog(
        onSubmit: (handle, proof) => ReviewApi(db).submit(id, handle, proof),
      ),
    );
    if (result == true && context.mounted) {
      toast(context, tr(context, 'proofSubmitted'));
    }
  }

  Future<void> withdraw(BuildContext context, String id) async {
    try {
      await ReviewApi(db).withdraw(id);
      if (context.mounted) toast(context, tr(context, 'withdrawDone'));
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.from('campaigns').stream(primaryKey: ['id']),
    builder: (context, campaigns) {
      if (campaigns.hasError) return Center(child: Text(tr(context, 'error')));
      if (!campaigns.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: db
            .from('campaign_claims')
            .stream(primaryKey: ['campaign_id', 'user_id'])
            .eq('user_id', uid),
        builder: (context, claims) {
          if (claims.hasError) return Center(child: Text(tr(context, 'error')));
          if (!claims.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mine = claims.data!;
          final byCampaign = {
            for (final claim in mine) claim['campaign_id']: claim,
          };
          final allCampaigns = {
            for (final campaign in campaigns.data!) campaign['id']: campaign,
          };
          final tasks = campaigns.data!
              .where((d) => d['ownerId'] != uid && d['status'] == 'active')
              .toList();
          final history = mine.toList()
            ..sort(
              (a, b) => (b['created_at'] as String).compareTo(
                a['created_at'] as String,
              ),
            );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                tr(context, 'earnTitle'),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(tr(context, 'earnDesc')),
              const SizedBox(height: 16),
              const Notice(),
              const SizedBox(height: 12),
              if (history.isNotEmpty) ...[
                Text(
                  tr(context, 'mySubmissions'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in history.take(10))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(
                      tr(
                        context,
                        allCampaigns[entry['campaign_id']]?['type'] ?? 'type',
                      ),
                    ),
                    subtitle: Text(
                      tr(
                        context,
                        entry['status'] == 'cancelled'
                            ? 'reviewCancelled'
                            : entry['status'],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(child: Text(tr(context, 'emptyTasks'))),
                ),
              for (final task in tasks)
                Builder(
                  builder: (context) {
                    final status = byCampaign[task['id']]?['status'];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Icon(actionIcon(task['type'])),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tr(context, task['type']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                const Chip(label: Text('+1 coin')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              task['link'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            if (status == 'pending' ||
                                status == 'approved' ||
                                status == 'legacy')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(tr(context, status)),
                              ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      openInstagram(context, task['link']),
                                  child: Text(tr(context, 'open')),
                                ),
                                if (status == 'pending')
                                  TextButton(
                                    onPressed: () =>
                                        withdraw(context, task['id'] as String),
                                    child: Text(tr(context, 'withdraw')),
                                  ),
                                FilledButton(
                                  onPressed:
                                      status == 'pending' ||
                                          status == 'approved' ||
                                          status == 'legacy'
                                      ? null
                                      : () => claim(
                                          context,
                                          task['id'] as String,
                                        ),
                                  child: Text(tr(context, 'submitProof')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      );
    },
  );
}

class PendingReviews extends StatelessWidget {
  const PendingReviews({super.key, required this.campaignId});
  final String campaignId;
  Future<void> review(BuildContext context, Map<String, dynamic> claim) async {
    final participant = claim['user_id'] as String;
    final submission = claim['submission_id'] as String;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClaimReviewDialog(
        handle: claim['instagram_handle'] as String? ?? '',
        loadEvidence: () =>
            ReviewApi(db).evidence(campaignId, participant, submission),
        onDecision: (approve) =>
            ReviewApi(db).decide(campaignId, participant, submission, approve),
      ),
    );
    if (result == true && context.mounted) {
      toast(context, tr(context, 'reviewDone'));
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: db
            .from('campaign_claims')
            .stream(primaryKey: ['campaign_id', 'user_id'])
            .eq('campaign_id', campaignId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text(tr(context, 'error'));
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final pending = snapshot.data!
              .where((c) => c['status'] == 'pending')
              .toList();
          final legacyCount = snapshot.data!
              .where((c) => c['status'] == 'legacy')
              .length;
          if (pending.isEmpty && legacyCount == 0) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              if (legacyCount > 0)
                Text(
                  '${tr(context, 'legacyCount')}: $legacyCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (pending.isNotEmpty)
                Text(
                  '${tr(context, 'pending')} (${pending.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              for (final entry in pending)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('@${entry['instagram_handle']}'),
                  trailing: OutlinedButton(
                    onPressed: () => review(context, entry),
                    child: Text(tr(context, 'reviewTitle')),
                  ),
                ),
            ],
          );
        },
      );
}

class Campaigns extends StatelessWidget {
  const Campaigns({super.key, required this.uid});
  final String uid;
  Future<void> cancel(BuildContext context, String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'cancelTitle')),
        content: Text(tr(context, 'cancelBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'cancelCampaign')),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await db.rpc('cancel_campaign', params: {'p_campaign_id': id});
      if (context.mounted) toast(context, tr(context, 'cancelledMessage'));
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.from('campaigns').stream(primaryKey: ['id']).eq('ownerId', uid),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr(context, 'error')));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.toList()
        ..sort(
          (a, b) =>
              (b['createdAt'] as String).compareTo(a['createdAt'] as String),
        );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'myCampaigns'),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filled(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateCampaign(),
                  ),
                ),
                icon: const Icon(Icons.add),
                tooltip: tr(context, 'create'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(child: Text(tr(context, 'emptyCampaigns'))),
            ),
          for (final doc in docs)
            Builder(
              builder: (context) {
                final data = doc;
                final remaining = data['remaining'] as int;
                final requested = data['requested'] as int;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(child: Icon(actionIcon(data['type']))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr(context, data['type']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            Chip(label: Text(tr(context, data['status']))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['link'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (requested - remaining) / requested,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${requested - remaining}/$requested ${tr(context, 'claims')}',
                        ),
                        PendingReviews(campaignId: data['id'] as String),
                        if (data['status'] == 'active')
                          TextButton(
                            onPressed: () =>
                                cancel(context, doc['id'] as String),
                            child: Text(tr(context, 'cancelCampaign')),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class CreateCampaign extends StatefulWidget {
  const CreateCampaign({super.key});
  @override
  State<CreateCampaign> createState() => _CreateCampaignState();
}

class _CreateCampaignState extends State<CreateCampaign> {
  final form = GlobalKey<FormState>();
  final link = TextEditingController();
  final count = TextEditingController(text: '1');
  String type = 'follow';
  bool busy = false;
  @override
  void dispose() {
    link.dispose();
    count.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await db.rpc(
        'create_campaign',
        params: {
          'p_type': type,
          'p_link': link.text.trim(),
          'p_count': int.parse(count.text),
        },
      );
      if (mounted) {
        Navigator.pop(context);
        toast(context, tr(context, 'created'));
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'create'))),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(context, 'create'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: tr(context, 'type')),
            items: ['follow', 'like', 'comment', 'share']
                .map(
                  (t) =>
                      DropdownMenuItem(value: t, child: Text(tr(context, t))),
                )
                .toList(),
            onChanged: busy ? null : (v) => setState(() => type = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: tr(context, 'link'),
              hintText: tr(
                context,
                type == 'follow' ? 'profileHint' : 'postHint',
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? tr(context, 'required') : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: count,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr(context, 'count'),
              helperText: tr(context, 'cost'),
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 100
                  ? tr(context, 'validCount')
                  : null;
            },
          ),
          const SizedBox(height: 24),
          const Notice(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(tr(context, 'submit')),
            ),
          ),
        ],
      ),
    ),
  );
}

String? profileName(User user) {
  final value = user.userMetadata?['full_name'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class Profile extends StatelessWidget {
  const Profile({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        tr(context, 'profile'),
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(profileName(user) ?? user.email ?? ''),
          subtitle: profileName(user) == null ? null : Text(user.email ?? ''),
          trailing: TextButton(
            onPressed: () => db.auth.signOut(),
            child: Text(tr(context, 'signout')),
          ),
        ),
      ),
      const SizedBox(height: 20),
      BalanceCard(uid: user.id),
      const SizedBox(height: 24),
      Text(
        tr(context, 'history'),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: db
            .from('coin_ledger')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text(tr(context, 'error'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.toList()
            ..sort(
              (a, b) => (b['createdAt'] as String).compareTo(
                a['createdAt'] as String,
              ),
            );
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Text(tr(context, 'emptyHistory')),
            );
          }
          return Column(
            children: [
              for (final doc in docs)
                Builder(
                  builder: (context) {
                    final data = doc;
                    final amount = data['amount'] as int;
                    final reason = switch (data['reason']) {
                      'welcome' => 'welcomeReason',
                      'campaign' => 'campaignReason',
                      'task' => 'taskReason',
                      'refund' => 'refundReason',
                      _ => 'history',
                    };
                    return Card(
                      child: ListTile(
                        title: Text(tr(context, reason)),
                        trailing: Text(
                          '${amount > 0 ? '+' : ''}$amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: amount > 0 ? Colors.green.shade700 : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ],
  );
}
