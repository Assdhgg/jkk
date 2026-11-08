-- Administrators may inspect pending submissions. Only the owner can decide.
begin;
create table public.admin_review_presence (
  session_id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null,
  user_id uuid not null,
  submission_id uuid not null,
  expires_at timestamptz not null,
  foreign key (campaign_id,user_id) references public.campaign_claims(campaign_id,user_id) on delete cascade
);
alter table public.admin_review_presence enable row level security;
revoke all on public.admin_review_presence from public, anon, authenticated;
grant select on public.admin_review_presence to authenticated;
create policy admin_review_presence_read on public.admin_review_presence for select to authenticated using (
  public.account_access_allowed() and (user_id=auth.uid() or exists
    (select 1 from public.campaigns c where c.id=campaign_id and c."ownerId"=auth.uid()))
);
create table growth_internal.admin_review_sessions (
  session_id uuid primary key references public.admin_review_presence(session_id) on delete cascade,
  admin_id uuid not null references auth.users(id) on delete cascade
);
create table growth_internal.admin_review_audit (
  id bigint generated always as identity primary key,
  admin_id uuid references auth.users(id) on delete set null,
  campaign_id uuid,
  user_id uuid,
  submission_id uuid,
  started_at timestamptz not null default now()
);
revoke all on growth_internal.admin_review_sessions, growth_internal.admin_review_audit from public, anon, authenticated;

create function public.admin_pending_submissions(p_offset integer default 0, p_limit integer default 30)
returns table(campaign_id uuid,user_id uuid,submission_id uuid,action_type text,campaign_link text,submitted_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if p_offset is null or p_offset < 0 or p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'Invalid page.' using errcode='P0001';
  end if;
  return query select cl.campaign_id,cl.user_id,cl.submission_id,c.type,c.link,cl.created_at
    from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id
    where cl.status='pending' and c.status='active'
    order by cl.created_at,cl.campaign_id,cl.user_id limit p_limit offset p_offset;
end $$;
create function public.admin_begin_submission_review(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cl public.campaign_claims%rowtype; result jsonb; session uuid;
begin
  perform growth_internal.require_admin();
  select * into cl from public.campaign_claims where campaign_id=p_campaign_id and user_id=p_user_id for update;
  if not found or cl.status <> 'pending' or cl.submission_id is distinct from p_submission_id then
    raise exception 'This submission is no longer pending.' using errcode='P0001';
  end if;
  select jsonb_build_object('username',cl.instagram_handle,'mime',e.mime_type,'data',e.data_base64) into result
    from public.claim_evidence e join public.campaigns c on c.id=e.campaign_id
    where e.campaign_id=p_campaign_id and e.user_id=p_user_id and c.status='active';
  if result is null then raise exception 'Evidence is unavailable.' using errcode='P0001'; end if;
  delete from public.admin_review_presence where expires_at <= now();
  insert into public.admin_review_presence(campaign_id,user_id,submission_id,expires_at)
    values(p_campaign_id,p_user_id,p_submission_id,now()+interval '2 minutes') returning session_id into session;
  insert into growth_internal.admin_review_sessions(session_id,admin_id) values(session,auth.uid());
  insert into growth_internal.admin_review_audit(admin_id,campaign_id,user_id,submission_id)
    values(auth.uid(),p_campaign_id,p_user_id,p_submission_id);
  return result || jsonb_build_object('session_id',session);
end $$;
create function public.admin_renew_submission_review(p_session_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  update public.admin_review_presence p set expires_at=now()+interval '2 minutes'
    where p.session_id=p_session_id and p.expires_at>now()
      and exists(select 1 from growth_internal.admin_review_sessions s where s.session_id=p.session_id and s.admin_id=auth.uid())
      and exists(select 1 from public.campaign_claims cl where cl.campaign_id=p.campaign_id and cl.user_id=p.user_id and cl.submission_id=p.submission_id and cl.status='pending');
  return found;
end $$;
create function public.admin_end_submission_review(p_session_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  -- UPDATE reaches filtered realtime subscribers; DELETE can contain only a primary key.
  update public.admin_review_presence p set expires_at=now() where p.session_id=p_session_id and exists
    (select 1 from growth_internal.admin_review_sessions s where s.session_id=p.session_id and s.admin_id=auth.uid());
  delete from growth_internal.admin_review_sessions where session_id=p_session_id and admin_id=auth.uid();
end $$;
revoke all on function public.admin_pending_submissions(integer,integer),public.admin_begin_submission_review(uuid,uuid,uuid),public.admin_renew_submission_review(uuid),public.admin_end_submission_review(uuid) from public,anon;
grant execute on function public.admin_pending_submissions(integer,integer),public.admin_begin_submission_review(uuid,uuid,uuid),public.admin_renew_submission_review(uuid),public.admin_end_submission_review(uuid) to authenticated;
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime' and not puballtables) and not exists
    (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='admin_review_presence') then
    alter publication supabase_realtime add table public.admin_review_presence;
  end if;
end $$;
commit;
