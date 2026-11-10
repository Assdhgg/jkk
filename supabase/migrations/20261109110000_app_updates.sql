begin;
create table public.app_releases (
 id uuid primary key default gen_random_uuid(),
 version_code bigint not null unique check(version_code between 1 and 2100000000),
 version_name text not null check(length(trim(version_name)) between 1 and 60),
 apk_path text not null unique check(apk_path ~ '^[a-f0-9-]{36}\.apk$'),
 sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),
 size_bytes bigint not null check(size_bytes between 1 and 209715200),
 notes text not null default '' check(length(notes)<=4000),
 created_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null
);
alter table public.app_releases enable row level security;
revoke all on public.app_releases from public,anon,authenticated;
grant select on public.app_releases to authenticated;
create policy releases_read on public.app_releases for select to authenticated using(public.account_access_allowed());
create function public.app_release_editor() returns boolean language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); return true; end $$;
revoke all on function public.app_release_editor() from public,anon;
grant execute on function public.app_release_editor() to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('app-releases','app-releases',true,209715200,array['application/vnd.android.package-archive']) on conflict(id) do nothing;
create policy release_upload on storage.objects for insert to authenticated
 with check(bucket_id='app-releases' and name ~ '^[a-f0-9-]{36}\.apk$' and public.app_release_editor());
create policy release_objects_read on storage.objects for select to authenticated
 using(bucket_id='app-releases' and public.app_release_editor());
-- Published files are immutable, including to editors. Only orphaned uploads can be removed.
create policy release_remove_orphan on storage.objects for delete to authenticated
 using(bucket_id='app-releases' and public.app_release_editor() and not exists(select 1 from public.app_releases r where r.apk_path=name));
create function public.admin_publish_app_release(p_version_code bigint,p_version_name text,p_path text,p_sha256 text,p_size bigint,p_notes text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare release_id uuid;
begin
 perform growth_internal.require_admin_editor();
 perform pg_catalog.pg_advisory_xact_lock(89110412);
 if p_version_code <= coalesce((select max(version_code) from public.app_releases),0) then raise exception 'Version code must increase.'; end if;
 if not exists(select 1 from storage.objects where bucket_id='app-releases' and name=p_path and (metadata->>'size')::bigint=p_size) then raise exception 'Upload the APK first; its size must match.'; end if;
 insert into public.app_releases(version_code,version_name,apk_path,sha256,size_bytes,notes,created_by)
 values(p_version_code,p_version_name,p_path,p_sha256,p_size,coalesce(p_notes,''),auth.uid()) returning id into release_id;
 return release_id;
end $$;
revoke all on function public.admin_publish_app_release(bigint,text,text,text,bigint,text) from public,anon;
grant execute on function public.admin_publish_app_release(bigint,text,text,text,bigint,text) to authenticated;
alter table public.notifications add column release_id uuid references public.app_releases(id);
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply','app_update'));
create function growth_internal.notify_app_update() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.notifications(user_id,kind,release_id) select id,'app_update',new.id from public.wallets;
 return new;
end $$;
revoke all on function growth_internal.notify_app_update() from public,anon,authenticated;
create trigger app_update_notification after insert on public.app_releases for each row execute function growth_internal.notify_app_update();
alter publication supabase_realtime add table public.app_releases;
commit;
