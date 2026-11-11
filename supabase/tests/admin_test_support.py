"""Synthetic MFA fixtures for disposable DBs, never used against Supabase."""
import json
import re
import subprocess

def enroll_test_admins(db):
    subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', db, '-c',
        "insert into auth.mfa_factors(id,user_id,status) select gen_random_uuid(),m.user_id,'verified' from public.admin_members m where not exists(select 1 from auth.mfa_factors f where f.user_id=m.user_id and f.status='verified')"], check=True, capture_output=True)

def test_claims(prefix):
    if 'set role authenticated' not in prefix: return prefix
    pattern = r"set_config\('request.jwt.claims','([^']*)',false\)"
    match = re.search(pattern, prefix)
    if match:
        claims = json.loads(match[1]); claims.setdefault('aal', 'aal2')
        return prefix[:match.start(1)] + json.dumps(claims) + prefix[match.end(1):]
    return prefix + "select set_config('request.jwt.claims','{\"aal\":\"aal2\"}',false); "
