from admin_test_support import enroll_test_admins, test_claims
"""Run only against a disposable database with bootstrap and all migrations."""
import base64
import json
import subprocess
import time
import sys
import unittest

from pin_test_support import issue_pin_nonce

DB = sys.argv[1]
sys.argv = sys.argv[:1]
OWNER = '60000000-0000-4000-8000-000000000001'
ACTOR = '60000000-0000-4000-8000-000000000002'
OTHER = '60000000-0000-4000-8000-000000000003'
ADMIN = '60000000-0000-4000-8000-000000000004'
PNG = base64.b64encode(bytes.fromhex('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6360000000020001e221bc330000000049454e44ae426082')).decode()


def sql(query, user=None, role='authenticated', fails=False, claims=None):
    prefix = f'set role {role}; '
    if user:
        prefix += f"select set_config('request.jwt.claim.sub','{user}',false); "
    if claims is not None:
        claims = {'email': 'synthetic@example.test', 'phone':'', **claims}
        prefix += f"select set_config('request.jwt.claims','{json.dumps(claims)}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success: ' + query)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


class NotificationsTests(unittest.TestCase):
    def test_real_review_coin_and_isolation(self):
        values = ','.join(f"('{u}')" for u in [OWNER, ACTOR, OTHER, ADMIN])
        subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', f"insert into auth.users(id) values {values}; insert into public.admin_members(user_id) values ('{ADMIN}')"], check=True, capture_output=True)
        enroll_test_admins(DB)
        for user in [OWNER, ACTOR, OTHER]:
            sql('select public.initialize_wallet()', user)
        self.assertEqual(sql("select count(*) from public.notifications where kind='coins_received' and amount=10", ACTOR), '1')
        pub = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', "select count(*) from pg_publication_tables where pubname='supabase_realtime' and tablename='notifications'"], check=True, capture_output=True, text=True)
        self.assertEqual(pub.stdout.strip(), '1')
        subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', f"begin; insert into public.coin_ledger(user_id,amount,reason) values ('{ACTOR}', 8, 'welcome'); rollback"], check=True, capture_output=True)
        self.assertEqual(sql("select count(*) from public.notifications where amount=8", ACTOR), '0')
        issue_pin_nonce(DB, OWNER)
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')", OWNER, claims={}), 'ok')
        campaign = sql("select public.create_campaign('like','https://instagram.com/p/ABC/',2)", OWNER)
        self.assertEqual(sql("select count(*) from public.notifications", OWNER), '1')  # spend creates no notification
        def submit():
            sql(f"select public.submit_claim('{campaign}','user','image/png','{PNG}')", ACTOR)
            return sql(f"select submission_id from public.campaign_claims where campaign_id='{campaign}' and user_id='{ACTOR}'", ACTOR)
        first = submit()
        sql(f"select public.review_claim_with_pin('{campaign}','{ACTOR}','{first}',false,null)", OWNER)
        self.assertEqual(sql("select count(*) from public.notifications where kind='rejected'", ACTOR), '1')
        second = submit()
        self.assertNotEqual(first, second)
        sql(f"select public.review_claim_with_pin('{campaign}','{ACTOR}','{second}',true,'1234')", OWNER)
        sql(f"select public.review_claim_with_pin('{campaign}','{ACTOR}','{second}',true,'1234')", OWNER, fails=True)
        self.assertEqual(sql("select string_agg(kind,',' order by kind) from public.notifications", ACTOR), 'approved,coins_received,coins_received,rejected')
        self.assertEqual(sql("select count(*) from public.notifications where kind='coins_received' and amount=1", ACTOR), '1')
        self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{ACTOR}'", OTHER), '0')
        sql(f"insert into public.notifications(user_id,kind) values ('{ACTOR}','approved')", ACTOR, fails=True)
        sql("update public.notifications set kind='approved'", ACTOR, fails=True)
        sql(f"update public.notifications set read_at=now() where user_id='{ACTOR}'", OTHER)
        self.assertEqual(sql("select count(*) from public.notifications where read_at is not null", ACTOR), '0')
        sql("update public.notifications set read_at=now() where kind='rejected'", ACTOR)
        self.assertEqual(sql("select count(*) from public.notifications where read_at is not null", ACTOR), '1')
        sql('select * from public.notifications', role='anon', fails=True)
        sql(f"select public.admin_set_blocked('{ACTOR}',true)", ADMIN)
        self.assertEqual(sql('select count(*) from public.notifications', ACTOR), '0')
        sql("update public.notifications set read_at=null", ACTOR)
        sql(f"select public.admin_set_blocked('{ACTOR}',false)", ADMIN)
        self.assertEqual(sql("select count(*) from public.notifications where read_at is not null", ACTOR), '1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
