<!-- coderabbit-ai-generated:v1 -->

# User identifiers, settings and PIN email deployment

## Hosted Supabase changes required

1. Apply `supabase/migrations/20261109100000_public_user_identifiers.sql` after all existing migrations. Existing users receive a unique eight-digit public User ID; authentication continues using the existing UUID. Referral codes become four capital letters followed by three digits, for example `ABCD123`. Existing codes remain accepted privately as aliases, so previously shared codes continue working. Existing referral relationships and rewards remain intact. Unique constraints and non-cycling sequences prevent duplicate allocation, including concurrent requests; exhausted ranges fail rather than reuse identifiers.
2. In Supabase Dashboard → Authentication → Email Templates → **Magic Link**, replace the body with `supabase/templates/magic_link.html` and set the subject to **Growth Circle verification code**. Save the template. This is the template used by `signInWithOtp` for an existing email account. Changing Confirm signup alone does not fix PIN emails.
3. Under Authentication email settings, set OTP length to **6** and verify SMTP delivery. The template displays `{{ .Token }}` and contains no sign-in link. Keep the password recovery template intact.
4. Build and install the updated app. Profile shows the new User ID. Open the gear → Settings for push notification enable/disable and language selection.

The client cannot select email OTP versus a magic link through a request flag: Supabase email template configuration determines the email content. The existing isolated OTP verification session and server PIN proof checks are preserved. No hosted settings or migrations were deployed from this workspace.

## Verify after deployment

Send a PIN OTP from a real signed-in account. Confirm the email contains six digits and enter those digits in the app; set the PIN and verify the main password session remains signed in. Confirm another account cannot use that code. Check notification delivery before and after switching push off on an Android device with Firebase configured. Local widget/SQL checks do not establish actual email or FCM delivery.

Reference: [Supabase email OTP documentation](https://supabase.com/docs/guides/auth/auth-email-passwordless#with-email-otp).
