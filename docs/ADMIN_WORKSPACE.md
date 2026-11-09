<!-- coderabbit-ai-generated:v1 -->

# Administrator workspace

Apply `supabase/migrations/20261107110000_admin_workspace.sql` after all earlier migrations, then distribute the updated administrator app. The migration does not apply itself when code is published. The workspace loads current counts, recent user history, activity, daily UTC reports and review signals from administrator-only RPCs. Submission approval remains with the campaign owner.

## Roles

Existing administrators become `editor`, preserving their existing access. Editors can change account access, action controls and coin settings. `viewer` administrators can see account, campaign, referral, coin and audit data and inspect pending evidence, but cannot change those controls. Both roles are checked on the server, including for older clients. Inspection still creates a presence session and audit entry. A viewer has access to sensitive user information; assign this role only to trusted staff.

Only the project owner can provision administrators or change roles. In the Supabase SQL Editor, after creating and confirming the account, use its email:

```sql
insert into public.admin_members (user_id, role)
select id, 'viewer' from auth.users
where lower(email) = lower('ADMIN_EMAIL_HERE') and email_confirmed_at is not null
on conflict (user_id) do update set role = excluded.role;
```

Use `editor` instead of `viewer` to grant control changes. Role changes affect subsequent requests; an already running request can finish. No role management credentials or service-role key are placed in the application.

## Data and reports

User detail sections show the latest 100 campaigns, submissions and ledger entries each. The activity log combines existing access, action, coin setting and submission inspection audit records; it does not backfill events that were never recorded. Reports contain daily registration counts, campaign creation counts, transaction counts, and positive and negative coin totals, grouped by UTC date. Select at most 366 days, then use Export CSV to save the displayed aggregates. This export uses the system save dialog on Windows.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:32ac374c4001ac829b7f7c9cc35f95fe0f440dc440fd73bed04a5e4fb7ecb2f8 -->

Alerts show up to 100 signals: pending submissions older than 24 hours by campaign, at least 1,000 coins credited to an account in the previous 24 hours, and at least five referrals by an account in the previous 24 hours. After applying `20261107120000_admin_operations.sql`, editors can configure these thresholds. These are signals, not evidence of abuse. Review them before taking action. See [Admin operations](ADMIN_OPERATIONS.md) for notification and configuration details.

<!-- /coderabbit-ai-generated:v1 -->

## Verification

Run `flutter analyze`, `flutter test`, and `python3 supabase/tests/admin_workspace_integration.py DATABASE_NAME` against a disposable PostgreSQL database prepared with `supabase/tests/bootstrap.sql` and all migrations. The bootstrap mocks Supabase authentication and must never be applied to a real project. Test a Windows release build and real Supabase deployment separately.
