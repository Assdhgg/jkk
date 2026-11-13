begin;

-- The service-only publisher records the release and referral link atomically.
-- The original RPC remains available to older upload functions.
create function public.publish_r2_app_release_with_referral(
  p_user_id uuid, p_version_code bigint, p_version_name text, p_path text,
  p_sha256 text, p_size bigint, p_notes text, p_url text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare release_id uuid;
begin
  release_id := public.publish_r2_app_release(
    p_user_id, p_version_code, p_version_name, p_path, p_sha256,
    p_size, p_notes, p_url
  );
  insert into public.referral_download_link(singleton, url) values (true, p_url)
    on conflict (singleton) do update set url = excluded.url;
  insert into growth_internal.admin_operations_audit(actor_id, action)
    values (p_user_id, 'Referral download link updated by app release');
  return release_id;
end $$;
revoke all on function public.publish_r2_app_release_with_referral(uuid,bigint,text,text,text,bigint,text,text) from public, anon, authenticated;
grant execute on function public.publish_r2_app_release_with_referral(uuid,bigint,text,text,text,bigint,text,text) to service_role;
commit;
