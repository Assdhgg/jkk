"""Run only on an isolated disposable database after all migrations."""
import json
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = '40000000-0000-4000-8000-000000000001'
OWNER = '40000000-0000-4000-8000-000000000002'
ACTOR = '40000000-0000-4000-8000-000000000003'
OTHER = '40000000-0000-4000-8000-000000000004'
ADMIN2 = '40000000-0000-4000-8000-000000000005'
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='

def sql(query, user=ADMIN, fails=False):
    prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success: '+query)
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class InspectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        values = ','.join(f"('{u}')" for u in (ADMIN, OWNER, ACTOR, OTHER, ADMIN2))
        subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-d',DB,'-c',f"insert into auth.users(id) values {values}; insert into public.admin_members(user_id) values ('{ADMIN}'),('{ADMIN2}')"], check=True, capture_output=True)
        for user in (ADMIN, OWNER, ACTOR, OTHER, ADMIN2): sql('select public.initialize_wallet()', user)

    def test_inspection_privacy_presence_lifecycle_and_stale_submission(self):
        cid = sql("select public.create_campaign('like','https://instagram.com/p/ABC/',1)", OWNER)
        submit = f"select public.submit_claim('{cid}','sample','image/png','{PNG}')"
        sql(submit, ACTOR)
        sid = sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}'", ACTOR)
        begin = f"select public.admin_begin_submission_review('{cid}','{ACTOR}','{sid}')"
        sql('select * from public.admin_pending_submissions(0,30)', ACTOR, fails=True)
        sql(begin, ACTOR, fails=True)
        self.assertEqual(sql('select count(*) from public.admin_pending_submissions(0,30)'), '1')
        self.assertEqual(sql('select count(*) from public.admin_review_presence where expires_at > now()', ACTOR), '0')
        first = json.loads(sql(begin))
        self.assertEqual(first['username'], 'sample')
        self.assertEqual(first['data'], PNG)
        self.assertEqual(sql('select count(*) from public.admin_review_presence where expires_at > now()', ACTOR), '1')
        self.assertEqual(sql('select count(*) from public.admin_review_presence where expires_at > now()', OWNER), '1')
        self.assertEqual(sql('select count(*) from public.admin_review_presence where expires_at > now()', OTHER), '0')
        sql('select * from public.claim_evidence', ADMIN, fails=True)
        sql('select * from growth_internal.admin_review_audit', ADMIN, fails=True)
        first_id = first['session_id']
        sql(f"select public.admin_end_submission_review('{first_id}')", ADMIN2)
        self.assertEqual(sql('select count(*) from public.admin_review_presence where expires_at > now()', ACTOR), '1')
        self.assertEqual(sql(f"select public.admin_renew_submission_review('{first_id}')", ADMIN2), 'f')
        self.assertEqual(sql(f"select public.admin_renew_submission_review('{first_id}')", ADMIN), 't')
        second = json.loads(sql(begin, ADMIN2))['session_id']
        sql(f"select public.admin_end_submission_review('{first_id}')", ADMIN)
        self.assertEqual(sql('select count(*) from public.admin_review_presence where expires_at > now()', ACTOR), '1')
        sql(f"select public.withdraw_claim('{cid}')", ACTOR)
        self.assertEqual(sql(f"select public.admin_renew_submission_review('{second}')", ADMIN2), 'f')
        sql(begin, ADMIN, fails=True)
        sql(submit, ACTOR)
        new_sid = sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}'", ACTOR)
        self.assertNotEqual(new_sid, sid)
        self.assertEqual(sql(f"select count(*) from public.admin_review_presence where submission_id='{new_sid}'", ACTOR), '0')
        sql(f"select public.set_release_pin('1234',null)", ADMIN)
        sql(f"select public.review_claim_with_pin('{cid}','{ACTOR}','{new_sid}',true,'1234')", ADMIN, fails=True)
        self.assertEqual(sql('select balance from public.wallets', ACTOR), '10')
        self.assertEqual(subprocess.check_output(['psql','-X','-qAt','-d',DB,'-c','select count(*) from growth_internal.admin_review_audit'], text=True).strip(), '2')

if __name__ == '__main__': unittest.main(verbosity=2)
