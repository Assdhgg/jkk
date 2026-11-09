-- User history, saved tasks, feedback and a private push outbox.
begin;
alter table public.campaign_claims add column rejection_reason text check(rejection_reason is null or length(rejection_reason)<=500);
create table public.submission_history (
 submission_id uuid primary key, campaign_id uuid not null references public.campaigns(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, status text not null,
 submitted_at timestamptz not null, reviewed_at timestamptz, rejection_reason text
);
create index submission_history_user_idx on public.submission_history(user_id,submitted_at desc,submission_id);
alter table public.submission_history enable row level security;
revoke all on public.submission_history from public,anon,authenticated;
grant select on public.submission_history to authenticated;
create policy submission_history_read on public.submission_history for select to authenticated using(public.account_access_allowed() and user_id=auth.uid());
insert into public.submission_history(submission_id,campaign_id,user_id,status,submitted_at,reviewed_at)
 select submission_id,campaign_id,user_id,status,created_at,reviewed_at from public.campaign_claims;
create function growth_internal.clear_claim_feedback() returns trigger language plpgsql security definer set search_path='' as $$
begin if new.submission_id is distinct from old.submission_id or new.status='pending' then new.rejection_reason:=null; end if; return new; end $$;
create trigger claim_clear_feedback before update on public.campaign_claims for each row execute function growth_internal.clear_claim_feedback();
create function growth_internal.capture_submission_history() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.submission_history(submission_id,campaign_id,user_id,status,submitted_at,reviewed_at,rejection_reason)
 values(new.submission_id,new.campaign_id,new.user_id,new.status,new.created_at,new.reviewed_at,new.rejection_reason)
 on conflict(submission_id) do update set status=excluded.status,reviewed_at=excluded.reviewed_at,rejection_reason=excluded.rejection_reason;
 return new;
end $$;
create trigger claim_history after insert or update on public.campaign_claims for each row execute function growth_internal.capture_submission_history();
revoke all on function growth_internal.clear_claim_feedback(),growth_internal.capture_submission_history() from public,anon,authenticated;

create function public.user_submission_history(p_status text default null,p_query text default '',p_from timestamptz default null,p_to timestamptz default null,p_offset integer default 0,p_limit integer default 50)
returns table(submission_id uuid,campaign_id uuid,status text,submitted_at timestamptz,reviewed_at timestamptz,rejection_reason text,action_type text,campaign_link text) language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if (p_status is not null and p_status not in ('pending','approved','rejected','withdrawn','cancelled','legacy')) or length(coalesce(p_query,''))>100 or (p_from is not null and p_to is not null and p_from>=p_to) or p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid filter or page.' using errcode='P0001'; end if;
 return query select h.submission_id,h.campaign_id,h.status,h.submitted_at,h.reviewed_at,h.rejection_reason,c.type,c.link from public.submission_history h join public.campaigns c on c.id=h.campaign_id where h.user_id=auth.uid() and (p_status is null or h.status=p_status) and (p_from is null or h.submitted_at>=p_from) and (p_to is null or h.submitted_at<p_to) and strpos(lower(c.link || ' ' || c.type),lower(coalesce(p_query,'')))>0 order by h.submitted_at desc,h.submission_id desc limit p_limit offset p_offset;
end $$;
revoke all on function public.user_submission_history(text,text,timestamptz,timestamptz,integer,integer) from public,anon;
grant execute on function public.user_submission_history(text,text,timestamptz,timestamptz,integer,integer) to authenticated;

-- The existing review RPC still enforces ownership, current submission, evidence and PIN.
create function public.review_claim_with_feedback(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid,p_approve boolean,p_pin text default null,p_reason text default null) returns text language plpgsql security definer set search_path='' as $$
declare result text; reason text:=nullif(btrim(coalesce(p_reason,'')),'');
begin
 if reason is not null and (length(reason)>500 or p_approve is distinct from false) then raise exception 'Invalid feedback.' using errcode='P0001'; end if;
 result:=public.review_claim_with_pin(p_campaign_id,p_user_id,p_submission_id,p_approve,p_pin);
 if result='ok' and p_approve=false and reason is not null then
   update public.campaign_claims set rejection_reason=reason where campaign_id=p_campaign_id and user_id=p_user_id and submission_id=p_submission_id and status='rejected';
   if not found then raise exception 'Submission changed.' using errcode='P0001'; end if;
 end if;
 return result;
end $$;
revoke all on function public.review_claim_with_feedback(uuid,uuid,uuid,boolean,text,text) from public,anon;
grant execute on function public.review_claim_with_feedback(uuid,uuid,uuid,boolean,text,text) to authenticated;

create table public.saved_tasks(user_id uuid not null references auth.users(id) on delete cascade,campaign_id uuid not null references public.campaigns(id) on delete cascade,created_at timestamptz not null default now(),primary key(user_id,campaign_id));
alter table public.saved_tasks enable row level security;
revoke all on public.saved_tasks from public,anon,authenticated;
grant select on public.saved_tasks to authenticated;
create policy saved_tasks_read on public.saved_tasks for select to authenticated using(public.account_access_allowed() and user_id=auth.uid());
create function public.set_task_saved(p_campaign uuid,p_saved boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if p_campaign is null or p_saved is null then raise exception 'Invalid saved task.' using errcode='P0001'; end if;
 if p_saved then
  if not exists(select 1 from public.campaigns where id=p_campaign and status='active' and "ownerId"<>auth.uid()) then raise exception 'Task unavailable.' using errcode='P0001'; end if;
  insert into public.saved_tasks(user_id,campaign_id) values(auth.uid(),p_campaign) on conflict do nothing;
 else delete from public.saved_tasks where user_id=auth.uid() and campaign_id=p_campaign; end if;
end $$;
revoke all on function public.set_task_saved(uuid,boolean) from public,anon;
grant execute on function public.set_task_saved(uuid,boolean) to authenticated;

-- Admin replies notify the member without exposing the message to a push provider.
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply'));
create function growth_internal.notify_support_reply() returns trigger language plpgsql security definer set search_path='' as $$
begin if new.is_admin then insert into public.notifications(user_id,kind) select user_id,'support_reply' from growth_internal.support_tickets where id=new.ticket_id; end if; return new; end $$;
create trigger support_reply_notification after insert on growth_internal.support_messages for each row execute function growth_internal.notify_support_reply();
revoke all on function growth_internal.notify_support_reply() from public,anon,authenticated;

create table growth_internal.push_tokens(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,token text not null unique check(length(token) between 20 and 4096),updated_at timestamptz not null default now());
create table growth_internal.push_jobs(id uuid primary key default gen_random_uuid(),notification_id uuid not null references public.notifications(id) on delete cascade,token_id uuid not null references growth_internal.push_tokens(id) on delete cascade,status text not null default 'pending' check(status in ('pending','leased','sent','failed')),attempts integer not null default 0,next_attempt timestamptz not null default now(),lease_until timestamptz,lease_id uuid,unique(notification_id,token_id));
create index push_jobs_pending_idx on growth_internal.push_jobs(status,next_attempt);
revoke all on growth_internal.push_tokens,growth_internal.push_jobs from public,anon,authenticated;
create function public.register_push_token(p_token text) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if p_token is null or length(p_token) not between 20 and 4096 then raise exception 'Invalid push token.' using errcode='P0001'; end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_token,86420)); delete from growth_internal.push_tokens where token=p_token and user_id<>auth.uid(); insert into growth_internal.push_tokens(user_id,token) values(auth.uid(),p_token) on conflict(token) do update set updated_at=now(); end $$;
create function public.unregister_push_token(p_token text) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); delete from growth_internal.push_tokens where user_id=auth.uid() and token=p_token; end $$;
revoke all on function public.register_push_token(text),public.unregister_push_token(text) from public,anon;
grant execute on function public.register_push_token(text),public.unregister_push_token(text) to authenticated;
create function growth_internal.enqueue_push() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into growth_internal.push_jobs(notification_id,token_id) select new.id,t.id from growth_internal.push_tokens t where t.user_id=new.user_id; return new; end $$;
create trigger enqueue_notification_push after insert on public.notifications for each row execute function growth_internal.enqueue_push();
revoke all on function growth_internal.enqueue_push() from public,anon,authenticated;
create function public.claim_push_jobs(p_limit integer default 50) returns table(job_id uuid,lease_id uuid,token text,kind text) language plpgsql security definer set search_path='' as $$
begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid limit.' using errcode='P0001'; end if;
 return query with selected as (select j.id from growth_internal.push_jobs j where (j.status='pending' and j.next_attempt<=now()) or (j.status='leased' and j.lease_until<now()) order by j.next_attempt,j.id for update skip locked limit p_limit), claimed as (update growth_internal.push_jobs j set status='leased',attempts=j.attempts+1,lease_until=now()+interval '2 minutes',lease_id=gen_random_uuid() from selected s where j.id=s.id returning j.id,j.lease_id,j.notification_id,j.token_id) select c.id,c.lease_id,t.token,n.kind from claimed c join growth_internal.push_tokens t on t.id=c.token_id join public.notifications n on n.id=c.notification_id;
end $$;
create function public.finish_push_job(p_id uuid,p_lease uuid,p_success boolean,p_permanent boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare j growth_internal.push_jobs%rowtype;
begin
 if p_id is null or p_lease is null or p_success is null or p_permanent is null then raise exception 'Invalid push result.' using errcode='P0001'; end if;
 select * into j from growth_internal.push_jobs where id=p_id for update;
 if not found or j.status<>'leased' or j.lease_id is distinct from p_lease or j.lease_until<now() then raise exception 'Push job unavailable.' using errcode='P0001'; end if;
 if p_permanent then delete from growth_internal.push_tokens where id=j.token_id;
 else update growth_internal.push_jobs set status=case when p_success then 'sent' when attempts>=8 then 'failed' else 'pending' end,lease_until=null,lease_id=null,next_attempt=now()+make_interval(mins=>least(60,1<<least(attempts,5))) where id=p_id; end if;
end $$;
revoke all on function public.claim_push_jobs(integer),public.finish_push_job(uuid,uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.claim_push_jobs(integer),public.finish_push_job(uuid,uuid,boolean,boolean) to service_role;
commit;
