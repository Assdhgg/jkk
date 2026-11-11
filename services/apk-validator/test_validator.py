import hashlib
import importlib.util
import io
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('validator', Path(__file__).with_name('validator.py'))
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)

class ValidatorTests(unittest.TestCase):
    def test_auth_and_configuration_fail_closed(self):
        def call(env):
            status = []
            body = v.application(env, lambda s, h: status.append(s))
            return status[0], json.loads(b''.join(body))
        with patch.dict(os.environ, {}, clear=True):
            self.assertTrue(call({})[0].startswith('503'))
        with patch.dict(os.environ, {'VALIDATOR_SECRET': 'x'*40, 'APK_SIGNER_SHA256': 'a'*64}):
            self.assertTrue(call({'REQUEST_METHOD':'POST','PATH_INFO':'/verify'})[0].startswith('401'))
            env = {'REQUEST_METHOD':'POST','PATH_INFO':'/verify','HTTP_AUTHORIZATION':'Bearer '+'x'*40,'CONTENT_LENGTH':'2','wsgi.input':io.BytesIO(b'{}')}
            self.assertTrue(call(env)[0].startswith('422'))

    def test_real_signed_apk_and_reject_wrong_signer_version_or_executable(self):
        apk = os.environ['TEST_APK']; signer_tool = os.environ['APKSIGNER']; aapt = os.environ['AAPT']
        output = subprocess.check_output([signer_tool,'verify','--print-certs',apk],text=True)
        signer = re.search(r'Signer #1 certificate SHA-256 digest: ([a-f0-9]{64})',output)[1]
        with open(apk,'rb') as stream: digest = hashlib.file_digest(stream,'sha256').hexdigest()
        version = int(re.search(r"versionCode='(\d+)'",subprocess.check_output([aapt,'dump','badging',apk],text=True))[1])
        name = re.search(r"versionName='([^']+)'",subprocess.check_output([aapt,'dump','badging',apk],text=True))[1]
        data = {'sha256':digest,'size':Path(apk).stat().st_size,'versionCode':version,'versionName':name}
        self.assertEqual(v.inspect_apk(apk,data,signer,signer_tool,aapt)['sha256'],digest)
        for metadata, fingerprint in [(data,'0'*64),({**data,'versionCode':version+1},signer),({**data,'sha256':'0'*64},signer)]:
            with self.assertRaises((ValueError,subprocess.SubprocessError)):
                v.inspect_apk(apk,metadata,fingerprint,signer_tool,aapt)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'renamed.apk'; path.write_bytes(b'MZsynthetic-not-an-apk')
            fake = {**data,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':path.stat().st_size}
            with self.assertRaises(subprocess.SubprocessError):
                v.inspect_apk(str(path),fake,signer,signer_tool,aapt)

if __name__ == '__main__': unittest.main()
