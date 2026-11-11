begin;
-- Keep one bounded, private profile image per account.
create table growth_internal.profile_photos (
  user_id uuid primary key references auth.users(id) on delete cascade,
  mime_type text not null,
  data_base64 text not null
);
revoke all on growth_internal.profile_photos from public, anon, authenticated;

create function public.profile_photo() returns text
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  return (select data_base64 from growth_internal.profile_photos where user_id=auth.uid());
end $$;
revoke all on function public.profile_photo() from public, anon;
grant execute on function public.profile_photo() to authenticated;

create function public.set_profile_photo(p_mime text, p_data text) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  if not growth_internal.evidence_image_safe(p_mime,p_data) then
    raise exception 'Invalid profile photo';
  end if;
  insert into growth_internal.profile_photos(user_id,mime_type,data_base64)
  values(auth.uid(),p_mime,p_data)
  on conflict(user_id) do update set mime_type=excluded.mime_type,data_base64=excluded.data_base64;
end $$;
revoke all on function public.set_profile_photo(text,text) from public, anon;
grant execute on function public.set_profile_photo(text,text) to authenticated;
commit;
