begin;
alter table public.notifications add column title text;
alter table public.notifications add column body text;
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply','app_update','admin_message'));
alter table public.notifications add constraint notifications_admin_content_check check (
 (kind='admin_message' and title is not null and length(trim(title)) between 1 and 80 and body is not null and length(trim(body)) between 1 and 500)
 or (kind<>'admin_message' and title is null and body is null)
);

create table growth_internal.admin_notification_requests (
 actor_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 target_user uuid,
 title text not null,
 body text not null,
 recipient_count integer not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
revoke all on growth_internal.admin_notification_requests from public,anon,authenticated;

create function public.admin_notification_users(p_query text default '',p_offset integer default 0)
returns table(id uuid,email text,display_name text,public_id text)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 if p_offset is null or p_offset < 0 or length(coalesce(p_query,'')) > 100 then raise exception 'Invalid search.'; end if;
 return query select u.id,u.email::text,coalesce(u.raw_user_meta_data->>'full_name',''),i.public_id
 from auth.users u left join growth_internal.user_identifiers i on i.user_id=u.id
 where u.email_confirmed_at is not null and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked)
 and strpos(lower(coalesce(u.email::text,'') || ' ' || coalesce(u.raw_user_meta_data->>'full_name','') || ' ' || coalesce(i.public_id,'')),lower(coalesce(p_query,'')))>0
 order by u.created_at desc,u.id limit 25 offset p_offset;
end $$;
revoke all on function public.admin_notification_users(text,integer) from public,anon;
grant execute on function public.admin_notification_users(text,integer) to authenticated;

create function public.admin_send_notification(p_request_id uuid,p_target_user uuid,p_title text,p_body text)
returns integer language plpgsql security definer set search_path='' as $$
declare t text:=btrim(coalesce(p_title,'')); b text:=btrim(coalesce(p_body,'')); previous growth_internal.admin_notification_requests%rowtype; count_sent integer;
begin
 perform growth_internal.require_admin_editor();
 if p_request_id is null or length(t) not between 1 and 80 or length(b) not between 1 and 500 then raise exception 'Invalid notification.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text || p_request_id::text, 89321));
 select * into previous from growth_internal.admin_notification_requests where actor_id=auth.uid() and request_id=p_request_id;
 if found then
  if previous.target_user is distinct from p_target_user or previous.title<>t or previous.body<>b then raise exception 'Request ID already used.'; end if;
  return previous.recipient_count;
 end if;
 if p_target_user is not null and not exists(select 1 from auth.users u where u.id=p_target_user and u.email_confirmed_at is not null and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked)) then raise exception 'User unavailable.'; end if;
 insert into public.notifications(user_id,kind,title,body)
 select u.id,'admin_message',t,b from auth.users u
 where u.email_confirmed_at is not null and (p_target_user is null or u.id=p_target_user)
 and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked);
 get diagnostics count_sent = row_count;
 insert into growth_internal.admin_notification_requests(actor_id,request_id,target_user,title,body,recipient_count) values(auth.uid(),p_request_id,p_target_user,t,b,count_sent);
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details) values(auth.uid(),'Send notification',p_target_user,concat('Recipients: ',count_sent));
 return count_sent;
end $$;
revoke all on function public.admin_send_notification(uuid,uuid,text,text) from public,anon;
grant execute on function public.admin_send_notification(uuid,uuid,text,text) to authenticated;

-- Preserve v1 for old workers; v2 includes the message stored with each job.
create function public.claim_push_jobs_v2(p_limit integer default 50)
returns table(job_id uuid,lease_id uuid,token text,kind text,title text,body text)
language sql security definer set search_path='' as $$
 select claimed.job_id,claimed.lease_id,claimed.token,claimed.kind,n.title,n.body
 from public.claim_push_jobs(p_limit) claimed
 join growth_internal.push_jobs j on j.id=claimed.job_id
 join public.notifications n on n.id=j.notification_id;
$$;
revoke all on function public.claim_push_jobs_v2(integer) from public,anon,authenticated;
grant execute on function public.claim_push_jobs_v2(integer) to service_role;
commit;
