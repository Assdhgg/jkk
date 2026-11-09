"""Disposable PostgreSQL only: test bootstrap and every migration."""
import json, subprocess, sys, unittest
DB=sys.argv[1];sys.argv=sys.argv[:1]
O='81000000-0000-4000-8000-000000000001'; U='81000000-0000-4000-8000-000000000002'; X='81000000-0000-4000-8000-000000000003'; A='81000000-0000-4000-8000-000000000004'; C='82000000-0000-4000-8000-000000000001'; S='83000000-0000-4000-8000-000000000001'; TOKEN='synthetic-token-0123456789abcdef0123456789'
PNG='iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='
def sql(q,uid=None,role='authenticated',fail=False):
 prefix=f"set role {role}; select set_config('request.jwt.claim.sub','{uid}',false); " if uid else (f'set role {role}; ' if role!='owner' else '')
 r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+q],capture_output=True,text=True)
 if fail:
  if r.returncode==0: raise AssertionError('Unexpected success: '+q)
 elif r.returncode: raise AssertionError(r.stderr)
 return (r.stdout.strip().splitlines() or [''])[-1]
class UserExperience(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  sql(f"""insert into auth.users(id,email) values ('{O}','o@example.test'),('{U}','u@example.test'),('{X}','x@example.test'),('{A}','a@example.test');
  insert into public.admin_members(user_id,role) values ('{A}','editor'); insert into public.wallets(id,balance) values('{O}',10),('{U}',10),('{X}',10);
  insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,reward_per_task) values('{C}','{O}','like','https://instagram.com/p/TEST/','active',2,2,1);
  insert into public.campaign_claims(campaign_id,user_id,submission_id,status,instagram_handle) values('{C}','{U}','{S}','pending','sample');
  insert into public.claim_evidence(campaign_id,user_id,mime_type,data_base64) values('{C}','{U}','image/png','{PNG}');""",role='owner')
 def test_01_feedback_owner_and_history(self):
  q=f"select public.review_claim_with_feedback('{C}','{U}','{S}',false,null,'Please retry')"
  sql(q,X,fail=True);self.assertEqual(sql(q,O),'ok')
  self.assertEqual(sql(f"select rejection_reason from public.submission_history where submission_id='{S}'",U),'Please retry')
  self.assertEqual(sql('select count(*) from public.submission_history',X),'0')
  self.assertEqual(sql("select count(*) from public.user_submission_history('rejected','TEST',null,null,0,50)",U),'1')
  self.assertEqual(sql("select count(*) from public.user_submission_history('approved','TEST',null,null,0,50)",U),'0')
  self.assertEqual(sql("select count(*) from public.user_submission_history(null,'TEST',null,null,0,50)",X),'0')
  sql("select * from public.user_submission_history(null,'',null,null,0,101)",U,fail=True)
  self.assertEqual(sql(f"select count(*) from public.claim_evidence where campaign_id='{C}'",role='owner'),'0')
  sql(f"select public.submit_claim('{C}','sample','image/png','{PNG}')",U)
  self.assertEqual(sql('select count(*) from public.submission_history',U),'2')
  self.assertEqual(sql("select count(*) from public.submission_history where status='pending' and rejection_reason is null",U),'1')
  sql(q,O,fail=True)
 def test_02_saved_tasks_isolation(self):
  sql(f"select public.set_task_saved('{C}',true)",U)
  self.assertEqual(sql('select count(*) from public.saved_tasks',U),'1')
  self.assertEqual(sql('select count(*) from public.saved_tasks',X),'0')
  sql(f"select public.set_task_saved('{C}',true)",O,fail=True)
  sql(f"delete from public.saved_tasks where campaign_id='{C}'",U,fail=True)
  sql(f"select public.set_task_saved('{C}',false)",U)
 def test_03_push_queue_security_and_lease(self):
  sql(f"select public.register_push_token('{TOKEN}')",U)
  sql(f"insert into public.notifications(user_id,kind) values('{U}','approved')",role='owner')
  sql('select * from public.claim_push_jobs()',U,fail=True)
  job=json.loads(sql('select row_to_json(t) from public.claim_push_jobs(50) t',role='service_role'))
  sql(f"select public.finish_push_job('{job['job_id']}','{S}',true,false)",role='service_role',fail=True)
  sql(f"select public.finish_push_job('{job['job_id']}','{job['lease_id']}',true,false)",role='service_role')
  sql(f"insert into public.notifications(user_id,kind) values('{U}','rejected')",role='owner')
  sql(f"select public.register_push_token('{TOKEN}')",X)
  self.assertEqual(sql("select count(*) from growth_internal.push_jobs",role='owner'),'0')
 def test_04_support_reply_notification(self):
  tid=sql("select public.support_create_ticket('Help','Please help')",U)
  sql(f"select public.support_reply('{tid}','We can help')",A)
  self.assertEqual(sql("select count(*) from public.notifications where kind='support_reply'",U),'1')
  self.assertEqual(sql("select count(*) from public.notifications where kind='support_reply'",X),'0')
if __name__=='__main__':unittest.main(verbosity=2)
