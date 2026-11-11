"""Security regression tests: disposable PostgreSQL with bootstrap + all migrations.
Supabase signatures and email delivery are mocked, never exercised here.
"""
import base64
import json
import struct
import subprocess
import sys
import time
import unittest
import zlib

from pin_test_support import issue_pin_nonce

DB = sys.argv[1]
sys.argv = sys.argv[:1]
OWNER='80000000-0000-4000-8000-000000000001'
ACTOR='80000000-0000-4000-8000-000000000002'
PHONE='80000000-0000-4000-8000-000000000003'
UNCONFIRMED='80000000-0000-4000-8000-000000000004'
PNG=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg==')


# Synthetic static 2x2 JPEG generated in a local browser canvas.
JPEG=base64.b64decode('/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAj/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCbgKIH/9k=')

def sql(query,user=None,claims=None,fails=False):
    prefix=''
    if user:
        proof={'email':'synthetic@example.test','phone':'',**(claims or {})}
        prefix=f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{json.dumps(proof)}',false); "
    r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query],text=True,capture_output=True)
    if fails:
        if r.returncode==0:raise AssertionError('Unexpected success')
    elif r.returncode:raise AssertionError(r.stderr)
    return (r.stdout.strip().splitlines() or [''])[-1]


def proof(**extra):
    return {'amr':[{'method':'otp','timestamp':int(time.time())-10}],**extra}


def png_dimensions(width,height):
    raw=bytearray(PNG)
    raw[16:24]=struct.pack('>II',width,height)
    raw[29:33]=struct.pack('>I',zlib.crc32(raw[12:29]))
    return bytes(raw)


class SecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id) values '+','.join(f"('{u}')" for u in [OWNER,ACTOR,PHONE,UNCONFIRMED]))
        sql(f"update auth.users set phone='+15555550123' where id='{PHONE}'; update auth.users set email_confirmed_at=null where id='{UNCONFIRMED}'")
        for u in [OWNER,ACTOR,PHONE]:sql('select public.initialize_wallet()',u)

    def test_01_permissions_and_email_factor(self):
        self.assertEqual(sql("select has_schema_privilege('authenticated','growth_internal','USAGE')"),'f')
        self.assertEqual(sql("select count(*) from pg_tables t join pg_class c on c.relname=t.tablename join pg_namespace n on n.oid=c.relnamespace and n.nspname=t.schemaname where t.schemaname='public' and not c.relrowsecurity"),'0')
        self.assertEqual(sql("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef and has_function_privilege('anon',p.oid,'EXECUTE')"),'0')
        # Metadata supplied by the user cannot substitute for a verified email.
        sql("select public.set_release_pin_reauthenticated('1234','123456')",UNCONFIRMED,proof(user_metadata={'email_verified':True}),fails=True)
        sql('select public.initialize_wallet()',UNCONFIRMED,fails=True)
        self.assertEqual(sql('select count(*) from public.wallets',UNCONFIRMED),'0')
        sql('select public.initialize_wallet()',ACTOR,{'is_anonymous':True},fails=True)
        self.assertEqual(sql('select count(*) from public.wallets',ACTOR,{'is_anonymous':True}),'0')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",PHONE,proof()),'email_otp_required')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",ACTOR,proof(phone='+15555550123')),'email_otp_required')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",ACTOR,proof(email='old-address@example.test')),'email_otp_required')
        for amr in [None,{},[{'method':'otp','timestamp':'bad'}],[{'method':'otp','timestamp':'9'*50}]]:
            self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",ACTOR,{'amr':amr}),'otp_required')
        issue_pin_nonce(DB, OWNER)
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('1234','123456')",OWNER,proof()),'ok')
        self.assertEqual(sql("select public.set_release_pin_reauthenticated('9999','123456')",OWNER,proof()),'otp_required')

    def test_02_images_fail_without_partial_submission(self):
        cid=sql("select public.create_campaign_at_rate('like','https://instagram.com/p/ABC/',1,1)",OWNER)
        def submit(raw,mime='image/png',fails=False):
            encoded=base64.b64encode(raw).decode()
            return sql(f"select public.submit_claim('{cid}','participant','{mime}','{encoded}')",ACTOR,fails=fails)
        submit(PNG)
        sql(f"select public.withdraw_claim('{cid}')",ACTOR)
        # Tiny encoded files must not advertise unbounded decoded surfaces.
        invalid=[png_dimensions(60000,60000),png_dimensions(0,10),png_dimensions(2,0),png_dimensions(0xffffffff,2),PNG[:24]]
        # Add an animation control chunk to an otherwise unchanged PNG.
        animation=b'acTL'+struct.pack('>II',100000,0)
        chunk=struct.pack('>I',8)+animation+struct.pack('>I',zlib.crc32(animation))
        invalid.append(PNG[:33]+chunk+PNG[33:])
        for raw in invalid:submit(raw,fails=True)
        # JPEG SOF dimensions and truncated segment bounds are checked as well.
        for width,height in [(60000,60000),(0,1),(1,0)]:
            raw=b'\xff\xd8\xff\xc0'+struct.pack('>HBHHB',17,8,height,width,3)+b'\x01\x11\x00\x02\x11\x00\x03\x11\x00'+b'\xff\xd9'+bytes(8)
            submit(raw,'image/jpeg',fails=True)
        submit(b'\xff\xd8\xff\xe1\xff\xff'+bytes(40),'image/jpeg',fails=True)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{cid}'",ACTOR),'withdrawn')
        self.assertEqual(sql(f"select count(*) from public.claim_evidence where campaign_id='{cid}'"),'0')
        self.assertEqual(sql('select balance from public.wallets',ACTOR),'10')
        self.assertEqual(sql('select balance from public.wallets',OWNER),'9')
        # Both supported static image formats remain accepted.
        submit(JPEG,'image/jpeg')
        sql(f"select public.withdraw_claim('{cid}')",ACTOR)
        submit(PNG)
        sql(f"select public.cancel_campaign('{cid}')",OWNER)
        self.assertEqual(sql('select balance from public.wallets',OWNER),'10')


if __name__=='__main__':unittest.main(verbosity=2)
