"""Disposable PostgreSQL only. Applies the owner-review upgrade to the original schema."""
import base64
import concurrent.futures
import json
import subprocess
import sys
import unittest
from pathlib import Path

DB = sys.argv[1]
sys.argv = sys.argv[:1]
MIGRATION = Path(__file__).resolve().parents[1] / 'migrations/20261107010000_owner_review.sql'
PNG = base64.b64encode(bytes.fromhex('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6360000000020001e221bc330000000049454e44ae426082')).decode()

def sql(q, uid=None, role='authenticated', fails=False):
    prefix = f'set role {role}; '
    if uid: prefix += f"select set_config('request.jwt.claim.sub','{uid}',false); "
    r = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+q],text=True,capture_output=True)
    if fails:
        if r.returncode == 0: raise AssertionError('Unexpected success: '+q[:100])
    elif r.returncode: raise AssertionError(r.stderr)
    return (r.stdout.strip().splitlines() or [''])[-1]

def uid(n): return f'00000000-0000-4000-8000-{n:012d}'
def balance(u): return int(sql(f"select balance from public.wallets where id='{u}'",u))
def create(u,count): return sql(f"select public.create_campaign('like','https://instagram.com/p/ABC/',{count})",u)
def submit(cid,user,handle='testuser',img=PNG,mime='image/png',fails=False):
    return sql(f"select public.submit_claim('{cid}','{handle}','{mime}','{img}')",user,fails=fails)
def token(cid,user,viewer):
    return sql(f"select submission_id from public.campaign_claims where campaign_id='{cid}' and user_id='{user}'",viewer)
def evidence(cid,user,viewer,submission=None,fails=False):
    submission=submission or token(cid,user,user)
    return sql(f"select public.get_claim_evidence('{cid}','{user}','{submission}')",viewer,fails=fails)
def review(cid,user,owner,accept=True,fails=False,submission=None):
    submission=submission or token(cid,user,user)
    return sql(f"select public.review_claim('{cid}','{user}','{submission}',{'true' if accept else 'false'})",owner,fails=fails)

class ReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.legacyowner,cls.legacyactor=uid(1),uid(2)
        cls.add_users([cls.legacyowner,cls.legacyactor])
        cls.legacycid=create(cls.legacyowner,2)
        sql(f"select public.claim_task('{cls.legacycid}')",cls.legacyactor)
        subprocess.run(['psql','-X','-q','-v','ON_ERROR_STOP=1','-d',DB,'-f',str(MIGRATION)],check=True)

    @classmethod
    def add_users(cls,users):
        values=','.join(f"('{u}')" for u in users)
        subprocess.run(['psql','-X','-q','-v','ON_ERROR_STOP=1','-d',DB,'-c',f'insert into auth.users(id) values {values}'],check=True)
        for u in users: sql('select public.initialize_wallet()',u)

    def test_01_upgrade_preserves_legacy_and_disables_old_client(self):
        self.assertEqual(balance(self.legacyactor),11)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{self.legacycid}'",self.legacyowner),'legacy')
        sql(f"select public.claim_task('{self.legacycid}')",self.legacyactor,fails=True)
        self.assertEqual(balance(self.legacyactor),11)
        submit(self.legacycid,self.legacyactor,fails=True)

    def test_02_owner_review_permissions_and_evidence_privacy(self):
        owner,actor,other=map(uid,[10,11,12]);self.add_users([owner,actor,other]);cid=create(owner,2)
        submit(cid,actor)
        self.assertEqual(balance(actor),10)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{cid}'",owner),'pending')
        self.assertEqual(sql(f"select count(*) from public.campaign_claims where campaign_id='{cid}'",other),'0')
        sql('select * from public.claim_evidence',owner,fails=True)
        evidence(cid,actor,other,fails=True)
        self.assertEqual(json.loads(evidence(cid,actor,owner))['data'], PNG)
        self.assertEqual(json.loads(evidence(cid,actor,actor))['data'], PNG)
        submit(cid,actor,fails=True)
        submit(cid,owner,fails=True)
        review(cid,actor,other,fails=True)
        review(cid,actor,owner)
        review(cid,actor,owner,fails=True)
        self.assertEqual(balance(actor),11)
        self.assertEqual(sql(f"select remaining from public.campaigns where id='{cid}'",owner),'1')
        evidence(cid,actor,owner,fails=True)
        sql(f"update public.campaign_claims set status='approved' where campaign_id='{cid}'",actor,fails=True)
        sql(f"select public.submit_claim('{cid}','testuser','image/png','{PNG}')",role='anon',fails=True)

    def test_03_reject_resubmit_and_cancel_refund(self):
        owner,actor,other=map(uid,[20,21,22]);self.add_users([owner,actor,other]);cid=create(owner,2)
        submit(cid,actor);review(cid,actor,owner,False)
        self.assertEqual(balance(actor),10)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{cid}'",actor),'rejected')
        submit(cid,actor);submit(cid,other)
        sql(f"select public.cancel_campaign('{cid}')",owner)
        self.assertEqual(balance(owner),10)
        self.assertEqual(balance(actor),10)
        self.assertEqual(sql(f"select count(*) from public.campaign_claims where campaign_id='{cid}' and status='cancelled'",owner),'2')
        review(cid,actor,owner,fails=True)
        evidence(cid,actor,owner,fails=True)

    def test_04_submission_and_review_races(self):
        owner,actor,other=map(uid,[30,31,32]);self.add_users([owner,actor,other]);cid=create(owner,1)
        def attempt(u):
            try: submit(cid,u);return u
            except AssertionError: return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            result=list(pool.map(attempt,[actor,actor,other]))
        winners=[x for x in result if x];self.assertEqual(len(winners),1)
        winner=winners[0]
        def approve(_):
            try: review(cid,winner,owner);return True
            except AssertionError: return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: approvals=list(pool.map(approve,range(3)))
        self.assertEqual(sum(approvals),1)
        self.assertEqual(balance(winner),11)
        self.assertEqual(sql(f"select remaining || ':' || status from public.campaigns where id='{cid}'",owner),'0:completed')
        self.assertEqual(sql(f"select count(*) from public.coin_ledger where campaign_id='{cid}' and reason='task'",winner),'1')

    def test_05_cancellation_approval_race(self):
        owner,actor=map(uid,[40,41]);self.add_users([owner,actor]);cid=create(owner,2);submit(cid,actor)
        def attempt(which):
            try:
                if which=='approve': review(cid,actor,owner)
                else: sql(f"select public.cancel_campaign('{cid}')",owner)
            except AssertionError: pass
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(attempt,['approve','cancel']))
        self.assertEqual(balance(owner)+balance(actor),20)
        self.assertIn(balance(actor),[10,11])
        self.assertEqual(sql(f"select status from public.campaigns where id='{cid}'",owner),'cancelled')
        evidence(cid,actor,owner,fails=True)

    def test_06_withdrawal_reopens_slot_and_removes_proof(self):
        owner,actor,other=map(uid,[45,46,47]);self.add_users([owner,actor,other]);cid=create(owner,1)
        submit(cid,actor)
        sql(f"select public.withdraw_claim('{cid}')",other,fails=True)
        sql(f"select public.withdraw_claim('{cid}')",actor)
        sql(f"select public.withdraw_claim('{cid}')",actor,fails=True)
        evidence(cid,actor,owner,fails=True)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{cid}'",actor),'withdrawn')
        submit(cid,other)
        review(cid,other,owner)
        self.assertEqual(balance(other),11)
        self.assertEqual(balance(actor),10)

    def test_07_stale_review_cannot_approve_replacement(self):
        owner,actor=map(uid,[48,49]);self.add_users([owner,actor]);cid=create(owner,1)
        submit(cid,actor)
        old=token(cid,actor,owner)
        evidence(cid,actor,owner,submission=old)
        sql(f"select public.withdraw_claim('{cid}')",actor)
        submit(cid,actor,handle='replacement')
        new=token(cid,actor,owner)
        self.assertNotEqual(old,new)
        evidence(cid,actor,owner,submission=old,fails=True)
        review(cid,actor,owner,submission=old,fails=True)
        self.assertEqual(balance(actor),10)
        review(cid,actor,owner,submission=new)
        self.assertEqual(balance(actor),11)

    def test_08_withdrawal_approval_race(self):
        owner,actor=map(uid,[52,53]);self.add_users([owner,actor]);cid=create(owner,1)
        submit(cid,actor);submission=token(cid,actor,actor)
        def attempt(which):
            try:
                if which=='approve': review(cid,actor,owner,submission=submission)
                else: sql(f"select public.withdraw_claim('{cid}')",actor)
            except AssertionError: pass
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(attempt,['approve','withdraw']))
        status=sql(f"select status from public.campaign_claims where campaign_id='{cid}'",actor)
        self.assertIn(status,['approved','withdrawn'])
        self.assertEqual(balance(actor),11 if status=='approved' else 10)
        if status=='withdrawn': sql(f"select public.cancel_campaign('{cid}')",owner)
        self.assertEqual(balance(owner)+balance(actor),20)
        evidence(cid,actor,owner,fails=True)

    def test_09_bad_evidence_and_direct_access(self):
        owner,actor=map(uid,[50,51]);self.add_users([owner,actor]);cid=create(owner,1)
        submit(cid,actor,handle='https://evil',fails=True)
        submit(cid,actor,img='%%%bad',fails=True)
        submit(cid,actor,img=PNG,mime='image/jpeg',fails=True)
        sql(f"select public.submit_claim('{cid}','testuser','image/png',repeat('A',699053))",actor,fails=True)
        sql(f"update public.wallets set balance=999 where id='{actor}'",actor,fails=True)
        sql(f"insert into public.claim_evidence(campaign_id,user_id,mime_type,data_base64) values('{cid}','{actor}','image/png','{PNG}')",actor,fails=True)
        self.assertEqual(balance(actor),10)

if __name__=='__main__': unittest.main(verbosity=2)
