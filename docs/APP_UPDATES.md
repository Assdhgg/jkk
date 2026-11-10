<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0d439a1a97e3826a461444a4a06bd14d48eaa654b4c2ba7a8a91f58b6d1706a4 -->

# Android APK updates

## Implemented flow

Admin → **App releases** → choose a signed universal APK, enter its exact Android version code, version name and release notes, then publish. Editor access and the existing administrator MFA rules apply; viewers can only read releases. Uploads are limited to 200 MiB. Each publication must increase the version code. Published artifacts cannot be overwritten or removed through client credentials.

Publishing inserts an in-app notification for existing wallet accounts and queues push jobs for their registered devices. The foreground Home banner and Settings → App updates compare the latest release with the installed Android version, including after returning to the app. Notification taps open the update page. Users who turn push off still see the in-app update offer.

**Update app** opens Android's installation permission settings if necessary. After allowing installation, tap **Update app** again. The app downloads over HTTPS into private cache, validates the exact size and SHA-256, then checks the APK package ID, increasing version code and signing identity against the installed app before opening the Android installer. The user confirms installation. Failed downloads can be retried. No automatic silent installation is attempted.

## Hosted deployment required

1. Apply all migrations in order, including the preceding identifiers migration and `supabase/migrations/20261109110000_app_updates.sql`. The update migration creates `app_releases`, the public `app-releases` Storage bucket, access rules, notification trigger and Realtime publication entry. Only APK files are public; release publication requires editor credentials.
2. Confirm the project's global Storage upload limit permits the APK size. The bucket limit is 200 MiB; a lower project or plan limit still takes precedence.
3. Deploy this branch's `push-delivery` Edge Function with JWT verification enabled. Reuse the Firebase service-account secrets, worker secret and Cron/Vault setup described in `docs/USER_FEATURES.md`. Use the same Supabase and Firebase projects as the installed app. Do not create a second duplicate worker schedule. The existing schedule processes queued jobs; background delivery is not activated by committing source files.
4. Build and distribute the updated Windows admin application and the first Android APK containing this updater. Existing installations without updater code need that first APK installed manually. Subsequent compatible releases can use the in-app flow.

Hosted SQL, Storage, function deployment and real FCM delivery were not performed from this workspace because authenticated Supabase management access is unavailable. Local checks do not establish that these hosted services are configured.

## Build each production APK

Keep the existing application ID `com.growthcircle.growth_circle` and the production signing keystore used by installed copies. Follow the release-signing setup in `README.md`; signing credentials remain outside source control. Build a universal APK with a strictly higher build number, for example:

```bash
flutter build apk --release --build-name=1.2.0 --build-number=8 \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

The example build 8 is suitable only when installed and published builds are lower. Upload `build/app/outputs/flutter-apk/app-release.apk` and enter the APK's matching version code/name. Do not upload an app bundle or an APK signed with another key. Flutter split-per-ABI APKs can have adjusted version codes; use the universal APK for this flow. Never distribute a debug artifact as the production update.

## Verify before distributing

Install an older production-signed APK containing the updater on a real Android device. Enable notifications in Settings, publish a newer APK signed with the same key, and confirm the notification, foreground banner and Settings update page. Exercise installation permission, successful installation, version detection after reopening, an interrupted download, and rejection of an APK with a different package/signing key. Confirm push-off suppresses device delivery while the foreground banner remains available. Verify the Windows administrator can choose and publish an APK and a viewer cannot publish.

Local Flutter, SQL and worker tests cover release selection, retry/permission UI, publication permissions, immutable artifacts, notifications and queue creation. A debug Android compilation checks the native integration. Actual device installation and hosted delivery remain separate acceptance checks.


<!-- /coderabbit-ai-generated:v1 -->