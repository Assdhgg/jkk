"""Disposable PostgreSQL only. Auth email issuance is synthetic, never live."""
import concurrent.futures
import json
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
USER = '91000000-0000-4000-8000-000000000001'
OTHER = '91000000-0000-4000-8000-000000000002'


def sql(query, user=None, claims=None, fails=False):
    prefix = ''
    if user:
        proof = {'email': 'synthetic@example.test', 'phone': '', **(claims or {})}
        prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{json.dumps(proof)}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix + query], text=True, capture_output=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success')
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


def issue(user=USER, nonce='123456', age="interval '10 seconds'"):
    sql(f"update auth.users set reauthentication_token=encode(extensions.digest(email || '{nonce}','sha224'),'hex'), reauthentication_sent_at=now()-{age} where id='{user}'; insert into auth.one_time_tokens(user_id,token_type,token_hash) values('{user}','reauthentication_token','synthetic-hash')")


def save(nonce='123456', user=USER, claims=None, pin='1234'):
    return sql(f"select public.set_release_pin_reauthenticated('{pin}','{nonce}')", user, claims)


class PinReauthenticationTests(unittest.TestCase):
    def setUp(self):
        sql(f"delete from auth.users where id in ('{USER}','{OTHER}'); insert into auth.users(id) values('{USER}'),('{OTHER}')")
        for user in [USER, OTHER]:
            sql('select public.initialize_wallet()', user)

    def test_setup_reset_replay_and_existing_pin_lockout(self):
        self.assertEqual(save(), 'otp_required')
        issue()
        self.assertEqual(save(), 'ok')
        self.assertEqual(save(), 'otp_required')
        self.assertEqual(sql(f"select reauthentication_token='' from auth.users where id='{USER}'"), 't')
        self.assertEqual(sql(f"select count(*) from auth.one_time_tokens where user_id='{USER}'"), '0')
        sql(f"update growth_internal.release_pins set failures=5,locked_until=now()+interval '15 minutes' where user_id='{USER}'")
        before = sql(f"select pin_hash from growth_internal.release_pins where user_id='{USER}'")
        self.assertEqual(save(), 'otp_required')
        self.assertEqual(sql(f"select pin_hash from growth_internal.release_pins where user_id='{USER}'"), before)
        issue(nonce='654321')
        self.assertEqual(save('654321', pin='9876'), 'ok')
        self.assertEqual(sql(f"select failures=0 and locked_until is null from growth_internal.release_pins where user_id='{USER}'"), 't')
        self.assertEqual(sql(f"select extensions.crypt('9876',pin_hash)=pin_hash from growth_internal.release_pins where user_id='{USER}'"), 't')

    def test_wrong_account_expiry_format_and_identity(self):
        issue()
        self.assertEqual(save(user=OTHER), 'otp_required')
        for claims in [{'email': 'old@example.test'}, {'phone': '+15555550123'}]:
            self.assertEqual(save(claims=claims), 'email_otp_required')
        sql(f"update auth.users set phone='+15555550123' where id='{USER}'")
        self.assertEqual(save(), 'email_otp_required')
        sql(f"update auth.users set phone='' where id='{USER}'")
        self.assertEqual(save(pin='abc'), 'invalid_format')
        self.assertEqual(save(), 'ok')
        for age in ["interval '6 minutes'", "interval '-2 minutes'"]:
            issue(age=age)
            self.assertEqual(save(), 'otp_required')
        sql(f"update auth.users set email_confirmed_at=null where id='{USER}'")
        sql("select public.set_release_pin_reauthenticated('1234','123456')", USER, fails=True)

    def test_five_attempt_limit_resend_and_legacy_path(self):
        issue()
        for _ in range(5):
            self.assertEqual(save('000000'), 'otp_required')
        self.assertEqual(save(), 'otp_required')
        issue(age="interval '1 seconds'")
        self.assertEqual(save(), 'ok')
        sql("select public.set_release_pin('9999',null)", USER)
        self.assertEqual(sql("select public.set_release_pin('9999',null)", USER,
                             {'amr': [{'method': 'otp', 'timestamp': 9999999999}]}), 'otp_required')
        self.assertEqual(sql(f"select extensions.crypt('1234',pin_hash)=pin_hash from growth_internal.release_pins where user_id='{USER}'"), 't')

    def test_concurrent_nonce_can_only_be_consumed_once(self):
        issue()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: save(), range(2)))
        self.assertEqual(sorted(results), ['ok', 'otp_required'])

    def test_permissions_blocked_and_other_auth_tokens_preserved(self):
        self.assertEqual(sql("select has_function_privilege('anon','public.set_release_pin_reauthenticated(text,text)','EXECUTE')"), 'f')
        sql('select * from growth_internal.pin_reauthentication_attempts', USER, fails=True)
        sql("update auth.users set reauthentication_token='forged'", USER, fails=True)
        issue()
        sql(f"insert into auth.one_time_tokens(user_id,token_type,token_hash) values('{USER}','email_change_token_new','synthetic-other-hash')")
        sql(f"insert into public.user_access(user_id,blocked) values('{USER}',true) on conflict(user_id) do update set blocked=true")
        sql("select public.set_release_pin_reauthenticated('1234','123456')", USER, fails=True)
        sql(f"update public.user_access set blocked=false where user_id='{USER}'")
        self.assertEqual(save(), 'ok')
        self.assertEqual(sql(f"select count(*) from auth.one_time_tokens where user_id='{USER}' and token_type='email_change_token_new'"), '1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
