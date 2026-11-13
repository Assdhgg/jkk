begin;

create table public.referral_download_link (
  singleton boolean primary key default true check (singleton),
  url text not null check (
    length(url) between 1 and 2048 and
    url ~ '^https://[^/@?#[:space:]\\]+([/?#][^[:space:]\\]*)?$'
  )
);
alter table public.referral_download_link enable row level security;
revoke all on public.referral_download_link from public, anon, authenticated;
grant select on public.referral_download_link to authenticated;
create policy referral_download_link_read on public.referral_download_link
  for select to authenticated using (public.account_access_allowed());

create function public.admin_set_referral_download_link(p_url text) returns void
language plpgsql security definer set search_path = '' as $$
declare link text := pg_catalog.btrim(p_url);
begin
  perform growth_internal.require_admin_editor();
  if p_url is null then
    delete from public.referral_download_link where singleton;
  else
    if length(link) not between 1 and 2048 or
       link !~ '^https://[^/@?#[:space:]\\]+([/?#][^[:space:]\\]*)?$' then
      raise exception 'Enter a valid HTTPS download link.' using errcode = 'P0001';
    end if;
    insert into public.referral_download_link(singleton, url) values (true, link)
      on conflict (singleton) do update set url = excluded.url;
  end if;
  insert into growth_internal.admin_operations_audit(actor_id, action)
    values (auth.uid(), case when p_url is null then 'Referral download link removed' else 'Referral download link updated' end);
end $$;
revoke all on function public.admin_set_referral_download_link(text) from public, anon;
grant execute on function public.admin_set_referral_download_link(text) to authenticated;
commit;
