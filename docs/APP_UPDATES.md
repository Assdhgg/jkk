<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0d439a1a97e3826a461444a4a06bd14d48eaa654b4c2ba7a8a91f58b6d1706a4 -->

# Android APK updates

## Implemented flow

Admin → **App releases** → choose a signed universal APK, enter its exact Android version code, version name and release notes, then publish. Editor access and the existing administrator MFA rules apply; viewers can only read releases. Uploads are limited to 200 MiB. Each publication must increase the version code. Published artifacts cannot be overwritten or removed through client credentials.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a927d2ebf32d56eb36c7ce26c8dc06006c6cdf831011e4e2142a7f1e88dcc957 -->

Publishing inserts an in-app notification for existing wallet accounts and queues push jobs for their registered devices. Updated Android builds use a mandatory popup above the Navigator: every signed-in page is inaccessible when a newer release exists. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d1cc36a9105b6b46fd1f6c17c9b7834d38222be54bf8f54592d066819dc3e15f -->

Initial/resume checks, Realtime release changes and one-minute polling run silently in the background. Initial loading, network errors and unknown release state allow app use, including offline restarts. Only a confirmed newer release displays the mandatory popup. This intentionally replaces the earlier rule that blocked access while checking or on errors.

<!-- /coderabbit-ai-generated:v1 --> A known newer release stays required if it disappears from the feed during the session. Opening or cancelling the installer does not unlock the app; its installed version must reach the required version. Push settings do not disable this gate. This replaces the optional Home banner; older builds must first be replaced manually and are not remotely forced by this UI change.

<!-- /coderabbit-ai-generated:v1 -->

**Update app** opens Android's installation permission settings if necessary. After allowing installation, tap **Update app** again. The app downloads over HTTPS into private cache, validates the exact size and SHA-256, then checks the APK package ID, increasing version code and signing identity against the installed app before opening the Android installer. The user confirms installation. Failed downloads can be retried. No automatic silent installation is attempted.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:81245e085e574a0856b92d7f9e0e902c108b6e14b3098c3e4f4a00418605eb3f -->

## Hosted deployment required

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ccc8e9dcd93472e4bfa0eb6b362e142afa110a1fd726eea40720b20f1a81aeb6 -->

1. Apply all migrations in order, including `20261109110000_app_updates.sql` and `20261111042338_r2_app_releases.sql`. The R2 migration version matches the migration applied to the linked project. Existing Supabase releases remain downloadable. The original publication RPC remains available for older admin builds.

<!-- /coderabbit-ai-generated:v1 -->
2. Create a Cloudflare R2 Standard bucket and an R2 API token restricted to that bucket with object read/write access. Enable a public custom domain for the bucket; use a stable HTTPS URL without a path, query or fragment. Configure a lifecycle rule to expire objects under `staging/` after one day; do not expire `releases/`. The bucket contains public APKs. Configure the domain and bucket so public writes are disabled. The free tier has usage limits and may require a billing setup; see [R2 pricing](https://developers.cloudflare.com/r2/pricing/).
3. Set Supabase Edge Function secrets `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and `R2_PUBLIC_BASE_URL` (for example `https://updates.example.com`) using `supabase secrets set --env-file <secure-file-outside-repository>`. The platform provides Supabase URL, anon key and service role key. Keep credentials outside clients, source control and chat. Deploy with `supabase functions deploy app-release-upload` and keep JWT verification enabled. The function authorizes each request through the existing editor/MFA rule, signs a bounded temporary upload, copies it to a separate release key, and publishes metadata. Restrict R2 credentials and dashboard access: direct edits to release objects bypass this protection.
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d5baef2f8240fdde7b5bdd8935299c20138560a0f903a61b390a5776ec418100 -->

4. Deploy this branch's `push-delivery` Edge Function with JWT verification enabled so push messages use the Freelan Space name. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:01664b4338f6f4a2ad24f660065ca2276f89a3f533da3d1da4f9d96a7461a002 -->

Review the Firebase project and Cron/Vault setup in `docs/USER_FEATURES.md`. The supplied new app config uses `freelan-space` while the older app used `growth-circle-c8efe`; check the worker credentials and delivery impact before changing its Firebase project. Do not create another worker schedule.

<!-- /coderabbit-ai-generated:v1 --> In Supabase Authentication → Email Templates, update the subjects and content of the existing Confirm signup, Magic Link and any other templates containing the old name. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:736b1dda3a0ca0d50fe20d23d4eac1bda3dae9943451f8c04699edb68667682b -->

Use `supabase/templates/reauthentication.html` in **Reauthentication** for PIN OTP; keep the required OTP token and recovery behavior intact.

<!-- /coderabbit-ai-generated:v1 --> Saved dashboard templates do not change when repository files change.

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:8d5e838da566c3d39295a75391caf952b00617ca033a925433aa1aeb86ee84df -->

5. Build and distribute the updated Windows admin app and the first `space.freelan.app` Android APK **before publishing an R2 release**. The new package cannot replace the old `com.growthcircle.growth_circle` installation: distribute this first APK manually and ask users to sign in again. Do not publish this APK as an update for the old package; its installer correctly rejects a different package ID. Supabase accounts and server data are retained. Subsequent releases for the new app must keep `space.freelan.app` and the same production signing key.

<!-- /coderabbit-ai-generated:v1 -->

Admin chooses and publishes the APK as before. R2 uploads are limited to 200 MiB by this app. If the publication response is lost, refresh release history before retrying. Failed uploads and failed publication can leave objects in R2; staging lifecycle cleans temporary objects. Release objects may also be orphaned after a failed or uncertain publication: reconcile with `app_releases` before removing any object, and never delete a published release. Downloads validate size, SHA-256, package, version and signer as before. Hosted deployment and a real-device update must be verified separately.



<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1958843adfac4a381b88cd3a5d6086b9facbbf60ca47d6a068b92c666c4c67f9 -->

<!-- /coderabbit-ai-generated:v1 -->

## Build each production APK

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:001d3a42a2464e0a83c528db000318f726879e135742d16d96af536aa54172bf -->

Use application ID `space.freelan.app` and retain its production signing keystore for every future update. Download the matching Firebase Android configuration to `android/app/google-services.json` from the existing Firebase project; editing the package name in the old JSON does not register a new Firebase app. Follow the release-signing setup in `README.md`; signing credentials remain outside source control. Build a universal APK with a build number higher than all published releases (the release history is shared), for example:

<!-- /coderabbit-ai-generated:v1 -->

```bash
flutter build apk --release <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:bd28351a3482c73a77d305dc13ffa549c85dd0ad0d2c9359db95f11577fedc3f -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9ed86de708e74d3bc1d20446692ea881ff78f8fa7d26bd834d5cfbfee469a982 -->

--build-name=1.1.5 --build-number=13

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 --> \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:eaee7c1909f5a0718c77b0f43d2ad4d1ea14df545de7d5f2bc970fa9d623f7bb -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:e940d0205ae138b1ed6fd15d053a3c4e78189a2b00e10d91c0123d177682b618 -->

The example build 13 supersedes the previous code-12 build;

<!-- /coderabbit-ai-generated:v1 --> always check installed and published versions before building.

<!-- /coderabbit-ai-generated:v1 --> Upload `build/app/outputs/flutter-apk/app-release.apk` and enter the APK's matching version code/name. Do not upload an app bundle or an APK signed with another key. Flutter split-per-ABI APKs can have adjusted version codes; use the universal APK for this flow. Never distribute a debug artifact as the production update.

## Verify before distributing

Install an older production-signed APK containing the updater on a real Android device. Enable notifications in Settings, publish a newer APK signed with the same key, and <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:04af70e6e9d412f5666c6012a8d2fd2cf1ba441431e2af919cd16ba6ab69872f -->

confirm the notification, mandatory update popup over every page and Settings update page.

<!-- /coderabbit-ai-generated:v1 --> Exercise installation permission, successful installation, version detection after reopening, an interrupted download, and rejection of an APK with a different package/signing key. Confirm push-off suppresses device delivery <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:5c3c3f1c82cfc402a2efd5b15ba25947ee417cf29fd312be32dfb294122e32c9 -->

while the mandatory update popup remains active.

<!-- /coderabbit-ai-generated:v1 --> Verify the Windows administrator can choose and publish an APK and a viewer cannot publish.

Local Flutter, SQL and worker tests cover release selection, retry/permission UI, publication permissions, immutable artifacts, notifications and queue creation. A debug Android compilation checks the native integration. Actual device installation and hosted delivery remain separate acceptance checks.


<!-- /coderabbit-ai-generated:v1 -->