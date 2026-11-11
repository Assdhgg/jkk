import 'dart:async';
import 'dart:convert';

import 'design.dart';
import 'app_updates.dart';
import 'evidence_image.dart';
import 'support_page.dart';
import 'user_features.dart';
import 'push_notifications.dart';
import 'personal_information.dart';

import 'package:share_plus/share_plus.dart';

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
  'savedTasks': ['Saved tasks', 'Save ചെയ്ത tasks'],
  'saveTask': ['Save task', 'Task save ചെയ്യുക'],
  'unsaveTask': ['Remove saved task', 'Save ചെയ്ത task ഒഴിവാക്കുക'],
  'viewHistory': ['View all submissions', 'എല്ലാ submissions-ഉം കാണുക'],
  'helpGuide': ['Help & guide', 'സഹായവും മാർഗ്ഗനിർദ്ദേശവും'],
  'shareReferral': ['Share referral code', 'Referral code share ചെയ്യുക'],
  'rejectionReason': [
    'Reason for rejection (optional)',
    'നിരസിക്കാനുള്ള കാരണം (ഐച്ഛികം)',
  ],
  'supportReply': [
    'Support replied to your ticket',
    'നിങ്ങളുടെ ticket-ന് support മറുപടി നൽകി',
  ],
  'adminAdjustment': ['Admin adjustment', 'Admin adjustment'],
  'support': ['Support', 'സഹായം'],
  'reportCampaign': ['Report', 'റിപ്പോർട്ട്'],
  'email_otp_required': [
    'PIN setup requires a verified email account without a linked phone. Contact support to check your account.',
    'PIN സജ്ജമാക്കാൻ verified email account വേണം; linked phone ഉണ്ടെങ്കിൽ support-നെ ബന്ധപ്പെടുക.',
  ],
  'otp_required': [
    'Send and verify a fresh email OTP.',
    'പുതിയ email OTP അയച്ച് സ്ഥിരീകരിക്കുക.',
  ],
  'sendPinOtp': ['Send email OTP', 'Email OTP അയയ്ക്കുക'],
  'otpSentPin': [
    'OTP sent to your signed-in email. Enter it to verify and save your PIN.',
    'നിങ്ങളുടെ email-ലേക്ക് OTP അയച്ചു. അത് നൽകി PIN സ്ഥിരീകരിച്ച് സേവ് ചെയ്യുക.',
  ],
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
  'accountBlocked': [
    'Your app access is blocked. Contact the administrator.',
    'നിങ്ങളുടെ app access തടഞ്ഞിരിക്കുന്നു. Administrator-നെ ബന്ധപ്പെടുക.',
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
  'allTasks': ['All', 'എല്ലാം'],
  'noFilteredTasks': [
    'No tasks in this category.',
    'ഈ വിഭാഗത്തിൽ task-ുകൾ ഇല്ല.',
  ],
  'notifications': ['Notifications', 'അറിയിപ്പുകൾ'],
  'noNotifications': ['No notifications yet.', 'ഇതുവരെ അറിയിപ്പുകളൊന്നുമില്ല.'],
  'notificationApproved': [
    'Your submission was approved.',
    'നിങ്ങളുടെ submission അംഗീകരിച്ചു.',
  ],
  'notificationRejected': [
    'Your submission was rejected.',
    'നിങ്ങളുടെ submission നിരസിച്ചു.',
  ],
  'notificationCoins': ['Coins received', 'Coins ലഭിച്ചു'],
  'notificationUnread': ['Unread', 'വായിച്ചിട്ടില്ല'],
  'markRead': ['Mark as read', 'വായിച്ചതായി അടയാളപ്പെടുത്തുക'],
  'earnTitle': ['Explore tasks', 'Task-ുകൾ കണ്ടെത്തുക'],
  'submitProof': ['Submit for review', 'പരിശോധനയ്ക്ക് അയയ്ക്കുക'],
  'proofTitle': ['Submit your task', 'Task പരിശോധനയ്ക്ക് അയയ്ക്കുക'],
  'proofInfo': [
    'Enter your Instagram username and choose a screenshot. The campaign owner will review it before you earn coins.',
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
  'adminReviewing': [
    'AI is checking your submission',
    'AI നിങ്ങളുടെ submission പരിശോധിക്കുന്നു',
  ],
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
    'Share only the relevant screenshot. You, the campaign owner, and administrators can view it until review.',
    'ആവശ്യമായ screenshot മാത്രം നൽകുക. പരിശോധന വരെ അത് നിങ്ങൾക്കും campaign ഉടമയ്ക്കും administrators-നും കാണാം.',
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
    'Claim recorded. Coins received.',
    'സ്ഥിരീകരിച്ചു. Coins ലഭിച്ചു.',
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
  'perTask': ['per task', 'ഓരോ task-നും'],
  'totalCost': ['Total cost', 'ആകെ ചെലവ്'],
  'cost': ['1–100 tasks', '1–100 task-ുകൾ'],
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
  'accountSection': ['ACCOUNT', 'അക്കൗണ്ട്'],
  'profileJoined': ['Joined', 'ചേർന്നത്'],
  'profileAccounts': ['Accounts', 'അക്കൗണ്ടുകൾ'],
  'profileReferrals': ['Referrals', 'Referrals'],
  'profileReferralDesc': [
    'Share your code with friends',
    'നിങ്ങളുടെ code സുഹൃത്തുക്കളുമായി പങ്കിടൂ',
  ],
  'profileSettings': ['Profile settings', 'Profile settings'],
  'profileDataError': [
    'Could not load profile details.',
    'Profile വിവരങ്ങൾ ലഭ്യമായില്ല.',
  ],
  'instagramAccounts': ['Instagram accounts', 'Instagram അക്കൗണ്ടുകൾ'],
  'addAccount': [
    'Add Instagram username manually',
    'Instagram username നേരിട്ട് ചേർക്കുക',
  ],
  'instagramSearch': ['Search Instagram username', 'Instagram username തിരയുക'],
  'instagramSearchHelp': [
    'Enter the full username of a Business or Creator account. Personal and age-restricted accounts are not supported.',
    'Business അല്ലെങ്കിൽ Creator account-ന്റെ മുഴുവൻ username നൽകുക. Personal, പ്രായപരിധിയുള്ള accounts ലഭ്യമല്ല.',
  ],
  'instagramSearchHint': ['Exact username', 'മുഴുവൻ username'],
  'instagramSearchAction': ['Search', 'തിരയുക'],
  'instagramSearchAdd': ['Add account', 'Account ചേർക്കുക'],
  'instagramSearchNotFound': [
    'No supported account found. Check the full username; personal and age-restricted accounts may not appear.',
    'Account കണ്ടെത്തിയില്ല. മുഴുവൻ username പരിശോധിക്കുക; personal, പ്രായപരിധിയുള്ള accounts ലഭ്യമാകണമെന്നില്ല.',
  ],
  'instagramSearchUnavailable': [
    'Search is unavailable. Ask the app owner to configure Instagram access.',
    'Search ലഭ്യമല്ല. Instagram access ക്രമീകരിക്കാൻ app ഉടമയോട് പറയുക.',
  ],
  'instagramSearchLimited': [
    'Too many searches. Please try again later.',
    'തിരച്ചിലുകൾ കൂടുതലാണ്. കുറച്ച് കഴിഞ്ഞ് ശ്രമിക്കുക.',
  ],
  'instagramSearchDenied': [
    'Sign in again or contact the administrator.',
    'വീണ്ടും login ചെയ്യുക അല്ലെങ്കിൽ administrator-നെ ബന്ധപ്പെടുക.',
  ],
  'instagramSearchOwnership': [
    'This result does not verify account ownership.',
    'ഈ ഫലം account ഉടമസ്ഥാവകാശം സ്ഥിരീകരിക്കുന്നില്ല.',
  ],
  'noAccounts': [
    'No Instagram usernames added yet.',
    'Instagram username ചേർത്തിട്ടില്ല.',
  ],
  'removeAccount': ['Remove', 'നീക്കം ചെയ്യുക'],
  'referrals': ['Referral program', 'Referral പദ്ധതി'],
  'referralCode': ['Your referral code', 'നിങ്ങളുടെ referral കോഡ്'],
  'referralCount': ['People referred', 'Referral വഴി ചേർന്നവർ'],
  'referralEnter': ['Enter a referral code', 'Referral കോഡ് നൽകുക'],
  'referralApplied': ['Referral code applied.', 'Referral കോഡ് ചേർത്തു.'],
  'invalidReferral': ['Invalid referral code.', 'Referral കോഡ് തെറ്റാണ്.'],
  'duplicateAccount': [
    'This username is already added.',
    'ഈ username ചേർത്തിട്ടുണ്ട്.',
  ],
  'referralJoined': [
    'Referral code already applied.',
    'Referral കോഡ് ചേർത്തിട്ടുണ്ട്.',
  ],
  'referralNoReward': [
    'Referral rewards follow the current administrator settings.',
    'Admin settings അനുസരിച്ച് referral reward ലഭിക്കും.',
  ],
  'copyCode': ['Copy code', 'കോഡ് പകർത്തുക'],
  'copied': ['Code copied.', 'കോഡ് പകർത്തി.'],
  'apply': ['Apply', 'ചേർക്കുക'],
  'releasePin': ['Coin release PIN', 'Coin release PIN'],
  'setupPin': ['Set up 4-digit PIN', '4 അക്ക PIN സജ്ജമാക്കുക'],
  'changePin': ['Change / reset PIN', 'PIN മാറ്റുക / reset ചെയ്യുക'],
  'enterPin': [
    'Enter your 4-digit PIN to release the coin.',
    'Coin നൽകാൻ 4 അക്ക PIN നൽകുക.',
  ],
  'currentPin': ['Current PIN', 'നിലവിലെ PIN'],
  'newPin': ['New 4-digit PIN', 'പുതിയ 4 അക്ക PIN'],
  'confirmPin': ['Confirm PIN', 'PIN സ്ഥിരീകരിക്കുക'],
  'pinMismatch': ['Enter matching 4-digit PINs.', 'ഒരേ 4 അക്ക PIN നൽകുക.'],
  'pinSaved': ['PIN saved.', 'PIN സേവ് ചെയ്തു.'],
  'pin_missing': [
    'Set up a coin release PIN in your profile first.',
    'ആദ്യം പ്രൊഫൈലിൽ coin release PIN സജ്ജമാക്കുക.',
  ],
  'invalid_pin': [
    'Incorrect PIN. Try again.',
    'PIN തെറ്റാണ്. വീണ്ടും ശ്രമിക്കുക.',
  ],
  'pin_locked': [
    'Too many attempts. Try again in 15 minutes.',
    'ശ്രമങ്ങൾ കൂടുതലാണ്. 15 മിനിറ്റിന് ശേഷം ശ്രമിക്കുക.',
  ],
  'invalid_format': ['Enter a 4-digit PIN.', '4 അക്ക PIN നൽകുക.'],
  'save': ['Save', 'സേവ് ചെയ്യുക'],
  'processing': ['In progress', 'പുരോഗമിക്കുന്നു'],
  'actionDisabled': [
    'This action is temporarily disabled by an administrator.',
    'ഈ action administrator താൽക്കാലികമായി തടഞ്ഞിരിക്കുന്നു.',
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
        message.contains('error sending reauthentication email') ||
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
    if (e.message.contains('Account access is blocked')) {
      return tr(context, 'accountBlocked');
    }
    if (e.message.contains('already claimed') ||
        e.message.contains('already submitted')) {
      return tr(context, 'already');
    }
    if (e.message.contains('awaiting review')) {
      return tr(context, 'reviewCapacity');
    }
    if (e.message.contains('action is disabled')) {
      return tr(context, 'actionDisabled');
    }
    if (e.message.contains('Invalid referral code')) {
      return tr(context, 'invalidReferral');
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
    if (e.message.contains('Reward changed')) {
      return Localizations.localeOf(context).languageCode == 'ml'
          ? 'Coin നിരക്ക് മാറി. പുതിയ നിരക്ക് പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.'
          : 'Reward changed. Check the updated price and try again.';
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

// Shared user-app surfaces follow the profile layout on phones and wide windows.
ThemeData growthTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Poppins',
  colorScheme: ColorScheme.fromSeed(
    seedColor: growthPurple,
    surface: const Color(0xfffaf8ff),
  ),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: growthInk,
      fontSize: 19,
      fontWeight: FontWeight.w700,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    elevation: 0,
    indicatorColor: const Color(0xffd8c5ff),
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shadowColor: const Color(0x22755dc2),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xfff8f7fa),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffdedce6)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: growthPurple,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xfff2eff8),
    side: BorderSide.none,
    selectedColor: const Color(0xffded0ff),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  ),
);

class AppListView extends StatelessWidget {
  const AppListView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(20),
    this.panel = false,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool panel;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: padding,
        children: panel
            ? [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ]
            : children,
      ),
    ),
  );
}

class GrowthApp extends StatelessWidget {
  const GrowthApp({super.key, required this.configured});
  final bool configured;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (_, locale, _) => MaterialApp(
      title: 'Freelan Space',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ml')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: growthTheme(),
      builder: (context, child) => GrowthBackdrop(
        child: configured ? AppUpdateGate(child: child!) : child!,
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
  const AccountGate({super.key, required this.user, this.initializeWallet});
  final User user;
  final Future<void> Function()? initializeWallet;
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
    if (widget.initializeWallet != null) {
      await widget.initializeWallet!();
    } else {
      await db.rpc('initialize_wallet');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialize,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final blocked =
            snapshot.error is PostgrestException &&
            (snapshot.error! as PostgrestException).message.contains(
              'Account access is blocked',
            );
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (blocked) ...[
                      Row(
                        children: [
                          Image.asset(
                            'assets/design/brand_logo.png',
                            width: 48,
                            height: 48,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Freelan\nSpace',
                            style: TextStyle(
                              color: growthInk,
                              height: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const GrowthArt('blocked', height: 200),
                      const SizedBox(height: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        friendlyError(context, snapshot.error!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GrowthPrimaryButton(
                      onPressed: () {
                        final next = load();
                        next.ignore();
                        setState(() {
                          initialize = next;
                        });
                      },
                      label: tr(context, 'retry'),
                      icon: Icons.refresh,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => db.auth.signOut(),
                      icon: const Icon(Icons.logout),
                      label: Text(tr(context, 'signout')),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    if (blocked) ...[
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8ddfa),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.support_agent,
                              color: growthPurple,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                uf(
                                  context,
                                  'Need help? Contact the administrator.',
                                  'സഹായത്തിനായി administrator-നെ ബന്ധപ്പെടുക.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    IconData? icon,
  }) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xff6d6b7c)),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    prefixIcon: icon == null ? null : Icon(icon, color: growthPurple),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(32),
      borderSide: const BorderSide(color: Color(0xffd9d8e4)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/design/brand_logo.png',
                        width: 48,
                        height: 48,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Freelan\nSpace',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            color: growthInk,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: toggleLanguage,
                        child: Text(tr(context, 'language')),
                      ),
                    ],
                  ),
                  if (pendingEmail != null) ...[
                    const SizedBox(height: 18),
                    const GrowthArt('verify', height: 150),
                  ] else
                    const SizedBox(height: 42),
                  if (pendingEmail == null)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  context,
                                  registering ? 'register' : 'authWelcome',
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: growthInk,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tr(
                                  context,
                                  registering
                                      ? 'authSignupDesc'
                                      : 'authWelcomeDesc',
                                ),
                                style: const TextStyle(
                                  color: Color(0xff5f5d6c),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.asset(
                          'assets/design/${registering ? 'auth_signup_art' : 'auth_signin_art'}.png',
                          width: 72,
                          height: 88,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ],
                    )
                  else ...[
                    Text(
                      tr(context, 'otpTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: growthInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${tr(context, 'otpHint')} $pendingEmail',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff5f5d6c),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  if (pendingEmail != null) ...[
                    VerificationCodeField(controller: otp, enabled: !busy),
                    const SizedBox(height: 10),
                    GrowthPrimaryButton(
                      onPressed: busy ? null : verify,
                      label: tr(context, 'verifyOtp'),
                      icon: Icons.arrow_forward,
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
                          icon: Icons.person_outline,
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
                        icon: Icons.mail_outline,
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
                        icon: Icons.lock_outline,
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
                    GrowthPrimaryButton(
                      onPressed: busy || cooldown > 0 ? null : submit,
                      label: tr(context, registering ? 'register' : 'login'),
                      icon: Icons.arrow_forward,
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

class VerificationCodeField extends StatefulWidget {
  const VerificationCodeField({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final TextEditingController controller;
  final bool enabled;
  @override
  State<VerificationCodeField> createState() => _VerificationCodeFieldState();
}

class _VerificationCodeFieldState extends State<VerificationCodeField> {
  final focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    focusNode.addListener(_updateFocus);
  }

  void _updateFocus() => setState(() {});
  @override
  void dispose() {
    focusNode.removeListener(_updateFocus);
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffded5ed)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock, size: 14, color: growthPurple),
            const SizedBox(width: 6),
            Text(
              tr(context, 'otp'),
              style: const TextStyle(
                color: growthPurple,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++)
                      Expanded(
                        child: Container(
                          height: 46,
                          margin: EdgeInsets.only(right: i == 5 ? 0 : 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xfffaf9ff),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  focusNode.hasFocus &&
                                      i ==
                                          value.selection.extentOffset.clamp(
                                            0,
                                            5,
                                          )
                                  ? growthPurple
                                  : const Color(0xffe1dcec),
                            ),
                          ),
                          child: Text(
                            i < value.text.length ? value.text[i] : '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: TextField(
                key: const Key('otp'),
                controller: widget.controller,
                focusNode: focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: InputDecoration(
                  labelText: tr(context, 'otp'),
                  labelStyle: const TextStyle(color: Colors.transparent),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (_, value, _) => Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${value.text.length}/6',
              style: const TextStyle(fontSize: 10, color: Color(0xff746c8a)),
            ),
          ),
        ),
      ],
    ),
  );
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

List<Map<String, dynamic>> filterTasks(
  List<Map<String, dynamic>> tasks,
  String type,
) => type == 'all'
    ? tasks
    : tasks.where((task) => task['type'] == type).toList();

class TaskTypePicker extends StatelessWidget {
  const TaskTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final type in ['all', 'follow', 'like', 'comment', 'share'])
        ChoiceChip(
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 3),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(
            tr(context, type == 'all' ? 'allTasks' : type),
            style: TextStyle(
              color: selected == type ? Colors.white : growthInk,
              fontSize: 10,
            ),
          ),
          selectedColor: growthPurple,
          checkmarkColor: Colors.white,
          selected: selected == type,
          onSelected: (_) => onSelected(type),
        ),
    ],
  );
}

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({
    super.key,
    required this.stream,
    required this.onPressed,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) => IconButton(
          tooltip: tr(context, 'notifications'),
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible:
                snapshot.data?.any((item) => item['read_at'] == null) ?? false,
            child: const Icon(Icons.notifications_none_outlined),
          ),
        ),
      );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.stream,
    required this.markRead,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final Future<void> Function(String id) markRead;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'notifications')),
      actions: [
        IconButton(
          tooltip: uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const UserSettingsPage()),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(tr(context, 'error')));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return AppListView(
          children: [
            if (items.where((item) => item['read_at'] == null).length == 1)
              const GrowthArt('notifications', height: 125),
            if (items.where((item) => item['read_at'] == null).length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Badge.count(
                    count: items
                        .where((item) => item['read_at'] == null)
                        .length,
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: growthPurple,
                      size: 70,
                    ),
                  ),
                ),
              ),
            for (final item in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    item['kind'] == 'coins_received'
                        ? Icons.toll_outlined
                        : Icons.fact_check_outlined,
                  ),
                  onTap: item['kind'] == 'app_update'
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AppUpdatePage(),
                          ),
                        )
                      : null,
                  title: Text(switch (item['kind']) {
                    'admin_message' =>
                      item['title'] as String? ?? tr(context, 'notifications'),
                    'app_update' => uf(
                      context,
                      'App update available',
                      'പുതിയ app update ലഭ്യമാണ്',
                    ),
                    'approved' => tr(context, 'notificationApproved'),
                    'rejected' => tr(context, 'notificationRejected'),
                    'support_reply' => tr(context, 'supportReply'),
                    'coins_received' =>
                      '${tr(context, 'notificationCoins')}: +${item['amount']}',
                    _ => tr(context, 'notifications'),
                  }),
                  subtitle: Text(
                    [
                      if (item['kind'] == 'admin_message' &&
                          item['body'] is String)
                        item['body'] as String,
                      if (item['read_at'] == null)
                        tr(context, 'notificationUnread'),
                      if (DateTime.tryParse(
                            item['created_at']?.toString() ?? '',
                          )
                          case final date?)
                        MaterialLocalizations.of(context)
                            .formatShortDate(date.toLocal()),
                    ].join(' · '),
                  ),
                  trailing: item['read_at'] == null
                      ? IconButton(
                          tooltip: tr(context, 'markRead'),
                          icon: const Icon(Icons.mark_email_read_outlined),
                          onPressed: () async {
                            try {
                              await markRead(item['id'] as String);
                            } catch (_) {
                              if (context.mounted) {
                                toast(context, tr(context, 'error'));
                              }
                            }
                          },
                        )
                      : null,
                ),
              ),
            GrowthEmpty(
              art: 'notification_empty',
              title: items.isEmpty
                  ? tr(context, 'noNotifications')
                  : uf(
                      context,
                      'No more notifications',
                      'കൂടുതൽ notifications ഇല്ല',
                    ),
              subtitle: uf(
                context,
                "You're all caught up!",
                'പുതിയ notifications ഒന്നുമില്ല.',
              ),
            ),
          ],
        );
      },
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
  void initState() {
    super.initState();
    unawaited(PushCoordinator.instance.restore(db));
  }

  @override
  void dispose() {
    unawaited(PushCoordinator.instance.stop(db));
    super.dispose();
  }

  late final Stream<List<Map<String, dynamic>>> notifications = db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', widget.user.id)
      .order('created_at', ascending: false);
  void openNotifications() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => NotificationsPage(
        stream: notifications,
        markRead: (id) async {
          await db
              .from('notifications')
              .update({'read_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', id);
        },
      ),
    ),
  );
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
      Profile(
        user: widget.user,
        onNotifications: openNotifications,
        notifications: notifications,
      ),
    ];
    final labels = ['home', 'earn', 'campaigns', 'profile'];
    return Scaffold(
      appBar: selected == 3
          ? null
          : AppBar(
              title: Text(tr(context, labels[selected])),
              actions: [
                NotificationsButton(
                  stream: notifications,
                  onPressed: openNotifications,
                ),
                IconButton(
                  tooltip: uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const UserSettingsPage(),
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: GrowthNavigation(
        selected: selected,
        labels: [for (final label in labels) tr(context, label)],
        onSelected: (index) => setState(() => selected = index),
      ),
    );
  }
}

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key, required this.uid, this.balanceStream});
  final String uid;
  final Stream<List<Map<String, dynamic>>>? balanceStream;
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool revealed = false;
  late final Stream<List<Map<String, dynamic>>> balances =
      widget.balanceStream ??
      db.from('wallets').stream(primaryKey: ['id']).eq('id', widget.uid);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: BoxDecoration(
      gradient: growthGradient,
      image: const DecorationImage(
        image: AssetImage('assets/design/balance_background.png'),
        fit: BoxFit.fill,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                uf(context, 'Wallet', 'വാലറ്റ്'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (revealed)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: balances,
            builder: (context, snapshot) => Text(
              snapshot.hasError
                  ? uf(
                      context,
                      'Unable to load balance. Try again later.',
                      'Balance ലഭിച്ചില്ല. പിന്നീട് വീണ്ടും ശ്രമിക്കുക.',
                    )
                  : !snapshot.hasData
                  ? tr(context, 'loading')
                  : snapshot.data!.isEmpty
                  ? uf(context, 'Balance unavailable', 'Balance ലഭ്യമല്ല')
                  : '${snapshot.data!.first['balance']} ${tr(context, 'coins')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 8),
        IconButton.filledTonal(
          tooltip: revealed
              ? uf(context, 'Hide balance', 'Balance മറയ്ക്കുക')
              : uf(context, 'Check balance', 'Balance പരിശോധിക്കുക'),
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: Colors.white,
            foregroundColor: growthPurple,
          ),
          onPressed: () => setState(() => revealed = !revealed),
          icon: Icon(revealed ? Icons.visibility_off_outlined : Icons.check),
        ),
      ],
    ),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.onBrowse,
    required this.onCreate,
    required this.uid,
    this.balanceStream,
  });
  final Stream<List<Map<String, dynamic>>>? balanceStream;
  final VoidCallback onBrowse, onCreate;
  final String uid;
  @override
  Widget build(BuildContext context) => AppListView(
    padding: const EdgeInsets.all(20),
    children: [
      BalanceCard(uid: uid, balanceStream: balanceStream),
      const SizedBox(height: 20),
      Text(
        tr(context, 'welcome'),
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: growthInk,
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 42,
          height: 3,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: growthPurple,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        tr(context, 'homeDesc'),
        style: const TextStyle(fontSize: 13, color: Color(0xff635b80)),
      ),
      const SizedBox(height: 14),
      Column(
        children: [
          Card(
            child: ProfileMenuTile(
              icon: Icons.explore_outlined,
              title: tr(context, 'browse'),
              subtitle: uf(
                context,
                'Explore available tasks & earn coins',
                'Tasks കണ്ടെത്തി coins നേടുക',
              ),
              onTap: onBrowse,
            ),
          ),
          Card(
            child: ProfileMenuTile(
              icon: Icons.campaign_outlined,
              title: tr(context, 'create'),
              subtitle: uf(
                context,
                'Start your campaign & grow',
                'Campaign ആരംഭിക്കുക',
              ),
              onTap: onCreate,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Notice(),
      const SizedBox(height: 12),
      const GrowthArt('gift', height: 150),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.info, color: growthPurple, size: 24),
        Container(
          width: 1,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: const Color(0xffb99cdd),
        ),
        Expanded(
          child: Text(
            tr(context, 'disclaimer'),
            style: const TextStyle(fontSize: 11, color: growthInk),
          ),
        ),
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
  await validateEvidenceImage(bytes);
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
    this.onRejectWithReason,
  });
  final String handle;
  final Future<Map<String, dynamic>> Function() loadEvidence;
  final Future<void> Function(bool approve, String? pin) onDecision;
  final Future<void> Function(String reason)? onRejectWithReason;
  @override
  State<ClaimReviewDialog> createState() => _ClaimReviewDialogState();
}

class _ClaimReviewDialogState extends State<ClaimReviewDialog> {
  late final Future<Uint8List> evidence = load();
  bool busy = false;
  String? error;
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<Uint8List> load() async {
    final value = await widget.loadEvidence();
    final data = value['data'];
    if (data is! String) throw const FormatException('Missing evidence');
    return decodeEvidenceImage(data);
  }

  Future<void> decide(bool approve) async {
    if (busy) return;
    String? pin;
    if (approve) {
      pin = await showDialog<String>(
        context: context,
        builder: (_) => const ReleasePinDialog(),
      );
      if (pin == null || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!approve &&
          widget.onRejectWithReason != null &&
          reason.text.trim().isNotEmpty) {
        await widget.onRejectWithReason!(reason.text.trim());
      } else {
        await widget.onDecision(approve, pin);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PinException
              ? tr(context, e.code)
              : friendlyError(context, e),
        );
      }
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
          if (widget.onRejectWithReason != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr(context, 'rejectionReason'),
              ),
            ),
          ],
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

  Future<void> rejectWithReason(
    String campaign,
    String participant,
    String submission,
    String reason,
  ) async {
    final result = await client.rpc(
      'review_claim_with_feedback',
      params: {
        'p_campaign_id': campaign,
        'p_user_id': participant,
        'p_submission_id': submission,
        'p_approve': false,
        'p_pin': null,
        'p_reason': reason,
      },
    );
    if (result != 'ok') throw PinException(result.toString());
  }

  Future<void> decide(
    String campaign,
    String participant,
    String submission,
    bool approve, [
    String? pin,
  ]) async {
    final result = await client.rpc(
      'review_claim_with_pin',
      params: {
        'p_campaign_id': campaign,
        'p_user_id': participant,
        'p_submission_id': submission,
        'p_approve': approve,
        'p_pin': pin,
      },
    );
    if (result != 'ok') throw PinException(result.toString());
  }
}

class TaskList extends StatefulWidget {
  const TaskList({
    super.key,
    required this.uid,
    this.controlsStream,
    this.presenceStream,
    this.campaignsStream,
    this.claimsStream,
    this.loadSavedIds,
  });
  final String uid;
  final Stream<List<Map<String, dynamic>>>? controlsStream,
      presenceStream,
      campaignsStream,
      claimsStream;
  final Future<List<String>> Function()? loadSavedIds;
  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  String selectedType = 'all';
  final saved = <String>{};
  bool savedOnly = false, savedLoading = true, savedError = false;
  final saving = <String>{};
  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  Future<void> loadSaved() async {
    try {
      final ids = widget.loadSavedIds != null
          ? await widget.loadSavedIds!()
          : (await db
                    .from('saved_tasks')
                    .select('campaign_id')
                    .eq('user_id', widget.uid))
                .map((row) => row['campaign_id'] as String)
                .toList();
      if (mounted) {
        setState(() {
          saved
            ..clear()
            ..addAll(ids);
          savedError = false;
          savedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          savedError = true;
          savedLoading = false;
        });
      }
    }
  }

  Future<void> toggleSaved(String id) async {
    if (saving.contains(id)) return;
    final next = !saved.contains(id);
    setState(() => saving.add(id));
    try {
      await db.rpc(
        'set_task_saved',
        params: {'p_campaign': id, 'p_saved': next},
      );
      if (mounted) {
        setState(() {
          if (next) {
            saved.add(id);
          } else {
            saved.remove(id);
          }
        });
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

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
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream:
            widget.controlsStream ??
            db.from('action_controls').stream(primaryKey: ['action_type']),
        builder: (context, controls) {
          if (controls.hasError) {
            return Center(child: Text(tr(context, 'error')));
          }
          if (!controls.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final actionStates = {
            for (final row in controls.data!)
              row['action_type'] as String: row['enabled'] == true,
          };
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream:
                widget.presenceStream ??
                db
                    .from('admin_review_presence')
                    .stream(primaryKey: ['session_id'])
                    .eq('user_id', widget.uid),
            builder: (context, presence) {
              if (presence.hasError) {
                return Center(child: Text(tr(context, 'error')));
              }
              if (!presence.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return buildTasks(context, actionStates, presence.data!);
            },
          );
        },
      );

  Widget buildTasks(
    BuildContext context,
    Map<String, bool> controls,
    List<Map<String, dynamic>> presence,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream:
        widget.campaignsStream ??
        db.from('campaigns').stream(primaryKey: ['id']),
    builder: (context, campaigns) {
      if (campaigns.hasError) return Center(child: Text(tr(context, 'error')));
      if (!campaigns.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream:
            widget.claimsStream ??
            db
                .from('campaign_claims')
                .stream(primaryKey: ['campaign_id', 'user_id'])
                .eq('user_id', widget.uid),
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
              .where(
                (d) => d['ownerId'] != widget.uid && d['status'] == 'active',
              )
              .toList();
          final filteredTasks = filterTasks(
            tasks,
            selectedType,
          ).where((task) => !savedOnly || saved.contains(task['id'])).toList();
          final history = mine.toList()
            ..sort(
              (a, b) => (b['created_at'] as String).compareTo(
                a['created_at'] as String,
              ),
            );
          return AppListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'earnTitle'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: growthInk,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(tr(context, 'earnDesc')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const GrowthArt('task_header', height: 100),
                ],
              ),
              const SizedBox(height: 16),
              const Notice(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SubmissionHistoryPage(client: db),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: Text(tr(context, 'viewHistory')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: const BorderSide(color: Color(0xffc8b2eb)),
                  ),
                ),
              ),
              if (history.isNotEmpty) ...[
                Text(
                  tr(context, 'mySubmissions'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in history.take(10))
                  Card(
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xffeee6ff),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: growthPurple,
                        ),
                      ),
                      title: Text(
                        tr(
                          context,
                          allCampaigns[entry['campaign_id']]?['type'] ?? 'type',
                        ),
                      ),
                      subtitle: SubmissionStatus(
                        claim: entry,
                        presence: presence,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              TaskTypePicker(
                selected: selectedType,
                onSelected: (value) => setState(() => selectedType = value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  avatar: const Icon(
                    Icons.bookmark_border,
                    size: 16,
                    color: growthPurple,
                  ),
                  label: Text(tr(context, 'savedTasks')),
                  selected: savedOnly,
                  onSelected: savedLoading
                      ? null
                      : (value) => setState(() => savedOnly = value),
                ),
              ),
              if (savedError)
                TextButton(
                  onPressed: loadSaved,
                  child: Text(tr(context, 'retry')),
                ),
              const SizedBox(height: 12),
              if (filteredTasks.isEmpty)
                GrowthEmpty(
                  art: 'tasks',
                  title: tr(
                    context,
                    selectedType == 'all' ? 'emptyTasks' : 'noFilteredTasks',
                  ),
                  subtitle: uf(
                    context,
                    'Check back later for new tasks.',
                    'പുതിയ tasks പിന്നീട് പരിശോധിക്കുക.',
                  ),
                ),
              for (final task in filteredTasks)
                Builder(
                  builder: (context) {
                    final status = byCampaign[task['id']]?['status'];
                    final enabled = controls[task['type']] == true;
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
                                Chip(
                                  label: Text(
                                    '+${task['reward_per_task'] ?? 1} ${tr(context, 'coins')}',
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr(
                                    context,
                                    saved.contains(task['id'])
                                        ? 'unsaveTask'
                                        : 'saveTask',
                                  ),
                                  onPressed:
                                      savedLoading ||
                                          saving.contains(task['id'])
                                      ? null
                                      : () => toggleSaved(task['id'] as String),
                                  icon: Icon(
                                    saved.contains(task['id'])
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                  ),
                                ),
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
                                child: SubmissionStatus(
                                  claim: byCampaign[task['id']]!,
                                  presence: presence,
                                ),
                              ),
                            if (!enabled) Text(tr(context, 'actionDisabled')),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: enabled
                                      ? () =>
                                            openInstagram(context, task['link'])
                                      : null,
                                  child: Text(tr(context, 'open')),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final controller = TextEditingController();
                                    final reason = await showDialog<String>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: Text(tr(c, 'reportCampaign')),
                                        content: TextField(
                                          controller: controller,
                                          maxLength: 1000,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            labelText: supportText(
                                              c,
                                              'Reason',
                                              'കാരണം',
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(c),
                                            child: Text(tr(c, 'cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              if (controller.text
                                                  .trim()
                                                  .isNotEmpty) {
                                                Navigator.pop(
                                                  c,
                                                  controller.text.trim(),
                                                );
                                              }
                                            },
                                            child: Text(
                                              supportText(
                                                c,
                                                'Send',
                                                'അയയ്ക്കുക',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    controller.dispose();
                                    if (reason == null || !context.mounted) {
                                      return;
                                    }
                                    try {
                                      await db.rpc(
                                        'report_campaign',
                                        params: {
                                          'p_campaign': task['id'],
                                          'p_reason': reason,
                                        },
                                      );
                                      if (context.mounted) {
                                        toast(
                                          context,
                                          supportText(
                                            context,
                                            'Report sent.',
                                            'റിപ്പോർട്ട് അയച്ചു.',
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        toast(
                                          context,
                                          supportText(
                                            context,
                                            'Unable to send report.',
                                            'റിപ്പോർട്ട് അയയ്ക്കാനായില്ല.',
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(tr(context, 'reportCampaign')),
                                ),
                                if (status == 'pending')
                                  TextButton(
                                    onPressed: () =>
                                        withdraw(context, task['id'] as String),
                                    child: Text(tr(context, 'withdraw')),
                                  ),
                                FilledButton(
                                  onPressed:
                                      !enabled ||
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

class SubmissionStatus extends StatefulWidget {
  const SubmissionStatus({
    super.key,
    required this.claim,
    required this.presence,
  });
  final Map<String, dynamic> claim;
  final List<Map<String, dynamic>> presence;
  @override
  State<SubmissionStatus> createState() => _SubmissionStatusState();
}

class _SubmissionStatusState extends State<SubmissionStatus> {
  Timer? timer;
  DateTime? expiry() {
    if (widget.claim['status'] != 'pending') return null;
    DateTime? latest;
    for (final row in widget.presence) {
      if (row['campaign_id'] != widget.claim['campaign_id'] ||
          row['user_id'] != widget.claim['user_id'] ||
          row['submission_id'] != widget.claim['submission_id']) {
        continue;
      }
      final until = DateTime.tryParse(row['expires_at'] as String? ?? '');
      if (until != null && (latest == null || until.isAfter(latest))) {
        latest = until;
      }
    }
    return latest;
  }

  void scheduleExpiry() {
    timer?.cancel();
    final until = expiry();
    if (until != null && until.isAfter(DateTime.now())) {
      timer = Timer(
        until.difference(DateTime.now()) + const Duration(milliseconds: 50),
        () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    scheduleExpiry();
  }

  @override
  void didUpdateWidget(covariant SubmissionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleExpiry();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = expiry();
    final active = until != null && until.isAfter(DateTime.now());
    final status = widget.claim['status'] == 'cancelled'
        ? 'reviewCancelled'
        : widget.claim['status'] as String;
    return Text(tr(context, active ? 'adminReviewing' : status));
  }
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
        onDecision: (approve, pin) =>
            ReviewApi(db)
                .decide(campaignId, participant, submission, approve, pin),
        onRejectWithReason: (reason) =>
            ReviewApi(db)
                .rejectWithReason(campaignId, participant, submission, reason),
      ),
    );
    if (result == true && context.mounted) {
      toast(context, tr(context, 'reviewDone'));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text(
            uf(context, 'Current submission status', 'നിലവിലെ submission നില'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Wrap(
            spacing: 12,
            children: [
              for (final state in ['pending', 'approved', 'rejected'])
                Text(
                  '${state == 'rejected' ? uf(context, 'Rejected', 'നിരസിച്ചത്') : tr(context, state)}: ${snapshot.data!.where((row) => row['status'] == state).length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
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
  const Campaigns({super.key, required this.uid, this.campaignsStream});
  final String uid;
  final Stream<List<Map<String, dynamic>>>? campaignsStream;
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
    stream:
        campaignsStream ??
        db.from('campaigns').stream(primaryKey: ['id']).eq('ownerId', uid),
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
      return AppListView(
        padding: const EdgeInsets.all(20),
        children: [
          GrowthHero(
            title: tr(context, 'myCampaigns'),
            subtitle: uf(
              context,
              'Create and manage your campaigns with ease.',
              'നിങ്ങളുടെ campaigns സൃഷ്ടിക്കുകയും നിയന്ത്രിക്കുകയും ചെയ്യുക.',
            ),
            icon: Icons.campaign_rounded,
            background: 'campaign_background',
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            GrowthEmpty(
              art: 'campaigns',
              title: tr(context, 'emptyCampaigns'),
              subtitle: uf(
                context,
                'Create your first campaign and reach more audience.',
                'നിങ്ങളുടെ ആദ്യ campaign സൃഷ്ടിക്കുക.',
              ),
              action: GrowthActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateCampaign(),
                  ),
                ),
                icon: Icons.add,
                label: tr(context, 'create'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateCampaign(),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'create')),
              ),
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
                        if (data['status'] == 'active') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(tr(context, 'processing')),
                            ],
                          ),
                        ],
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
  const CreateCampaign({
    super.key,
    this.loadRates,
    this.controls,
    this.reserve,
  });
  final Future<List<Map<String, dynamic>>> Function()? loadRates;
  final Stream<List<Map<String, dynamic>>>? controls;
  final Future<void> Function(String type, String link, int count, int reward)?
  reserve;
  @override
  State<CreateCampaign> createState() => _CreateCampaignState();
}

class _CreateCampaignState extends State<CreateCampaign> {
  final form = GlobalKey<FormState>();
  final link = TextEditingController();
  final count = TextEditingController(text: '1');
  String type = 'follow';
  bool busy = false;
  late Future<List<Map<String, dynamic>>> rates = loadRates();
  Future<List<Map<String, dynamic>>> loadRates() async =>
      widget.loadRates != null
      ? widget.loadRates!()
      : db.from('coin_settings').select();
  late final controlsStream =
      widget.controls ??
      db.from('action_controls').stream(primaryKey: ['action_type']);
  @override
  void dispose() {
    link.dispose();
    count.dispose();
    super.dispose();
  }

  Future<void> submit(int reward) async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (widget.reserve != null) {
        await widget.reserve!(
          type,
          link.text.trim(),
          int.parse(count.text),
          reward,
        );
      } else {
        await db.rpc(
          'create_campaign_at_rate',
          params: {
            'p_type': type,
            'p_reward': reward,
            'p_link': link.text.trim(),
            'p_count': int.parse(count.text),
          },
        );
      }
      if (mounted) {
        Navigator.pop(context);
        toast(context, tr(context, 'created'));
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(context, e));
        setState(() {
          rates = loadRates();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'create'))),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: rates,
      builder: (context, prices) {
        if (prices.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                rates = loadRates();
              }),
              child: Text(tr(context, 'retry')),
            ),
          );
        }
        if (!prices.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reward =
            prices.data!.firstWhere((row) => row['key'] == type)['amount']
                as int;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: controlsStream,
          builder: (context, controls) {
            if (controls.hasError) {
              return Center(child: Text(tr(context, 'error')));
            }
            if (!controls.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final enabled = controls.data!.any(
              (row) => row['action_type'] == type && row['enabled'] == true,
            );
            return Form(
              key: form,
              child: AppListView(
                panel: true,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    tr(context, 'create'),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: type,
                    decoration: InputDecoration(labelText: tr(context, 'type')),
                    items: ['follow', 'like', 'comment', 'share']
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(tr(context, t)),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => type = v!),
                  ),
                  if (!enabled) Text(tr(context, 'actionDisabled')),
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
                    validator: (v) => v == null || v.trim().isEmpty
                        ? tr(context, 'required')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: count,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr(context, 'count'),
                      helperText:
                          '$reward ${tr(context, 'coins')} ${tr(context, 'perTask')} · ${tr(context, 'cost')}',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 100
                          ? tr(context, 'validCount')
                          : null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${tr(context, 'totalCost')}: ${(int.tryParse(count.text) ?? 0) * reward} ${tr(context, 'coins')}',
                  ),
                  const Notice(),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy || !enabled ? null : () => submit(reward),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(tr(context, 'submit')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

String? profileName(User user) {
  final value = user.userMetadata?['full_name'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class Profile extends StatelessWidget {
  const Profile({
    super.key,
    required this.user,
    this.gateway,
    this.onNotifications,
    this.notifications,
  });
  final User user;
  final ProfileGateway? gateway;
  final VoidCallback? onNotifications;
  final Stream<List<Map<String, dynamic>>>? notifications;
  @override
  Widget build(BuildContext context) => ProfileFeatures(
    user: user,
    gateway: gateway,
    onNotifications: onNotifications,
    notifications: notifications,
  );
}

class CoinHistoryPage extends StatefulWidget {
  const CoinHistoryPage({super.key, required this.uid, this.historyStream});
  final String uid;
  final Stream<List<Map<String, dynamic>>>? historyStream;
  @override
  State<CoinHistoryPage> createState() => _CoinHistoryPageState();
}

class _CoinHistoryPageState extends State<CoinHistoryPage> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'history'))),
    body: AppListView(
      padding: const EdgeInsets.all(20),
      children: [
        GrowthHero(
          title: tr(context, 'history'),
          subtitle: uf(
            context,
            'Track your earned and spent coins',
            'ലഭിച്ചതും ചെലവാക്കിയതുമായ coins കാണുക',
          ),
          icon: Icons.stars_rounded,
          background: 'coins_background',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in ['all', 'earned', 'spent', 'refund'])
              FilterChip(
                selectedColor: growthPurple,
                checkmarkColor: Colors.white,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(
                  switch (option) {
                    'earned' => uf(context, 'Earned', 'ലഭിച്ചത്'),
                    'spent' => uf(context, 'Spent', 'ചെലവായത്'),
                    'refund' => uf(context, 'Refunds', 'Refunds'),
                    _ => uf(context, 'All', 'എല്ലാം'),
                  },
                  style: TextStyle(
                    color: filter == option ? Colors.white : growthInk,
                    fontSize: 10,
                  ),
                ),
                selected: filter == option,
                onSelected: (_) => setState(() => filter = option),
              ),
          ],
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream:
              widget.historyStream ??
              db
                  .from('coin_ledger')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', widget.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(tr(context, 'error'));
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs =
                snapshot.data!.where((row) {
                  final amount = row['amount'] as int;
                  return switch (filter) {
                    'earned' => amount > 0 && row['reason'] != 'refund',
                    'spent' => amount < 0,
                    'refund' => row['reason'] == 'refund',
                    _ => true,
                  };
                }).toList()..sort(
                  (a, b) => (b['createdAt'] as String).compareTo(
                    a['createdAt'] as String,
                  ),
                );
            if (docs.isEmpty) {
              return GrowthEmpty(
                art: 'coins',
                title: uf(
                  context,
                  'No Coin History Yet',
                  'ഇതുവരെ coin history ഇല്ല',
                ),
                subtitle: uf(
                  context,
                  'Start earning coins and explore exciting rewards!',
                  'Coins നേടി rewards കണ്ടെത്തൂ!',
                ),
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
                        'referral' => 'referrals',
                        'admin_adjustment' => 'adminAdjustment',
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
    ),
  );
}

class PinException implements Exception {
  const PinException(this.code);
  final String code;
}

class ReleasePinDialog extends StatefulWidget {
  const ReleasePinDialog({
    super.key,
    this.setup = false,
    this.changing = false,
    this.savePin,
    this.sendOtp,
  });
  final Future<void> Function()? sendOtp;
  final bool setup;
  final bool changing;
  final Future<String> Function(String pin, String? otpCode)? savePin;
  @override
  State<ReleasePinDialog> createState() => _ReleasePinDialogState();
}

class _ReleasePinDialogState extends State<ReleasePinDialog> {
  final pin = TextEditingController();
  final confirm = TextEditingController();
  final current = TextEditingController();
  String? error;
  bool busy = false, otpSent = false;
  bool showPin = false, showConfirm = false;
  int cooldown = 0;
  Timer? otpTimer;
  @override
  void dispose() {
    pin.dispose();
    confirm.dispose();
    current.dispose();
    otpTimer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.setup &&
        (!otpSent || !RegExp(r'^\d{6}$').hasMatch(current.text))) {
      setState(() => error = tr(context, 'otp_required'));
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin.text) ||
        (widget.setup && pin.text != confirm.text)) {
      setState(
        () => error = tr(
          context,
          widget.setup ? 'pinMismatch' : 'invalid_format',
        ),
      );
      return;
    }
    if (!widget.setup) {
      Navigator.pop(context, pin.text);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final otpCode = current.text;
      final result = widget.savePin == null
          ? await db.rpc(
              'set_release_pin',
              params: {'p_pin': pin.text, 'p_current_pin': otpCode},
            )
          : await widget.savePin!(pin.text, otpCode);
      if (!mounted) return;
      if (result == 'ok') {
        Navigator.pop(context, 'ok');
      } else {
        setState(() => error = tr(context, result.toString()));
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget pinField(
    TextEditingController controller,
    String label, {
    bool confirmation = false,
  }) => TextField(
    controller: controller,
    obscureText: confirmation ? !showConfirm : !showPin,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    decoration: InputDecoration(
      labelText: tr(context, label),
      prefixIcon: const Icon(Icons.lock_outline, color: growthPurple),
      suffixIcon: IconButton(
        tooltip: tr(
          context,
          (confirmation ? showConfirm : showPin)
              ? 'hidePassword'
              : 'showPassword',
        ),
        onPressed: () => setState(() {
          if (confirmation) {
            showConfirm = !showConfirm;
          } else {
            showPin = !showPin;
          }
        }),
        icon: Icon(
          (confirmation ? showConfirm : showPin)
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    backgroundColor: const Color(0xfff8f5ff),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    title: Column(
      children: [
        if (widget.setup)
          Image.asset(
            'assets/design/pin_shield.png',
            height: 105,
            excludeFromSemantics: true,
          ),
        Text(
          tr(
            context,
            widget.setup
                ? (widget.changing ? 'changePin' : 'setupPin')
                : 'releasePin',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: growthInk,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.setup)
          Text(
            uf(
              context,
              'Keep your account more secure',
              'നിങ്ങളുടെ account കൂടുതൽ സുരക്ഷിതമാക്കുക',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
      ],
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.setup)
              const Icon(Icons.shield_rounded, color: growthPurple, size: 54),
            const SizedBox(height: 8),
            if (!widget.setup) Text(tr(context, 'enterPin')),
            if (widget.setup) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mail_outline),
                  onPressed: busy || cooldown > 0 || widget.sendOtp == null
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await widget.sendOtp!();
                            if (mounted) {
                              setState(() {
                                otpSent = true;
                                cooldown = 60;
                              });
                              otpTimer?.cancel();
                              otpTimer = Timer.periodic(
                                const Duration(seconds: 1),
                                (timer) {
                                  if (!mounted) {
                                    timer.cancel();
                                    return;
                                  }
                                  setState(() => cooldown--);
                                  if (cooldown == 0) timer.cancel();
                                },
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => error = friendlyError(context, e));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  label: Text(
                    '${tr(context, 'sendPinOtp')}${cooldown > 0 ? ' ($cooldown)' : ''}',
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xffe9def9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (otpSent) Text(tr(context, 'otpSentPin')),
              TextField(
                controller: current,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: tr(context, 'otp'),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: growthPurple,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            pinField(pin, widget.setup ? 'newPin' : 'releasePin'),
            if (widget.setup) ...[
              const SizedBox(height: 8),
              pinField(confirm, 'confirmPin', confirmation: true),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        style: TextButton.styleFrom(
          side: const BorderSide(color: Color(0xffa68ccf)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
        ),
        child: Text(tr(context, 'cancel')),
      ),
      SizedBox(
        width: 125,
        child: GrowthPrimaryButton(
          onPressed: busy ? null : submit,
          label: tr(context, widget.setup ? 'save' : 'yesConfirm'),
        ),
      ),
    ],
  );
}

class InstagramLookupException implements Exception {
  const InstagramLookupException(this.code);
  final String code;
}

class ProfileInfo {
  final Map<String, int> referralRewards;
  const ProfileInfo({
    this.referralRewards = const {},
    this.publicUserId,
    required this.usernames,
    required this.referralCode,
    required this.referralCount,
    required this.referralJoined,
    required this.pinSet,
  });
  final String? publicUserId;
  final List<String> usernames;
  final String referralCode;
  final int referralCount;
  final bool referralJoined, pinSet;
}

abstract class ProfileGateway {
  Future<ProfileInfo> load(String uid);
  Stream<int?> balance(String uid);
  Stream<List<Map<String, dynamic>>> history(String uid);
  Future<void> addAccount(String username);
  Future<String> searchInstagram(String username);
  Future<void> removeAccount(String username);
  Future<void> applyReferral(String code);
  Future<void> sendPinOtp();
  Future<String> setPin(String pin, String? otpCode);
  Future<void> signOut();
}

class SupabaseProfileGateway implements ProfileGateway {
  const SupabaseProfileGateway(this.client);
  final SupabaseClient client;
  @override
  Future<ProfileInfo> load(String uid) async {
    final values = await Future.wait<dynamic>([
      client
          .from('instagram_accounts')
          .select('username')
          .eq('user_id', uid)
          .order('created_at'),
      client.rpc('referral_info'),
      client.rpc('release_pin_is_set'),
      client.from('coin_settings').select(),
    ]);
    final accounts = values[0] as List;
    final referral = Map<String, dynamic>.from(values[1] as Map);
    return ProfileInfo(
      usernames: [
        for (final account in accounts) account['username'] as String,
      ],
      publicUserId: referral['user_id'] as String?,
      referralCode: referral['code'] as String,
      referralCount: referral['count'] as int,
      referralJoined: referral['joined'] as bool,
      pinSet: values[2] as bool,
      referralRewards: {
        for (final row in values[3] as List)
          if ([
            'invite',
            'milestone_5',
            'milestone_10',
            'milestone_15',
          ].contains(row['key']))
            row['key'] as String: row['amount'] as int,
      },
    );
  }

  @override
  Stream<int?> balance(String uid) => client
      .from('wallets')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) => rows.isEmpty ? null : rows.first['balance'] as int?);
  @override
  Stream<List<Map<String, dynamic>>> history(String uid) =>
      client.from('coin_ledger').stream(primaryKey: ['id']).eq('user_id', uid);
  @override
  Future<void> addAccount(String username) async =>
      client.rpc('add_instagram_account', params: {'p_username': username});
  @override
  Future<String> searchInstagram(String username) async {
    try {
      final response = await client.functions.invoke(
        'instagram-lookup',
        body: {'username': username},
      );
      final data = response.data;
      if (data is! Map || data['username'] is! String) {
        throw const InstagramLookupException('lookup_unavailable');
      }
      final result = data['username'] as String;
      final query = username.trim().replaceFirst(RegExp(r'^@'), '');
      if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(result) ||
          result.toLowerCase() != query.toLowerCase()) {
        throw const InstagramLookupException('lookup_unavailable');
      }
      return result;
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] : null;
      if (code == 'not_found_or_unsupported' ||
          code == 'rate_limited' ||
          code == 'access_denied' ||
          code == 'unauthorized') {
        throw InstagramLookupException(code as String);
      }
      if (e.status == 401) throw const InstagramLookupException('unauthorized');
      if (e.status == 403) {
        throw const InstagramLookupException('access_denied');
      }
      if (e.status == 429) throw const InstagramLookupException('rate_limited');
      throw const InstagramLookupException('lookup_unavailable');
    }
  }

  @override
  Future<void> removeAccount(String username) async =>
      client.rpc('remove_instagram_account', params: {'p_username': username});
  @override
  Future<void> applyReferral(String code) async =>
      client.rpc('apply_referral', params: {'p_code': code});
  @override
  Future<void> sendPinOtp() => client.auth.reauthenticate();

  @override
  Future<String> setPin(String pin, String? otpCode) async {
    if (client.auth.currentUser?.email == null || otpCode == null) {
      return 'otp_required';
    }
    return await client.rpc(
      'set_release_pin_reauthenticated',
      params: {'p_pin': pin, 'p_nonce': otpCode},
    ) as String;
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

String profileInitials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length > 1) {
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
  return parts.first.characters.take(2).toString().toUpperCase();
}

class ProfileFeatures extends StatefulWidget {
  const ProfileFeatures({
    super.key,
    required this.user,
    this.gateway,
    this.onNotifications,
    this.notifications,
  });
  final User user;
  final ProfileGateway? gateway;
  final VoidCallback? onNotifications;
  final Stream<List<Map<String, dynamic>>>? notifications;
  @override
  State<ProfileFeatures> createState() => _ProfileFeaturesState();
}

class _ProfileFeaturesState extends State<ProfileFeatures> {
  late final ProfileGateway gateway =
      widget.gateway ?? SupabaseProfileGateway(db);
  late final Stream<int?> balance = gateway.balance(widget.user.id);
  late Future<ProfileInfo> data = gateway.load(widget.user.id);
  void reload() => setState(() {
    data = gateway.load(widget.user.id);
  });
  Future<void> openDetails(bool accounts) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailsPage(
          uid: widget.user.id,
          gateway: gateway,
          accounts: accounts,
        ),
      ),
    );
    if (mounted) reload();
  }

  Future<void> openPin(bool pinSet) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => ReleasePinDialog(
        setup: true,
        changing: pinSet,
        savePin: gateway.setPin,
        sendOtp: gateway.sendPinOtp,
      ),
    );
    if (result == 'ok' && mounted) {
      toast(context, tr(context, 'pinSaved'));
      reload();
    }
  }

  Future<void> signOut() async {
    try {
      if (widget.gateway == null) await PushCoordinator.instance.stop(db);
      await gateway.signOut();
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProfileInfo>(
    future: data,
    builder: (context, details) => StreamBuilder<int?>(
      stream: balance,
      builder: (context, wallet) => ProfileLayout(
        user: widget.user,
        info: details.data,
        balance: wallet.data,
        loading: details.connectionState != ConnectionState.done,
        error: details.hasError,
        onRetry: reload,
        onPersonalInfo: !details.hasData
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PersonalInformationPage(
                    user: widget.user,
                    publicId: details.data?.publicUserId,
                    gateway: SupabasePersonalInformationGateway(
                      db,
                      () => SupabaseClient(
                        supabaseUrl,
                        supabaseKey,
                        authOptions: const AuthClientOptions(
                          autoRefreshToken: false,
                          authFlowType: AuthFlowType.implicit,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        onAccounts: () => openDetails(true),
        onReferrals: () => openDetails(false),
        onHistory: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CoinHistoryPage(
              uid: widget.user.id,
              historyStream: gateway.history(widget.user.id),
            ),
          ),
        ),
        onPin: details.hasData ? () => openPin(details.data!.pinSet) : null,
        onSignOut: signOut,
        onLanguage: toggleLanguage,
        onNotifications: widget.onNotifications,
        notifications: widget.notifications,
      ),
    ),
  );
}

class ProfileLayout extends StatelessWidget {
  const ProfileLayout({
    super.key,
    required this.user,
    required this.info,
    required this.balance,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onPersonalInfo,
    required this.onAccounts,
    required this.onReferrals,
    required this.onHistory,
    required this.onPin,
    required this.onSignOut,
    required this.onLanguage,
    this.onNotifications,
    this.notifications,
  });
  final VoidCallback? onNotifications;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final User user;
  final ProfileInfo? info;
  final int? balance;
  final bool loading, error;
  final VoidCallback? onPersonalInfo;
  final VoidCallback onRetry,
      onAccounts,
      onReferrals,
      onHistory,
      onSignOut,
      onLanguage;
  final VoidCallback? onPin;
  @override
  Widget build(BuildContext context) {
    final name = profileName(user) ?? user.email ?? tr(context, 'profile');
    final created = DateTime.tryParse(user.createdAt);
    final joined = created == null
        ? null
        : '${tr(context, 'profileJoined')} ${MaterialLocalizations.of(context).formatMonthYear(created.toLocal())}';
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'profile'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onNotifications != null && notifications != null)
                  NotificationsButton(
                    stream: notifications!,
                    onPressed: onNotifications!,
                  ),
                PopupMenuButton<String>(
                  tooltip: tr(context, 'profileSettings'),
                  icon: const Icon(Icons.settings_outlined),
                  onSelected: (value) {
                    if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const UserSettingsPage(),
                        ),
                      );
                    } else if (value == 'signout') {
                      onSignOut();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'settings',
                      child: Text(uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ')),
                    ),
                    PopupMenuItem(
                      value: 'signout',
                      child: Text(tr(context, 'signout')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xffc5a8fa),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: growthPurple.withValues(alpha: .12),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xffc5f64b),
                          child: Text(
                            profileInitials(name),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff171a13),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff17171b),
                      ),
                    ),
                    if (profileName(user) != null && user.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.email!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xff62647a)),
                      ),
                    ],
                    if (info?.publicUserId != null) ...[
                      const SizedBox(height: 6),
                      SelectableText(
                        'User ID: ${info!.publicUserId}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (joined != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        joined,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff62647a),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          ProfileStat(
                            value: balance?.toString() ?? '—',
                            label: tr(context, 'coins'),
                            icon: Icons.toll,
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: const Color(0xfff0eff4),
                          ),
                          ProfileStat(
                            value: info?.usernames.length.toString() ?? '—',
                            label: tr(context, 'profileAccounts'),
                            icon: Icons.person,
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: const Color(0xfff0eff4),
                          ),
                          ProfileStat(
                            value: info?.referralCount.toString() ?? '—',
                            label: tr(context, 'profileReferrals'),
                            icon: Icons.share,
                          ),
                        ],
                      ),
                    ),
                    if (error)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tr(context, 'profileDataError')),
                            ),
                            TextButton(
                              onPressed: onRetry,
                              child: Text(tr(context, 'retry')),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Material(
                      color: const Color(0xff4314b9),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        key: const Key('profile_referral_banner'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: onReferrals,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xff6840d6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.people_alt_outlined,
                                  color: Color(0xffe5d9ff),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(context, 'referrals'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      tr(context, 'profileReferralDesc'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Text(
                              tr(context, 'accountSection'),
                              style: const TextStyle(
                                color: Color(0xff6a6f8b),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.person_outline,
                            title: uf(
                              context,
                              'Personal information',
                              'വ്യക്തിഗത വിവരങ്ങൾ',
                            ),
                            onTap: onPersonalInfo,
                          ),
                          ProfileMenuTile(
                            icon: Icons.alternate_email,
                            title: tr(context, 'instagramAccounts'),
                            onTap: onAccounts,
                            trailingText: info?.usernames.length.toString(),
                          ),
                          ProfileMenuTile(
                            icon: Icons.history,
                            title: tr(context, 'history'),
                            onTap: onHistory,
                          ),
                          ProfileMenuTile(
                            icon: Icons.people_outline,
                            title: tr(context, 'referrals'),
                            onTap: onReferrals,
                          ),
                          ProfileMenuTile(
                            icon: Icons.help_outline,
                            title: tr(context, 'helpGuide'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => UserHelpPage(client: db),
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.support_agent_outlined,
                            title: tr(context, 'support'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SupportPage(client: db),
                              ),
                            ),
                          ),
                          ProfileMenuTile(
                            icon: Icons.lock_outline,
                            title: tr(context, 'releasePin'),
                            subtitle: info == null
                                ? null
                                : tr(
                                    context,
                                    info!.pinSet ? 'changePin' : 'setupPin',
                                  ),
                            onTap: onPin,
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });
  final String value, label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        if (icon != null) Icon(icon, size: 18, color: growthPurple),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff62647a), fontSize: 11),
        ),
      ],
    ),
  );
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle, trailingText;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      enabled: onTap != null,
      onTap: onTap,
      dense: true,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xffeee6ff),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: growthPurple),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: const TextStyle(color: Color(0xff71748b)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({
    super.key,
    required this.uid,
    required this.gateway,
    required this.accounts,
  });
  final String uid;
  final ProfileGateway gateway;
  final bool accounts;
  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late Future<ProfileInfo> data = widget.gateway.load(widget.uid);
  void reload() => setState(() {
    data = widget.gateway.load(widget.uid);
  });
  Future<void> input() async {
    final title = widget.accounts ? 'addAccount' : 'referralEnter';
    final value = await showDialog<String>(
      context: context,
      builder: (_) => ProfileInputDialog(titleKey: title),
    );
    if (value == null || value.isEmpty || !mounted) return;
    try {
      if (widget.accounts) {
        await widget.gateway.addAccount(value);
      } else {
        await widget.gateway.applyReferral(value);
      }
      if (!mounted) return;
      if (!widget.accounts) toast(context, tr(context, 'referralApplied'));
      reload();
    } catch (e) {
      if (mounted) {
        final message = e is PostgrestException && e.code == '23505'
            ? tr(
                context,
                widget.accounts ? 'duplicateAccount' : 'referralJoined',
              )
            : friendlyError(context, e);
        toast(context, message);
      }
    }
  }

  Future<void> search() async {
    final username = await showDialog<String>(
      context: context,
      builder: (_) => InstagramSearchDialog(gateway: widget.gateway),
    );
    if (username == null || !mounted) return;
    try {
      await widget.gateway.addAccount(username);
      if (mounted) reload();
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e is PostgrestException && e.code == '23505'
              ? tr(context, 'duplicateAccount')
              : friendlyError(context, e),
        );
      }
    }
  }

  Future<void> remove(String username) async {
    try {
      await widget.gateway.removeAccount(username);
      if (mounted) reload();
    } catch (e) {
      if (mounted) toast(context, friendlyError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        tr(context, widget.accounts ? 'instagramAccounts' : 'referrals'),
      ),
    ),
    body: FutureBuilder<ProfileInfo>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'profileDataError')),
                TextButton(
                  onPressed: reload,
                  child: Text(tr(context, 'retry')),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final info = snapshot.data!;
        return AppListView(
          panel: false,
          padding: const EdgeInsets.all(20),
          children: [
            if (!widget.accounts) ...[
              GrowthHero(
                title: uf(context, 'Refer & Earn', 'Refer & Earn'),
                subtitle: uf(
                  context,
                  'Invite your friends and earn rewards',
                  'സുഹൃത്തുക്കളെ ക്ഷണിച്ച് rewards നേടുക',
                ),
                icon: Icons.card_giftcard_rounded,
                background: 'referral_background',
              ),
              const SizedBox(height: 16),
            ],
            if (widget.accounts) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: search,
                        icon: const Icon(Icons.search),
                        label: Text(tr(context, 'instagramSearch')),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xffeee7fa),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                      if (info.usernames.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            uf(
                              context,
                              'No Instagram usernames added yet.',
                              'Instagram usernames ചേർത്തിട്ടില്ല.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      TextButton.icon(
                        onPressed: input,
                        icon: const Icon(Icons.add_circle),
                        label: Text(tr(context, 'addAccount')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (info.usernames.isEmpty)
                GrowthEmpty(
                  art: 'accounts',
                  title: uf(
                    context,
                    'No Instagram Accounts Yet!',
                    'Instagram accounts ചേർത്തിട്ടില്ല!',
                  ),
                  subtitle: uf(
                    context,
                    'Add your Instagram username to manage your account here.',
                    'നിങ്ങളുടെ Instagram username ചേർക്കുക.',
                  ),
                  action: GrowthActionButton(
                    onPressed: input,
                    icon: Icons.add,
                    label: uf(
                      context,
                      'Add Instagram username',
                      'Instagram username ചേർക്കുക',
                    ),
                  ),
                ),
              for (final username in info.usernames)
                Card(
                  child: ListTile(
                    title: Text('@$username'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: tr(context, 'removeAccount'),
                      onPressed: () => remove(username),
                    ),
                  ),
                ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard, color: growthPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(context, 'referralNoReward'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      for (final reward in info.referralRewards.entries)
                        Card(
                          color: const Color(0xfff2edfb),
                          elevation: 0,
                          child: ListTile(
                            dense: true,
                            minLeadingWidth: 20,
                            leading: const Icon(
                              Icons.radio_button_unchecked,
                              color: growthPurple,
                              size: 18,
                            ),
                            title: Text(
                              reward.key == 'invite'
                                  ? (Localizations.localeOf(context)
                                                .languageCode ==
                                            'ml'
                                        ? 'ഓരോ invite-നും'
                                        : 'Each referral')
                                  : '${reward.key.split('_').last} invites · ${Localizations.localeOf(context).languageCode == 'ml' ? 'അധിക bonus' : 'extra bonus'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '${reward.value} ${tr(context, 'coins')}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: growthPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        tr(context, 'referralCode'),
                        textAlign: TextAlign.center,
                      ),
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xffeee5fa),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xffc9b3ed)),
                        ),
                        child: SelectableText(
                          info.referralCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: growthInk,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: info.referralCode),
                          );
                          if (context.mounted) {
                            toast(context, tr(context, 'copied'));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(tr(context, 'copyCode')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          try {
                            await SharePlus.instance.share(
                              ShareParams(
                                text:
                                    '${tr(context, 'referralCode')}: ${info.referralCode}',
                              ),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              toast(context, tr(context, 'error'));
                            }
                          }
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: Text(tr(context, 'shareReferral')),
                      ),
                      Text(
                        '${tr(context, 'referralCount')}: ${info.referralCount}',
                      ),
                      Builder(
                        builder: (context) {
                          final next = [
                            5,
                            10,
                            15,
                          ].where((n) => n > info.referralCount).firstOrNull;
                          return next == null
                              ? Text(
                                  uf(
                                    context,
                                    'All referral milestones reached.',
                                    'എല്ലാ referral milestones-ഉം പൂർത്തിയായി.',
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      '${uf(context, 'Next milestone', 'അടുത്ത milestone')}: ${info.referralCount}/$next',
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: (info.referralCount / next).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                    ),
                                  ],
                                );
                        },
                      ),
                      if (info.referralJoined)
                        Text(tr(context, 'referralJoined'))
                      else
                        TextButton(
                          onPressed: input,
                          child: Text(tr(context, 'referralEnter')),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class ProfileInputDialog extends StatefulWidget {
  const ProfileInputDialog({super.key, required this.titleKey});
  final String titleKey;
  @override
  State<ProfileInputDialog> createState() => _ProfileInputDialogState();
}

class _ProfileInputDialogState extends State<ProfileInputDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, widget.titleKey)),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(labelText: tr(context, widget.titleKey)),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: Text(tr(context, 'apply')),
      ),
    ],
  );
}

class InstagramSearchDialog extends StatefulWidget {
  const InstagramSearchDialog({super.key, required this.gateway});
  final ProfileGateway gateway;
  @override
  State<InstagramSearchDialog> createState() => _InstagramSearchDialogState();
}

class _InstagramSearchDialogState extends State<InstagramSearchDialog> {
  final controller = TextEditingController();
  bool busy = false;
  String? result, error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (busy) return;
    final handle = controller.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(handle)) {
      setState(() {
        result = null;
        error = tr(context, 'proofBadHandle');
      });
      return;
    }
    setState(() {
      busy = true;
      result = null;
      error = null;
    });
    try {
      final username = await widget.gateway.searchInstagram(handle);
      if (mounted) setState(() => result = username);
    } on InstagramLookupException catch (e) {
      if (mounted) {
        final key = switch (e.code) {
          'not_found_or_unsupported' => 'instagramSearchNotFound',
          'rate_limited' => 'instagramSearchLimited',
          'access_denied' || 'unauthorized' => 'instagramSearchDenied',
          _ => 'instagramSearchUnavailable',
        };
        setState(() => error = tr(context, key));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = tr(context, 'instagramSearchUnavailable'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'instagramSearch')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'instagramSearchHelp')),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !busy,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr(context, 'instagramSearchHint'),
              hintText: '@username',
            ),
            onChanged: (_) => setState(() {
              result = null;
              error = null;
            }),
            onSubmitted: (_) => search(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : search,
            icon: const Icon(Icons.search),
            label: Text(tr(context, 'instagramSearchAction')),
          ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (result != null) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text('@$result'),
            ),
            Text(
              tr(context, 'instagramSearchOwnership'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: busy || result == null
            ? null
            : () => Navigator.pop(context, result),
        child: Text(tr(context, 'instagramSearchAdd')),
      ),
    ],
  );
}

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key, this.enabledLoader, this.pushUpdater});
  final Future<bool> Function()? enabledLoader;
  final Future<void> Function(bool)? pushUpdater;
  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage>
    with WidgetsBindingObserver {
  bool enabled = false, loading = true, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> load() async {
    try {
      final value =
          await (widget.enabledLoader?.call() ??
              PushCoordinator.instance.isEnabled(db));
      if (mounted) {
        setState(() {
          enabled = value;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, tr(context, 'error'));
      }
    }
  }

  Future<void> changePush(bool value) async {
    setState(() => busy = true);
    try {
      if (widget.pushUpdater != null) {
        await widget.pushUpdater!(value);
      } else if (value) {
        final granted = await PushCoordinator.instance.enable(db);
        if (!granted) throw const PushPermissionDenied();
      } else {
        await PushCoordinator.instance.disable(db);
      }
      if (mounted) setState(() => enabled = value);
    } on PushPermissionDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uf(
                context,
                'Allow notifications in Android settings, then turn this switch on again.',
                'Android settings-ൽ notifications അനുവദിച്ച ശേഷം switch വീണ്ടും ON ചെയ്യുക.',
              ),
            ),
            action: SnackBarAction(
              label: uf(context, 'Open settings', 'Settings തുറക്കുക'),
              onPressed: () async {
                try {
                  await updateChannel.invokeMethod<void>(
                    'openNotificationSettings',
                  );
                } catch (_) {
                  if (mounted) toast(context, tr(context, 'error'));
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          uf(
            context,
            'Unable to change notifications. Check permission and connection, then retry.',
            'Notification മാറ്റാനായില്ല. Permission, connection പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(uf(context, 'Settings', 'ക്രമീകരണങ്ങൾ'))),
    body: AppListView(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(uf(context, 'App updates', 'App updates')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AppUpdatePage()),
            ),
          ),
        ),
        Card(
          child: SwitchListTile(
            title: Text(
              uf(context, 'Push notifications', 'Push notifications'),
            ),
            value: enabled,
            onChanged: loading || busy ? null : changePush,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(uf(context, 'Language', 'ഭാഷ')),
            trailing: DropdownButton<String>(
              value: Localizations.localeOf(context).languageCode,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ml', child: Text('മലയാളം')),
              ],
              onChanged: (value) {
                if (value != null) language.value = Locale(value);
              },
            ),
          ),
        ),
        if (loading || busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
