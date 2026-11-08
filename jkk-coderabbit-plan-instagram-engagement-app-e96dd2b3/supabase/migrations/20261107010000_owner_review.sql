-- Owner review replaces immediate rewards for new submissions. Existing claims
-- were already paid and are preserved as self-reported legacy records.
begin;
alter table public.campaign_claims
  add column status text not null default 'legacy' check (status in ('pending','approved','legacy','rejected','withdrawn','cancelled')),
  add column submission_id uuid not null default gen_random_uuid(),
  add column instagram_handle text,
  add column reviewed_at timestamptz;

-- Small, private evidence is kept separately so campaign lists do not download
-- images. Evidence is removed once reviewed or cancelled.
create table public.claim_evidence (
  campaign_id uuid not null,
  user_id uuid not null,
  mime_type text not null check (mime_type in ('image/jpeg','image/png')),
  data_base64 text not null check (length(data_base64) <= 699052),
  primary key (campaign_id, user_id),
  foreign key (campaign_id,user_id) references public.campaign_claims(campaign_id,user_id) on delete cascade
);
alter table public.claim_evidence enable row level security;
revoke all on public.claim_evidence from public, anon, authenticated;

revoke all on public.campaign_claims from public, anon, authenticated;
grant select on public.campaign_claims to authenticated;
create policy claims_read on public.campaign_claims for select to authenticated
  using (user_id = auth.uid() or exists (select 1 from public.campaigns c where c.id = campaign_claims.campaign_id and c."ownerId" = auth.uid()));

-- Keep the old signature but fail closed: old APKs cannot bypass review.
create or replace function public.claim_task(p_campaign_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'Please update the app to submit a task for review.' using errcode = 'P0001';
end $$;

create function public.submit_claim(p_campaign_id uuid, p_instagram_handle text, p_mime text, p_evidence text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid(); c public.campaigns%rowtype; existing_status text;
  clean_handle text := trim(coalesce(p_instagram_handle,'')); raw bytea; pending_count integer;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  if clean_handle !~ '^[A-Za-z0-9._]{1,30}$' then raise exception 'Enter a valid Instagram username.' using errcode = 'P0001'; end if;
  if p_mime is null or p_mime not in ('image/jpeg','image/png') or p_evidence is null or length(p_evidence) > 699052 or p_evidence !~ '^[A-Za-z0-9+/]+={0,2}$' then
    raise exception 'Choose a JPEG or PNG image under 512 KB.' using errcode = 'P0001';
  end if;
  begin raw := decode(p_evidence, 'base64'); exception when others then raise exception 'Invalid image.' using errcode = 'P0001'; end;
  if octet_length(raw) < 16 or octet_length(raw) > 524288 or
     (p_mime = 'image/png' and substring(raw from 1 for 8) <> decode('89504e470d0a1a0a','hex')) or
     (p_mime = 'image/jpeg' and substring(raw from 1 for 3) <> decode('ffd8ff','hex')) then
    raise exception 'Choose a valid JPEG or PNG image under 512 KB.' using errcode = 'P0001';
  end if;
  select * into c from public.campaigns where id = p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  if c."ownerId" = uid then raise exception 'You cannot claim your own campaign.' using errcode = 'P0001'; end if;
  if c.status <> 'active' or c.remaining <= 0 then raise exception 'Campaign is no longer active.' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.wallets w where w.id = uid) then raise exception 'Initialize your account first.' using errcode = 'P0001'; end if;
  select status into existing_status from public.campaign_claims where campaign_id = p_campaign_id and user_id = uid;
  if found and existing_status not in ('rejected','withdrawn') then raise exception 'You already submitted this task.' using errcode = 'P0001'; end if;
  select count(*) into pending_count from public.campaign_claims where campaign_id = p_campaign_id and status = 'pending';
  if pending_count >= c.remaining then raise exception 'All remaining tasks are awaiting review.' using errcode = 'P0001'; end if;
  insert into public.campaign_claims(campaign_id,user_id,status,instagram_handle,reviewed_at,created_at)
    values(p_campaign_id,uid,'pending',clean_handle,null,now())
    on conflict (campaign_id,user_id) do update set status = 'pending', instagram_handle = excluded.instagram_handle, reviewed_at = null, created_at = now(), submission_id = excluded.submission_id;
  insert into public.claim_evidence(campaign_id,user_id,mime_type,data_base64)
    values(p_campaign_id,uid,p_mime,p_evidence)
    on conflict (campaign_id,user_id) do update set mime_type = excluded.mime_type, data_base64 = excluded.data_base64;
end $$;

create function public.get_claim_evidence(p_campaign_id uuid, p_user_id uuid, p_submission_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); result jsonb;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  select jsonb_build_object('mime', e.mime_type, 'data', e.data_base64) into result
  from public.claim_evidence e
  join public.campaign_claims cl on cl.campaign_id=e.campaign_id and cl.user_id=e.user_id
  join public.campaigns c on c.id=e.campaign_id
  where e.campaign_id=p_campaign_id and e.user_id=p_user_id and cl.status='pending' and cl.submission_id=p_submission_id
    and (uid=e.user_id or uid=c."ownerId");
  if result is null then raise exception 'Evidence is unavailable.' using errcode = 'P0001'; end if;
  return result;
end $$;

create function public.withdraw_claim(p_campaign_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); c public.campaigns%rowtype;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  select * into c from public.campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  update public.campaign_claims set status='withdrawn',reviewed_at=now()
    where campaign_id=p_campaign_id and user_id=uid and status='pending';
  if not found then raise exception 'This submission is no longer pending.' using errcode = 'P0001'; end if;
  delete from public.claim_evidence where campaign_id=p_campaign_id and user_id=uid;
end $$;

create function public.review_claim(p_campaign_id uuid, p_user_id uuid, p_submission_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); c public.campaigns%rowtype; cl public.campaign_claims%rowtype;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  if p_approve is null then raise exception 'Choose approve or reject.' using errcode = 'P0001'; end if;
  select * into c from public.campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  if c."ownerId" <> uid then raise exception 'Only the campaign owner can review.' using errcode = 'P0001'; end if;
  if c.status <> 'active' or c.remaining <= 0 then raise exception 'Campaign is no longer active.' using errcode = 'P0001'; end if;
  select * into cl from public.campaign_claims where campaign_id=p_campaign_id and user_id=p_user_id for update;
  if not found or cl.status <> 'pending' or p_submission_id is null or cl.submission_id <> p_submission_id then raise exception 'This submission is no longer pending.' using errcode = 'P0001'; end if;
  if not exists(select 1 from public.claim_evidence where campaign_id=p_campaign_id and user_id=p_user_id) then raise exception 'Evidence is unavailable.' using errcode = 'P0001'; end if;
  if p_approve then
    update public.wallets set balance=balance+1 where id=p_user_id;
    if not found then raise exception 'Participant account is unavailable.' using errcode = 'P0001'; end if;
    update public.campaign_claims set status='approved',reviewed_at=now() where campaign_id=p_campaign_id and user_id=p_user_id;
    update public.campaigns set remaining=c.remaining-1, status=case when c.remaining=1 then 'completed' else 'active' end where id=p_campaign_id;
    insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(p_user_id,1,'task',p_campaign_id);
  else
    update public.campaign_claims set status='rejected',reviewed_at=now() where campaign_id=p_campaign_id and user_id=p_user_id;
  end if;
  delete from public.claim_evidence where campaign_id=p_campaign_id and user_id=p_user_id;
end $$;

create or replace function public.cancel_campaign(p_campaign_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); c public.campaigns%rowtype;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  select * into c from public.campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  if c."ownerId" <> uid then raise exception 'Only the owner can cancel.' using errcode = 'P0001'; end if;
  if c.status <> 'active' then raise exception 'Campaign is no longer active.' using errcode = 'P0001'; end if;
  update public.campaigns set status='cancelled' where id=c.id;
  update public.campaign_claims set status='cancelled',reviewed_at=now() where campaign_id=c.id and status='pending';
  delete from public.claim_evidence where campaign_id=c.id;
  update public.wallets set balance=balance+c.remaining where id=uid;
  insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(uid,c.remaining,'refund',c.id);
end $$;
revoke all on function public.submit_claim(uuid,text,text,text), public.get_claim_evidence(uuid,uuid,uuid), public.withdraw_claim(uuid), public.review_claim(uuid,uuid,uuid,boolean) from public, anon;
grant execute on function public.submit_claim(uuid,text,text,text), public.get_claim_evidence(uuid,uuid,uuid), public.withdraw_claim(uuid), public.review_claim(uuid,uuid,uuid,boolean) to authenticated;
do $$ begin
  if exists (select 1 from pg_publication where pubname='supabase_realtime' and not puballtables) and not exists
    (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='campaign_claims') then
    alter publication supabase_realtime add table public.campaign_claims;
  end if;
end $$;
commit;
