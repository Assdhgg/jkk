<!-- coderabbit-ai-generated:v1 -->

# Admin operations

Apply `supabase/migrations/20261107120000_admin_operations.sql` after all earlier migrations and distribute the updated user and admin applications. The SQL migration is separate from pushing the repository. The existing workspace migration through `20261107110000` is required.

## Support and reports

Members can create support tickets, view replies and report an active campaign from the task list. Administrators see tickets and reports under **Workspace → Admin operations**. Editors can reply or close tickets and dismiss reports. An editor may cancel a reported active campaign: its pending submissions are cancelled, evidence is removed and the owner's unused reserved coins are refunded using the campaign's saved rate. The campaign owner still makes submission approval decisions. These administrator actions are recorded in the activity log. Both ticket and report lists show the latest 100 records.

## Notifications, alerts and analytics

The admin notifications button checks for unread ticket, report and coin-request events and current threshold signals when opened and every 60 seconds while the dashboard is visible. Marking an event read affects only the current administrator. These are in-app notifications, not device push. The latest 100 events are shown. Editors can change the pending hours, coins credited in 24 hours and referral count in 24 hours under Alert settings. Signals require human review and are not proof of abuse. Analytics displays daily registrations, campaign creations and credited coins for the latest 30 UTC days.

## Coin corrections and notes

An editor can request a nonzero correction between -10,000 and 10,000 coins with a reason. A different editor must approve or reject it. Approval locks the request and wallet, verifies that the resulting balance is valid, and writes the wallet and ledger in one transaction. Requests, decisions and reasons remain in the administrator records. Two active editor accounts are needed; the project owner provisions them. Admin notes are limited to administrators and reference a user or campaign ID. Notes, report decisions, ticket actions, threshold changes and coin requests/decisions are also recorded in the activity log.

## Administrator MFA and sessions

Admin operations supports authenticator-app enrollment and signing out other sessions. Once a verified factor exists, admin RPCs require an `aal2` session; users must enter a factor code at admin sign-in. Older administrator clients cannot complete this challenge, so update the administrator app before enrolling MFA. Supabase MFA must be enabled for the project and authenticator enrollment and recovery should be tested with the real provider before relying on it. The app does not log or store the displayed TOTP enrollment secret. Accounts without a verified factor continue using password sign-in until enrolled.

## Local verification

Run `flutter analyze` and `flutter test`. Run `python3 supabase/tests/admin_operations_integration.py DATABASE_NAME` only against a disposable database with the test bootstrap and every migration, including a test-only mock of `auth.mfa_factors`. Never install test bootstrap objects in Supabase. The tests cover authorization, two-editor approval, concurrent adjustment, wallet/ledger consistency, support isolation, refunds and AAL enforcement; they do not replace live Supabase Auth, SMTP, or Windows release verification.
