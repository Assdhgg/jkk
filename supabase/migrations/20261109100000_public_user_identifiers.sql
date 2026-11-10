begin;
-- Sequences never cycle: exhaustion fails rather than reusing an identifier.
create sequence growth_internal.referral_code_sequence minvalue 0 maxvalue 456975999 start 0 no cycle;
create function growth_internal.next_referral_code() returns text
language plpgsql security definer set search_path='' as $$
declare n bigint := nextval('growth_internal.referral_code_sequence'); letters bigint := n / 1000;
begin
 return chr(65+(letters/17576)::integer)||chr(65+((letters/676)%26)::integer)||
        chr(65+((letters/26)%26)::integer)||chr(65+(letters%26)::integer)||lpad((n%1000)::text,3,'0');
end $$;
revoke all on function growth_internal.next_referral_code() from public,anon,authenticated;
create table growth_internal.legacy_referral_codes (
 code text primary key,
 user_id uuid not null references auth.users(id) on delete cascade
);
insert into growth_internal.legacy_referral_codes select lower(code),user_id from growth_internal.referral_codes;
alter table growth_internal.referral_codes alter column code set default growth_internal.next_referral_code();
update growth_internal.referral_codes set code=growth_internal.next_referral_code();
alter table growth_internal.referral_codes add constraint referral_code_format check(code ~ '^[A-Z]{4}[0-9]{3}$');

create sequence growth_internal.public_user_id_sequence minvalue 10000000 maxvalue 99999999 start 10000000 no cycle;
create table growth_internal.user_identifiers (
 user_id uuid primary key references auth.users(id) on delete cascade,
 public_id text not null unique default nextval('growth_internal.public_user_id_sequence')::text check(public_id ~ '^[1-9][0-9]{7}$')
);
insert into growth_internal.user_identifiers(user_id) select id from auth.users order by created_at,id;
create function growth_internal.assign_public_user_id() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into growth_internal.user_identifiers(user_id) values(new.id);
 return new;
end $$;
create trigger assign_public_user_id after insert on auth.users for each row execute function growth_internal.assign_public_user_id();
revoke all on function growth_internal.assign_public_user_id() from public,anon,authenticated;
revoke all on growth_internal.user_identifiers,growth_internal.legacy_referral_codes from public,anon,authenticated;
revoke all on sequence growth_internal.referral_code_sequence,growth_internal.public_user_id_sequence from public,anon,authenticated;

create or replace function public.referral_info() returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text; total integer; joined boolean; public_id text;
begin
 perform growth_internal.require_active();
 insert into growth_internal.referral_codes(user_id) values(auth.uid()) on conflict(user_id) do nothing;
 select r.code into code from growth_internal.referral_codes r where r.user_id=auth.uid();
 select i.public_id into public_id from growth_internal.user_identifiers i where i.user_id=auth.uid();
 select count(*) into total from growth_internal.referrals where referrer_id=auth.uid();
 select exists(select 1 from growth_internal.referrals where referred_id=auth.uid()) into joined;
 return jsonb_build_object('code',code,'count',total,'joined',joined,'user_id',public_id);
end $$;
create or replace function public.apply_referral(p_code text) returns void
language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 perform growth_internal.require_active();
 select user_id into owner_id from growth_internal.referral_codes where code=upper(trim(coalesce(p_code,'')));
 if owner_id is null then
  select user_id into owner_id from growth_internal.legacy_referral_codes where code=lower(trim(coalesce(p_code,'')));
 end if;
 if owner_id is null or owner_id=auth.uid() then raise exception 'Invalid referral code.' using errcode='P0001'; end if;
 insert into growth_internal.referrals(referred_id,referrer_id) values(auth.uid(),owner_id);
end $$;
commit;
