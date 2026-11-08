"""Run against an isolated PostgreSQL database after bootstrap and migration."""
import concurrent.futures
import subprocess
import sys
import unittest

OWNER = '00000000-0000-0000-0000-000000000001'
ACTOR = '00000000-0000-0000-0000-000000000002'
OTHER = '00000000-0000-0000-0000-000000000003'
DB = sys.argv[1] if len(sys.argv) > 1 else 'growth_circle_test'
sys.argv = sys.argv[:1]

def sql(statement, user=None, role='authenticated', fail=False):
    prefix = f"set role {role}; "
    if user:
        prefix += f"select set_config('request.jwt.claim.sub', '{user}', false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix + statement], capture_output=True, text=True)
    if fail:
        if result.returncode == 0:
            raise AssertionError(f'Expected failure: {statement}')
    elif result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip().splitlines()[-1:] or ['']

def balance(uid):
    return int(sql(f"select balance from public.wallets where id = '{uid}'", uid)[0])

def create(owner=OWNER, count=3):
    return sql(f"select public.create_campaign('like','https://instagram.com/p/ABC/?source=x',{count})", owner)[0]

class DatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['psql','-X','-q','-v','ON_ERROR_STOP=1','-d',DB,'-c',f"insert into auth.users(id) values ('{OWNER}'),('{ACTOR}'),('{OTHER}')"],check=True)
        for user in (OWNER, ACTOR, OTHER): sql('select public.initialize_wallet()', user)

    def test_01_initialize_idempotent(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: sql('select public.initialize_wallet()', OWNER), range(4)))
        self.assertEqual(balance(OWNER), 10)
        self.assertEqual(sql("select count(*) from public.coin_ledger where reason = 'welcome'", OWNER)[0], '1')
        sql('select public.initialize_wallet()', role='anon', fail=True)

    def test_02_claim_and_refund(self):
        cid = create()
        self.assertEqual(balance(OWNER), 7)
        self.assertEqual(sql(f"select link from public.campaigns where id = '{cid}'", OWNER)[0], 'https://www.instagram.com/p/ABC/')
        sql(f"select public.claim_task('{cid}')", OWNER, fail=True)
        sql(f"select public.claim_task('{cid}')", ACTOR)
        sql(f"select public.claim_task('{cid}')", ACTOR, fail=True)
        self.assertEqual(balance(ACTOR), 11)
        sql(f"select public.cancel_campaign('{cid}')", OTHER, fail=True)
        sql(f"select public.cancel_campaign('{cid}')", OWNER)
        sql(f"select public.cancel_campaign('{cid}')", OWNER, fail=True)
        self.assertEqual(balance(OWNER), 9)
        self.assertEqual(sql(f"select remaining from public.campaigns where id = '{cid}'", OWNER)[0], '2')

    def test_03_concurrent_claims(self):
        cid = create(count=1)
        def claim(uid):
            try: sql(f"select public.claim_task('{cid}')", uid); return True
            except AssertionError: return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            results = list(pool.map(claim, [ACTOR, ACTOR, OTHER]))
        self.assertEqual(sum(results), 1)
        self.assertEqual(sql(f"select remaining || ':' || status from public.campaigns where id = '{cid}'", OWNER)[0], '0:completed')

    def test_04_cancel_claim_race(self):
        before = balance(OWNER) + balance(ACTOR)
        cid = create(count=2)
        def attempt(args):
            try: sql(*args)
            except AssertionError: pass
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(attempt, [(f"select public.claim_task('{cid}')", ACTOR), (f"select public.cancel_campaign('{cid}')", OWNER)]))
        self.assertEqual(balance(OWNER) + balance(ACTOR), before)
        self.assertEqual(sql(f"select status from public.campaigns where id = '{cid}'", OWNER)[0], 'cancelled')

    def test_05_invalid_and_permissions(self):
        for link in ('https://evil.com/p/abc', 'http://instagram.com/p/abc', 'https://instagram.com.evil.com/p/abc', 'https://instagram.com/user/'):
            sql(f"select public.create_campaign('like','{link}',1)", OWNER, fail=True)
        sql("select public.create_campaign('follow','https://instagram.com/user/',100)", OWNER, fail=True)
        sql(f"update public.wallets set balance = 100 where id = '{OWNER}'", OWNER, fail=True)
        sql("insert into public.campaigns(type, link, requested, remaining, status) values ('like','x',1,1,'active')", OWNER, fail=True)
        self.assertEqual(sql(f"select count(*) from public.wallets where id = '{OWNER}'", OTHER)[0], '0')
        self.assertEqual(sql(f"select count(*) from public.coin_ledger where user_id = '{OWNER}'", OTHER)[0], '0')
        sql('select * from public.campaigns', role='anon', fail=True)

if __name__ == '__main__': unittest.main(verbosity=2)
