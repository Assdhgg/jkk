-- Persist notifications transactionally with the events that produce them.
begin;
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('approved','rejected','coins_received')),
  amount integer check (amount > 0),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check ((kind = 'coins_received') = (amount is not null))
);
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;
revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
create policy notifications_read on public.notifications for select to authenticated
  using (public.account_access_allowed() and user_id = auth.uid());
create policy notifications_mark_read on public.notifications for update to authenticated
  using (public.account_access_allowed() and user_id = auth.uid())
  with check (public.account_access_allowed() and user_id = auth.uid());

create function growth_internal.notify_claim_review() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.status = 'pending' and new.status in ('approved','rejected') then
    insert into public.notifications(user_id,kind) values(new.user_id,new.status);
  end if;
  return new;
end $$;
create trigger claim_review_notification after update of status on public.campaign_claims
  for each row execute function growth_internal.notify_claim_review();

create function growth_internal.notify_coins_received() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.amount > 0 then
    insert into public.notifications(user_id,kind,amount) values(new.user_id,'coins_received',new.amount);
  end if;
  return new;
end $$;
create trigger coin_received_notification after insert on public.coin_ledger
  for each row execute function growth_internal.notify_coins_received();
revoke all on function growth_internal.notify_claim_review(), growth_internal.notify_coins_received() from public, anon, authenticated;
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime' and not puballtables)
     and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
commit;
