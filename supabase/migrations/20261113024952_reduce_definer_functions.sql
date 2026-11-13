begin;

-- These two implementations do not need their owner's privileges. Check the
-- exact existing bodies before changing their execution context.
do $$
begin
  if (select pg_catalog.md5(pg_catalog.regexp_replace(prosrc, '[[:space:]]+', ' ', 'g'))
      from pg_catalog.pg_proc where oid = 'public.claim_task(uuid)'::regprocedure)
       <> '95c9a67bd24520c33e4bc7cb2f065b99' then
    raise exception 'claim_task implementation has changed; review before migration';
  end if;
  if (select pg_catalog.md5(pg_catalog.regexp_replace(prosrc, '[[:space:]]+', ' ', 'g'))
      from pg_catalog.pg_proc where oid = 'public.admin_send_notification(uuid,uuid,text,text)'::regprocedure)
       <> '4a4f7c4947d0803a564ea5ef7e06c3f7' then
    raise exception 'admin_send_notification implementation has changed; review before migration';
  end if;
  if not pg_catalog.has_function_privilege('authenticated', 'public.admin_send_notification_v2(uuid,uuid,text,text,boolean,boolean)', 'EXECUTE')
     or (pg_catalog.has_function_privilege('service_role', 'public.admin_send_notification(uuid,uuid,text,text)', 'EXECUTE')
         and not pg_catalog.has_function_privilege('service_role', 'public.admin_send_notification_v2(uuid,uuid,text,text,boolean,boolean)', 'EXECUTE')) then
    raise exception 'Notification delegate permissions have changed; review before migration';
  end if;
end $$;

-- The obsolete claim RPC always raises its existing update-required error.
alter function public.claim_task(uuid) security invoker;
-- The legacy notification RPC delegates to v2, which enforces editor + MFA.
alter function public.admin_send_notification(uuid,uuid,text,text) security invoker;

commit;
