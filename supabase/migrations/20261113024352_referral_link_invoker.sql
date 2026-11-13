begin;

-- Keep the privileged implementation outside the API-exposed public schema.
-- Its existing editor, MFA, URL validation and audit logic remain unchanged.
create schema referral_link_private;
revoke all on schema referral_link_private from public, anon, authenticated, service_role;
grant usage on schema referral_link_private to authenticated, service_role;

alter function public.admin_set_referral_download_link(text)
  set schema referral_link_private;
revoke all on function referral_link_private.admin_set_referral_download_link(text)
  from public, anon;
grant execute on function referral_link_private.admin_set_referral_download_link(text)
  to authenticated, service_role;

-- Preserve the existing public RPC signature and caller's identity.
create function public.admin_set_referral_download_link(p_url text) returns void
language sql security invoker set search_path = '' as $$
  select referral_link_private.admin_set_referral_download_link(p_url);
$$;
revoke all on function public.admin_set_referral_download_link(text) from public, anon;
grant execute on function public.admin_set_referral_download_link(text)
  to authenticated, service_role;

commit;
