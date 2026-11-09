-- Admin workspace. Existing administrators retain editor permissions.
begin;
alter table public.admin_members add column role text not null default 'editor' check (role in ('editor','viewer'));
create function growth_internal.require_admin_editor() returns void language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  perform 1 from public.admin_members where user_id=auth.uid() and role='editor' for share;
  if not found then
    raise exception 'Editor access required.' using errcode='P0001';
  end if;
end $$;
revoke all on function growth_internal.require_admin_editor() from public,anon,authenticated;

-- Wrap existing mutations so old clients are subject to the same role check.
alter function public.admin_set_blocked(uuid,boolean) set schema growth_internal;
alter function public.admin_set_action_enabled(text,boolean) set schema growth_internal;
alter function public.admin_set_coin_setting(text,integer) set schema growth_internal;
revoke all on function growth_internal.admin_set_blocked(uuid,boolean),growth_internal.admin_set_action_enabled(text,boolean),growth_internal.admin_set_coin_setting(text,integer) from public,anon,authenticated;
create function public.admin_set_blocked(p_user_id uuid,p_blocked boolean) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); perform growth_internal.admin_set_blocked(p_user_id,p_blocked); end $$;
create function public.admin_set_action_enabled(p_type text,p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); perform growth_internal.admin_set_action_enabled(p_type,p_enabled); end $$;
create function public.admin_set_coin_setting(p_key text,p_amount integer) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); perform growth_internal.admin_set_coin_setting(p_key,p_amount); end $$;

create function public.admin_workspace_role() returns text language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return (select role from public.admin_members where user_id=auth.uid()); end $$;
create function public.admin_roles() returns table(email text,role text,created_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select u.email::text,m.role,m.created_at from public.admin_members m join auth.users u on u.id=m.user_id order by m.created_at,m.user_id; end $$;
create function public.admin_workspace_overview() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 return jsonb_build_object(
  'users',(select count(*) from auth.users),
  'active_campaigns',(select count(*) from public.campaigns where status='active'),
  'pending_submissions',(select count(*) from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.status='pending' and c.status='active'),
  'coins_credited',(select coalesce(sum(amount),0) from public.coin_ledger where amount>0));
end $$;

create function public.admin_user_details(p_user_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'User not found.' using errcode='P0001'; end if;
 return jsonb_build_object(
  'role',(select role from public.admin_members where user_id=p_user_id),
  'referrals',(select count(*) from growth_internal.referrals where referrer_id=p_user_id),
  'referred',(select exists(select 1 from growth_internal.referrals where referred_id=p_user_id)),
  'campaigns',coalesce((select jsonb_agg(to_jsonb(x)) from (select type,status,link,requested,remaining,"createdAt" as created_at from public.campaigns where "ownerId"=p_user_id order by "createdAt" desc,id desc limit 100) x),'[]'::jsonb),
  'submissions',coalesce((select jsonb_agg(to_jsonb(x)) from (select cl.status,cl.created_at,c.type,c.link from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.user_id=p_user_id order by cl.created_at desc,cl.campaign_id limit 100) x),'[]'::jsonb),
  'ledger',coalesce((select jsonb_agg(to_jsonb(x)) from (select amount,reason,"createdAt" as created_at from public.coin_ledger where user_id=p_user_id order by "createdAt" desc,id desc limit 100) x),'[]'::jsonb));
end $$;

create function public.admin_filtered_submissions(p_type text default null,p_campaign uuid default null,p_from timestamptz default null,p_to timestamptz default null,p_offset integer default 0,p_limit integer default 30)
returns table(campaign_id uuid,user_id uuid,submission_id uuid,action_type text,campaign_link text,submitted_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if (p_type is not null and p_type not in ('follow','like','share','comment')) or (p_from is not null and p_to is not null and p_from>=p_to) or p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid filter or page.' using errcode='P0001'; end if;
 return query select cl.campaign_id,cl.user_id,cl.submission_id,c.type,c.link,cl.created_at from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id
 where cl.status='pending' and c.status='active' and (p_type is null or c.type=p_type) and (p_campaign is null or c.id=p_campaign) and (p_from is null or cl.created_at>=p_from) and (p_to is null or cl.created_at<p_to)
 order by cl.created_at,cl.campaign_id,cl.user_id limit p_limit offset p_offset;
end $$;

create function public.admin_activity(p_offset integer default 0,p_limit integer default 50)
returns table(event_at timestamptz,actor text,action text,details text) language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid page.' using errcode='P0001'; end if;
 return query select e.event_at,coalesce(u.email::text,e.actor_id::text,'Deleted account'),e.action,e.details from (
  select a.created_at event_at,a.actor_id,'Access'::text action,concat(a.target_id,case when a.blocked then ' blocked' else ' restored' end) details, 'access-'||a.id::text sort_key from public.admin_access_audit a
  union all select a.created_at,a.actor_id,'Action control',concat(a.action_type,case when a.enabled then ' enabled' else ' disabled' end),'action-'||a.id::text from growth_internal.action_control_audit a
  union all select a.created_at,a.actor,'Coin setting',concat(a.key,': ',a.amount),'coin-'||a.id::text from growth_internal.coin_settings_audit a
  union all select a.started_at,a.admin_id,'Submission inspection',concat('Campaign ',a.campaign_id,' / submission ',a.submission_id),'review-'||a.id::text from growth_internal.admin_review_audit a
 ) e left join auth.users u on u.id=e.actor_id order by e.event_at desc,e.sort_key desc limit p_limit offset p_offset;
end $$;

create index admin_campaign_created_idx on public.campaigns ("createdAt");
create index admin_ledger_created_idx on public.coin_ledger ("createdAt");
create index admin_claim_pending_idx on public.campaign_claims (created_at) where status='pending';
create index admin_referrals_created_idx on growth_internal.referrals (created_at);

-- Daily UTC totals; report range is inclusive and limited to one year.
create function public.admin_daily_report(p_from date,p_to date) returns table(day date,registrations bigint,campaigns bigint,coin_transactions bigint,coins_credited bigint,coins_spent bigint)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>365 then raise exception 'Invalid report range.' using errcode='P0001'; end if;
 return query with days as (
   select g::date report_day from pg_catalog.generate_series(p_from::timestamp,p_to::timestamp,interval '1 day') g
 ), registrations as (
   select (u.created_at at time zone 'UTC')::date report_day,count(*) total from auth.users u
   where u.created_at >= (p_from::timestamp at time zone 'UTC') and u.created_at < ((p_to+1)::timestamp at time zone 'UTC') group by 1
 ), campaigns as (
   select (c."createdAt" at time zone 'UTC')::date report_day,count(*) total from public.campaigns c
   where c."createdAt" >= (p_from::timestamp at time zone 'UTC') and c."createdAt" < ((p_to+1)::timestamp at time zone 'UTC') group by 1
 ), coins as (
   select (l."createdAt" at time zone 'UTC')::date report_day,count(*) total,
     coalesce(sum(l.amount) filter(where l.amount>0),0)::bigint credited,
     coalesce(sum(-l.amount::bigint) filter(where l.amount<0),0)::bigint spent from public.coin_ledger l
   where l."createdAt" >= (p_from::timestamp at time zone 'UTC') and l."createdAt" < ((p_to+1)::timestamp at time zone 'UTC') group by 1
 ) select d.report_day,coalesce(r.total,0),coalesce(c.total,0),coalesce(l.total,0),coalesce(l.credited,0),coalesce(l.spent,0)
 from days d left join registrations r using(report_day) left join campaigns c using(report_day) left join coins l using(report_day) order by d.report_day desc;
end $$;

create function public.admin_alerts() returns table(kind text,subject text,activity bigint,observed_at timestamptz) language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 return query
 select 'pending'::text,cl.campaign_id::text,count(*)::bigint,min(cl.created_at) from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.status='pending' and c.status='active' and cl.created_at<now()-interval '24 hours' group by cl.campaign_id
 union all select 'coins',coalesce(u.email::text,l.user_id::text),sum(l.amount)::bigint,max(l."createdAt") from public.coin_ledger l left join auth.users u on u.id=l.user_id where l.amount>0 and l."createdAt">=now()-interval '24 hours' group by l.user_id,u.email having sum(l.amount)>=1000
 union all select 'referrals',coalesce(u.email::text,r.referrer_id::text),count(*)::bigint,max(r.created_at) from growth_internal.referrals r left join auth.users u on u.id=r.referrer_id where r.created_at>=now()-interval '24 hours' group by r.referrer_id,u.email having count(*)>=5
 order by 4 desc limit 100;
end $$;
revoke all on function public.admin_set_blocked(uuid,boolean),public.admin_set_action_enabled(text,boolean),public.admin_set_coin_setting(text,integer),public.admin_workspace_role(),public.admin_roles(),public.admin_workspace_overview(),public.admin_user_details(uuid),public.admin_filtered_submissions(text,uuid,timestamptz,timestamptz,integer,integer),public.admin_activity(integer,integer),public.admin_daily_report(date,date),public.admin_alerts() from public,anon;
grant execute on function public.admin_set_blocked(uuid,boolean),public.admin_set_action_enabled(text,boolean),public.admin_set_coin_setting(text,integer),public.admin_workspace_role(),public.admin_roles(),public.admin_workspace_overview(),public.admin_user_details(uuid),public.admin_filtered_submissions(text,uuid,timestamptz,timestamptz,integer,integer),public.admin_activity(integer,integer),public.admin_daily_report(date,date),public.admin_alerts() to authenticated;
commit;
