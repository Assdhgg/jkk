-- Only server-side functions may mutate coins and campaigns.
create table public.wallets (
  id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null check (balance >= 0),
  "createdAt" timestamptz not null default now()
);
create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  "ownerId" uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('follow', 'like', 'comment', 'share')),
  link text not null,
  requested integer not null check (requested between 1 and 100),
  remaining integer not null check (remaining between 0 and requested),
  status text not null check (status in ('active', 'completed', 'cancelled')),
  "createdAt" timestamptz not null default now()
);
create table public.campaign_claims (
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (campaign_id, user_id)
);
create table public.coin_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null,
  reason text not null check (reason in ('welcome', 'campaign', 'task', 'refund')),
  campaign_id uuid references public.campaigns(id) on delete set null,
  "createdAt" timestamptz not null default now()
);
create index campaigns_owner_idx on public.campaigns ("ownerId");
create index ledger_user_idx on public.coin_ledger (user_id);
alter table public.wallets enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_claims enable row level security;
alter table public.coin_ledger enable row level security;
revoke all on public.wallets, public.campaigns, public.campaign_claims, public.coin_ledger from public, anon, authenticated;
grant select on public.wallets, public.campaigns, public.coin_ledger to authenticated;
create policy wallet_read on public.wallets for select to authenticated using (id = auth.uid());
create policy campaigns_read on public.campaigns for select to authenticated using (auth.uid() is not null);
create policy ledger_read on public.coin_ledger for select to authenticated using (user_id = auth.uid());

create function public.initialize_wallet() returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); inserted uuid;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  insert into public.wallets(id, balance) values (uid, 10) on conflict do nothing returning id into inserted;
  if inserted is not null then
    insert into public.coin_ledger(user_id, amount, reason) values (uid, 10, 'welcome');
  end if;
end $$;

create function public.create_campaign(p_type text, p_link text, p_count integer) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); clean text; path text; campaign uuid; available integer;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  if p_type is null or p_type not in ('follow','like','comment','share') then raise exception 'Choose a task type.' using errcode = 'P0001'; end if;
  if p_count is null or p_count < 1 or p_count > 100 then raise exception 'Task count must be between 1 and 100.' using errcode = 'P0001'; end if;
  if p_link is null or length(p_link) > 500 then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  clean := regexp_replace(trim(p_link), '[?#].*$', '');
  if clean !~* '^https://(www\.)?instagram\.com/' then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  path := regexp_replace(clean, '^https://(www\.)?instagram\.com/', '', 'i');
  path := regexp_replace(path, '/+$', '');
  if p_type = 'follow' then
    if path !~ '^[A-Za-z0-9._]{1,30}$' or lower(path) in ('p','reel','reels','stories','explore','accounts') then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  else
    if path !~ '^(p|reel)/[A-Za-z0-9_-]+$' then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  end if;
  select balance into available from public.wallets where id = uid for update;
  if not found then raise exception 'Initialize your account first.' using errcode = 'P0001'; end if;
  if available < p_count then raise exception 'Not enough coins.' using errcode = 'P0001'; end if;
  update public.wallets set balance = balance - p_count where id = uid;
  insert into public.campaigns("ownerId",type,link,requested,remaining,status)
    values (uid,p_type,'https://www.instagram.com/' || path || '/',p_count,p_count,'active') returning id into campaign;
  insert into public.coin_ledger(user_id, amount, reason, campaign_id) values (uid, -p_count, 'campaign', campaign);
  return campaign;
end $$;

create function public.claim_task(p_campaign_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); c public.campaigns%rowtype;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  select * into c from public.campaigns where id = p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  if c."ownerId" = uid then raise exception 'You cannot claim your own campaign.' using errcode = 'P0001'; end if;
  if exists(select 1 from public.campaign_claims where campaign_id = c.id and user_id = uid) then raise exception 'You already claimed this task.' using errcode = 'P0001'; end if;
  if c.status <> 'active' or c.remaining <= 0 then raise exception 'Campaign is no longer active.' using errcode = 'P0001'; end if;
  update public.wallets set balance = balance + 1 where id = uid;
  if not found then raise exception 'Initialize your account first.' using errcode = 'P0001'; end if;
  insert into public.campaign_claims(campaign_id,user_id) values(c.id,uid);
  update public.campaigns set remaining = c.remaining - 1, status = case when c.remaining = 1 then 'completed' else 'active' end where id = c.id;
  insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(uid,1,'task',c.id);
end $$;

create function public.cancel_campaign(p_campaign_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); c public.campaigns%rowtype;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  select * into c from public.campaigns where id = p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  if c."ownerId" <> uid then raise exception 'Only the owner can cancel.' using errcode = 'P0001'; end if;
  if c.status <> 'active' then raise exception 'Campaign is no longer active.' using errcode = 'P0001'; end if;
  update public.campaigns set status = 'cancelled' where id = c.id;
  update public.wallets set balance = balance + c.remaining where id = uid;
  insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(uid,c.remaining,'refund',c.id);
end $$;
revoke all on function public.initialize_wallet(), public.create_campaign(text,text,integer), public.claim_task(uuid), public.cancel_campaign(uuid) from public, anon;
grant execute on function public.initialize_wallet(), public.create_campaign(text,text,integer), public.claim_task(uuid), public.cancel_campaign(uuid) to authenticated;
-- Realtime backs the app's balance, task and history streams.
do $$ declare table_name text; begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime' and not puballtables) then
    foreach table_name in array array['wallets','campaigns','coin_ledger'] loop
      if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = table_name) then
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      end if;
    end loop;
  end if;
end $$;
