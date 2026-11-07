<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:6946cdf13410aac306f33f197d601c95805a81d1b45ef53e89c8d1e058c27cbc -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:839d4b92f805dbbd5ccc6ba2ae0b5f0ccd8ece1d43944e89c5b6bbc554843b15 -->

# Growth Circle

Flutter Android app using Supabase Auth and PostgreSQL for self-reported Instagram engagement campaigns. Claims are not verified Instagram actions. Instagram passwords are never collected.

## Supabase setup

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

The app shows a setup screen if values are missing. For a distributable release configure `android/key.properties` with `storeFile` (absolute path), `storePassword`, `keyAlias` and `keyPassword` for a securely retained release keystore. Keep the keystore and passwords private and backed up; future updates require the same signing key. Without this file the release is unsigned. The package name is `com.growthcircle.growth_circle`.

## Tests

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:58bf115b1cd3357bb53e5e0e96db454c86b715e5a78c3e28995f81aed7d1ae2f -->

Run `flutter analyze` and `flutter test`. PostgreSQL tests mock Supabase `auth.uid()` and must only be run against isolated disposable databases, never a real project. For the original contract use `supabase/tests/bootstrap.sql`, the original migration, then `python3 supabase/tests/integration.py DATABASE_NAME`. For owner review, use a separate fresh database with bootstrap and the original migration, then run `python3 supabase/tests/review_integration.py DATABASE_NAME`; this script applies the owner-review migration after creating historical claims. Tests require a PostgreSQL superuser and do not replace verification against Supabase Auth, Realtime or a real Android device.

<!-- /coderabbit-ai-generated:v1 -->

## Coin model

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c64faf45931f12ec47d077d6d2401381342ff7988e233c74cb245f02e21f94de -->

Accounts receive 10 coins once. Campaigns reserve one coin per requested task. A participant submits an Instagram username and a JPEG or PNG screenshot (maximum 512 KiB); the owner sees a pending submission, reviews the screenshot and approves or rejects it. Approving pays one coin and consumes one reserved task. Rejecting or withdrawing reopens the slot. Cancellation refunds all unapproved slots, including pending submissions. Only campaign owners and the claimant can access pending evidence, and evidence is deleted on review, withdrawal or cancellation. A submission identifier prevents approving a replacement using stale evidence. Row locks serialize submission, decisions and cancellation. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:23ba3e61e44ea6b383e78113db5aba087f9dd4a8226ec86c5c1503e9d774b855 -->

Legacy claims remain paid and are displayed as self-reported, not owner-approved.

<!-- /coderabbit-ai-generated:v1 --> Owner review and screenshots do not verify or guarantee real Instagram engagement and may be abused. Review Instagram policies before distribution.

<!-- /coderabbit-ai-generated:v1 -->


<!-- /coderabbit-ai-generated:v1 -->


<!-- /coderabbit-ai-generated:v1 -->