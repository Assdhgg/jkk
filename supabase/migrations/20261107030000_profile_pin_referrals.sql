-- Profile data and PIN-protected coin release. Apply after admin_access.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table growth_internal.release_pins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pin_hash text not null,
  failures integer not null default 0,
  locked_until timestamptz
);
create table public.instagram_accounts (
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null check (username ~ '^[A-Za-z0-9._]{1,30}$'),
  created_at timestamptz not null default now(),
  primary key (user_id, username)
);
create unique index instagram_accounts_case_unique on public.instagram_accounts (user_id, lower(username));
alter table public.instagram_accounts enable row level security;
revoke all on public.instagram_accounts from public, anon, authenticated;
grant select on public.instagram_accounts to authenticated;
create policy instagram_accounts_read on public.instagram_accounts for select to authenticated
  using (public.account_access_allowed() and user_id=auth.uid());

create table growth_internal.referral_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique default replace(gen_random_uuid()::text, '-', '')
);
create table growth_internal.referrals (
  referred_id uuid primary key references auth.users(id) on delete cascade,
  referrer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (referred_id <> referrer_id)
);
revoke all on growth_internal.release_pins, growth_internal.referral_codes, growth_internal.referrals from public, anon, authenticated;

create function public.add_instagram_account(p_username text) returns void
language plpgsql security definer set search_path='' as $$
declare handle text := regexp_replace(trim(coalesce(p_username,'')), '^@', '');
begin
  perform growth_internal.require_active();
  if handle !~ '^[A-Za-z0-9._]{1,30}$' then raise exception 'Invalid Instagram username.' using errcode='P0001'; end if;
  insert into public.instagram_accounts(user_id,username) values(auth.uid(),handle);
end $$;
create function public.remove_instagram_account(p_username text) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  delete from public.instagram_accounts where user_id=auth.uid() and username=p_username;
end $$;

create function public.referral_info() returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text; total integer; joined boolean;
begin
  perform growth_internal.require_active();
  insert into growth_internal.referral_codes(user_id) values(auth.uid()) on conflict(user_id) do nothing;
  select r.code into code from growth_internal.referral_codes r where r.user_id=auth.uid();
  select count(*) into total from growth_internal.referrals where referrer_id=auth.uid();
  select exists(select 1 from growth_internal.referrals where referred_id=auth.uid()) into joined;
  return jsonb_build_object('code',code,'count',total,'joined',joined);
end $$;
create function public.apply_referral(p_code text) returns void
language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
  perform growth_internal.require_active();
  select user_id into owner_id from growth_internal.referral_codes where code=lower(trim(coalesce(p_code,'')));
  if owner_id is null or owner_id=auth.uid() then raise exception 'Invalid referral code.' using errcode='P0001'; end if;
  insert into growth_internal.referrals(referred_id,referrer_id) values(auth.uid(),owner_id);
end $$;

-- Supabase projects can have pgcrypto installed in different schemas.
create function growth_internal.pin_hash(p_pin text, p_salt text default null) returns text
language plpgsql security definer set search_path='' as $$
declare extension_schema text; result text;
begin
  select n.nspname into extension_schema from pg_catalog.pg_extension e
    join pg_catalog.pg_namespace n on n.oid=e.extnamespace where e.extname='pgcrypto';
  if extension_schema is null then raise exception 'pgcrypto is unavailable.'; end if;
  if p_salt is null then
    execute pg_catalog.format('select %1$I.crypt($1, %1$I.gen_salt(''bf'', 10))', extension_schema) into result using p_pin;
  else
    execute pg_catalog.format('select %I.crypt($1, $2)', extension_schema) into result using p_pin, p_salt;
  end if;
  return result;
end $$;
revoke all on function growth_internal.pin_hash(text,text) from public, anon, authenticated;

-- Incorrect attempts return a status rather than raising, so the lockout commits.
create function growth_internal.check_release_pin(p_pin text) returns text
language plpgsql security definer set search_path='' as $$
declare p growth_internal.release_pins%rowtype;
begin
  select * into p from growth_internal.release_pins where user_id=auth.uid() for update;
  if not found then return 'pin_missing'; end if;
  if p.locked_until > now() then return 'pin_locked'; end if;
  if p_pin is null or p_pin !~ '^[0-9]{4}$' or growth_internal.pin_hash(p_pin,p.pin_hash) <> p.pin_hash then
    update growth_internal.release_pins set failures=case when coalesce(locked_until, '-infinity'::timestamptz) <= now() and failures >= 5 then 1 else failures+1 end,
      locked_until=case when (case when coalesce(locked_until, '-infinity'::timestamptz) <= now() and failures >= 5 then 1 else failures+1 end) >= 5 then now()+interval '15 minutes' else null end
      where user_id=auth.uid();
    return 'invalid_pin';
  end if;
  update growth_internal.release_pins set failures=0, locked_until=null where user_id=auth.uid();
  return 'ok';
end $$;
revoke all on function growth_internal.check_release_pin(text) from public, anon, authenticated;
create function public.release_pin_is_set() returns boolean
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  return exists(select 1 from growth_internal.release_pins where user_id=auth.uid());
end $$;
create function public.set_release_pin(p_pin text, p_current_pin text default null) returns text
language plpgsql security definer set search_path='' as $$
declare result text;
begin
  perform growth_internal.require_active();
  if p_pin is null or p_pin !~ '^[0-9]{4}$' then return 'invalid_format'; end if;
  if exists(select 1 from growth_internal.release_pins where user_id=auth.uid()) then
    result := growth_internal.check_release_pin(p_current_pin);
    if result <> 'ok' then return result; end if;
    update growth_internal.release_pins set pin_hash=growth_internal.pin_hash(p_pin) where user_id=auth.uid();
  else
    insert into growth_internal.release_pins(user_id,pin_hash) values(auth.uid(),growth_internal.pin_hash(p_pin));
  end if;
  return 'ok';
end $$;

-- Disable the old endpoint: it could release coins without a PIN.
revoke execute on function public.review_claim(uuid,uuid,uuid,boolean) from authenticated;
create function public.review_claim_with_pin(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid,p_approve boolean,p_pin text default null) returns text
language plpgsql security definer set search_path='' as $$
declare result text;
begin
  perform growth_internal.require_active();
  if p_approve is null then raise exception 'Choose approve or reject.' using errcode='P0001'; end if;
  if p_approve then
    result := growth_internal.check_release_pin(p_pin);
    if result <> 'ok' then return result; end if;
  end if;
  perform growth_internal.review_claim(p_campaign_id,p_user_id,p_submission_id,p_approve);
  return 'ok';
end $$;
revoke all on function public.add_instagram_account(text), public.remove_instagram_account(text), public.referral_info(), public.apply_referral(text), public.release_pin_is_set(), public.set_release_pin(text,text), public.review_claim_with_pin(uuid,uuid,uuid,boolean,text) from public, anon;
grant execute on function public.add_instagram_account(text), public.remove_instagram_account(text), public.referral_info(), public.apply_referral(text), public.release_pin_is_set(), public.set_release_pin(text,text), public.review_claim_with_pin(uuid,uuid,uuid,boolean,text) to authenticated;
commit;
