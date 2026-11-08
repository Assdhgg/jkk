"""Run against an isolated disposable database with all four migrations applied."""
import json
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
OWNER = '20000000-0000-4000-8000-000000000001'
ACTOR = '20000000-0000-4000-8000-000000000002'
OTHER = '20000000-0000-4000-8000-000000000003'
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='

def sql(query, user=OWNER, fails=False):
    prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    r = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix + query], capture_output=True, text=True)
    if fails:
        if r.returncode == 0: raise AssertionError('Unexpected success: ' + query)
    elif r.returncode: raise AssertionError(r.stderr)
    return (r.stdout.strip().splitlines() or [''])[-1]

class ProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', f"insert into auth.users(id) values ('{OWNER}'),('{ACTOR}'),('{OTHER}')"], check=True, capture_output=True)
        for user in (OWNER, ACTOR, OTHER): sql('select public.initialize_wallet()', user)

    def test_accounts_and_referrals(self):
        for n in range(12): sql(f"select public.add_instagram_account('@account{n}')")
        self.assertEqual(sql('select count(*) from public.instagram_accounts'), '12')
        self.assertEqual(sql('select count(*) from public.instagram_accounts', ACTOR), '0')
        sql("select public.add_instagram_account('ACCOUNT0')", fails=True)
        sql("select public.add_instagram_account('bad handle')", fails=True)
        sql("delete from public.instagram_accounts", fails=True)
        sql("select public.remove_instagram_account('account0')")
        self.assertEqual(sql('select count(*) from public.instagram_accounts'), '11')
        info = json.loads(sql('select public.referral_info()'))
        sql(f"select public.apply_referral('{info['code']}')", OWNER, fails=True)
        sql(f"select public.apply_referral('{info['code']}')", ACTOR)
        sql(f"select public.apply_referral('{info['code']}')", ACTOR, fails=True)
        self.assertEqual(json.loads(sql('select public.referral_info()'))['count'], 1)
        self.assertTrue(json.loads(sql('select public.referral_info()', ACTOR))['joined'])
        self.assertEqual(sql('select balance from public.wallets', ACTOR), '10')

    def test_coin_release_guard_and_lockout(self):
        cid = sql("select public.create_campaign('like','https://instagram.com/p/ABC/',2)")
        sql(f"select public.submit_claim('{cid}','actor','image/png','{PNG}')", ACTOR)
        sid = sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}'", OWNER)
        call = lambda pin: f"select public.review_claim_with_pin('{cid}','{ACTOR}','{sid}',true,{pin})"
        sql(f"select public.review_claim('{cid}','{ACTOR}','{sid}',true)", fails=True)
        self.assertEqual(sql(call('null')), 'pin_missing')
        self.assertEqual(sql("select public.set_release_pin('1234',null)"), 'ok')
        self.assertEqual(sql("select public.set_release_pin('9876','0000')"), 'invalid_pin')
        for _ in range(4): self.assertEqual(sql(call("'0000'")), 'invalid_pin')
        self.assertEqual(sql(call("'1234'")), 'pin_locked')
        self.assertEqual(sql('select balance from public.wallets', ACTOR), '10')
        subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', f"update growth_internal.release_pins set locked_until=now()-interval '1 minute' where user_id='{OWNER}'"], check=True, capture_output=True)
        self.assertEqual(sql(call("'1234'")), 'ok')
        self.assertEqual(sql('select balance from public.wallets', ACTOR), '11')
        self.assertEqual(sql("select public.set_release_pin('9876','1234')"), 'ok')
        sql(f"select public.submit_claim('{cid}','other','image/png','{PNG}')", OTHER)
        sid2 = sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}' and user_id='{OTHER}'")
        self.assertEqual(sql(f"select public.review_claim_with_pin('{cid}','{OTHER}','{sid2}',false,null)"), 'ok')
        self.assertEqual(sql('select balance from public.wallets', OTHER), '10')
        sql('select * from growth_internal.release_pins', fails=True)

if __name__ == '__main__': unittest.main(verbosity=2)
