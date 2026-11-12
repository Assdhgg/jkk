begin;
create function public.admin_push_readiness(p_target_user uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 return (select jsonb_build_object('users',count(distinct u.id),'users_with_devices',count(distinct t.user_id),'devices',count(t.id))
 from auth.users u left join growth_internal.push_tokens t on t.user_id=u.id
 where u.email_confirmed_at is not null and (p_target_user is null or u.id=p_target_user)
 and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked));
end $$;
revoke all on function public.admin_push_readiness(uuid) from public,anon;
grant execute on function public.admin_push_readiness(uuid) to authenticated;
create or replace function public.admin_send_notification_v2(p_request_id uuid,p_target_user uuid,p_title text,p_body text,p_in_app boolean,p_push boolean)
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
 if p_push and not p_in_app and not exists(
  select 1 from growth_internal.push_tokens t join auth.users u on u.id=t.user_id
  where u.email_confirmed_at is not null and (p_target_user is null or u.id=p_target_user)
  and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked)
 ) then raise exception 'No push-enabled devices. Users must sign in and enable push notifications.'; end if;
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


commit;
