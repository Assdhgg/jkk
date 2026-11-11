begin;
-- Only the Auth service issues the nonce via GET /reauthenticate and its
-- Reauthentication email template. Match Auth v2.197.0 SHA-224(email || nonce).
-- This is an internal Auth schema integration; recheck it on Auth upgrades.
create table growth_internal.pin_reauthentication_attempts (
 user_id uuid primary key references auth.users(id) on delete cascade,
 sent_at timestamptz not null,
 failures integer not null default 0 check(failures between 0 and 5)
);
revoke all on growth_internal.pin_reauthentication_attempts from public,anon,authenticated;

-- Retire the former Magic Link / OTP-AMR authorization path. Existing PIN
-- hashes and the coin release lockout are unchanged; older apps need updating.
create or replace function public.set_release_pin(p_pin text,p_current_pin text default null)
returns text language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 return 'otp_required';
end $$;

create function public.set_release_pin_reauthenticated(p_pin text,p_nonce text)
returns text language plpgsql security definer set search_path='' as $$
declare account auth.users%rowtype; attempts integer; claims jsonb := auth.jwt();
begin
 perform growth_internal.require_active();
 if p_pin is null or p_pin !~ '^[0-9]{4}$' then return 'invalid_format'; end if;
 -- Lock serializes verification, resend and consumption across concurrent calls.
 select * into account from auth.users where id=auth.uid() for update;
 if account.email_confirmed_at is null or nullif(account.email,'') is null
    or lower(coalesce(claims->>'email','')) <> lower(account.email)
    or coalesce(account.phone,'') <> '' or coalesce(claims->>'phone','') <> '' then
  return 'email_otp_required';
 end if;
 if nullif(account.reauthentication_token,'') is null
    or account.reauthentication_sent_at is null
    or account.reauthentication_sent_at < now()-interval '5 minutes'
    or account.reauthentication_sent_at > now()+interval '30 seconds' then
  return 'otp_required';
 end if;
 insert into growth_internal.pin_reauthentication_attempts(user_id,sent_at,failures)
 values(auth.uid(),account.reauthentication_sent_at,0)
 on conflict(user_id) do update set sent_at=excluded.sent_at,failures=0
 where pin_reauthentication_attempts.sent_at <> excluded.sent_at;
 select failures into attempts from growth_internal.pin_reauthentication_attempts where user_id=auth.uid();
 if attempts>=5 then return 'otp_required'; end if;
 if p_nonce is null or p_nonce !~ '^[0-9]{6}$'
    or encode(extensions.digest(account.email || p_nonce,'sha224'),'hex') <> account.reauthentication_token then
  update growth_internal.pin_reauthentication_attempts set failures=failures+1 where user_id=auth.uid();
  if attempts>=4 then
   update auth.users set reauthentication_token='' where id=auth.uid();
   delete from auth.one_time_tokens where user_id=auth.uid() and token_type='reauthentication_token';
  end if;
  return 'otp_required';
 end if;
 update auth.users set reauthentication_token='' where id=auth.uid();
 delete from auth.one_time_tokens where user_id=auth.uid() and token_type='reauthentication_token';
 insert into growth_internal.release_pins(user_id,pin_hash)
 values(auth.uid(),growth_internal.pin_hash(p_pin))
 on conflict(user_id) do update set pin_hash=excluded.pin_hash,failures=0,locked_until=null;
 return 'ok';
end $$;
revoke all on function public.set_release_pin_reauthenticated(text,text) from public,anon;
grant execute on function public.set_release_pin_reauthenticated(text,text) to authenticated;
commit;
