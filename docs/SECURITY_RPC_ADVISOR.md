<!-- coderabbit-ai-generated:v1 -->

# Security advisor: function warnings

Supabase advisor reports functions that run with owner privileges and can be called by authenticated users. Such a warning is a prompt to inspect the function; it does not establish that unauthorized access occurred.

Migration `20261113024952_reduce_definer_functions.sql` changes the legacy `claim_task` and `admin_send_notification` RPCs to invoker permissions. The first continues to reject legacy claims with the same update-required message. The second delegates to `admin_send_notification_v2`, which enforces editor access and MFA. The migration checks the known function bodies and delegate grants before applying. It was applied to Supabase project `stpxbshwdiupigymakfy`; apply it in order after earlier migrations on other projects.

The live advisor still reports 68 other authenticated security-definer functions. They include account checks, user data and coin operations, and administrator APIs. Many contain explicit active-user or admin checks and depend on privileged access; the warning list and simple guard scans are not a complete security audit. Review each implementation, its callers, role grants, RLS dependencies and tests before changing its execution context. Do not remove their permissions or hide warnings in bulk without verifying the original behavior and authorization rules.

The isolated PostgreSQL checks cover the legacy rejection and notification permissions and behavior with synthetic accounts; real admin sessions and notification delivery were not tested. See [Supabase advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
