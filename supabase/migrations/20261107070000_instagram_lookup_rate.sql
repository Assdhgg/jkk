-- Limit lookups per active user; the Meta access token remains server-side.
begin;
create table growth_internal.instagram_lookup_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  attempts integer not null check (attempts >= 0)
);
revoke all on growth_internal.instagram_lookup_limits from public, anon, authenticated;
create function public.reserve_instagram_lookup() returns boolean
language plpgsql security definer set search_path='' as $$
declare current_limit growth_internal.instagram_lookup_limits%rowtype;
begin
  perform growth_internal.require_active();
  select * into current_limit from growth_internal.instagram_lookup_limits where user_id=auth.uid() for update;
  if not found then
    insert into growth_internal.instagram_lookup_limits(user_id,window_started_at,attempts) values(auth.uid(),now(),1);
    return true;
  end if;
  if current_limit.window_started_at <= now()-interval '1 minute' then
    update growth_internal.instagram_lookup_limits set window_started_at=now(),attempts=1 where user_id=auth.uid();
    return true;
  end if;
  if current_limit.attempts >= 20 then return false; end if;
  update growth_internal.instagram_lookup_limits set attempts=attempts+1 where user_id=auth.uid();
  return true;
end $$;
revoke all on function public.reserve_instagram_lookup() from public, anon;
grant execute on function public.reserve_instagram_lookup() to authenticated;
commit;
