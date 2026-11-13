"""Run against a disposable database with bootstrap and all migrations."""
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]

def sql(query):
    return subprocess.run(
        ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', query],
        capture_output=True, text=True,
    )

class RpcInvoker(unittest.TestCase):
    def test_legacy_claim_still_fails_closed(self):
        result = sql("set role authenticated; select public.claim_task('00000000-0000-4000-8000-000000000001')")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Please update the app to submit a task for review.', result.stderr)
        result = sql("set role anon; select public.claim_task('00000000-0000-4000-8000-000000000001')")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('permission denied', result.stderr)

    def test_legacy_rpcs_use_invoker(self):
        result = sql("select prosecdef from pg_proc where oid in ('public.claim_task(uuid)'::regprocedure, 'public.admin_send_notification(uuid,uuid,text,text)'::regprocedure) order by oid")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip().splitlines(), ['f', 'f'])

if __name__ == '__main__': unittest.main()
