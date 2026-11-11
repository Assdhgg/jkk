begin;
create function growth_internal.profile_image_safe(p_mime text,p_data text) returns boolean
language plpgsql immutable set search_path='' as $$
declare raw bytea; n integer; pos integer; size bigint; marker integer;
 width bigint; height bigint; kind bytea; saw_data boolean := false;
begin
 if p_data is null or length(p_data)>6990508 or p_mime is null then return false; end if;
 raw := decode(p_data,'base64'); n := octet_length(raw);
 if n<24 or n>5242880 then return false; end if;
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
revoke all on function growth_internal.profile_image_safe(text,text) from public,anon,authenticated;
create or replace function public.set_profile_photo(p_mime text, p_data text) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  if not growth_internal.profile_image_safe(p_mime,p_data) then
    raise exception 'Invalid profile photo';
  end if;
  insert into growth_internal.profile_photos(user_id,mime_type,data_base64)
  values(auth.uid(),p_mime,p_data)
  on conflict(user_id) do update set mime_type=excluded.mime_type,data_base64=excluded.data_base64;
end $$;

create function public.verify_security_pin(p_pin text) returns text
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 return growth_internal.check_release_pin(p_pin);
end $$;
revoke all on function public.verify_security_pin(text) from public, anon;
grant execute on function public.verify_security_pin(text) to authenticated;
commit;
