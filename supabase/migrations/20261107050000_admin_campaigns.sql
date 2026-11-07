-- Campaign details and account emails are already visible to administrators.
begin;
create function public.admin_list_campaigns(p_type text default null, p_status text default null, p_offset integer default 0, p_limit integer default 30)
returns table(id uuid, owner_id uuid, owner_email text, type text, link text, status text, requested integer, remaining integer, created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if (p_type is not null and p_type not in ('follow','like','share','comment')) or
     (p_status is not null and p_status not in ('active','completed','cancelled')) or
     p_offset is null or p_offset < 0 or p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'Invalid campaign filter or page.' using errcode='P0001';
  end if;
  return query
    select c.id,c."ownerId",u.email::text,c.type,c.link,c.status,c.requested,c.remaining,c."createdAt"
    from public.campaigns c left join auth.users u on u.id=c."ownerId"
    where (p_type is null or c.type=p_type) and (p_status is null or c.status=p_status)
    order by c."createdAt" desc,c.id desc limit p_limit offset p_offset;
end $$;
revoke all on function public.admin_list_campaigns(text,text,integer,integer) from public, anon;
grant execute on function public.admin_list_campaigns(text,text,integer,integer) to authenticated;
commit;
