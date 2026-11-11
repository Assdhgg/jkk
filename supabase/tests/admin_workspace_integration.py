from admin_test_support import enroll_test_admins, test_claims
"""Run against an isolated disposable database after bootstrap and all migrations."""
import json, subprocess, sys, unittest
DB = sys.argv[1]; sys.argv = sys.argv[:1]
EDITOR='61000000-0000-4000-8000-000000000001'
VIEWER='61000000-0000-4000-8000-000000000002'
USER='61000000-0000-4000-8000-000000000003'
OWNER='61000000-0000-4000-8000-000000000004'
CAMPAIGN='62000000-0000-4000-8000-000000000001'
SUBMISSION='63000000-0000-4000-8000-000000000001'
def sql(query, uid=None, fails=False):
    prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else ''
    r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+query],capture_output=True,text=True)
    if fails:
        if r.returncode == 0: raise AssertionError('Unexpected success: '+query)
    elif r.returncode: raise AssertionError(r.stderr)
    return (r.stdout.strip().splitlines() or [''])[-1]
class WorkspaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql(f"""insert into auth.users(id,email) values ('{EDITOR}','editor@example.test'),('{VIEWER}','viewer@example.test'),('{USER}','user@example.test'),('{OWNER}','owner@example.test');
        insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer');
        insert into public.campaigns(id,\"ownerId\",type,link,requested,remaining,status) values ('{CAMPAIGN}','{OWNER}','like','https://instagram.com/p/TEST/',5,5,'active');
        insert into public.campaign_claims(campaign_id,user_id,submission_id,status,created_at) values ('{CAMPAIGN}','{USER}','{SUBMISSION}','pending',now()-interval '2 days');
        insert into public.coin_ledger(user_id,amount,reason) values ('{USER}',1000,'welcome');""")
        enroll_test_admins(DB)
    def test_access_and_roles(self):
        self.assertEqual(sql('select public.admin_workspace_role()', VIEWER),'viewer')
        for q in ['select public.admin_workspace_overview()', 'select * from public.admin_daily_report(current_date,current_date)', 'select * from public.admin_activity()', 'select * from public.admin_alerts()', 'select * from public.admin_roles()', f"select public.admin_user_details('{USER}')", 'select * from public.admin_filtered_submissions()']:
            sql(q,USER,fails=True)
            sql(q,VIEWER)
        for q in [f"select public.admin_set_blocked('{USER}',true)", "select public.admin_set_action_enabled('like',false)", "select public.admin_set_coin_setting('like',2)", f"update public.admin_members set role='editor' where user_id='{VIEWER}'"]:
            sql(q,VIEWER,fails=True)
        sql(f"select public.admin_set_blocked('{USER}',true)",EDITOR)
        sql(f"select public.admin_set_blocked('{USER}',false)",EDITOR)
        sql("select public.admin_set_action_enabled('like',false)",EDITOR)
        sql("select public.admin_set_coin_setting('like',2)",EDITOR)
        self.assertEqual(sql('select count(*) from public.admin_activity()',VIEWER),'4')
    def test_queries_and_bounds(self):
        overview=json.loads(sql('select public.admin_workspace_overview()',VIEWER))
        self.assertEqual((overview['users'],overview['active_campaigns'],overview['pending_submissions'],overview['coins_credited']),(4,1,1,1000))
        details=json.loads(sql(f"select public.admin_user_details('{USER}')",VIEWER))
        self.assertEqual((len(details['submissions']),len(details['ledger'])),(1,1))
        self.assertEqual(sql("select count(*) from public.admin_filtered_submissions('like')",VIEWER),'1')
        self.assertEqual(sql("select count(*) from public.admin_filtered_submissions('share')",VIEWER),'0')
        self.assertEqual(sql("select count(*) from public.admin_filtered_submissions(null,null,now()-interval '1 day')",VIEWER),'0')
        self.assertEqual(sql('select count(*) from public.admin_alerts()',VIEWER),'2')
        report=json.loads(sql("select row_to_json(r) from public.admin_daily_report(current_date,current_date) r",VIEWER))
        self.assertEqual((report['registrations'],report['campaigns'],report['coins_credited']),(4,1,1000))
        for q in ["select * from public.admin_daily_report(current_date-367,current_date)", "select * from public.admin_filtered_submissions('invalid')", "select * from public.admin_activity(0,101)"]:
            sql(q,VIEWER,fails=True)
if __name__=='__main__': unittest.main(verbosity=2)
