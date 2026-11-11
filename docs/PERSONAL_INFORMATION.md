<!-- coderabbit-ai-generated:v1 -->

# Personal information

The Profile menu opens a page with the authenticated account name, email, eight-digit public User ID, joined date, and a profile photo. The ID can be copied. Photos are private to the account, limited to static JPEG/PNG up to 512 KiB and 4096 pixels per dimension, and removed with the account. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c4ebe1d4ebec612cd3ec34f5e1320285439b8279ac3826209d84283dab1203f9 -->

Apply `supabase/migrations/20261111111908_personal_information.sql` after preceding migrations before distributing the app. The version matches the migration applied to the linked Supabase project.

<!-- /coderabbit-ai-generated:v1 -->

## Email changes

Email change is disabled in builds by default. Before enabling it, in Supabase Authentication verify that **Confirm email** and **Secure email change** are enabled, SMTP works, and the **Change Email Address** template sends a six-digit `{{ .Token }}` to each address. Confirm these settings on the intended project and test delivery to both addresses. Do not change the password recovery or PIN OTP templates. Build only after those checks, adding `--dart-define=SECURE_EMAIL_CHANGE_ENABLED=true` alongside the normal public Supabase defines. Never include service-role keys in the app.

The app requests a change, asks for the current email code, then asks for the new email code; the current session is replaced only after the new session is verified as belonging to the same user. Supabase sends both messages when the request is made. Secure Email Change must remain enabled on the server: it requires both confirmations, even if an attacker bypasses the app. Supabase Auth accepts its two confirmations in either order when used outside this app; the old-first order is enforced by this app's UI, not by Supabase Auth itself. Do not claim that reverse ordering is rejected by the server. Real hosted email delivery, expiry, failed codes, uniqueness conflicts, session refresh, and unchanged PIN behavior require device testing before release.
