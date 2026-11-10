-- Disposable database only: bootstrap and all migrations are required.
begin;
insert into auth.users(id) select ('90000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,2000) n;
insert into growth_internal.referral_codes(user_id) select id from auth.users where id::text like '90000000-%';
do $$
begin
 if (select count(distinct public_id) from growth_internal.user_identifiers where user_id::text like '90000000-%') <> 2000 then raise exception 'Duplicate/missing IDs'; end if;
 if exists(select 1 from growth_internal.user_identifiers where public_id !~ '^[1-9][0-9]{7}$') then raise exception 'Bad ID format'; end if;
 if (select count(distinct code) from growth_internal.referral_codes where user_id::text like '90000000-%') <> 2000 then raise exception 'Duplicate/missing referral codes'; end if;
 if exists(select 1 from growth_internal.referral_codes where code !~ '^[A-Z]{4}[0-9]{3}$') then raise exception 'Bad referral format'; end if;
 if has_table_privilege('authenticated','growth_internal.user_identifiers','select') then raise exception 'Private identifiers leaked'; end if;
 begin
  update growth_internal.user_identifiers set public_id=(select public_id from growth_internal.user_identifiers limit 1) where user_id='90000000-0000-4000-8000-000000002000';
  raise exception 'Duplicate ID accepted';
 exception when unique_violation then null; end;
 begin
  update growth_internal.referral_codes set code=(select code from growth_internal.referral_codes limit 1) where user_id='90000000-0000-4000-8000-000000002000';
  raise exception 'Duplicate code accepted';
 exception when unique_violation then null; end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"email":"synthetic@example.test","phone":""}',true);
do $$ declare info jsonb; begin
 info := public.referral_info();
 if info->>'code' !~ '^[A-Z]{4}[0-9]{3}$' or info->>'user_id' !~ '^[1-9][0-9]{7}$' then raise exception 'RPC identifiers invalid'; end if;
end $$;
rollback;
