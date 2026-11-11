<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ec75219879f26337f605ba870813e39358337c434fe36499742cc07d7d8bcec8 -->

# Personal information

The Profile menu opens a page with the authenticated account name, email, eight-digit public User ID, joined date, and a profile photo. The ID can be copied. Photos are private to the account, limited to static JPEG/PNG up to 512 KiB and 4096 pixels per dimension, and removed with the account. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c4ebe1d4ebec612cd3ec34f5e1320285439b8279ac3826209d84283dab1203f9 -->

Apply `supabase/migrations/20261111111908_personal_information.sql` after preceding migrations before distributing the app. The version matches the migration applied to the linked Supabase project.

<!-- /coderabbit-ai-generated:v1 -->

## Email changes

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:5b92eca04be7a6c8a4d399be6525a8e5dcd7b21caab2c4a46c265a574d733dc2 -->

Email change is enabled by default after the project owner reported enabling Secure Email Change and the Change Email Address OTP template. Supabase Authentication must keep **Confirm email** and **Secure email change** enabled, with working SMTP and a six-digit `{{ .Token }}` in the **Change Email Address** template for both addresses. The configuration could not be independently read from this workspace; test actual delivery to both addresses before releasing. If these settings are unverified or disabled in any project, build with `--dart-define=SECURE_EMAIL_CHANGE_ENABLED=false` to disable the app feature. Keep the password recovery and PIN OTP templates intact. Never include service-role keys in the app.

<!-- /coderabbit-ai-generated:v1 -->

The app requests a change, asks for the current email code, then asks for the new email code; the current session is replaced only after the new session is verified as belonging to the same user. Supabase sends both messages when the request is made. Secure Email Change must remain enabled on the server: it requires both confirmations, even if an attacker bypasses the app. Supabase Auth accepts its two confirmations in either order when used outside this app; the old-first order is enforced by this app's UI, not by Supabase Auth itself. Do not claim that reverse ordering is rejected by the server. Real hosted email delivery, expiry, failed codes, uniqueness conflicts, session refresh, and unchanged PIN behavior require device testing before release.

## Name editing

Personal information offers Edit name for adding or changing full_name. The app trims whitespace and accepts 1–80 characters. Save uses the authenticated Supabase updateUser metadata API; it does not change email, password or account UUID. Failed saves retain the displayed name and can be retried. Auth user-update events refresh the profile. The Wallet button is a circular check icon with a localized Check balance/Hide balance tooltip and an accessible touch target.


<!-- /coderabbit-ai-generated:v1 -->