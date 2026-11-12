<!-- coderabbit-ai-generated:v1 -->

# Administrator desktop controls

## Delivery channels

Send notification has separate In-app notification and Push notification checkboxes. Select either or both. Push only messages are excluded from the user's notification inbox through database RLS. Existing clients keep sending to both channels. Retrying the same request and delivery selection does not duplicate notifications.

## Saved sign-in and password recovery

After a successful administrator password sign-in and MFA challenge, Save login securely stores one login per project using flutter_secure_storage on the current Windows account. Click the email field on a later visit to fill the saved email/password. Passwords remain obscured until the visibility control is used. Forget saved login removes the protected entry. No passwords are stored in preferences.

In Supabase Dashboard → Authentication → Email Templates → Reset Password, set the recovery email body to the contents of supabase/templates/recovery.html. The template must include {{ .Token }} so the recipient receives the six-digit recovery OTP. Preserve configured SMTP, expiry and rate limits. This dashboard setting cannot be applied through the connected Supabase tools.

Forgot password uses an isolated recovery client: request email, verify the recovery OTP, then set a matching password of at least eight characters. It does not authorize the administrator console. After reset, the saved login is removed and password sign-in/MFA must be completed again. Test the recovery email with your SMTP configuration.

## Sessions

Use the Session settings clock button in the bottom right. Choose manual sign-out or 10/30/60 idle minutes, and whether minimizing signs out. Defaults preserve the former 10 minute timeout and sign-out on minimize. Preferences apply to this Windows account. Server session expiry, revoked access and MFA checks still apply. A transient access-check network error no longer logs out the UI; API operations continue to enforce server authorization.

## Users and wallets

Users displays separate name, email, public eight-digit user ID, join date, coins and role/status columns. Copy controls are available for name/email/public ID, including the compact layout.

Wallet controls opens the existing coin correction workflow. Enter the eight-digit public user ID, signed amount (positive credit/negative debit) and reason. A different editor must approve or reject the request; approval writes the wallet and ledger atomically and rejects negative resulting balances. Viewers cannot request or approve corrections. Review the user's balance and ledger under User details.

## Verification

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:71b8d04cf05628e144705b1bdda559edd23bec91d14e82af4789dc72f36a1c4d -->

All 25 repository migrations are applied to project `stpxbshwdiupigymakfy`, including mandatory administrator MFA. Disposable PostgreSQL tests cover channel isolation, legacy send compatibility, request idempotency, permissions, public ID lookup, wallet approval and balance protection. The preceding app validation passed all 111 Flutter tests, Flutter analysis and Android debug compilation; this deployment audit does not change Dart code. Windows secure storage, saved autofill, real email delivery and the desktop layout still require a Windows acceptance check. The recovery email template above cannot be inspected or updated through the connected tools; verify it in the Supabase Dashboard.

<!-- /coderabbit-ai-generated:v1 -->
