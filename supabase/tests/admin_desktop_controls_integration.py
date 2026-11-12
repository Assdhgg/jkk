"""Disposable PostgreSQL only: bootstrap, storage fixture and all migrations."""
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
E, E2, V, U = [f'96000000-0000-4000-8000-{i:012d}' for i in range(1, 5)]

def sql(query, user=None, fails=False):
    prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false);" if user else ''
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix)+query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success')
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class DesktopControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id) values '+','.join(f"('{u}')" for u in (E,E2,V,U)))
        sql(f"insert into public.admin_members(user_id,role) values ('{E}','editor'),('{E2}','editor'),('{V}','viewer')")
        enroll_test_admins(DB)
        sql('select public.initialize_wallet()', U)
        sql("select public.register_push_token('synthetic-desktop-fcm-token')", U)

    def test_independent_channels_and_idempotency(self):
        for index, (in_app, push) in enumerate(((True,False),(False,True),(True,True)),1):
            request = f'96000000-0000-4000-9000-{index:012d}'
            send = f"select public.admin_send_notification_v2('{request}','{U}','Desktop {index}','Message',{str(in_app).lower()},{str(push).lower()})"
            self.assertEqual(sql(send,E),'1')
            self.assertEqual(sql(send,E),'1')
            self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{U}' and title='Desktop {index}'",U),str(int(in_app)))
            self.assertEqual(sql(f"select count(*) from growth_internal.push_jobs j join public.notifications n on n.id=j.notification_id where n.user_id='{U}' and n.title='Desktop {index}'"),str(int(push)))
            sql(send,V,fails=True)
        sql(f"select public.admin_send_notification_v2(gen_random_uuid(),'{U}','Empty','None',false,false)",E,fails=True)
        sql(f"select public.admin_send_notification_v2('96000000-0000-4000-9000-000000000001','{U}','Desktop 1','Message',false,true)",E,fails=True)

    def test_public_ids_and_wallet_approval(self):
        public_id = sql(f"select public_id from growth_internal.user_identifiers where user_id='{U}'")
        self.assertEqual(sql(f"select public_id from public.admin_list_users_v2('{public_id}')",E),public_id)
        before = int(sql(f"select balance from public.wallets where id='{U}'"))
        request = sql(f"select public.admin_request_wallet_adjustment('{public_id}',5,'Synthetic correction')",E)
        sql(f"select public.admin_decide_adjustment('{request}',true)",E,fails=True)
        sql(f"select public.admin_decide_adjustment('{request}',true)",E2)
        self.assertEqual(int(sql(f"select balance from public.wallets where id='{U}'")),before+5)
        sql(f"select public.admin_request_wallet_adjustment('{public_id}',1,'No access')",V,fails=True)
        sql("select public.admin_request_wallet_adjustment('00000000',1,'Missing')",E,fails=True)
        request = sql(f"select public.admin_request_wallet_adjustment('{public_id}',-{before+6},'Would be negative')",E)
        sql(f"select public.admin_decide_adjustment('{request}',true)",E2,fails=True)
        self.assertEqual(int(sql(f"select balance from public.wallets where id='{U}'")),before+5)

if __name__ == '__main__': unittest.main()
