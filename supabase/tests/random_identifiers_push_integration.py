from admin_test_support import enroll_test_admins, test_claims
"""Disposable PostgreSQL only; runner seeds pre-upgrade IDs and mock Vault/net."""
import concurrent.futures
import json
import subprocess
import sys
import unittest
DB = sys.argv[1]
sys.argv = sys.argv[:1]
OWNER='92000000-0000-4000-8000-000000000001'
OTHER='92000000-0000-4000-8000-000000000002'

def sql(query,user=None,fails=False):
    prefix=''
    if user:
        claims=json.dumps({'email':'synthetic@example.test','phone':''})
        prefix=f"set role authenticated;select set_config('request.jwt.claim.sub','{user}',false);select set_config('request.jwt.claims','{claims}',false);"
    result=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+query],text=True,capture_output=True)
    if fails:
        if result.returncode==0: raise AssertionError('Unexpected success')
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class IdentifierPushTests(unittest.TestCase):
    def test_01_rotation_and_old_code_retirement(self):
        self.assertEqual(sql("select count(*) from public.test_identifier_before b join growth_internal.user_identifiers i using(user_id) where b.public_id=i.public_id"),'0')
        self.assertEqual(sql("select count(*) from public.test_identifier_before b join growth_internal.referral_codes r using(user_id) where b.code=r.code"),'0')
        self.assertEqual(sql("select count(*) from public.test_identifier_before b join growth_internal.identifier_reservations r on r.kind='user' and r.value=b.public_id"),'2')
        sql('select public.initialize_wallet()',OWNER)
        self.assertEqual(sql("select count(*) from public.test_wallet_before b join public.wallets w using(id) where b.balance<>w.balance"),'0')
        self.assertEqual(sql(f"select count(*) from growth_internal.referrals where referred_id='{OTHER}' and referrer_id='{OWNER}'"),'1')
        fresh='95000000-0000-4000-8000-000000000001'
        sql(f"insert into auth.users(id) values('{fresh}')")
        old=sql(f"select code from public.test_identifier_before where user_id='{OWNER}'")
        sql(f"select public.apply_referral('{old}')",fresh,fails=True)
        code=sql(f"select code from growth_internal.referral_codes where user_id='{OWNER}'")
        sql(f"select public.apply_referral('{code}')",fresh)
        self.assertEqual(sql(f"select referrer_id from growth_internal.referrals where referred_id='{OTHER}'"),OWNER)
        for func in ['random_public_user_id()','next_referral_code()','secure_random_integer(integer)']:
            self.assertEqual(sql(f"select has_function_privilege('authenticated','growth_internal.{func}','EXECUTE')"),'f')
        sql('select * from growth_internal.identifier_reservations',OTHER,fails=True)

    def test_02_concurrent_allocations_and_no_reuse(self):
        users=[f'93000000-0000-4000-8000-{i:012d}' for i in range(100)]
        def create(user):
            sql(f"insert into auth.users(id) values('{user}');insert into growth_internal.referral_codes(user_id) values('{user}')")
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            list(executor.map(create,users))
        self.assertEqual(sql("select count(distinct public_id) from growth_internal.user_identifiers where user_id::text like '93000000-%'"),'100')
        self.assertEqual(sql("select count(distinct code) from growth_internal.referral_codes where user_id::text like '93000000-%'"),'100')
        self.assertEqual(sql("select count(*) from growth_internal.referral_codes where code !~ '^[A-Z]{4}[0-9]{3}$'"),'0')
        deleted=sql(f"select public_id from growth_internal.user_identifiers where user_id='{users[0]}'")
        sql(f"delete from auth.users where id='{users[0]}'")
        self.assertEqual(sql(f"select count(*) from growth_internal.identifier_reservations where kind='user' and value='{deleted}'"),'1')
        self.assertEqual(sql("select strpos(pg_get_functiondef('growth_internal.secure_random_integer(integer)'::regprocedure),'gen_random_bytes')>0"),'t')

    def test_03_bulk_notification_wakes_once_and_retry_is_idempotent(self):
        sql(f"insert into public.admin_members(user_id) values('{OWNER}')")
        enroll_test_admins(DB)
        for user in [OWNER,OTHER]:
            sql("select public.register_push_token('synthetic-device-"+user+"')",user)
        before=int(sql('select count(*) from public.test_wakeups'))
        call="select public.admin_send_notification('94000000-0000-4000-8000-000000000001',null,'Hello','Immediate message')"
        count=sql(call,OWNER)
        self.assertEqual(int(sql('select count(*) from public.test_wakeups')),before+1)
        self.assertEqual(sql(call,OWNER),count)
        self.assertEqual(int(sql('select count(*) from public.test_wakeups')),before+1)
        self.assertEqual(sql("select has_function_privilege('authenticated','growth_internal.request_push_delivery()','EXECUTE')"),'f')
        self.assertEqual(sql("select count(*) from growth_internal.push_jobs where status='pending'"),'2')

if __name__=='__main__':unittest.main(verbosity=2)
