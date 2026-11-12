begin;
-- Authentication and MFA enrollment remain available; business APIs require MFA.
create or replace function growth_internal.require_admin() returns void
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if not exists(select 1 from public.admin_members where user_id=auth.uid()) then
  raise exception 'Administrator access required.' using errcode='P0001';
 end if;
 if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' or not exists(
  select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified'
 ) then
  raise exception 'Enroll and verify administrator MFA.' using errcode='P0001';
 end if;
end $$;
commit;
