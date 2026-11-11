from admin_test_support import enroll_test_admins, test_claims
"""Isolated disposable PostgreSQL database with all migrations applied."""
import concurrent.futures
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = '50000000-0000-4000-8000-000000000001'
USER = '50000000-0000-4000-8000-000000000002'
OTHER = '50000000-0000-4000-8000-000000000003'

def sql(query, user=USER, fails=False, role='authenticated'):
    prefix = f"set role {role}; "
    if user: prefix += f"select set_config('request.jwt.claim.sub','{user}',false); "
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success: '+query)
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class LookupQuotaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-d',DB,'-c',f"insert into auth.users(id) values ('{ADMIN}'),('{USER}'),('{OTHER}'); insert into public.admin_members(user_id) values ('{ADMIN}')"], check=True, capture_output=True)
        enroll_test_admins(DB)

    def test_quota_concurrency_reset_and_block(self):
        sql('select public.reserve_instagram_lookup()', None, fails=True, role='anon')
        sql('select * from growth_internal.instagram_lookup_limits', USER, fails=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: sql('select public.reserve_instagram_lookup()'), range(30)))
        self.assertEqual(results.count('t'), 20)
        self.assertEqual(results.count('f'), 10)
        self.assertEqual(sql('select public.reserve_instagram_lookup()', OTHER), 't')
        subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-d',DB,'-c',f"update growth_internal.instagram_lookup_limits set window_started_at=now()-interval '2 minutes' where user_id='{USER}'"],check=True,capture_output=True)
        self.assertEqual(sql('select public.reserve_instagram_lookup()'), 't')
        sql(f"select public.admin_set_blocked('{USER}',true)", ADMIN)
        sql('select public.reserve_instagram_lookup()', USER, fails=True)
        self.assertEqual(sql('select public.reserve_instagram_lookup()', OTHER), 't')

if __name__ == '__main__': unittest.main(verbosity=2)
