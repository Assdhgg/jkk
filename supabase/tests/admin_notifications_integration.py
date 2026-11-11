"""Disposable local database only: bootstrap, storage fixture and all migrations."""
import subprocess
import sys
import unittest
DB=sys.argv[1]
sys.argv=sys.argv[:1]
E='94000000-0000-4000-8000-000000000001'
V='94000000-0000-4000-8000-000000000002'
A='94000000-0000-4000-8000-000000000003'
B='94000000-0000-4000-8000-000000000004'
C='94000000-0000-4000-8000-000000000005'
U='94000000-0000-4000-8000-000000000006'
R1='10000000-0000-4000-8000-000000000001'
R2='10000000-0000-4000-8000-000000000002'

def sql(q,user=None,aal='aal1',role=None,fails=False):
 prefix=f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{{\"email\":\"synthetic@example.test\",\"aal\":\"{aal}\"}}',false); " if user else (f'set role {role}; ' if role else '')
 p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+q],capture_output=True,text=True)
 if fails:
  if p.returncode==0: raise AssertionError('unexpected success')
 elif p.returncode: raise AssertionError(p.stderr)
 return (p.stdout.strip().splitlines() or [''])[-1]

def send(request,target='null',title='News',body='Hello'):
 return f"select public.admin_send_notification('{request}',{target},'{title}','{body}')"

class AdminNotifications(unittest.TestCase):
 def test_audience_permission_idempotency_and_delivery(self):
  sql('insert into auth.users(id) values '+','.join(f"('{u}')" for u in (E,V,A,B,C)))
  sql(f"insert into auth.users(id,email_confirmed_at) values ('{U}',null)")
  sql(f"insert into public.admin_members(user_id,role) values ('{E}','editor'),('{V}','viewer')")
  for u in (A,B,C): sql(f"select public.register_push_token('synthetic-token-{u}')",u)
  sql(f"insert into public.user_access(user_id,blocked) values ('{C}',true)")
  sql(f"insert into auth.mfa_factors(id,user_id,status) values (gen_random_uuid(),'{E}','verified')")
  sql(send(R1, f"'{A}'"),A,fails=True)
  sql(send(R1, f"'{A}'"),V,fails=True)
  sql(send(R1, f"'{A}'"),E,fails=True)
  sql(send(R1, f"'{A}'"),role='anon',fails=True)
  self.assertEqual(sql(send(R1,f"'{A}'"),E,aal='aal2'),'1')
  self.assertEqual(sql(send(R1,f"'{A}'"),E,aal='aal2'),'1')
  sql(send(R1,f"'{A}'",body='changed'),E,aal='aal2',fails=True)
  sql(send(R2,f"'{C}'"),E,aal='aal2',fails=True)
  sql(send(R2,f"'{U}'"),E,aal='aal2',fails=True)
  sql(send(R2,title=''),E,aal='aal2',fails=True)
  sql(send(R2,body='x'*501),E,aal='aal2',fails=True)
  self.assertEqual(sql(send(R2),E,aal='aal2'),'4')
  self.assertEqual(sql("select count(*) from public.notifications where kind='admin_message'"),'5')
  self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{C}'"),'0')
  self.assertEqual(sql(f"select count(*) from public.notifications where user_id='{U}'"),'0')
  self.assertEqual(sql("select count(*) from public.notifications where kind='admin_message'",A),'2')
  self.assertEqual(sql("select count(*) from public.notifications where kind='admin_message'",B),'1')
  self.assertEqual(sql('select count(*) from growth_internal.push_jobs'),'3')
  sql("update public.notifications set body='hijack'",A,fails=True)
  pid=sql(f"select public_id from growth_internal.user_identifiers where user_id='{A}'")
  self.assertEqual(sql(f"select count(*) from public.admin_notification_users('{pid}',0)",E,aal='aal2'),'1')
  sql('select * from public.claim_push_jobs_v2(10)',A,fails=True)
  self.assertEqual(sql("select count(*) from public.claim_push_jobs(1)",role='service_role'),'1')
  self.assertEqual(sql("select count(*) from public.claim_push_jobs_v2(10) where kind='admin_message' and title='News' and body='Hello'",role='service_role'),'2')

if __name__=='__main__': unittest.main()
