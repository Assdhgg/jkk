-- Administrator operations; apply after admin workspace.
begin;
-- Existing administrators may enroll TOTP; enrolled administrators must use AAL2.
create or replace function growth_internal.require_admin() returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if not exists(select 1 from public.admin_members where user_id=auth.uid()) then raise exception 'Administrator access required.' using errcode='P0001'; end if;
 if exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified') and coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
   raise exception 'Multi-factor verification required.' using errcode='P0001';
 end if;
end $$;

create table growth_internal.support_tickets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 subject text not null check(length(subject) between 1 and 120), status text not null default 'open' check(status in ('open','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table growth_internal.support_messages (
 id uuid primary key default gen_random_uuid(), ticket_id uuid not null references growth_internal.support_tickets(id) on delete cascade,
 author_id uuid references auth.users(id) on delete set null, is_admin boolean not null, body text not null check(length(body) between 1 and 2000), created_at timestamptz not null default now()
);
create table growth_internal.campaign_reports (
 id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.campaigns(id) on delete cascade,
 reporter_id uuid not null references auth.users(id) on delete cascade, reason text not null check(length(reason) between 1 and 1000),
 status text not null default 'open' check(status in ('open','dismissed','cancelled')), created_at timestamptz not null default now(), resolved_at timestamptz, resolved_by uuid references auth.users(id) on delete set null,
 unique(campaign_id,reporter_id)
);
create table growth_internal.admin_events (
 id bigint generated always as identity primary key, kind text not null, subject_id uuid, created_at timestamptz not null default now()
);
create table growth_internal.admin_event_reads (
 admin_id uuid not null references auth.users(id) on delete cascade, event_id bigint not null references growth_internal.admin_events(id) on delete cascade, primary key(admin_id,event_id)
);
create table growth_internal.admin_notes (
 id uuid primary key default gen_random_uuid(), subject_type text not null check(subject_type in ('user','campaign')),
 subject_id uuid not null, author_id uuid references auth.users(id) on delete set null,
 body text not null check(length(body) between 1 and 2000), created_at timestamptz not null default now()
);
create table growth_internal.admin_operations_audit (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id) on delete set null,
 action text not null, subject_id uuid, details text not null default '', created_at timestamptz not null default now()
);
revoke all on growth_internal.admin_operations_audit from public,anon,authenticated;
revoke all on sequence growth_internal.admin_operations_audit_id_seq from public,anon,authenticated;
create table growth_internal.coin_adjustments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 requester_id uuid not null references auth.users(id) on delete restrict, approver_id uuid references auth.users(id) on delete restrict,
 amount integer not null check(amount between -10000 and 10000 and amount<>0), reason text not null check(length(reason) between 1 and 1000),
 status text not null default 'pending' check(status in ('pending','approved','rejected')), created_at timestamptz not null default now(), resolved_at timestamptz,
 check(approver_id is null or approver_id<>requester_id)
);
revoke all on growth_internal.support_tickets,growth_internal.support_messages,growth_internal.campaign_reports,growth_internal.admin_events,growth_internal.admin_event_reads,growth_internal.admin_notes,growth_internal.coin_adjustments from public,anon,authenticated;
revoke all on sequence growth_internal.admin_events_id_seq from public,anon,authenticated;
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check(reason in ('welcome','campaign','task','refund','referral','admin_adjustment'));

create function public.support_create_ticket(p_subject text,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare tid uuid; subject text:=btrim(coalesce(p_subject,'')); body text:=btrim(coalesce(p_body,''));
begin
 perform growth_internal.require_active();
 if length(subject) not between 1 and 120 or length(body) not between 1 and 2000 then raise exception 'Invalid ticket.' using errcode='P0001'; end if;
 insert into growth_internal.support_tickets(user_id,subject) values(auth.uid(),subject) returning id into tid;
 insert into growth_internal.support_messages(ticket_id,author_id,is_admin,body) values(tid,auth.uid(),false,body);
 insert into growth_internal.admin_events(kind,subject_id) values('support_ticket',tid);
 return tid;
end $$;
create function public.support_my_tickets() returns table(id uuid,subject text,status text,updated_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); return query select t.id,t.subject,t.status,t.updated_at from growth_internal.support_tickets t where t.user_id=auth.uid() order by t.updated_at desc,t.id limit 100; end $$;
create function public.support_messages(p_ticket uuid) returns table(body text,is_admin boolean,created_at timestamptz) language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if not exists(select 1 from growth_internal.support_tickets where id=p_ticket and user_id=auth.uid()) then perform growth_internal.require_admin(); end if;
 return query select m.body,m.is_admin,m.created_at from growth_internal.support_messages m where m.ticket_id=p_ticket order by m.created_at,m.id limit 200;
end $$;
create function public.support_reply(p_ticket uuid,p_body text) returns void language plpgsql security definer set search_path='' as $$
declare t growth_internal.support_tickets%rowtype; admin_reply boolean:=false; body text:=btrim(coalesce(p_body,''));
begin
 perform growth_internal.require_active();
 if length(body) not between 1 and 2000 then raise exception 'Invalid message.' using errcode='P0001'; end if;
 select * into t from growth_internal.support_tickets where id=p_ticket for update;
 if not found or t.status<>'open' then raise exception 'Ticket unavailable.' using errcode='P0001'; end if;
 if t.user_id<>auth.uid() then perform growth_internal.require_admin_editor(); admin_reply:=true; end if;
 insert into growth_internal.support_messages(ticket_id,author_id,is_admin,body) values(t.id,auth.uid(),admin_reply,body);
 update growth_internal.support_tickets set updated_at=now() where id=t.id;
 if not admin_reply then insert into growth_internal.admin_events(kind,subject_id) values('support_reply',t.id); else insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Support reply',t.id); end if;
end $$;
create function public.admin_support_tickets() returns table(id uuid,user_id uuid,email text,subject text,status text,updated_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select t.id,t.user_id,u.email::text,t.subject,t.status,t.updated_at from growth_internal.support_tickets t left join auth.users u on u.id=t.user_id order by t.updated_at desc,t.id limit 100; end $$;
create function public.admin_close_ticket(p_ticket uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); update growth_internal.support_tickets set status='closed',updated_at=now() where id=p_ticket and status='open'; if not found then raise exception 'Ticket unavailable.' using errcode='P0001'; end if; insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Ticket closed',p_ticket); end $$;

create function public.report_campaign(p_campaign uuid,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid; reason text:=btrim(coalesce(p_reason,''));
begin
 perform growth_internal.require_active();
 if length(reason) not between 1 and 1000 or not exists(select 1 from public.campaigns c where c.id=p_campaign and c."ownerId"<>auth.uid() and c.status='active') then raise exception 'Invalid report.' using errcode='P0001'; end if;
 insert into growth_internal.campaign_reports(campaign_id,reporter_id,reason) values(p_campaign,auth.uid(),reason) returning id into rid;
 insert into growth_internal.admin_events(kind,subject_id) values('campaign_report',rid); return rid;
end $$;
create function public.admin_campaign_reports() returns table(id uuid,campaign_id uuid,reason text,status text,created_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select r.id,r.campaign_id,r.reason,r.status,r.created_at from growth_internal.campaign_reports r order by r.created_at desc,r.id limit 100; end $$;
create function public.admin_resolve_report(p_report uuid,p_cancel boolean) returns void language plpgsql security definer set search_path='' as $$
declare r growth_internal.campaign_reports%rowtype; c public.campaigns%rowtype;
begin
 perform growth_internal.require_admin_editor();
 if p_cancel is null then raise exception 'Invalid decision.' using errcode='P0001'; end if;
 select * into r from growth_internal.campaign_reports where id=p_report for update;
 if not found or r.status<>'open' then raise exception 'Report unavailable.' using errcode='P0001'; end if;
 if p_cancel then
  select * into c from public.campaigns where id=r.campaign_id for update;
  if not found or c.status<>'active' then raise exception 'Campaign is no longer active.' using errcode='P0001'; end if;
  update public.campaigns set status='cancelled' where id=c.id;
  update public.campaign_claims set status='cancelled',reviewed_at=now() where campaign_id=c.id and status='pending';
  delete from public.claim_evidence where campaign_id=c.id;
  update public.wallets set balance=balance+c.remaining*c.reward_per_task where id=c."ownerId";
  if not found then raise exception 'Owner wallet unavailable.' using errcode='P0001'; end if;
  insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(c."ownerId",c.remaining*c.reward_per_task,'refund',c.id);
 end if;
 update growth_internal.campaign_reports set status=case when p_cancel then 'cancelled' else 'dismissed' end,resolved_by=auth.uid(),resolved_at=now() where id=r.id;
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details) values(auth.uid(),case when p_cancel then 'Campaign cancelled' else 'Report dismissed' end,r.campaign_id,r.id::text);
end $$;

create table growth_internal.admin_alert_settings (key text primary key,value integer not null check(value between 1 and 1000000));
insert into growth_internal.admin_alert_settings values('pending_hours',24),('coins_24h',1000),('referrals_24h',5);
create table growth_internal.admin_setting_audit (id bigint generated always as identity primary key,actor_id uuid references auth.users(id) on delete set null,key text not null,value integer not null,created_at timestamptz not null default now());
revoke all on growth_internal.admin_alert_settings,growth_internal.admin_setting_audit from public,anon,authenticated;
revoke all on sequence growth_internal.admin_setting_audit_id_seq from public,anon,authenticated;
create function public.admin_alert_settings() returns table(key text,value integer) language plpgsql security definer set search_path='' as $$ begin perform growth_internal.require_admin(); return query select s.key,s.value from growth_internal.admin_alert_settings s order by s.key; end $$;
create function public.admin_set_alert_setting(p_key text,p_value integer) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); if p_value is null or p_value not between 1 and 1000000 then raise exception 'Invalid threshold.' using errcode='P0001'; end if; update growth_internal.admin_alert_settings set value=p_value where key=p_key; if not found then raise exception 'Invalid threshold.' using errcode='P0001'; end if; insert into growth_internal.admin_setting_audit(actor_id,key,value) values(auth.uid(),p_key,p_value); insert into growth_internal.admin_operations_audit(actor_id,action,details) values(auth.uid(),'Alert threshold',concat(p_key,': ',p_value)); end $$;
create or replace function public.admin_alerts() returns table(kind text,subject text,activity bigint,observed_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query
 select 'pending'::text,cl.campaign_id::text,count(*)::bigint,min(cl.created_at) from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.status='pending' and c.status='active' and cl.created_at<now()-make_interval(hours=>(select value from growth_internal.admin_alert_settings where key='pending_hours')) group by cl.campaign_id
 union all select 'coins',coalesce(u.email::text,l.user_id::text),sum(l.amount)::bigint,max(l."createdAt") from public.coin_ledger l left join auth.users u on u.id=l.user_id where l.amount>0 and l."createdAt">=now()-interval '24 hours' group by l.user_id,u.email having sum(l.amount)>=(select value from growth_internal.admin_alert_settings where key='coins_24h')
 union all select 'referrals',coalesce(u.email::text,r.referrer_id::text),count(*)::bigint,max(r.created_at) from growth_internal.referrals r left join auth.users u on u.id=r.referrer_id where r.created_at>=now()-interval '24 hours' group by r.referrer_id,u.email having count(*)>=(select value from growth_internal.admin_alert_settings where key='referrals_24h') order by 4 desc limit 100; end $$;

create function public.admin_event_feed() returns table(id bigint,kind text,subject_id uuid,created_at timestamptz,read boolean) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select e.id,e.kind,e.subject_id,e.created_at,exists(select 1 from growth_internal.admin_event_reads r where r.event_id=e.id and r.admin_id=auth.uid()) from growth_internal.admin_events e order by e.created_at desc,e.id desc limit 100; end $$;
create function public.admin_mark_event_read(p_id bigint) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); if not exists(select 1 from growth_internal.admin_events where id=p_id) then raise exception 'Event unavailable.' using errcode='P0001'; end if; insert into growth_internal.admin_event_reads(admin_id,event_id) values(auth.uid(),p_id) on conflict do nothing; end $$;
create function public.admin_add_note(p_type text,p_id uuid,p_body text) returns void language plpgsql security definer set search_path='' as $$
declare body text:=btrim(coalesce(p_body,''));
begin perform growth_internal.require_admin_editor(); if length(body) not between 1 and 2000 or not ((p_type='user' and exists(select 1 from auth.users where id=p_id)) or (p_type='campaign' and exists(select 1 from public.campaigns where id=p_id))) then raise exception 'Invalid note.' using errcode='P0001'; end if; insert into growth_internal.admin_notes(subject_type,subject_id,author_id,body) values(p_type,p_id,auth.uid(),body); insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details) values(auth.uid(),'Admin note',p_id,p_type); end $$;
create function public.admin_notes(p_type text,p_id uuid) returns table(body text,author text,created_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); if p_type not in ('user','campaign') or p_id is null then raise exception 'Invalid subject.' using errcode='P0001'; end if; return query select n.body,coalesce(u.email::text,'Deleted administrator'),n.created_at from growth_internal.admin_notes n left join auth.users u on u.id=n.author_id where n.subject_type=p_type and n.subject_id=p_id order by n.created_at desc,n.id limit 100; end $$;

create function public.admin_request_adjustment(p_user uuid,p_amount integer,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid; reason text:=btrim(coalesce(p_reason,''));
begin perform growth_internal.require_admin_editor(); if p_amount is null or p_amount=0 or p_amount not between -10000 and 10000 or length(reason) not between 1 and 1000 or not exists(select 1 from public.wallets where id=p_user) then raise exception 'Invalid adjustment.' using errcode='P0001'; end if; insert into growth_internal.coin_adjustments(user_id,requester_id,amount,reason) values(p_user,auth.uid(),p_amount,reason) returning id into rid; insert into growth_internal.admin_events(kind,subject_id) values('coin_adjustment',rid); insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details) values(auth.uid(),'Coin correction requested',p_user,rid::text); return rid; end $$;
create function public.admin_adjustments() returns table(id uuid,user_id uuid,requester_id uuid,approver_id uuid,amount integer,reason text,status text,created_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select a.id,a.user_id,a.requester_id,a.approver_id,a.amount,a.reason,a.status,a.created_at from growth_internal.coin_adjustments a order by a.created_at desc,a.id limit 100; end $$;
create function public.admin_decide_adjustment(p_id uuid,p_approve boolean) returns void language plpgsql security definer set search_path='' as $$
declare a growth_internal.coin_adjustments%rowtype; current_balance integer;
begin perform growth_internal.require_admin_editor(); if p_approve is null then raise exception 'Invalid decision.' using errcode='P0001'; end if;
 select * into a from growth_internal.coin_adjustments where id=p_id for update;
 if not found or a.status<>'pending' or a.requester_id=auth.uid() then raise exception 'A different editor must decide a pending request.' using errcode='P0001'; end if;
 if p_approve then
  select balance into current_balance from public.wallets where id=a.user_id for update;
  if not found or current_balance::bigint+a.amount<0 or current_balance::bigint+a.amount>2147483647 then raise exception 'Invalid resulting balance.' using errcode='P0001'; end if;
  update public.wallets set balance=balance+a.amount where id=a.user_id;
  insert into public.coin_ledger(user_id,amount,reason) values(a.user_id,a.amount,'admin_adjustment');
 end if;
 update growth_internal.coin_adjustments set status=case when p_approve then 'approved' else 'rejected' end,approver_id=auth.uid(),resolved_at=now() where id=a.id;
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details) values(auth.uid(),case when p_approve then 'Coin correction approved' else 'Coin correction rejected' end,a.user_id,a.id::text);
end $$;

create or replace function public.admin_activity(p_offset integer default 0,p_limit integer default 50)
returns table(event_at timestamptz,actor text,action text,details text) language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid page.' using errcode='P0001'; end if;
 return query select e.event_at,coalesce(u.email::text,e.actor_id::text,'Deleted account'),e.action,e.details from (
  select a.created_at event_at,a.actor_id,'Access'::text action,concat(a.target_id,case when a.blocked then ' blocked' else ' restored' end) details, 'access-'||a.id::text sort_key from public.admin_access_audit a
  union all select a.created_at,a.actor_id,'Action control',concat(a.action_type,case when a.enabled then ' enabled' else ' disabled' end),'action-'||a.id::text from growth_internal.action_control_audit a
  union all select a.created_at,a.actor,'Coin setting',concat(a.key,': ',a.amount),'coin-'||a.id::text from growth_internal.coin_settings_audit a
  union all select a.started_at,a.admin_id,'Submission inspection',concat('Campaign ',a.campaign_id,' / submission ',a.submission_id),'review-'||a.id::text from growth_internal.admin_review_audit a
  union all select a.created_at,a.actor_id,a.action,concat(a.subject_id,' ',a.details),'operation-'||a.id::text from growth_internal.admin_operations_audit a
 ) e left join auth.users u on u.id=e.actor_id order by e.event_at desc,e.sort_key desc limit p_limit offset p_offset;
end $$;

revoke all on function public.support_create_ticket(text,text),public.support_my_tickets(),public.support_messages(uuid),public.support_reply(uuid,text),public.admin_support_tickets(),public.admin_close_ticket(uuid),public.report_campaign(uuid,text),public.admin_campaign_reports(),public.admin_resolve_report(uuid,boolean),public.admin_alert_settings(),public.admin_set_alert_setting(text,integer),public.admin_event_feed(),public.admin_mark_event_read(bigint),public.admin_add_note(text,uuid,text),public.admin_notes(text,uuid),public.admin_request_adjustment(uuid,integer,text),public.admin_adjustments(),public.admin_decide_adjustment(uuid,boolean) from public,anon;
grant execute on function public.support_create_ticket(text,text),public.support_my_tickets(),public.support_messages(uuid),public.support_reply(uuid,text),public.admin_support_tickets(),public.admin_close_ticket(uuid),public.report_campaign(uuid,text),public.admin_campaign_reports(),public.admin_resolve_report(uuid,boolean),public.admin_alert_settings(),public.admin_set_alert_setting(text,integer),public.admin_event_feed(),public.admin_mark_event_read(bigint),public.admin_add_note(text,uuid,text),public.admin_notes(text,uuid),public.admin_request_adjustment(uuid,integer,text),public.admin_adjustments(),public.admin_decide_adjustment(uuid,boolean) to authenticated;
commit;
