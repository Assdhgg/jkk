"""Isolated PostgreSQL database only, after all three migrations."""
import concurrent.futures
import json
import subprocess
import time
import sys
import unittest

DB=sys.argv[1];sys.argv=sys.argv[:1]
A='10000000-0000-4000-8000-000000000001'
B='10000000-0000-4000-8000-000000000002'
C='10000000-0000-4000-8000-000000000003'
D='10000000-0000-4000-8000-000000000004'
PNG='iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='
def sql(q,uid=None,role='authenticated',fails=False):
    prefix=f'set role {role}; '
    if uid:prefix+=f"select set_config('request.jwt.claim.sub','{uid}',false); "
    r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+q],capture_output=True,text=True)
    if fails:
        if r.returncode==0:raise AssertionError('Unexpected success: '+q[:100])
    elif r.returncode:raise AssertionError(r.stderr)
    return (r.stdout.strip().splitlines() or [''])[-1]
def balance(u):return int(sql(f"select balance from public.wallets where id='{u}'",u))
class AdminTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        values=','.join(f"('{u}','{email}',now(),'{{}}')" for u,email in [(A,'admin@example.test'),(B,'person@example.test'),(C,'owner@example.test'),(D,'admin2@example.test')])
        subprocess.run(['psql','-X','-q','-v','ON_ERROR_STOP=1','-d',DB,'-c',f"insert into auth.users(id,email,created_at,raw_user_meta_data) values {values}; insert into public.admin_members(user_id) values ('{A}'),('{D}');"],check=True)
        for u in (A,B,C,D):sql('select public.initialize_wallet()',u)
    def test_01_admin_only_and_pagination(self):
        self.assertEqual(sql('select public.admin_is_admin()',A),'t')
        self.assertEqual(sql('select public.admin_is_admin()',B),'f')
        self.assertEqual(sql("select count(*) from public.admin_list_users('person',0,50)",A),'1')
        self.assertEqual(sql("select count(*) from public.admin_list_users('',0,2)",A),'2')
        sql("select * from public.admin_list_users('',0,50)",B,fails=True)
        sql("select * from public.admin_list_users('',0,101)",A,fails=True)
        sql('select public.admin_is_admin()',role='anon',fails=True)
        sql(f"insert into public.admin_members(user_id) values ('{B}')",B,fails=True)
        sql('select * from public.user_access',B,fails=True)
        sql('select * from public.admin_access_audit',A,fails=True)
    def test_02_block_existing_session_and_unblock(self):
        sql(f"select public.admin_set_blocked('{B}',true)",C,fails=True)
        sql(f"select public.admin_set_blocked('{A}',true)",A,fails=True)
        sql(f"select public.admin_set_blocked('{D}',true)",A,fails=True)
        sql(f"select public.admin_set_blocked('{B}',true)",A)
        sql(f"select public.admin_set_blocked('{B}',true)",A)
        self.assertEqual(sql('select public.account_access_allowed()',B),'f')
        self.assertEqual(sql('select count(*) from public.wallets',B),'0')
        self.assertEqual(sql('select count(*) from public.campaigns',B),'0')
        self.assertEqual(sql('select count(*) from public.coin_ledger',B),'0')
        for q in ['select public.initialize_wallet()',"select public.create_campaign('like','https://instagram.com/p/ABC/',1)",f"select public.cancel_campaign('{A}')",f"select public.withdraw_claim('{A}')",f"select public.get_claim_evidence('{A}','{B}','{C}')",f"select public.review_claim('{A}','{B}','{C}',true)"]:
            sql(q,B,fails=True)
        sql("select growth_internal.create_campaign('like','https://instagram.com/p/ABC/',1)",B,fails=True)
        sql(f"select public.admin_set_blocked('{B}',false)",A)
        self.assertEqual(sql('select public.account_access_allowed()',B),'t')
        self.assertEqual(balance(B),10)
        self.assertEqual(subprocess.check_output(['psql','-X','-qAt','-d',DB,'-c',f"select count(*) from public.admin_access_audit where target_id='{B}'"],text=True).strip(),'2')
    def test_03_review_contract_for_active_users_and_blocked_actor(self):
        cid=sql("select public.create_campaign('like','https://instagram.com/p/ABC/',1)",C)
        submit=f"select public.submit_claim('{cid}','sample','image/png','{PNG}')"
        sql(f"select public.admin_set_blocked('{B}',true)",A)
        sql(submit,B,fails=True)
        sql(f"select public.admin_set_blocked('{B}',false)",A)
        sql(submit,B)
        sid=sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}'",C)
        sql(f"select public.admin_set_blocked('{C}',true)",A)
        sql(f"select public.review_claim('{cid}','{B}','{sid}',true)",C,fails=True)
        sql(f"select public.admin_set_blocked('{C}',false)",A)
        sql(f"select public.review_claim('{cid}','{B}','{sid}',true)",C)
        self.assertEqual(balance(B),11)
        self.assertEqual(sql(f"select status from public.campaigns where id='{cid}'",C),'completed')
    def test_04_concurrent_block_and_operation_fail_closed(self):
        def block():sql(f"select public.admin_set_blocked('{B}',true)",A)
        def act():
            try:sql("select public.create_campaign('like','https://instagram.com/p/TEST/',1)",B)
            except AssertionError:pass
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda f:f(),[block,act]))
        self.assertEqual(sql('select public.account_access_allowed()',B),'f')
        sql("select public.create_campaign('like','https://instagram.com/p/TEST/',1)",B,fails=True)
        sql(f"select public.admin_set_blocked('{B}',false)",A)
    def test_05_block_commit_precedes_waiting_action(self):
        # Hold the target lock until after the action has started. Once the
        # block commits, the waiting call must observe the new status.
        q=(f"set role authenticated; select set_config('request.jwt.claim.sub','{A}',false); "
           f"begin; select public.admin_set_blocked('{B}',true); select pg_sleep(1.5); commit;")
        proc=subprocess.Popen(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',q],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            deadline=time.monotonic()+3
            while time.monotonic()<deadline:
                probe=subprocess.check_output(['psql','-X','-qAt','-d',DB,'-c',f"select pg_try_advisory_lock(hashtextextended('{B}',314159))"],text=True).strip()
                if probe=='f': break
                time.sleep(0.05)
            else: raise AssertionError('Admin did not acquire target lock')
            sql('select public.initialize_wallet()',B,fails=True)
            _,err=proc.communicate(timeout=5)
            if proc.returncode: raise AssertionError(err)
            self.assertEqual(sql('select public.account_access_allowed()',B),'f')
        finally:
            if proc.poll() is None: proc.kill();proc.communicate()
            sql(f"select public.admin_set_blocked('{B}',false)",A)

if __name__=='__main__':unittest.main(verbosity=2)
