-- Apply after coin_settings_referrals_pin_otp. Preserve existing PINs/rewards.
begin;
-- The application requires confirmed email signup. Do not let direct API or
-- anonymous Auth sessions bypass that UI and mint registration/referral coins.
create or replace function public.account_access_allowed() returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null
 and coalesce(auth.jwt()->>'is_anonymous','false') <> 'true'
 and exists(select 1 from auth.users u where u.id=auth.uid()
   and nullif(u.email,'') is not null and u.email_confirmed_at is not null)
 and not exists(select 1 from public.user_access a where a.user_id=auth.uid() and a.blocked);
$$;
create or replace function public.set_release_pin(p_pin text,p_current_pin text default null) returns text language plpgsql security definer set search_path='' as $$
declare verified bigint; account_email text; account_phone text; confirmed timestamptz; claims jsonb := auth.jwt();
begin
 perform growth_internal.require_active();
 -- This application's PIN factor is email OTP. Generic 'otp' AMR also
 -- represents SMS; deny phone-linked identities rather than accepting SMS.
 select email,phone,email_confirmed_at into account_email,account_phone,confirmed from auth.users where id=auth.uid();
 if confirmed is null or nullif(account_email,'') is null
    or lower(coalesce(claims->>'email','')) <> lower(account_email)
    or coalesce(account_phone,'') <> '' or coalesce(claims->>'phone','') <> '' then
  return 'email_otp_required';
 end if;
 if jsonb_typeof(claims->'amr') is distinct from 'array' then return 'otp_required'; end if;
 if p_pin is null or p_pin !~ '^[0-9]{4}$' then return 'invalid_format'; end if;
 select max((entry->>'timestamp')::bigint) into verified
 from jsonb_array_elements(claims->'amr') entry
 where entry->>'method'='otp' and entry->>'timestamp' ~ '^[0-9]{1,12}$';
 if verified is null or verified < extract(epoch from now())-300 or verified > extract(epoch from now())+30 then return 'otp_required'; end if;
 insert into growth_internal.pin_otp_used values(auth.uid(),verified) on conflict do nothing;
 if not found then return 'otp_required'; end if;
 insert into growth_internal.release_pins(user_id,pin_hash) values(auth.uid(),growth_internal.pin_hash(p_pin))
 on conflict(user_id) do update set pin_hash=excluded.pin_hash,failures=0,locked_until=null;
 return 'ok';
end $$;

-- Check encoded image metadata before allowing storage. Existing rows stay
-- readable for rejection/removal; updated clients also validate historical data.
create function growth_internal.evidence_image_safe(p_mime text,p_data text) returns boolean
language plpgsql immutable set search_path='' as $$
declare raw bytea; n integer; pos integer; size bigint; marker integer;
 width bigint; height bigint; kind bytea; saw_data boolean := false;
begin
 if p_data is null or length(p_data)>699052 or p_mime is null then return false; end if;
 raw := decode(p_data,'base64'); n := octet_length(raw);
 if n<24 or n>524288 then return false; end if;
 if p_mime='image/png' then
  if substring(raw from 1 for 8) <> decode('89504e470d0a1a0a','hex') or
     substring(raw from 9 for 8) <> decode('0000000d49484452','hex') then return false; end if;
  width := (get_byte(raw,16)::bigint<<24)+(get_byte(raw,17)<<16)+(get_byte(raw,18)<<8)+get_byte(raw,19);
  height := (get_byte(raw,20)::bigint<<24)+(get_byte(raw,21)<<16)+(get_byte(raw,22)<<8)+get_byte(raw,23);
  if width not between 1 and 4096 or height not between 1 and 4096 then return false; end if;
  pos := 8;
  while pos+12<=n loop
   size := (get_byte(raw,pos)::bigint<<24)+(get_byte(raw,pos+1)<<16)+(get_byte(raw,pos+2)<<8)+get_byte(raw,pos+3);
   if size>n-pos-12 then return false; end if;
   kind := substring(raw from pos+5 for 4);
   -- Animation is not a screenshot and can exhaust decoder resources.
   if kind=decode('6163544c','hex') then return false; end if;
   if kind=decode('49484452','hex') and pos<>8 then return false; end if;
   if kind=decode('49444154','hex') then saw_data := true; end if;
   pos := pos+size::integer+12;
   if kind=decode('49454e44','hex') then return saw_data and size=0 and pos=n; end if;
  end loop;
  return false;
 elsif p_mime='image/jpeg' then
  if substring(raw from 1 for 2) <> decode('ffd8','hex') then return false; end if;
  pos := 2;
  while pos<n loop
   if get_byte(raw,pos)<>255 then return false; end if;
   while pos<n and get_byte(raw,pos)=255 loop pos:=pos+1; end loop;
   if pos>=n then return false; end if;
   marker:=get_byte(raw,pos); pos:=pos+1;
   if marker in (0,216,217,218) then return false; end if;
   if marker=1 or marker between 208 and 215 then continue; end if;
   if pos+2>n then return false; end if;
   size:=(get_byte(raw,pos)<<8)+get_byte(raw,pos+1);
   if size<2 or size>n-pos then return false; end if;
   if marker in (192,193,194,195,197,198,199,201,202,203,205,206,207) then
    if size<8 then return false; end if;
    height:=(get_byte(raw,pos+3)<<8)+get_byte(raw,pos+4);
    width:=(get_byte(raw,pos+5)<<8)+get_byte(raw,pos+6);
    return width between 1 and 4096 and height between 1 and 4096;
   end if;
   pos:=pos+size::integer;
  end loop;
 end if;
 return false;
exception when others then return false;
end $$;
revoke all on function growth_internal.evidence_image_safe(text,text) from public,anon,authenticated;
alter table public.claim_evidence add constraint evidence_image_bounded
 check(growth_internal.evidence_image_safe(mime_type,data_base64)) not valid;
commit;
