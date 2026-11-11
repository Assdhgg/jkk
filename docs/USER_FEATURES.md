<!-- coderabbit-ai-generated:v1 -->

# User app features and Android push setup

Apply `20261107130000_user_experience.sql` after all earlier migrations before distributing the updated user app. The migration backfills the currently retained submission for each claim; attempts overwritten before this migration cannot be recovered. New attempts retain their own review status and optional rejection reason. Saved tasks do not reserve a campaign slot. Campaign status counts describe the current submissions, not the complete historical count. Submission history date filters use UTC days.

The app still displays in-app notifications without Firebase. Android push requires all of the following on the same Firebase and Supabase projects:

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dc06e6a6769c1328898ef6387a68cc8c8f524a0098444d99b8a4dc382b7b5743 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:59befc06a50f5b63fd38685a51b941b750861606d5e242f87ef980e4c0d8fb08 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:e7b1c60584c05ac897ce00feb7a52be5130eaefb8017769e42543867ec96f81c -->

1. The supplied `android/app/google-services.json` registers package `space.freelan.app` in Firebase project `freelan-space`. The old Android app used Firebase project `growth-circle-c8efe`. Before releasing, verify that the push worker's `FCM_PROJECT_ID` and service account match the Firebase project used by the APK. The worker sends to one Firebase project, so switching it to `freelan-space` can stop push delivery to devices registered under the old project. To retain the existing project instead, register `space.freelan.app` in `growth-circle-c8efe` and replace this file with the downloaded matching configuration. Do not edit the package field of an old file: each app needs its registered Firebase app ID. Enable Cloud Messaging and use an authorized service account in the chosen project. Users enable notifications again after signing into the new Android installation.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
2. Build the user app with the normal Supabase defines from the main README. Firebase initializes from the Android configuration file; explicit Firebase Dart defines are optional and must match the same project if provided. Do not put service-account credentials or Supabase service-role keys in the app. Users must choose **Enable push notifications** in Profile and grant Android notification permission. Push is Android only.

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b5838b1034e2702fa96a10d1587e54b62406449bce9abcf3502d0c16c814b194 -->

3. Deploy `supabase/functions/push-delivery` to the same Supabase project, with JWT verification enabled. Provide Edge Function secrets `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and `FCM_PRIVATE_KEY` from a service account authorized to send Firebase Cloud Messaging messages, plus a random `PUSH_WORKER_SECRET` for the scheduler. The platform supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. Use the Supabase secret manager or an environment file stored outside the repository; never commit or share those credentials.
4. Enable Supabase Cron, pg_net and Vault, then create Vault entries `push_delivery_url` (the deployed function URL), `push_anon_jwt` (the project's legacy anon JWT), and `push_worker_secret` (the same random value as `PUSH_WORKER_SECRET`). Schedule a POST as a database administrator:

<!-- /coderabbit-ai-generated:v1 -->

```sql
select cron.schedule('growth-circle-push-delivery', '* * * * *', $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'push_delivery_url' limit 1),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dffd8c967128170ad4d6cf15fa9c6ef045bf5706125845d28e02971cef79472a -->

      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'push_anon_jwt' limit 1),
      'X-Push-Worker-Secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_worker_secret' limit 1)

<!-- /coderabbit-ai-generated:v1 -->
    ),
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3a10b7a8ae98468a80f889c05207f70228ccc3980fd121fa998ad2a6da5a90e9 -->

    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );

<!-- /coderabbit-ai-generated:v1 -->
$job$);
```

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:98d5656587de622f69f1cf4f11e5ce9c9c68dac8bcb98e7c28af326291426576 -->

The function accepts the worker secret or a service-role Bearer token after gateway JWT verification. Keep Vault access limited to administrators. pg_net temporarily stores request headers where database login roles can read them, so the scheduler uses a dedicated worker secret instead of a service-role key. Rotate it in both Vault and Edge Function secrets if database access changes.

<!-- /coderabbit-ai-generated:v1 --> Each invocation leases up to 10 queued messages; retries use backoff and stop after eight unsuccessful attempts. A worker interruption can cause duplicate delivery after its lease expires. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0ca5c52a32c0235d01425f8f0ac0d2e9871f2d6a0b46358b7ea9f311ef8e80fc -->

Event notification content remains generic. Administrator-authored notifications display the supplied title and message, including on the device lock screen; see `docs/ADMIN_NOTIFICATIONS.md`.

<!-- /coderabbit-ai-generated:v1 --> Registrations belong to the signed-in account and are removed on sign-out when the server is reachable; a device registration is reassigned on the next successful sign-in. Push only covers events created after a device is registered. Check function logs and Cron/pg_net results, then test permission, sign-out and all four notification types on an actual Android device before distribution. Firebase, the worker, its schedule, and the migration require separate deployment; committing files does not activate them.

For isolated local verification, apply all migrations to a disposable PostgreSQL database using the test bootstrap and run `python3 supabase/tests/user_experience_integration.py DATABASE_NAME`, `node --test supabase/functions/push-delivery/handler.test.mjs`, `flutter analyze` and `flutter test`. Provider delivery and Android background behavior require the configured Firebase project and a physical device or suitable emulator.
