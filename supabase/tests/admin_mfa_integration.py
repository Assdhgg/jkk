"""All migrations, disposable DB. Explicitly prove AAL2 and enrollment required."""
import subprocess,sys,unittest
DB=sys.argv[1];sys.argv=sys.argv[:1]
ADMIN='97000000-0000-4000-8000-000000000001'
def sql(query):
 return subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',query],text=True,capture_output=True)
def request(aal):
 return sql(f"set role authenticated;select set_config('request.jwt.claim.sub','{ADMIN}',false); select set_config('request.jwt.claims','{{\"aal\":\"{aal}\"}}',false);select public.admin_workspace_role();")
class MfaTests(unittest.TestCase):
 def test_mfa_is_mandatory_even_before_first_enrollment(self):
  self.assertEqual(sql(f"insert into auth.users(id) values('{ADMIN}');insert into public.admin_members(user_id) values('{ADMIN}')").returncode,0)
  self.assertNotEqual(request('aal1').returncode,0)
  self.assertNotEqual(request('aal2').returncode,0)
  self.assertEqual(sql(f"insert into auth.mfa_factors(id,user_id,status) values(gen_random_uuid(),'{ADMIN}','verified')").returncode,0)
  self.assertNotEqual(request('aal1').returncode,0)
  self.assertEqual(request('aal2').returncode,0)
  self.assertEqual(sql(f"delete from auth.mfa_factors where user_id='{ADMIN}'").returncode,0)
  self.assertNotEqual(request('aal2').returncode,0)
if __name__=='__main__':unittest.main()
