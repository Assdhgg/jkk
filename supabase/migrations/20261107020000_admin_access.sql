-- Administrators are provisioned by the project owner through SQL, never by a client.
begin;
create schema growth_internal;
revoke all on schema growth_internal from public, anon, authenticated;

create table public.admin_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.user_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  blocked boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);
create table public.admin_access_audit (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  target_id uuid references auth.users(id) on delete set null,
  blocked boolean not null,
  created_at timestamptz not null default now()
);
alter table public.admin_members enable row level security;
alter table public.user_access enable row level security;
alter table public.admin_access_audit enable row level security;
revoke all on public.admin_members, public.user_access, public.admin_access_audit from public, anon, authenticated;
revoke all on sequence public.admin_access_audit_id_seq from public, anon, authenticated;

create function public.account_access_allowed() returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and not exists
    (select 1 from public.user_access where user_id=auth.uid() and blocked);
$$;
revoke all on function public.account_access_allowed() from public, anon;
grant execute on function public.account_access_allowed() to authenticated;

-- Serialize blocking and mutating operations for a user. A request already in
-- progress can finish before the block commits; subsequent operations fail.
create function growth_internal.require_active() returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Please sign in.' using errcode='P0001'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 314159));
  if not public.account_access_allowed() then raise exception 'Account access is blocked.' using errcode='P0001'; end if;
end $$;
create function growth_internal.require_admin() returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  if not exists(select 1 from public.admin_members where user_id=auth.uid()) then
    raise exception 'Administrator access required.' using errcode='P0001';
  end if;
end $$;
revoke all on function growth_internal.require_active(), growth_internal.require_admin() from public, anon, authenticated;

-- Existing coin/review implementations remain intact in an unexposed schema.
alter function public.initialize_wallet() set schema growth_internal;
alter function public.create_campaign(text,text,integer) set schema growth_internal;
alter function public.cancel_campaign(uuid) set schema growth_internal;
alter function public.submit_claim(uuid,text,text,text) set schema growth_internal;
alter function public.get_claim_evidence(uuid,uuid,uuid) set schema growth_internal;
alter function public.withdraw_claim(uuid) set schema growth_internal;
alter function public.review_claim(uuid,uuid,uuid,boolean) set schema growth_internal;
revoke all on function growth_internal.initialize_wallet(), growth_internal.create_campaign(text,text,integer), growth_internal.cancel_campaign(uuid), growth_internal.submit_claim(uuid,text,text,text), growth_internal.get_claim_evidence(uuid,uuid,uuid), growth_internal.withdraw_claim(uuid), growth_internal.review_claim(uuid,uuid,uuid,boolean) from public, anon, authenticated;

create function public.initialize_wallet() returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); perform growth_internal.initialize_wallet(); end $$;
create function public.create_campaign(p_type text,p_link text,p_count integer) returns uuid language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); return growth_internal.create_campaign(p_type,p_link,p_count); end $$;
create function public.cancel_campaign(p_campaign_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); perform growth_internal.cancel_campaign(p_campaign_id); end $$;
create function public.submit_claim(p_campaign_id uuid,p_instagram_handle text,p_mime text,p_evidence text) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); perform growth_internal.submit_claim(p_campaign_id,p_instagram_handle,p_mime,p_evidence); end $$;
create function public.get_claim_evidence(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); return growth_internal.get_claim_evidence(p_campaign_id,p_user_id,p_submission_id); end $$;
create function public.withdraw_claim(p_campaign_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); perform growth_internal.withdraw_claim(p_campaign_id); end $$;
create function public.review_claim(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid,p_approve boolean) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); perform growth_internal.review_claim(p_campaign_id,p_user_id,p_submission_id,p_approve); end $$;
revoke all on function public.initialize_wallet(),public.create_campaign(text,text,integer),public.cancel_campaign(uuid),public.submit_claim(uuid,text,text,text),public.get_claim_evidence(uuid,uuid,uuid),public.withdraw_claim(uuid),public.review_claim(uuid,uuid,uuid,boolean) from public, anon;
grant execute on function public.initialize_wallet(),public.create_campaign(text,text,integer),public.cancel_campaign(uuid),public.submit_claim(uuid,text,text,text),public.get_claim_evidence(uuid,uuid,uuid),public.withdraw_claim(uuid),public.review_claim(uuid,uuid,uuid,boolean) to authenticated;

drop policy wallet_read on public.wallets;
create policy wallet_read on public.wallets for select to authenticated using (public.account_access_allowed() and id=auth.uid());
drop policy campaigns_read on public.campaigns;
create policy campaigns_read on public.campaigns for select to authenticated using (public.account_access_allowed());
drop policy ledger_read on public.coin_ledger;
create policy ledger_read on public.coin_ledger for select to authenticated using (public.account_access_allowed() and user_id=auth.uid());
drop policy claims_read on public.campaign_claims;
create policy claims_read on public.campaign_claims for select to authenticated using (
  public.account_access_allowed() and (user_id=auth.uid() or exists(select 1 from public.campaigns c where c.id=campaign_claims.campaign_id and c."ownerId"=auth.uid()))
);

create function public.admin_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select public.account_access_allowed() and exists(select 1 from public.admin_members where user_id=auth.uid());
$$;
create function public.admin_list_users(p_query text default '',p_offset integer default 0,p_limit integer default 50)
returns table (id uuid,email text,display_name text,created_at timestamptz,last_sign_in_at timestamptz,coins integer,blocked boolean,is_admin boolean)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if p_offset is null or p_offset < 0 or p_limit is null or p_limit < 1 or p_limit > 100 or length(coalesce(p_query,'')) > 100 then
    raise exception 'Invalid search or page.' using errcode='P0001';
  end if;
  return query select u.id,u.email::text,coalesce(u.raw_user_meta_data->>'full_name',''),u.created_at,u.last_sign_in_at,w.balance,
    coalesce(a.blocked,false),exists(select 1 from public.admin_members m where m.user_id=u.id)
    from auth.users u left join public.wallets w on w.id=u.id left join public.user_access a on a.user_id=u.id
    where pg_catalog.strpos(pg_catalog.lower(coalesce(u.email::text,'') || ' ' || coalesce(u.raw_user_meta_data->>'full_name','')),pg_catalog.lower(coalesce(p_query,''))) > 0
    order by u.created_at desc,u.id limit p_limit offset p_offset;
end $$;
create function public.admin_set_blocked(p_user_id uuid,p_blocked boolean) returns void
language plpgsql security definer set search_path='' as $$
declare prior boolean;
begin
  perform growth_internal.require_admin();
  if p_user_id is null or p_blocked is null or not exists(select 1 from auth.users where id=p_user_id) then
    raise exception 'User not found.' using errcode='P0001';
  end if;
  if exists(select 1 from public.admin_members where user_id=p_user_id) then
    raise exception 'Administrators cannot be blocked here.' using errcode='P0001';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 314159));
  select coalesce((select blocked from public.user_access where user_id=p_user_id),false) into prior;
  if prior=p_blocked then return; end if;
  insert into public.user_access(user_id,blocked,updated_by,updated_at) values(p_user_id,p_blocked,auth.uid(),now())
    on conflict(user_id) do update set blocked=excluded.blocked,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
  insert into public.admin_access_audit(actor_id,target_id,blocked) values(auth.uid(),p_user_id,p_blocked);
end $$;
revoke all on function public.admin_is_admin(),public.admin_list_users(text,integer,integer),public.admin_set_blocked(uuid,boolean) from public, anon;
grant execute on function public.admin_is_admin(),public.admin_list_users(text,integer,integer),public.admin_set_blocked(uuid,boolean) to authenticated;
commit;
