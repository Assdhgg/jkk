-- Existing releases remain in Supabase Storage. R2 releases are published only
-- by the server after it has copied a verified upload to an immutable key.
begin;
alter table public.app_releases add column storage_provider text not null default 'supabase' check (storage_provider in ('supabase','r2'));
alter table public.app_releases add column download_url text;
alter table public.app_releases add constraint app_releases_location_check check (
 (storage_provider = 'supabase' and download_url is null) or
 (storage_provider = 'r2' and download_url is not null and download_url ~ '^https://[^/@?#]+/[^?#]+$' and length(download_url) <= 2048)
);

-- Only the Edge Function's service role can attest that the object was copied.
create function public.publish_r2_app_release(p_user_id uuid,p_version_code bigint,p_version_name text,p_path text,p_sha256 text,p_size bigint,p_notes text,p_url text) returns uuid
language plpgsql security definer set search_path='' as $$
declare release_id uuid;
begin
 perform pg_catalog.pg_advisory_xact_lock(89110412);
 if p_version_code <= coalesce((select max(version_code) from public.app_releases),0) then raise exception 'Version code must increase.'; end if;
 insert into public.app_releases(version_code,version_name,apk_path,sha256,size_bytes,notes,created_by,storage_provider,download_url)
 values(p_version_code,p_version_name,p_path,p_sha256,p_size,coalesce(p_notes,''),p_user_id,'r2',p_url) returning id into release_id;
 return release_id;
end $$;
revoke all on function public.publish_r2_app_release(uuid,bigint,text,text,text,bigint,text,text) from public,anon,authenticated;
grant execute on function public.publish_r2_app_release(uuid,bigint,text,text,text,bigint,text,text) to service_role;
commit;
