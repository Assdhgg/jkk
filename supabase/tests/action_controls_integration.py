from admin_test_support import enroll_test_admins, test_claims
"""Isolated disposable PostgreSQL only, after all five migrations."""
import json
import subprocess
import time
import sys
import unittest

from pin_test_support import issue_pin_nonce

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = '30000000-0000-4000-8000-000000000001'
OWNER = '30000000-0000-4000-8000-000000000002'
PARTICIPANT = '30000000-0000-4000-8000-000000000003'
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='

def sql(query, user=ADMIN, fails=False, claims=None):
    prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    if claims is not None:
        claims = {'email': 'owner@example.test', 'phone':'', **claims}
        prefix += f"select set_config('request.jwt.claims','{json.dumps(claims)}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], text=True, capture_output=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success: ' + query)
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

def create(action):
    link = 'https://instagram.com/example/' if action == 'follow' else 'https://instagram.com/p/ABC/'
    return f"select public.create_campaign('{action}','{link}',1)"

class ActionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-d',DB,'-c',f"insert into auth.users(id,email) values ('{ADMIN}','admin@example.test'),('{OWNER}','owner@example.test'),('{PARTICIPANT}','participant@example.test'); insert into public.admin_members(user_id) values ('{ADMIN}')"], check=True, capture_output=True)
        enroll_test_admins(DB)
        for user in (ADMIN, OWNER, PARTICIPANT): sql('select public.initialize_wallet()', user)

    def test_actions_enforce_controls_and_preserve_pending_review(self):
        sql("select public.admin_set_action_enabled('like',false)", OWNER, fails=True)
        sql("update public.action_controls set enabled=false", ADMIN, fails=True)
        sql("select public.admin_set_action_enabled('bad',false)", ADMIN, fails=True)
        for action in ('follow', 'like', 'share', 'comment'):
            cid = sql(create(action), OWNER)
            sql(f"select public.admin_set_action_enabled('{action}',false)")
            sql(create(action), OWNER, fails=True)
            sql(f"select public.submit_claim('{cid}','sample','image/png','{PNG}')", PARTICIPANT, fails=True)
            sql(f"select public.admin_set_action_enabled('{action}',true)")
            sql(f"select public.submit_claim('{cid}','sample','image/png','{PNG}')", PARTICIPANT)
            sql(f"select public.admin_set_action_enabled('{action}',false)")
            # Pending submissions remain withdrawable and the owner's budget refundable.
            sql(f"select public.withdraw_claim('{cid}')", PARTICIPANT)
            sql(f"select public.cancel_campaign('{cid}')", OWNER)
            sql(f"select public.admin_set_action_enabled('{action}',true)")
        self.assertEqual(sql('select balance from public.wallets', OWNER), '10')
        count = subprocess.check_output(['psql','-X','-qAt','-d',DB,'-c','select count(*) from growth_internal.action_control_audit'], text=True).strip()
        self.assertEqual(count, '16')
        sql('select * from growth_internal.action_control_audit', ADMIN, fails=True)
        sql(f"select public.admin_set_blocked('{PARTICIPANT}',true)")
        self.assertEqual(sql('select count(*) from public.action_controls', PARTICIPANT), '0')
        sql(f"select public.admin_set_blocked('{PARTICIPANT}',false)")

    def test_pending_approval_remains_available(self):
        cid = sql(create('like'), OWNER)
        sql(f"select public.submit_claim('{cid}','sample','image/png','{PNG}')", PARTICIPANT)
        sid = sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}'", OWNER)
        issue_pin_nonce(DB, OWNER)
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')", OWNER, claims={}), 'ok')
        sql("select public.admin_set_action_enabled('like',false)")
        self.assertEqual(sql(f"select public.review_claim_with_pin('{cid}','{PARTICIPANT}','{sid}',true,'1234')", OWNER), 'ok')
        self.assertEqual(sql('select balance from public.wallets', PARTICIPANT), '11')

    def test_toggle_commit_precedes_waiting_creation(self):
        command = (f"set application_name='gc_action_lock_test'; set role authenticated; "
                   f"select set_config('request.jwt.claim.sub','{ADMIN}',false); select set_config('request.jwt.claims','{{\"aal\":\"aal2\"}}',false); begin; "
                   "select public.admin_set_action_enabled('follow',false); select pg_sleep(1.5); commit;")
        process = subprocess.Popen(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',command], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                state = subprocess.check_output(['psql','-X','-qAt','-d',DB,'-c', "select count(*) from pg_stat_activity where application_name='gc_action_lock_test' and wait_event='PgSleep'"], text=True).strip()
                if state == '1': break
                time.sleep(0.05)
            else: raise AssertionError('Administrator did not acquire the action lock')
            sql(create('follow'), OWNER, fails=True)
            _, error = process.communicate(timeout=5)
            if process.returncode: raise AssertionError(error)
            self.assertEqual(sql("select enabled from public.action_controls where action_type='follow'", OWNER), 'f')
        finally:
            if process.poll() is None: process.kill(); process.communicate()
            sql("select public.admin_set_action_enabled('follow',true)")

    def test_z_admin_campaign_listing(self):
        self.assertEqual(sql("select count(*) from public.admin_list_campaigns(null,null,0,30)"), '5')
        self.assertEqual(sql("select owner_email from public.admin_list_campaigns('like','completed',0,30)"), 'owner@example.test')
        self.assertEqual(sql("select count(*) from public.admin_list_campaigns(null,null,0,2)"), '2')
        self.assertEqual(sql("select count(*) from public.admin_list_campaigns(null,null,4,2)"), '1')
        sql("select * from public.admin_list_campaigns(null,null,0,30)", OWNER, fails=True)
        sql("select * from public.admin_list_campaigns('bad',null,0,30)", ADMIN, fails=True)
        sql("select * from public.admin_list_campaigns(null,null,0,101)", ADMIN, fails=True)
        sql("select * from public.claim_evidence", ADMIN, fails=True)

if __name__ == '__main__': unittest.main(verbosity=2)
