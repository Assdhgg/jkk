begin;
-- Reserve every issued value permanently, including retired sequential values.
create table growth_internal.identifier_reservations (
 kind text not null check(kind in ('user','referral')),
 value text not null,
 primary key(kind,value)
);
revoke all on growth_internal.identifier_reservations from public,anon,authenticated;
insert into growth_internal.identifier_reservations select 'user',public_id from growth_internal.user_identifiers;
insert into growth_internal.identifier_reservations select 'referral',lower(code) from growth_internal.referral_codes
 union select 'referral',lower(code) from growth_internal.legacy_referral_codes;

create function growth_internal.secure_random_integer(p_bound integer) returns integer
language plpgsql volatile security definer set search_path='' as $$
declare bytes bytea; n bigint; cutoff bigint;
begin
 if p_bound is null or p_bound<1 then raise exception 'Invalid random bound'; end if;
 cutoff := (4294967296::bigint / p_bound) * p_bound;
 loop
  bytes := extensions.gen_random_bytes(4);
  n := get_byte(bytes,0)::bigint*16777216 + get_byte(bytes,1)::bigint*65536 + get_byte(bytes,2)::bigint*256 + get_byte(bytes,3);
  if n<cutoff then return (n % p_bound)::integer; end if;
 end loop;
end $$;
create function growth_internal.random_public_user_id() returns text
language plpgsql volatile security definer set search_path='' as $$
declare candidate text;
begin
 for i in 1..1000 loop
  candidate := (10000000+growth_internal.secure_random_integer(90000000))::text;
  insert into growth_internal.identifier_reservations values('user',candidate) on conflict do nothing;
  if found then return candidate; end if;
 end loop;
 raise exception 'Unable to allocate a unique user ID';
end $$;
create or replace function growth_internal.next_referral_code() returns text
language plpgsql volatile security definer set search_path='' as $$
declare candidate text;
begin
 for i in 1..1000 loop
  candidate := chr(65+growth_internal.secure_random_integer(26)) || chr(65+growth_internal.secure_random_integer(26)) ||
     chr(65+growth_internal.secure_random_integer(26)) || chr(65+growth_internal.secure_random_integer(26)) ||
     lpad(growth_internal.secure_random_integer(1000)::text,3,'0');
  insert into growth_internal.identifier_reservations values('referral',lower(candidate)) on conflict do nothing;
  if found then return candidate; end if;
 end loop;
 raise exception 'Unable to allocate a unique referral code';
end $$;
revoke all on function growth_internal.secure_random_integer(integer),growth_internal.random_public_user_id(),growth_internal.next_referral_code() from public,anon,authenticated;
alter table growth_internal.user_identifiers alter column public_id set default growth_internal.random_public_user_id();
update growth_internal.user_identifiers set public_id=growth_internal.random_public_user_id();
update growth_internal.referral_codes set code=growth_internal.next_referral_code();
-- Predictable old codes must stop working; existing referral relationships stay.
delete from growth_internal.legacy_referral_codes where code ~ '^[a-z]{4}[0-9]{3}$';

create function growth_internal.request_push_delivery() returns bigint
language plpgsql security definer set search_path='' as $$
declare request_id bigint;
begin
 -- Vault/pg_net are configured only on hosted projects. Never expose secrets.
 if to_regclass('vault.decrypted_secrets') is null then return null; end if;
 execute $wake$
  select net.http_post(url := (select decrypted_secret from vault.decrypted_secrets where name='push_delivery_url' limit 1),
   headers := jsonb_build_object('Content-Type','application/json',
    'Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='push_anon_jwt' limit 1),
    'X-Push-Worker-Secret',(select decrypted_secret from vault.decrypted_secrets where name='push_worker_secret' limit 1)),
   body := '{}'::jsonb, timeout_milliseconds := 30000)
  where (select count(*) from vault.decrypted_secrets where name in ('push_delivery_url','push_anon_jwt','push_worker_secret') and nullif(decrypted_secret,'') is not null)=3
 $wake$ into request_id;
 return request_id;
exception when others then
 raise warning 'Push wakeup unavailable; scheduled delivery will retry.';
 return null;
end $$;
create function growth_internal.wake_push_delivery() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from new_notifications n join growth_internal.push_jobs j on j.notification_id=n.id where j.status='pending') then
  perform growth_internal.request_push_delivery();
 end if;
 return null;
end $$;
revoke all on function growth_internal.request_push_delivery(),growth_internal.wake_push_delivery() from public,anon,authenticated;
-- A bulk admin send wakes the worker once, after all row-level jobs exist.
create trigger wake_push_delivery after insert on public.notifications
 referencing new table as new_notifications for each statement execute function growth_internal.wake_push_delivery();
commit;
