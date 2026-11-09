<!-- coderabbit-ai-generated:v1 -->

# User app features and Android push setup

Apply `20261107130000_user_experience.sql` after all earlier migrations before distributing the updated user app. The migration backfills the currently retained submission for each claim; attempts overwritten before this migration cannot be recovered. New attempts retain their own review status and optional rejection reason. Saved tasks do not reserve a campaign slot. Campaign status counts describe the current submissions, not the complete historical count. Submission history date filters use UTC days.

The app still displays in-app notifications without Firebase. Android push requires all of the following on the same Firebase and Supabase projects:

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dc06e6a6769c1328898ef6387a68cc8c8f524a0098444d99b8a4dc382b7b5743 -->

1. The Android package `com.growthcircle.growth_circle` uses the supplied Firebase public configuration in `android/app/google-services.json`. The Gradle plugin includes these resources so Firebase can initialize when Android starts the app for a notification. Configure the Firebase Cloud Messaging API for that project. For another Firebase project, replace this file with that project's matching Android app configuration.
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

<!-- /coderabbit-ai-generated:v1 --> Each invocation leases up to 10 queued messages; retries use backoff and stop after eight unsuccessful attempts. A worker interruption can cause duplicate delivery after its lease expires. Notification content is generic and excludes submission evidence, support messages and personal data. Registrations belong to the signed-in account and are removed on sign-out when the server is reachable; a device registration is reassigned on the next successful sign-in. Push only covers events created after a device is registered. Check function logs and Cron/pg_net results, then test permission, sign-out and all four notification types on an actual Android device before distribution. Firebase, the worker, its schedule, and the migration require separate deployment; committing files does not activate them.

For isolated local verification, apply all migrations to a disposable PostgreSQL database using the test bootstrap and run `python3 supabase/tests/user_experience_integration.py DATABASE_NAME`, `node --test supabase/functions/push-delivery/handler.test.mjs`, `flutter analyze` and `flutter test`. Provider delivery and Android background behavior require the configured Firebase project and a physical device or suitable emulator.
