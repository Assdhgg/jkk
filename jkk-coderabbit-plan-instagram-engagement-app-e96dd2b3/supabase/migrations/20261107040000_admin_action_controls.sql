-- Administrators can pause new campaigns and submissions by action type.
begin;
create table public.action_controls (
  action_type text primary key check (action_type in ('follow','like','share','comment')),
  enabled boolean not null default true
);
insert into public.action_controls(action_type) values ('follow'),('like'),('share'),('comment');
alter table public.action_controls enable row level security;
revoke all on public.action_controls from public, anon, authenticated;
grant select on public.action_controls to authenticated;
create policy action_controls_read on public.action_controls for select to authenticated using (public.account_access_allowed());

create table growth_internal.action_control_audit (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action_type text not null,
  enabled boolean not null,
  created_at timestamptz not null default now()
);
revoke all on growth_internal.action_control_audit from public, anon, authenticated;

create function growth_internal.require_action_enabled(p_type text) returns void
language plpgsql security definer set search_path='' as $$
declare allowed boolean;
begin
  -- The shared lock ensures a disable waits for already-running operations.
  select enabled into allowed from public.action_controls where action_type=p_type for share;
  if allowed is distinct from true then
    raise exception 'This action is disabled by an administrator.' using errcode='P0001';
  end if;
end $$;
revoke all on function growth_internal.require_action_enabled(text) from public, anon, authenticated;

create or replace function public.create_campaign(p_type text,p_link text,p_count integer) returns uuid
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  perform growth_internal.require_action_enabled(p_type);
  return growth_internal.create_campaign(p_type,p_link,p_count);
end $$;
create or replace function public.submit_claim(p_campaign_id uuid,p_instagram_handle text,p_mime text,p_evidence text) returns void
language plpgsql security definer set search_path='' as $$
declare action_type text;
begin
  perform growth_internal.require_active();
  select c.type into action_type from public.campaigns c where c.id=p_campaign_id;
  if not found then raise exception 'Campaign not found.' using errcode='P0001'; end if;
  perform growth_internal.require_action_enabled(action_type);
  perform growth_internal.submit_claim(p_campaign_id,p_instagram_handle,p_mime,p_evidence);
end $$;

create function public.admin_set_action_enabled(p_type text,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
declare previous boolean;
begin
  perform growth_internal.require_admin();
  if p_type is null or p_type not in ('follow','like','share','comment') or p_enabled is null then
    raise exception 'Invalid action control.' using errcode='P0001';
  end if;
  select enabled into previous from public.action_controls where action_type=p_type for update;
  if not found then raise exception 'Action not found.' using errcode='P0001'; end if;
  if previous=p_enabled then return; end if;
  update public.action_controls set enabled=p_enabled where action_type=p_type;
  insert into growth_internal.action_control_audit(actor_id,action_type,enabled) values(auth.uid(),p_type,p_enabled);
end $$;
revoke all on function public.admin_set_action_enabled(text,boolean) from public, anon;
grant execute on function public.admin_set_action_enabled(text,boolean) to authenticated;
do $$ begin
  if exists (select 1 from pg_publication where pubname='supabase_realtime' and not puballtables) and not exists
    (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='action_controls') then
    alter publication supabase_realtime add table public.action_controls;
  end if;
end $$;
commit;
