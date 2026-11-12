begin;
alter table public.notifications add column show_in_app boolean not null default true;
alter table public.notifications add column deliver_push boolean not null default true;
alter table growth_internal.admin_notification_requests add column in_app boolean not null default true;
alter table growth_internal.admin_notification_requests add column push boolean not null default true;
alter policy notifications_read on public.notifications using (show_in_app and public.account_access_allowed() and user_id=auth.uid());
alter policy notifications_mark_read on public.notifications using (show_in_app and public.account_access_allowed() and user_id=auth.uid()) with check (show_in_app and public.account_access_allowed() and user_id=auth.uid());
create or replace function growth_internal.enqueue_push() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.deliver_push then
  insert into growth_internal.push_jobs(notification_id,token_id) select new.id,t.id from growth_internal.push_tokens t where t.user_id=new.user_id;
 end if;
 return new;
end $$;
create function public.admin_send_notification_v2(p_request_id uuid,p_target_user uuid,p_title text,p_body text,p_in_app boolean,p_push boolean)
returns integer language plpgsql security definer set search_path='' as $$
declare t text:=btrim(coalesce(p_title,'')); b text:=btrim(coalesce(p_body,'')); previous growth_internal.admin_notification_requests%rowtype; count_sent integer;
begin
 perform growth_internal.require_admin_editor();
 if p_in_app is null or p_push is null or not (p_in_app or p_push) or p_request_id is null or length(t) not between 1 and 80 or length(b) not between 1 and 500 then raise exception 'Invalid notification.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text || p_request_id::text, 89321));
 select * into previous from growth_internal.admin_notification_requests where actor_id=auth.uid() and request_id=p_request_id;
 if found then
  if previous.target_user is distinct from p_target_user or previous.title<>t or previous.body<>b or previous.in_app<>p_in_app or previous.push<>p_push then raise exception 'Request ID already used.'; end if;
  return previous.recipient_count;
 end if;
 if p_target_user is not null and not exists(select 1 from auth.users u where u.id=p_target_user and u.email_confirmed_at is not null and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked)) then raise exception 'User unavailable.'; end if;
 insert into public.notifications(user_id,kind,title,body,show_in_app,deliver_push)
 select u.id,'admin_message',t,b,p_in_app,p_push from auth.users u
 where u.email_confirmed_at is not null and (p_target_user is null or u.id=p_target_user)
 and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked);
 get diagnostics count_sent = row_count;
 insert into growth_internal.admin_notification_requests(actor_id,request_id,target_user,title,body,recipient_count,in_app,push) values(auth.uid(),p_request_id,p_target_user,t,b,count_sent,p_in_app,p_push);
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details) values(auth.uid(),'Send notification',p_target_user,concat('Recipients: ',count_sent));
 return count_sent;
end $$;
revoke all on function public.admin_send_notification_v2(uuid,uuid,text,text,boolean,boolean) from public,anon;
grant execute on function public.admin_send_notification_v2(uuid,uuid,text,text,boolean,boolean) to authenticated;


-- Older clients retain delivery to both channels.
create or replace function public.admin_send_notification(p_request_id uuid,p_target_user uuid,p_title text,p_body text) returns integer
language sql security definer set search_path='' as $$
 select public.admin_send_notification_v2(p_request_id,p_target_user,p_title,p_body,true,true);
$$;
create function public.admin_list_users_v2(p_query text default '',p_offset integer default 0,p_limit integer default 50)
returns table (id uuid,email text,display_name text,created_at timestamptz,last_sign_in_at timestamptz,coins integer,blocked boolean,is_admin boolean,public_id text)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if p_offset is null or p_offset < 0 or p_limit is null or p_limit < 1 or p_limit > 100 or length(coalesce(p_query,'')) > 100 then
    raise exception 'Invalid search or page.' using errcode='P0001';
  end if;
  return query select u.id,u.email::text,coalesce(u.raw_user_meta_data->>'full_name',''),u.created_at,u.last_sign_in_at,w.balance,
    coalesce(a.blocked,false),exists(select 1 from public.admin_members m where m.user_id=u.id),i.public_id
    from auth.users u left join growth_internal.user_identifiers i on i.user_id=u.id left join public.wallets w on w.id=u.id left join public.user_access a on a.user_id=u.id
    where pg_catalog.strpos(pg_catalog.lower(coalesce(u.email::text,'') || ' ' || coalesce(u.raw_user_meta_data->>'full_name','') || ' ' || coalesce(i.public_id,'')),pg_catalog.lower(coalesce(p_query,''))) > 0
    order by u.created_at desc,u.id limit p_limit offset p_offset;
end $$;

revoke all on function public.admin_list_users_v2(text,integer,integer) from public,anon;
grant execute on function public.admin_list_users_v2(text,integer,integer) to authenticated;
-- Resolve a public user ID without changing the existing adjustment approval contract.
create function public.admin_request_wallet_adjustment(p_public_id text,p_amount integer,p_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid;
begin
 perform growth_internal.require_admin_editor();
 select user_id into uid from growth_internal.user_identifiers where public_id=p_public_id;
 if uid is null then raise exception 'User ID not found.'; end if;
 return public.admin_request_adjustment(uid,p_amount,p_reason);
end $$;
revoke all on function public.admin_request_wallet_adjustment(text,integer,text) from public,anon;
grant execute on function public.admin_request_wallet_adjustment(text,integer,text) to authenticated;
commit;
