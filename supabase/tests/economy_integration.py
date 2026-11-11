from admin_test_support import enroll_test_admins, test_claims
"""Disposable PostgreSQL only: bootstrap.sql and all migrations must be applied.
Auth claims here are a privileged local mock, not a signature/email delivery test.
"""
import concurrent.futures
import json
import subprocess
import sys
import time
import unittest

from pin_test_support import issue_pin_nonce

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = '70000000-0000-4000-8000-000000000001'
OWNER = '70000000-0000-4000-8000-000000000002'
ACTOR = '70000000-0000-4000-8000-000000000003'
INVITER = '70000000-0000-4000-8000-000000000004'
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='


def sql(query, user=None, claims=None, fails=False):
    prefix = ''
    if user:
        claims = {'email':'synthetic@example.test','phone':'', **(claims or {})}
        prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{json.dumps(claims)}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix)+query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success: '+query)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


def otp(timestamp=None):
    return {'amr': [{'method': 'otp', 'timestamp': timestamp or int(time.time())}]}


def setting(key, amount):
    return sql(f"select public.admin_set_coin_setting('{key}',{amount})", ADMIN)


def balance(user):
    return int(sql('select balance from public.wallets', user))


class EconomyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id) values '+','.join(f"('{u}')" for u in [ADMIN,OWNER,ACTOR,INVITER]))
        sql(f"insert into public.admin_members(user_id) values ('{ADMIN}')")
        enroll_test_admins(DB)
        for u in [ADMIN,OWNER,ACTOR,INVITER]:
            sql('select public.initialize_wallet()', u)

    def test_01_settings_registration_and_authorization(self):
        self.assertEqual(balance(OWNER), 10)
        sql("select public.admin_set_coin_setting('registration',99)", ACTOR, fails=True)
        sql("update public.coin_settings set amount=99", ACTOR, fails=True)
        sql("select public.admin_set_coin_setting('follow',0)", ADMIN, fails=True)
        sql("select public.admin_set_coin_setting('invite',-1)", ADMIN, fails=True)
        sql("select public.admin_set_coin_setting('registration',10001)", ADMIN, fails=True)
        sql("select public.admin_set_coin_setting('unknown',1)", ADMIN, fails=True)
        setting('registration', 60)
        self.assertEqual(sql("select count(*) from growth_internal.coin_settings_audit where key='registration' and amount=60"), '1')
        new_user = '70000000-0000-4000-8000-000000000005'
        sql(f"insert into auth.users(id) values ('{new_user}')")
        sql('select public.initialize_wallet()', new_user)
        sql('select public.initialize_wallet()', new_user)
        self.assertEqual(balance(new_user), 60)
        self.assertEqual(balance(OWNER), 10)
        self.assertEqual(sql("select count(*) from public.coin_ledger where reason='welcome'",new_user), '1')
        setting('registration',10)
        sql('select * from growth_internal.coin_settings_audit', ACTOR, fails=True)
        sql(f"select public.admin_set_blocked('{ACTOR}',true)", ADMIN)
        self.assertEqual(sql('select count(*) from public.coin_settings',ACTOR),'0')
        sql(f"select public.admin_set_blocked('{ACTOR}',false)", ADMIN)

    def test_02_email_proof_replay_expiry_and_reset(self):
        # Password-only sessions and legacy Magic Link proof cannot set a PIN.
        self.assertEqual(sql("select public.set_release_pin('1234',null)",OWNER,otp()),'otp_required')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",OWNER),'otp_required')
        for age in ['10 minutes', '-10 minutes']:
            issue_pin_nonce(DB, OWNER, age=age)
            self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",OWNER),'otp_required')
        issue_pin_nonce(DB, OWNER)
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('12','123456')",OWNER),'invalid_format')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",OWNER),'ok')
        # Same nonce remains consumed even if the session is refreshed.
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('9999','123456')",OWNER,{'amr':[{'method':'token_refresh','timestamp':int(time.time())}]}),'otp_required')
        sql(f"update growth_internal.release_pins set failures=5,locked_until=now()+interval '15 minutes' where user_id='{OWNER}'")
        issue_pin_nonce(DB, OWNER, nonce='654321')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('4321','654321')",OWNER),'ok')
        self.assertEqual(sql(f"select failures||':'||(locked_until is null) from growth_internal.release_pins where user_id='{OWNER}'"),'0:true')
        sql('select * from growth_internal.pin_reauthentication_attempts',OWNER,fails=True)
        sql(f"select public.admin_set_blocked('{OWNER}',true)",ADMIN)
        sql("select public.set_release_pin_reauthenticated('1111','123456')",OWNER,fails=True)
        sql(f"select public.admin_set_blocked('{OWNER}',false)",ADMIN)

    def test_03_campaign_snapshot_conservation_and_notifications(self):
        setting('like',3)
        sql("select public.create_campaign_at_rate('like','https://instagram.com/p/ABC/',2,1)",OWNER,fails=True)
        self.assertEqual(balance(OWNER),10)
        campaign=sql("select public.create_campaign_at_rate('like','https://instagram.com/p/ABC/',2,3)",OWNER)
        self.assertEqual(balance(OWNER),4)
        setting('like',5)
        sql(f"select public.submit_claim('{campaign}','participant','image/png','{PNG}')",ACTOR)
        submission=sql(f"select submission_id from public.campaign_claims where campaign_id='{campaign}'",OWNER)
        call=f"select public.review_claim_with_pin('{campaign}','{ACTOR}','{submission}',true,"
        for _ in range(5):
            self.assertEqual(sql(call+"'1234')",OWNER),'invalid_pin')
        self.assertEqual(sql(call+"'1234')",OWNER),'pin_locked')
        self.assertEqual(balance(ACTOR),10)
        sql(f"update growth_internal.release_pins set locked_until=now()-interval '1 minute' where user_id='{OWNER}'")
        self.assertEqual(sql(call+"'4321')",OWNER),'ok')
        self.assertEqual(balance(ACTOR),13)
        self.assertEqual(sql("select count(*) from public.notifications where kind='coins_received' and amount=3",ACTOR),'1')
        self.assertEqual(sql("select count(*) from public.notifications where kind='approved'",ACTOR),'1')
        sql(call+"'4321')",OWNER,fails=True)
        sql(f"select public.cancel_campaign('{campaign}')",OWNER)
        self.assertEqual(balance(OWNER),7)
        self.assertEqual(balance(OWNER)+balance(ACTOR),20)
        self.assertEqual(sql(f"select reward_per_task from public.campaigns where id='{campaign}'",OWNER),'3')
        for action in ['follow','comment','share']:
            setting(action,2)
            link='https://instagram.com/example/' if action=='follow' else 'https://instagram.com/p/XYZ/'
            cid=sql(f"select public.create_campaign_at_rate('{action}','{link}',1,2)",OWNER)
            sql(f"select public.cancel_campaign('{cid}')",OWNER)
            self.assertEqual(balance(OWNER),7)
        sql("select public.admin_set_action_enabled('like',false)",ADMIN)
        sql("select public.create_campaign_at_rate('like','https://instagram.com/p/ABC/',1,5)",OWNER,fails=True)
        sql("select public.admin_set_action_enabled('like',true)",ADMIN)

    def test_04_referrals_milestones_concurrent_and_no_duplicates(self):
        code=json.loads(sql('select public.referral_info()',INVITER))['code']
        # Verify all configured initial values and then adjust for synthetic tests.
        self.assertEqual(sql("select amount from public.coin_settings where key='invite'",INVITER),'100')
        for key,amount in [('invite',10),('milestone_5',50),('milestone_10',100),('milestone_15',150)]: setting(key,amount)
        sql(f"select public.apply_referral('{code}')",INVITER,fails=True)
        users=[f'71000000-0000-4000-8000-{i:012d}' for i in range(1,17)]
        sql('insert into auth.users(id) values '+','.join(f"('{u}')" for u in users))
        for u in users: sql('select public.initialize_wallet()',u)
        # Simultaneous inserts must pay each milestone once, including waiters.
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda u: sql(f"select public.apply_referral('{code}')",u),users[:15]))
        self.assertEqual(balance(INVITER),10+150+50+100+150)
        self.assertEqual(json.loads(sql('select public.referral_info()',INVITER))['count'],15)
        self.assertEqual(sql("select count(*) from public.coin_ledger where reason='referral'",INVITER),'15')
        self.assertEqual(sql("select count(*) from public.notifications where kind='coins_received' and amount in (60,110,160)",INVITER),'3')
        sql(f"select public.apply_referral('{code}')",users[2],fails=True)
        self.assertEqual(balance(INVITER),460)
        setting('invite',0)
        sql(f"select public.apply_referral('{code}')",users[15])
        self.assertEqual(balance(INVITER),460)
        self.assertEqual(balance(users[15]),10)
        # Deleting referred accounts must not allow milestone 15 to pay twice.
        sql(f"delete from auth.users where id in ('{users[0]}','{users[1]}')")
        replacement='71000000-0000-4000-8000-000000000099'
        sql(f"insert into auth.users(id) values ('{replacement}')")
        sql(f"select public.apply_referral('{code}')",replacement)
        self.assertEqual(balance(INVITER),460)
        self.assertEqual(sql(f"select count(*) from growth_internal.referral_milestones where referrer_id='{INVITER}'"),'3')
        sql('insert into public.coin_ledger(user_id,amount,reason) values (auth.uid(),100,\'referral\')',users[2],fails=True)
        sql('select * from growth_internal.referrals',users[2],fails=True)


if __name__=='__main__': unittest.main(verbosity=2)
