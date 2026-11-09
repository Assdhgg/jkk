"""Disposable database only: bootstrap + all migrations, with mock auth.mfa_factors."""
import concurrent.futures, json, subprocess, sys, unittest
DB=sys.argv[1]; sys.argv=sys.argv[:1]
A='71000000-0000-4000-8000-000000000001'; B='71000000-0000-4000-8000-000000000002'; V='71000000-0000-4000-8000-000000000003'; U='71000000-0000-4000-8000-000000000004'; O='71000000-0000-4000-8000-000000000005'; C='72000000-0000-4000-8000-000000000001'; D='71000000-0000-4000-8000-000000000006'; F='73000000-0000-4000-8000-000000000001'
def sql(q,uid=None,claims=None,fails=False):
    prefix=f"set role authenticated; select set_config('request.jwt.claim.sub','{uid}',false); select set_config('request.jwt.claims','{json.dumps(claims or {})}',false); " if uid else ''
    r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+q],capture_output=True,text=True)
    if fails:
        if r.returncode==0: raise AssertionError('Unexpected success: '+q)
    elif r.returncode: raise AssertionError(r.stderr)
    return (r.stdout.strip().splitlines() or [''])[-1]
class Operations(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
    sql(f"""insert into auth.users(id,email) values ('{A}','a@example.test'),('{B}','b@example.test'),('{V}','v@example.test'),('{U}','u@example.test'),('{O}','o@example.test'),('{D}','d@example.test');
    insert into public.admin_members(user_id,role) values ('{A}','editor'),('{B}','editor'),('{V}','viewer'),('{D}','editor');
    insert into public.wallets(id,balance) values ('{U}',10),('{O}',10);
    insert into public.campaigns(id,\"ownerId\",type,link,status,requested,remaining,reward_per_task) values ('{C}','{O}','like','https://instagram.com/p/TEST/','active',5,3,2);""")
 def test_01_tickets_privacy_and_events(self):
    tid=sql("select public.support_create_ticket('Help','Please help')",U)
    self.assertEqual(sql(f"select count(*) from public.support_messages('{tid}')",U),'1')
    sql(f"select * from public.support_messages('{tid}')",O,fails=True)
    sql(f"select public.support_reply('{tid}','Reply')",V,fails=True)
    sql(f"select public.support_reply('{tid}','Reply')",A)
    self.assertEqual(sql(f"select count(*) from public.support_messages('{tid}')",U),'2')
    self.assertEqual(sql('select count(*) from public.admin_event_feed()',A),'1')
    sql('select public.admin_mark_event_read((select id from public.admin_event_feed() limit 1))',V)
    self.assertEqual(sql('select count(*) from public.admin_event_feed() where read',V),'1')
    self.assertEqual(sql('select count(*) from public.admin_event_feed() where read',A),'0')
    sql(f"select public.admin_close_ticket('{tid}')",A)
    sql(f"select public.support_reply('{tid}','again')",U,fails=True)
 def test_02_campaign_report_and_refund(self):
    rid=sql(f"select public.report_campaign('{C}','Unsafe')",U)
    sql(f"select public.admin_resolve_report('{rid}',true)",V,fails=True)
    sql(f"select public.admin_resolve_report('{rid}',true)",A)
    self.assertEqual(sql(f"select balance from public.wallets where id='{O}'",O),'16')
    self.assertEqual(sql(f"select status from public.campaigns where id='{C}'",O),'cancelled')
    self.assertEqual(sql(f"select count(*) from public.coin_ledger where user_id='{O}' and amount=6 and reason='refund'",O),'1')
    sql(f"select public.admin_resolve_report('{rid}',true)",B,fails=True)
 def test_03_coin_approval_atomicity(self):
    rid=sql(f"select public.admin_request_adjustment('{U}',-3,'Correction')",A)
    sql(f"select public.admin_decide_adjustment('{rid}',true)",A,fails=True)
    sql(f"select public.admin_decide_adjustment('{rid}',true)",V,fails=True)
    sql(f"select public.admin_decide_adjustment('{rid}',true)",B)
    self.assertEqual(sql(f"select balance from public.wallets where id='{U}'",U),'7')
    self.assertEqual(sql(f"select count(*) from public.coin_ledger where user_id='{U}' and amount=-3 and reason='admin_adjustment'",U),'1')
    sql(f"select public.admin_decide_adjustment('{rid}',true)",B,fails=True)
    self.assertEqual(sql("select count(*) from public.admin_activity() where action='Coin correction approved'",A),'1')
    bad=sql(f"select public.admin_request_adjustment('{U}',-100,'Too much')",A)
    sql(f"select public.admin_decide_adjustment('{bad}',true)",B,fails=True)
    self.assertEqual(sql(f"select balance from public.wallets where id='{U}'",U),'7')
 def test_04_concurrent_coin_approval_is_once(self):
    rid=sql(f"select public.admin_request_adjustment('{U}',5,'Concurrent')",A)
    def decide(actor):
      try: sql(f"select public.admin_decide_adjustment('{rid}',true)",actor); return True
      except AssertionError: return False
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(decide,[B,D]))
    self.assertEqual(sorted(results),[False,True])
    self.assertEqual(sql(f"select count(*) from public.coin_ledger where user_id='{U}' and amount=5 and reason='admin_adjustment'",U),'1')
    self.assertEqual(sql(f"select balance from public.wallets where id='{U}'",U),'12')
 def test_05_thresholds_notes_and_mfa(self):
    sql("select public.admin_set_alert_setting('coins_24h',10)",V,fails=True)
    sql("select public.admin_set_alert_setting('coins_24h',10)",A)
    self.assertEqual(sql("select value from public.admin_alert_settings() where key='coins_24h'",V),'10')
    sql(f"select public.admin_add_note('user','{U}','Investigate')",A)
    sql(f"select public.admin_add_note('user','{U}','No')",V,fails=True)
    self.assertEqual(sql(f"select count(*) from public.admin_notes('user','{U}')",V),'1')
    sql(f"select * from public.admin_notes('user','{U}')",U,fails=True)
    sql(f"insert into auth.mfa_factors(id,user_id,status) values ('{F}','{A}','verified')")
    sql('select * from public.admin_event_feed()',A,fails=True)
    sql("select public.admin_set_coin_setting('like',2)",A,fails=True)
    sql('select * from public.admin_event_feed()',A,{'aal':'aal2'})
    sql("select public.admin_set_coin_setting('like',2)",A,{'aal':'aal2'})
if __name__=='__main__': unittest.main(verbosity=2)
