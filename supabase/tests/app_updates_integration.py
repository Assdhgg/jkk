"""Disposable DB: bootstrap, mock Storage schema and all migrations required."""
import subprocess
import sys
import unittest
DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR = '92000000-0000-4000-8000-000000000001'
VIEWER = '92000000-0000-4000-8000-000000000002'
USER = '92000000-0000-4000-8000-000000000003'
PATH = '12345678-1234-1234-1234-123456789abc.apk'
OTHER = '12345678-1234-1234-1234-123456789abd.apk'
def sql(query, user=None, fails=False):
    prefix = '' if not user else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{{\"email\":\"synthetic@example.test\",\"phone\":\"\"}}',false); "
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query],capture_output=True,text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success')
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]
def publish(code, path=PATH, hash_value='a'*64):
    return f"select public.admin_publish_app_release({code},'1.2.0','{path}','{hash_value}',100,'Release notes')"
class Updates(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id) values '+','.join(f"('{u}')" for u in [EDITOR,VIEWER,USER]))
        sql(f"insert into public.admin_members(user_id,role) values('{EDITOR}','editor'),('{VIEWER}','viewer')")
        for u in [EDITOR,VIEWER,USER]: sql('select public.initialize_wallet()',u)
        sql("select public.register_push_token('synthetic-update-token-12345')",USER)
        for p in [PATH,OTHER]: sql(f"insert into storage.objects(bucket_id,name,metadata) values('app-releases','{p}','{{\"size\":100}}')")
    def test_release_authorization_notifications_and_immutable_artifact(self):
        sql(publish(8),USER,fails=True)
        sql(publish(8),VIEWER,fails=True)
        sql(f"insert into storage.objects(bucket_id,name,metadata) values('app-releases','{OTHER}','{{}}')",USER,fails=True)
        sql(f"insert into storage.objects(bucket_id,name,metadata) values('app-releases','{OTHER}','{{}}')",VIEWER,fails=True)
        self.assertEqual(sql(f"with gone as(delete from storage.objects where name='{OTHER}' returning id) select count(*) from gone",EDITOR),'1')
        sql(f"insert into storage.objects(bucket_id,name,metadata) values('app-releases','{OTHER}','{{\"size\":100}}')",EDITOR)
        self.assertTrue(sql(publish(8),EDITOR))
        self.assertEqual(sql("select count(*) from public.notifications where kind='app_update'",USER),'1')
        self.assertEqual(sql(f"select count(*) from growth_internal.push_jobs j join public.notifications n on n.id=j.notification_id where n.user_id='{USER}' and n.kind='app_update'"),'1')
        self.assertEqual(sql('select version_code from public.app_releases',USER),'8')
        sql(publish(8,OTHER),EDITOR,fails=True)
        sql(publish(9,OTHER,'bad'),EDITOR,fails=True)
        self.assertEqual(sql('select count(*) from public.app_releases'),'1')
        self.assertEqual(sql(f"with gone as(delete from storage.objects where name='{PATH}' returning id) select count(*) from gone",EDITOR),'0')
        sql('delete from public.app_releases',EDITOR,fails=True)
        sql(publish(9,OTHER),EDITOR)
        self.assertEqual(sql("select count(*) from public.notifications where kind='app_update'",USER),'2')
        r2path = '12345678-1234-1234-1234-123456789abe.apk'
        call = f"select public.publish_r2_app_release('{EDITOR}',10,'1.3.0','{r2path}','{'b'*64}',100,'R2 release','https://updates.example.test/releases/{r2path}')"
        sql(call, USER, fails=True)
        sql(call, EDITOR, fails=True)
        self.assertTrue(sql('set role service_role; '+call))
        self.assertEqual(sql("select storage_provider from public.app_releases where version_code=10",USER),'r2')
        self.assertEqual(sql("select storage_provider from public.app_releases where version_code=8",USER),'supabase')
        self.assertEqual(sql("select count(*) from public.notifications where kind='app_update'",USER),'3')
        sql('set role service_role; '+call,fails=True)

if __name__ == '__main__': unittest.main()
