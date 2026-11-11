<!-- coderabbit-ai-generated:v1 -->

# User identifiers, settings and PIN email deployment

## Hosted Supabase changes required

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:94a73703ccd2e5ad272f8dce78860750a641932110757a1adcf629b43ff39be9 -->

1. Apply migrations in order, including the latest `random_identifiers_fast_push` migration. Public User IDs are random unique eight-digit numbers; referral codes are four random capital letters followed by three random digits. PostgreSQL pgcrypto generates unbiased random samples and a private permanent reservation table prevents collisions and reuse, including after account deletion. Existing public IDs and referral codes are rotated once by this migration. Predictable old four-letter/three-digit codes are retired, including legacy aliases: users must share their new code. Earlier random UUID referral aliases remain accepted. Authentication UUIDs, accounts, existing referral relationships and earned balances remain unchanged. This intentionally replaces the earlier sequential generation and sequential-alias compatibility contract. Display identifiers are not credentials.

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:55706cd856c592372947677e9688059d6f53918d40d4d9f2c28d0c23eea647a1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c05ff491a7136aae88d974f691982ec2ff673be0983e619fbf06052f7a51880f -->

2. In Supabase Dashboard → Authentication → Email Templates → **Reauthentication**, replace the body with `supabase/templates/reauthentication.html` and set the subject to **Freelan Space PIN verification**. Save it. Updated PIN setup/reset uses `reauthenticate()`; Magic Link and Confirm signup are separate. Apply the latest PIN reauthentication migration and distribute the updated app. See [current PIN flow](PIN_REAUTHENTICATION.md).

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
3. Under Authentication email settings, set OTP length to **6** and verify SMTP delivery. The template displays `{{ .Token }}` and contains no sign-in link. Keep the password recovery template intact.
4. Build and install the updated app. Profile shows the new User ID. Open the gear → Settings for push notification enable/disable and language selection.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:e2f468f4f3a505b7d75d1b5e6f66565e3e536e5c330a86320c096e97bb916549 -->

The current client explicitly requests Reauthentication. Its server RPC consumes the email nonce with a five-minute lifetime and five-attempt limit; the former Magic Link proof endpoint is retired. Dashboard template changes are separate from code and migration deployment. Actual email delivery and device acceptance must be checked on the hosted project.

<!-- /coderabbit-ai-generated:v1 -->

## Verify after deployment

Send a PIN OTP from a real signed-in account. Confirm the email contains six digits and enter those digits in the app; set the PIN and verify the main password session remains signed in. Confirm another account cannot use that code. Check notification delivery before and after switching push off on an Android device with Firebase configured. Local widget/SQL checks do not establish actual email or FCM delivery.

Reference: [Supabase email OTP documentation](https://supabase.com/docs/guides/auth/auth-email-passwordless#with-email-otp).
