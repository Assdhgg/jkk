<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:6946cdf13410aac306f33f197d601c95805a81d1b45ef53e89c8d1e058c27cbc -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:839d4b92f805dbbd5ccc6ba2ae0b5f0ccd8ece1d43944e89c5b6bbc554843b15 -->

# Growth Circle

Flutter Android app using Supabase Auth and PostgreSQL for self-reported Instagram engagement campaigns. Claims are not verified Instagram actions. Instagram passwords are never collected.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1c07e2717a8f2f9782074e698bf8261404c2dec1f9c1f703699aa1999c8a939a -->

[Visual Studio setup and build guide (Malayalam)](docs/VISUAL_STUDIO_BUILD_GUIDE.md)

## Supabase setup

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f24dde85e125e562cf2124f3ccc92529f5111eda2b20320eecc21d7bc2111f9e -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:bb7f26bba409c994aff694dc36a35cfe61121fc0a0fdc824b10cbe631281c292 -->

1. Enable email/password authentication and **Confirm email** in Supabase Authentication. Configure custom SMTP. In Authentication → Email templates → Confirm signup, replace the confirmation link with `<p>Your Growth Circle verification code is: <strong>{{ .Token }}</strong></p>`. Configure email OTP length to 6 digits. Keep the password recovery template intact. Signup uses `signUp(email, password)`, then `verifyOTP(type: signup)` on a separate in-memory client; verification never logs the main app in. The user must then sign in using email and password. Invalid credentials display a signup suggestion because Supabase does not distinguish an unknown email from a wrong password. Signup/resend have a 60-second client cooldown; server rate limits still apply. The Already received a code option lets an unconfirmed user resume after app restart.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
2. In Authentication → URL Configuration, add `io.supabase.growthcircle://login-callback/` as an allowed redirect URL for signup and password recovery.
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ae87e7b9ad6474da4755d50a24fed3ca759194e89d12befb8fdb545ba30a95b9 -->

3. In the SQL Editor, apply `supabase/migrations/20261107000000_growth_circle.sql` to a new project, then apply `supabase/migrations/20261107010000_owner_review.sql` once. Existing Growth Circle projects that already have the first migration only need the second. The second migration changes the coin contract: new submissions require owner approval. It disables immediate claims from old APKs; distribute the upgraded APK after applying the migration. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3030a55e17c45b50c9148e9cc745817009e204d58213b7dcdbe8d5ecd6754fe0 -->

Existing paid claims remain marked as legacy self-reports and are not reversed.

<!-- /coderabbit-ai-generated:v1 --> There is no automatic migration of Firebase accounts or data.

<!-- /coderabbit-ai-generated:v1 -->
4. Copy the project URL and publishable key (or legacy anon key) from the project's API settings. These are client-side values. Never put the service-role key or database password in the app.
5. Install Flutter 3.47.9, JDK 21 and the Android SDK, then run `flutter pub get` and build:

```sh
flutter build apk --release \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

The app shows a setup screen if values are missing. For a distributable release configure `android/key.properties` with `storeFile` (absolute path), `storePassword`, `keyAlias` and `keyPassword` for a securely retained release keystore. Keep the keystore and passwords private and backed up; future updates require the same signing key. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:de61abf7b131aaf3ae5fc1ac0e48c9b4080ecd739f5954886f4d1ca672357792 -->

Release APK and app bundle packaging fails with an actionable error when signing configuration is missing or incomplete, rather than creating an uninstallable unsigned package. Debug builds do not require this file. Keep using the same signing key for updates; an APK signed with a different key cannot update an installed app. To diagnose an existing APK, run `apksigner verify --verbose --print-certs app-release.apk` from Android SDK Build-Tools and compare the certificate with the installed release.

<!-- /coderabbit-ai-generated:v1 --> The package name is `com.growthcircle.growth_circle`.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:cd37f3b5cf27005467ce51dba5ef788d107000199de4aba6890481c57bfa8db9 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a98e37d76ff9563248a081ae337b40f87d0960362413007ec2bebd1247e4907f -->

## Android release signing

If you have an existing release keystore, use that same keystore and alias. If this app has never been distributed with a retained signing key, create one with `keytool -genkeypair -v -keystore ~/growth-circle-release.jks -alias growth-circle -keyalg RSA -keysize 2048 -validity 10000` and securely retain the keystore and passwords. A newly created key cannot update an app signed with another key.

Create `android/key.properties` locally (do not commit it):

```properties
storeFile=/absolute/path/to/growth-circle-release.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=growth-circle
keyPassword=YOUR_KEY_PASSWORD
```

Build with the Supabase project URL and public key shown above. Before sharing the APK, run `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`. To investigate an installation error, check the exact APK's signature, app ID, version code, and device architecture; the same message can have more than one cause.

## Windows administrator app

<!-- /coderabbit-ai-generated:v1 -->

The Windows administrator app lists/searches accounts, shows coin balances, and blocks/restores app data access. It uses normal Supabase email/password authentication and the publishable/anon key; no service-role key is used or stored in the client. Blocking is enforced in database RLS and RPCs even for previously issued sessions; requests already in progress can finish before a block commits, and cached data may remain visible. Blocking app data does not ban the user from Supabase Auth itself.

Apply migrations in order, including `supabase/migrations/20261107020000_admin_access.sql`, in the intended Supabase project. Then create a confirmed admin account through the existing app, and as the project owner run this in the Supabase SQL Editor after replacing the placeholder with that account's email:

```sql
insert into public.admin_members (user_id)
select id from auth.users
where lower(email) = lower('ADMIN_EMAIL_HERE') and email_confirmed_at is not null
on conflict (user_id) do nothing;
```

Only a database owner can provision administrators. The admin UI cannot block administrator accounts. Admin changes are recorded in `public.admin_access_audit`; that table and the admin allowlist are not directly readable or writable by app clients. No delete-account or coin-edit feature is provided.

On Windows with Flutter 3.47.9 and Visual Studio C++ tools, run `flutter pub get` and `flutter build windows --release -t lib/admin_main.dart`. Run `build\windows\x64\runner\Release\growth_circle_admin.exe` with the entire Release directory. A GitHub Actions workflow also produces a Windows ZIP artifact. On first launch enter the project URL and publishable/anon key, then sign in as the provisioned admin. The public project configuration is stored locally; passwords and service-role keys are not stored by the app. Supabase SQL deployment and a real Windows build must be verified on the target environment.

## Tests

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:58bf115b1cd3357bb53e5e0e96db454c86b715e5a78c3e28995f81aed7d1ae2f -->

Run `flutter analyze` and `flutter test`. PostgreSQL tests mock Supabase `auth.uid()` and must only be run against isolated disposable databases, never a real project. For the original contract use `supabase/tests/bootstrap.sql`, the original migration, then `python3 supabase/tests/integration.py DATABASE_NAME`. For owner review, use a separate fresh database with bootstrap and the original migration, then run `python3 supabase/tests/review_integration.py DATABASE_NAME`; this script applies the owner-review migration after creating historical claims. Tests require a PostgreSQL superuser and do not replace verification against Supabase Auth, Realtime or a real Android device.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f2f17671c506c58af26acf8ab677d734ecaa328e0bab90e83fda3cbcdf5c828f -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dd8737c9688b580259fd2d3f80adfd03b0afd0c1f3f266a036775b7109ba6356 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:907444502ca19dd120b7a8274d64fd7fe01235a134066b9b475dda7122ddef4b -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:00d23226cd9b44dff7373890f13416954c466ed19f96947df380fc36e9e8f145 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:40898aafea10f08a5e4c83d28271a67f3572bcd60748b57ef221489e5b77a5d5 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:70bf78bff72d93bf90e70badef71da3e261c6514ae11cd29fbd61a4dd25ea3b3 -->

## Instagram username lookup

For project `stpxbshwdiupigymakfy`, follow the [Malayalam live setup checklist](docs/INSTAGRAM_LIVE_SETUP.md). Hosted deployment and Meta access must be verified separately from source tests.

<!-- /coderabbit-ai-generated:v1 -->

The in-app lookup searches an exact username using Meta Business Discovery. Meta supports Business/Creator accounts for this endpoint; personal or age-restricted accounts may not be returned, partial-name suggestions are not supported, and a result does not establish ownership. Manual username entry remains available.

Apply `supabase/migrations/20261107070000_instagram_lookup_rate.sql` after all earlier migrations. Set up a Meta app and an authorized Instagram professional account using [Meta's Business Discovery requirements](https://developers.facebook.com/documentation/instagram-platform/instagram-graph-api/reference/ig-user/business_discovery): the applicable Facebook access token requires `instagram_basic`, `instagram_manage_insights` and `pages_read_engagement`; Meta app review or additional permissions may be required for your deployment. Obtain that authorized account's Instagram user ID and access token through Meta's official flow. The token belongs only on the server; do not put it in the Flutter app, source control, or chat.

Deploy `supabase/functions/instagram-lookup` to the same Supabase project. Set the Edge Function secrets `META_INSTAGRAM_USER_ID` and `META_INSTAGRAM_ACCESS_TOKEN` in Supabase's secret manager; the platform supplies `SUPABASE_URL` and `SUPABASE_ANON_KEY`. For example, after installing and authenticating the [Supabase CLI](https://supabase.com/docs/guides/functions/deploy), link the intended project and use `supabase secrets set --env-file <secure-file-outside-repository>` followed by `supabase functions deploy instagram-lookup`. The secure file contains those two `NAME=value` entries and must be protected and excluded from version control. Keep JWT verification enabled. Invalid/expired credentials show an unavailable message; rotate them through Meta and update the Supabase secrets. The server validates the user session, rejects blocked users and limits lookups to 20 per user per minute.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0c829ef2a10d0ac13f82b0a314d87ef3ebcce2934d0131ccdccf13b5c84f8763 -->

## Task filters and notifications

Earn tasks can be filtered by Follow, Like, Comment or Share; submission history stays visible. Apply `supabase/migrations/20261107080000_notifications.sql` after the earlier migrations and enable the `notifications` table in Supabase Realtime if it is not already published. The new migration records future approvals, rejections and positive coin ledger entries transactionally; earlier events are not backfilled. Signed-in active users can view only their own notifications and mark them read. An unread indicator and list update while the app is open and connected. These are in-app notifications; no device push notification service is configured.

## Administrator submission inspection

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107060000_admin_submission_review.sql` after the preceding migrations. Administrators can inspect pending usernames and screenshots; each inspection is recorded in a private audit table. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3ceeea8a6f7add72f8994cabee4291ff7327c84afdd653ca3f0705c0dd1a589c -->

Participants see “AI is checking your submission” while an administrator is checking it.

<!-- /coderabbit-ai-generated:v1 --> The indicator expires after two minutes without a connection and is refreshed while the inspection is open. Campaign owners continue to make approval decisions using their PIN. No AI review is performed.

## Administrator campaign overview

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107050000_admin_campaigns.sql` after the preceding migrations. The administrator app can list campaigns by action and status, including their owner email and task progress. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7c61c051ab47f1de730559a2c54dd6684a9a255f8ac029ed45a33523f35a20a6 -->

The campaign owner retains the approval decision; administrators can inspect pending evidence as described above.

<!-- /coderabbit-ai-generated:v1 -->

## Administrator action controls

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107040000_admin_action_controls.sql` after the preceding migrations and distribute updated user and administrator apps. In the administrator app, open Action controls to enable or disable Follow, Like, Share and Comment independently. Disabling an action blocks new campaigns and submissions for that action on the server, including requests from older clients. Operations already in progress can finish before the change commits. Existing submissions remain available for owner review or withdrawal, and campaign cancellation still refunds unused coins. These controls apply inside Growth Circle; they cannot control actions directly on Instagram.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1ce76b4e4b99a55e89f1d4c9b37beb991ebf83d06740bce98ae128c6b9a4acd4 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3a88de9ea64157cf907adfedb072d93bae9ecee31ede80d08208ef681ef934c8 -->

## Security hardening

Apply `supabase/migrations/20261107100000_security_hardening.sql` after **all ten earlier migrations**, then distribute updated user/admin apps. If Instagram lookup is deployed, redeploy its updated Edge Function as well; lookup activation remains separate.

- App data and coin RPCs now require a real account with a confirmed email. Anonymous Auth sessions and unconfirmed accounts cannot bypass the signup UI to initialize wallets or earn referral credits. User-editable metadata is not accepted as email verification. Existing RLS ownership and administrator checks remain enforced.
- PIN setup/reset now checks the current confirmed account email against the signed JWT email. Generic `otp` AMR can also represent SMS, so PIN setup/reset explicitly rejects accounts with a linked phone or JWT phone claim. This app supports email account login; phone-linked accounts need account support before changing their PIN. Existing PINs still release coins for active verified-email users. Freshness, one-use OTP proof and five-failure/15-minute release lockout remain intact. A stale email claim must be refreshed before setup/reset.
- Evidence remains JPEG/PNG and at most 512 KiB, and now must also be static and no more than 4096 pixels in either dimension. The database checks PNG/JPEG metadata for new writes. Both reviewer apps check dimensions before decoding and validate a bounded thumbnail before rendering. Historical malformed evidence is not deleted by the migration; updated owners can reject it, while approval stays disabled when evidence cannot be safely decoded. A dimension check is not a claim that a screenshot proves Instagram activity.
- The lookup Edge Function stops reading request bodies at 2048 bytes and cancels stalled reads after eight seconds. This applies before upstream API calls; credentials remain server-side.
- Android release traffic explicitly disallows cleartext HTTP. App backup is disabled, with Android 12+ cloud/device-transfer exclusions to keep stored login sessions from being copied. Debug-only cleartext support is retained for Flutter development. See [Android backup configuration](https://developer.android.com/identity/data/autobackup).

Verification: Flutter analyzer and all 52 tests passed; isolated PostgreSQL security/economy/notification/action/admin-inspection/lookup tests passed; Edge handler tests and Deno checks passed; Gradle debug/release manifest merging and debug resource compilation passed. A query of OSV for the 93 hosted packages in the unchanged lockfile returned no listed advisories. These checks use synthetic Auth/Meta fixtures and do not establish live Supabase configuration, actual OTP delivery, native device behavior or production deployment. Committing migrations and pushing GitHub does **not** apply them to Supabase.

## Coin settings, referral rewards and email OTP PIN

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107090000_coin_settings_referrals_pin_otp.sql` **after all preceding migrations**, including `20261107080000_notifications.sql`. Distribute updated user and administrator builds with this migration. Old clients cannot set/change a PIN after the upgrade; existing PINs still release coins. New clients use `create_campaign_at_rate` to reject a changed price before spending coins. Legacy creation requests use the current configured rate: retire old builds before changing task prices, because they display a fixed one-coin cost.

In the administrator dashboard, choose **Coin settings**. Defaults and limits:

| Setting | Default coins | Allowed range |
| --- | ---: | ---: |
| Registration bonus | 10 | 0–10000 |
| Follow / Like / Comment / Share | 1 each | 1–10000 |
| Each successful referral | 100 | 0–10000 |
| 5 / 10 / 15 referrals: extra milestone bonus | 100 / 200 / 300 | 0–10000 each |

Only active administrators can change settings, and each change is audited. Registration changes affect wallets initialized afterward. Each new campaign saves its reward; approval and cancellation use that saved amount. Existing campaigns retain a one-coin reward. Available task cards show the reward; the creation form shows the total reservation and rejects a stale displayed rate.

A referral is credited when a signed-in user successfully applies another account's valid referral code. The inviter must have initialized their wallet. Credit and notifications commit in the same transaction. Self-referrals and duplicate codes for a joined user are rejected. At invite 5, 10 and 15, the current extra milestone amount is added to that invite's reward once. A zero setting disables that credit. Historical referrals receive no backfill; previously achieved milestones are recorded as consumed without payout. A zero-valued milestone is also consumed when reached. Deleting a referred account cannot earn the same milestone again. These are account referrals; they do not prove an Instagram follow or prevent someone registering multiple email accounts.

### Email OTP configuration and PIN recovery

1. In Supabase Authentication, keep **Email** authentication enabled. Configure SMTP/email sending and provider rate limits for production. This app uses email accounts; phone OTP is not an app login flow.
2. In **Authentication → Email Templates → Magic Link**, use the `{{ .Token }}` variable to display the six-digit login OTP instead of requiring a link. For example: `<p>Your Growth Circle verification code is: {{ .Token }}</p>`. The existing signup confirmation template is separate. See [Supabase email OTP setup](https://supabase.com/docs/guides/auth/auth-email-passwordless#with-email-otp).
3. In Profile, choose **Coin release PIN → Set up** or **Change / reset PIN**. Send the OTP to the signed-in email, enter that code, then enter and confirm the new four-digit PIN. The app permits resend after 60 seconds; Supabase may impose a longer sending limit.
4. OTP verification uses a separate short-lived client so the main password session is preserved. The server requires a signed Auth JWT with a recent `otp` authentication event (within five minutes of verification), and consumes that event once across token refreshes. Password-only, stale and reused proof cannot change a PIN. The old `p_current_pin` RPC parameter is retained for compatibility but is no longer authorization. See [Supabase JWT authentication methods](https://supabase.com/docs/guides/auth/jwt-fields#authentication-methods-amrmethod).
5. A successful email-verified reset clears PIN lockout. Releasing coins still requires the PIN and retains the five-failure, 15-minute lock. Verify email delivery, first setup, forgotten-PIN recovery and approval on your live project before distributing builds.

Local verification uses Flutter tests plus `python3 supabase/tests/economy_integration.py DATABASE_NAME` after `bootstrap.sql` and all migrations in an isolated PostgreSQL database. The test bootstrap's `auth.jwt()` is a privileged mock; **never install that bootstrap in Supabase**. Notification/action/admin inspection tests also accept explicit mock OTP claims for setup. Existing `profile_integration.py` documents/tests the earlier four-migration PIN contract and must use that earlier schema.

Live rollout is not performed by committing SQL or pushing GitHub. Apply only unapplied migrations in the correct project, configure email templates/SMTP, and verify actual email and Realtime delivery. No Edge Function or Meta credentials are required for these features. Instagram live search remains separate.

## Profile and release PIN upgrade

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107030000_profile_pin_referrals.sql` after the administrator migration. Distribute the updated app at the same time: older clients cannot review submissions after this upgrade. Owners must set a four-digit PIN in Profile before approving and releasing a coin. Five incorrect attempts lock the PIN for 15 minutes. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c009fa4e50f7f72b3f0068404f465c0032a57f65fbca343e81865be63df838e7 -->

After the economy/OTP upgrade below, both initial PIN setup and change/reset require a fresh email OTP instead of the current PIN. PIN release attempts retain the five-attempt lockout.

<!-- /coderabbit-ai-generated:v1 -->

Profile supports multiple Instagram usernames, a separate coin history page and referral codes. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:720f73b969649381e83927dd616b5bbf422f53a0e5b4cb7853aaddfb87af416a -->

A user can apply one other user's code once. The economy migration below enables configurable rewards for future referral events.

<!-- /coderabbit-ai-generated:v1 -->

## Coin model

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c64faf45931f12ec47d077d6d2401381342ff7988e233c74cb245f02e21f94de -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:edb3e906f6395dd43354cbb3a3b30fb96533f500b6227a5099e527c48b29fa98 -->

The default registration bonus is 10 coins once, and the default campaign reward is one coin per task. After the economy migration, administrators can change both. Campaigns reserve the configured reward multiplied by the requested task count.

<!-- /coderabbit-ai-generated:v1 --> A participant submits an Instagram username and a JPEG or PNG screenshot (maximum 512 KiB); the owner sees a pending submission, reviews the screenshot and approves or rejects it. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:04c6b5e61c4712e1f6c99ef7592762da032e646f0bf8ddc1006f9c76cef62ee8 -->

Approving pays the campaign's saved reward and consumes one reserved task. Later setting changes do not alter existing campaign payouts or refunds.

<!-- /coderabbit-ai-generated:v1 --> Rejecting or withdrawing reopens the slot. Cancellation refunds all unapproved slots, including pending submissions. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:fe5d94089b88fd5520ac3eac467b5dcf4d301cd218dd3803a58442b0e7928c07 -->

Campaign owners, the claimant and administrators can access pending evidence. Evidence is deleted on review, withdrawal or cancellation.

<!-- /coderabbit-ai-generated:v1 --> A submission identifier prevents approving a replacement using stale evidence. Row locks serialize submission, decisions and cancellation. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:23ba3e61e44ea6b383e78113db5aba087f9dd4a8226ec86c5c1503e9d774b855 -->

Legacy claims remain paid and are displayed as self-reported, not owner-approved.

<!-- /coderabbit-ai-generated:v1 --> Owner review and screenshots do not verify or guarantee real Instagram engagement and may be abused. Review Instagram policies before distribution.

<!-- /coderabbit-ai-generated:v1 -->


<!-- /coderabbit-ai-generated:v1 -->


<!-- /coderabbit-ai-generated:v1 -->