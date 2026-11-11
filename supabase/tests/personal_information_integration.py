"""Run against a disposable local database after the test bootstrap and all migrations."""
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
A = '93000000-0000-4000-8000-000000000001'
B = '93000000-0000-4000-8000-000000000002'
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='

def sql(query, user=None, role=None, fails=False):
    prefix = ''
    if user:
        prefix = f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{{\"email\":\"synthetic@example.test\"}}',false); "
    elif role:
        prefix = f'set role {role}; '
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query],capture_output=True,text=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success')
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class PersonalInformation(unittest.TestCase):
    def test_private_bounded_photos_and_access(self):
        sql(f"insert into auth.users(id) values ('{A}'),('{B}')")
        sql(f"select public.set_profile_photo('image/png','{PNG}')", role='anon', fails=True)
        sql(f"select public.set_profile_photo('image/png','{PNG}')", A)
        self.assertEqual(sql('select public.profile_photo()',A),PNG)
        self.assertEqual(sql("select coalesce(public.profile_photo(),'missing')",B),'missing')
        sql(f"select public.set_profile_photo('image/jpeg','{PNG}')", B, fails=True)
        sql("select public.set_profile_photo('image/png',repeat('A',699056))", B, fails=True)
        sql('select * from growth_internal.profile_photos',B,fails=True)
        sql(f"insert into public.user_access(user_id,blocked) values('{A}',true)")
        sql('select public.profile_photo()',A,fails=True)
        sql(f"select public.set_profile_photo('image/png','{PNG}')",A,fails=True)
        sql(f"delete from auth.users where id='{A}'")
        self.assertEqual(sql('select count(*) from growth_internal.profile_photos'),'0')

if __name__ == '__main__': unittest.main()
