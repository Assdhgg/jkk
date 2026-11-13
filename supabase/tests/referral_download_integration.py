"""Run only against a disposable DB with bootstrap, storage fixture and all migrations."""
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR, VIEWER, USER = [f'97000000-0000-4000-8000-{i:012d}' for i in range(1, 4)]

def sql(query, user=None, fails=False, aal='aal2'):
    prefix = '' if user is None else (
        f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
        f"select set_config('request.jwt.claims','{{\"email\":\"synthetic@example.test\",\"phone\":\"\",\"aal\":\"{aal}\"}}',false); "
    )
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success')
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class ReferralLink(unittest.TestCase):
    def test_permissions_validation_and_delete(self):
        sql('insert into auth.users(id) values ' + ','.join(f"('{u}')" for u in (EDITOR, VIEWER, USER)))
        sql(f"insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer')")
        enroll_test_admins(DB)
        for user in (EDITOR, VIEWER, USER): sql('select public.initialize_wallet()', user)
        self.assertEqual(sql('select count(*) from public.referral_download_link', USER), '0')
        sql("select public.admin_set_referral_download_link('https://updates.example.test/one.apk')", USER, fails=True)
        sql("select public.admin_set_referral_download_link('https://updates.example.test/one.apk')", VIEWER, fails=True)
        sql("select public.admin_set_referral_download_link('https://updates.example.test/one.apk')", EDITOR, fails=True, aal='aal1')
        sql("select referral_link_private.admin_set_referral_download_link('https://updates.example.test/one.apk')", USER, fails=True)
        sql("select referral_link_private.admin_set_referral_download_link('https://updates.example.test/one.apk')", VIEWER, fails=True)
        sql("select referral_link_private.admin_set_referral_download_link('https://updates.example.test/one.apk')", EDITOR, fails=True, aal='aal1')
        sql("insert into public.referral_download_link(url) values ('https://example.test/x')", EDITOR, fails=True)
        sql('set role anon; select * from public.referral_download_link', fails=True)
        sql("set role anon; select public.admin_set_referral_download_link('https://example.test/x')", fails=True)
        sql("set role anon; select referral_link_private.admin_set_referral_download_link('https://example.test/x')", fails=True)
        self.assertEqual(sql("select prosecdef from pg_proc where oid='public.admin_set_referral_download_link(text)'::regprocedure"), 'f')
        self.assertEqual(sql("select prosecdef from pg_proc where oid='referral_link_private.admin_set_referral_download_link(text)'::regprocedure"), 't')
        for invalid in ('', 'http://example.test/app.apk', 'https://user:pass@example.test/app.apk', 'https://example.test/a b', 'https://example.test/\\evil'):
            sql(f"select public.admin_set_referral_download_link('{invalid}')", EDITOR, fails=True)
        sql("select public.admin_set_referral_download_link('https://updates.example.test/one.apk')", EDITOR)
        self.assertEqual(sql('select url from public.referral_download_link', USER), 'https://updates.example.test/one.apk')
        sql("select public.admin_set_referral_download_link('https://updates.example.test/two.apk?x=1')", EDITOR)
        self.assertEqual(sql('select url from public.referral_download_link', USER), 'https://updates.example.test/two.apk?x=1')
        sql('select public.admin_set_referral_download_link(null)', VIEWER, fails=True)
        sql('select public.admin_set_referral_download_link(null)', EDITOR)
        self.assertEqual(sql('select count(*) from public.referral_download_link', USER), '0')
        self.assertEqual(sql("select count(*) from growth_internal.admin_operations_audit where action like 'Referral download link %'"), '3')

if __name__ == '__main__': unittest.main()
