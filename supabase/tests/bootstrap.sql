-- Only for an isolated local PostgreSQL test database; never run against Supabase.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (
 id uuid primary key,
 email text default 'synthetic@example.test',
 phone text default '',
 email_confirmed_at timestamptz default now(),
 created_at timestamptz default now(),
 last_sign_in_at timestamptz,
 reauthentication_token varchar default '',
 reauthentication_sent_at timestamptz,
 raw_user_meta_data jsonb default '{}'::jsonb
);
create table auth.one_time_tokens (
 user_id uuid references auth.users(id) on delete cascade,
 token_type text not null,
 token_hash text
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
create publication supabase_realtime;

-- Mock only: production auth.jwt() is provided by Supabase and verifies signed JWTs.
create function auth.jwt() returns jsonb language sql stable as $$
 select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
