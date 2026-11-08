begin;
create table public.coin_settings (
 key text primary key check (key in ('registration','follow','like','comment','share','invite','milestone_5','milestone_10','milestone_15')),
 amount integer not null check(amount between 0 and 10000),
 check(key not in ('follow','like','comment','share') or amount >= 1)
);
insert into public.coin_settings values ('registration',10),('follow',1),('like',1),('comment',1),('share',1),('invite',100),('milestone_5',100),('milestone_10',200),('milestone_15',300);
alter table public.coin_settings enable row level security;
revoke all on public.coin_settings from public,anon,authenticated;
grant select on public.coin_settings to authenticated;
create policy settings_read on public.coin_settings for select to authenticated using(public.account_access_allowed());
create table growth_internal.coin_settings_audit(id bigint generated always as identity primary key,actor uuid, key text, amount integer, created_at timestamptz default now());
create function public.admin_set_coin_setting(p_key text,p_amount integer) returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 update public.coin_settings set amount=p_amount where key=p_key;
 if not found then raise exception 'Invalid setting'; end if;
 insert into growth_internal.coin_settings_audit(actor,key,amount) values(auth.uid(),p_key,p_amount);
end $$;
revoke all on function public.admin_set_coin_setting(text,integer) from public,anon;
grant execute on function public.admin_set_coin_setting(text,integer) to authenticated;
alter table public.campaigns add column reward_per_task integer not null default 1 check(reward_per_task between 1 and 10000);
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check(reason in ('welcome','campaign','task','refund','referral'));
create or replace function growth_internal.initialize_wallet() returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); inserted uuid; reward integer;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  select amount into reward from public.coin_settings where key='registration';
  insert into public.wallets(id, balance) values (uid, reward) on conflict do nothing returning id into inserted;
  if inserted is not null then
    insert into public.coin_ledger(user_id, amount, reason) values (uid, reward, 'welcome');
  end if;
end $$;
create or replace function growth_internal.create_campaign(p_type text, p_link text, p_count integer) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); clean text; path text; campaign uuid; available integer; reward integer;
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
  select amount into reward from public.coin_settings where key=p_type;
  select balance into available from public.wallets where id = uid for update;
  if not found then raise exception 'Initialize your account first.' using errcode = 'P0001'; end if;
  if available < p_count*reward then raise exception 'Not enough coins.' using errcode = 'P0001'; end if;
  update public.wallets set balance = balance - p_count*reward where id = uid;
  insert into public.campaigns("ownerId",type,link,requested,remaining,status,reward_per_task)
    values (uid,p_type,'https://www.instagram.com/' || path || '/',p_count,p_count,'active',reward) returning id into campaign;
  insert into public.coin_ledger(user_id, amount, reason, campaign_id) values (uid, -p_count*reward, 'campaign', campaign);
  return campaign;
end $$;
create or replace function growth_internal.review_claim(p_campaign_id uuid, p_user_id uuid, p_submission_id uuid, p_approve boolean) returns void
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
    update public.wallets set balance=balance+c.reward_per_task where id=p_user_id;
    if not found then raise exception 'Participant account is unavailable.' using errcode = 'P0001'; end if;
    update public.campaign_claims set status='approved',reviewed_at=now() where campaign_id=p_campaign_id and user_id=p_user_id;
    update public.campaigns set remaining=c.remaining-1, status=case when c.remaining=1 then 'completed' else 'active' end where id=p_campaign_id;
    insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(p_user_id,c.reward_per_task,'task',p_campaign_id);
  else
    update public.campaign_claims set status='rejected',reviewed_at=now() where campaign_id=p_campaign_id and user_id=p_user_id;
  end if;
  delete from public.claim_evidence where campaign_id=p_campaign_id and user_id=p_user_id;
end $$;
create or replace function growth_internal.cancel_campaign(p_campaign_id uuid) returns void
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
  update public.wallets set balance=balance+c.remaining*c.reward_per_task where id=uid;
  insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(uid,c.remaining*c.reward_per_task,'refund',c.id);
end $$;
-- Preserve milestone consumption even if a referred account is later deleted.
create table growth_internal.referral_milestones (
 referrer_id uuid references auth.users(id) on delete cascade,
 threshold integer check(threshold in (5,10,15)),
 primary key(referrer_id,threshold)
);
-- Historical achievements are recorded without issuing retroactive credits.
insert into growth_internal.referral_milestones
 select referrer_id,threshold from growth_internal.referrals
 cross join (values(5),(10),(15)) as milestones(threshold)
 group by referrer_id,threshold having count(*) >= threshold;
revoke all on growth_internal.referral_milestones from public,anon,authenticated;
create function growth_internal.reward_referral() returns trigger language plpgsql security definer set search_path='' as $$
declare reward integer; bonus integer := 0; total integer;
begin
 -- Serialize all credits and milestone counts for this inviter.
 perform 1 from public.wallets where id=new.referrer_id for update;
 if not found then raise exception 'Inviter wallet missing'; end if;
 select count(*) into total from growth_internal.referrals where referrer_id=new.referrer_id;
 select amount into reward from public.coin_settings where key='invite';
 if total in (5,10,15) then
  insert into growth_internal.referral_milestones values(new.referrer_id,total) on conflict do nothing;
  if found then select amount into bonus from public.coin_settings where key='milestone_'||total; end if;
 end if;
 reward := reward+bonus;
 if reward > 0 then
  update public.wallets set balance=balance+reward where id=new.referrer_id;
  insert into public.coin_ledger(user_id,amount,reason) values(new.referrer_id,reward,'referral');
 end if;
 return new;
end $$;
create trigger referral_reward after insert on growth_internal.referrals for each row execute function growth_internal.reward_referral();
revoke all on function growth_internal.reward_referral() from public,anon,authenticated;
-- OTP authentication time is consumed once, including across refreshed JWTs.
create table growth_internal.pin_otp_used(user_id uuid references auth.users(id) on delete cascade, otp_time bigint, primary key(user_id,otp_time));
create or replace function public.set_release_pin(p_pin text,p_current_pin text default null) returns text language plpgsql security definer set search_path='' as $$
declare verified bigint;
begin
 perform growth_internal.require_active();
 if p_pin is null or p_pin !~ '^[0-9]{4}$' then return 'invalid_format'; end if;
 select max((entry->>'timestamp')::bigint) into verified from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) entry where entry->>'method'='otp';
 if verified is null or verified < extract(epoch from now())-300 or verified > extract(epoch from now())+30 then return 'otp_required'; end if;
 insert into growth_internal.pin_otp_used values(auth.uid(),verified) on conflict do nothing;
 if not found then return 'otp_required'; end if;
 insert into growth_internal.release_pins(user_id,pin_hash) values(auth.uid(),growth_internal.pin_hash(p_pin))
 on conflict(user_id) do update set pin_hash=excluded.pin_hash,failures=0,locked_until=null;
 return 'ok';
end $$;
revoke all on growth_internal.coin_settings_audit,growth_internal.pin_otp_used from public,anon,authenticated;
-- Lock the price until reservation completes, and reject stale displayed prices.
create function public.create_campaign_at_rate(p_type text,p_link text,p_count integer,p_reward integer) returns uuid
language plpgsql security definer set search_path='' as $$
declare current_reward integer;
begin
 perform growth_internal.require_active();
 perform growth_internal.require_action_enabled(p_type);
 select amount into current_reward from public.coin_settings where key=p_type for share;
 if p_reward is null or current_reward is distinct from p_reward then raise exception 'Reward changed. Refresh and try again.'; end if;
 return growth_internal.create_campaign(p_type,p_link,p_count);
end $$;
revoke all on function public.create_campaign_at_rate(text,text,integer,integer) from public,anon;
grant execute on function public.create_campaign_at_rate(text,text,integer,integer) to authenticated;
commit;
