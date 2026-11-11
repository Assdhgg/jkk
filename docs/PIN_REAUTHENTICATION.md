<!-- coderabbit-ai-generated:v1 -->

# PIN Reauthentication deployment

1. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ebb2814f96662eae763dc010d4b88af69884b54b83bfb0153b04ef1aa99e01c9 -->

Apply `supabase/migrations/20261111125040_pin_reauthentication.sql` after all preceding migrations.

<!-- /coderabbit-ai-generated:v1 --> It adds the authenticated `set_release_pin_reauthenticated(p_pin,p_nonce)` RPC and retires `set_release_pin` by returning `otp_required`. Old apps need updating for PIN setup/reset; existing PIN hashes and coin release lockout remain unchanged.
2. Supabase Dashboard → Authentication → Email Templates → **Reauthentication**: subject **Freelan Space PIN verification**, body from `supabase/templates/reauthentication.html`. Save. Keep `{{ .Token }}`, configure six-digit email OTP and working SMTP. Dashboard template changes are not deployed by committing this file or running SQL.
3. Distribute a production-signed Android APK with this change and the mandatory updater. Test initial PIN setup, reset, invalid/expired code, resend, replay, and coin release from a real confirmed email account. The primary password/session must remain unchanged.

The client sends authenticated `reauthenticate()`. Supabase has no standalone documented verification API for a PIN-specific use of this nonce; the custom security-definer RPC integrates with the Auth schema. It locks the current `auth.users` row, verifies SHA-224(email + nonce) against `reauthentication_token`, checks current verified email/no linked phone, requires issuance within five minutes, allows five incorrect attempts per issuance, and clears the nonce and only its `reauthentication_token` rows in `auth.one_time_tokens`. PIN change and nonce consumption commit together. Invalid attempts commit their counters. A successful reset clears existing PIN failures/lockout. It never changes the password or creates another login session.

This intentionally replaces the earlier Magic Link OTP-AMR proof contract. Password-only requests and old `set_release_pin` calls cannot set or reset a PIN. Provider resend/rate limits still apply. The SQL integration matches Supabase Auth v2.197.0 `internal/api/reauthenticate.go`, `internal/api/mail.go`, `internal/crypto/crypto.go` and `internal/models/user.go`; revalidate these schema/encoding assumptions on Auth upgrades. Do not run test bootstrap/nonce fixtures in a hosted project.

Local tests use synthetic nonce issuance, not actual email. The configured MCP cannot read or update hosted Auth email templates; a saved repository template is not proof of deployed email content. Real-device email delivery, production signing and native update installation are separate acceptance checks.

## Wallet

Home displays **Wallet** with **Check balance**. The amount is hidden until requested; **Hide balance** hides it again. The wallet stream remains the existing owner-scoped balance source, with loading, unavailable and error states. Both English and Malayalam support narrow screens and enlarged text.
