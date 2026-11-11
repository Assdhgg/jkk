"""Fail-closed APK validation. Run behind HTTPS; never expose this port directly."""
import hashlib
import hmac
import json
import os
import re
import subprocess
import tempfile
import urllib.request
from pathlib import Path

MAX_SIZE = 209715200

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('Redirect forbidden')

def inspect_apk(path, metadata, signer, apksigner, aapt):
    with open(path, 'rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != metadata['sha256'] or Path(path).stat().st_size != metadata['size']:
        raise ValueError('Hash/size mismatch')
    result = subprocess.run([apksigner, 'verify', '--verbose', '--print-certs', path],
                            check=True, capture_output=True, text=True, timeout=90).stdout
    certificates = re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]{64})$', result, re.M)
    # Explicit allowlist: reject additional signers; rotation requires operator update.
    if len(certificates) != 1 or not hmac.compare_digest(certificates[0].lower(), signer):
        raise ValueError('Untrusted signer')
    badging = subprocess.run([aapt, 'dump', 'badging', path], check=True,
                             capture_output=True, text=True, timeout=30).stdout
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']*)'", badging, re.M)
    if not package or package[1] != 'space.freelan.app' or int(package[2]) != metadata['versionCode'] or package[3] != metadata['versionName']:
        raise ValueError('Package/version mismatch')
    return {'sha256': digest, 'size': metadata['size'], 'versionCode': int(package[2])}

def application(environ, start_response):
    def respond(status, data):
        body = json.dumps(data).encode()
        start_response(status, [('Content-Type', 'application/json'), ('Cache-Control', 'no-store')])
        return [body]
    secret = os.environ.get('VALIDATOR_SECRET', '')
    signer = os.environ.get('APK_SIGNER_SHA256', '').lower()
    if len(secret) < 32 or not re.fullmatch('[a-f0-9]{64}', signer):
        return respond('503 Service Unavailable', {'error': 'configuration'})
    if environ.get('REQUEST_METHOD') != 'POST' or environ.get('PATH_INFO') != '/verify':
        return respond('404 Not Found', {'error': 'not_found'})
    if not hmac.compare_digest(environ.get('HTTP_AUTHORIZATION', ''), 'Bearer ' + secret):
        return respond('401 Unauthorized', {'error': 'unauthorized'})
    try:
        length = int(environ.get('CONTENT_LENGTH', '0'))
        if not 1 <= length <= 16384: raise ValueError('Request size')
        data = json.loads(environ['wsgi.input'].read(length))
        if type(data['size']) is not int or not 4 <= data['size'] <= MAX_SIZE or not re.fullmatch('[a-f0-9]{64}', data['sha256']): raise ValueError('Metadata')
        from urllib.parse import urlparse
        url = urlparse(data['url'])
        host = os.environ['R2_DOWNLOAD_HOST']
        bucket = os.environ['R2_BUCKET']
        if not re.fullmatch(r'[a-f0-9]{32}\.r2\.cloudflarestorage\.com', host): raise ValueError('Configuration')
        if url.scheme != 'https' or url.netloc != host or url.username or url.fragment or not re.fullmatch('/' + re.escape(bucket) + r'/staging/[a-f0-9-]{36}/[a-f0-9-]{36}\.apk', url.path): raise ValueError('Source URL')
        if not re.fullmatch(r'"[a-fA-F0-9-]+"', data['etag']): raise ValueError('ETag')
        request = urllib.request.Request(data['url'], headers={'If-Match': data['etag']})
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / 'release.apk')
            with urllib.request.build_opener(NoRedirect).open(request, timeout=30) as response, open(path, 'wb') as output:
                count = 0
                while chunk := response.read(1024 * 1024):
                    count += len(chunk)
                    if count > data['size']: raise ValueError('Oversized upload')
                    output.write(chunk)
            result = inspect_apk(path, data, signer, os.environ.get('APKSIGNER', '/opt/android/apksigner'), os.environ.get('AAPT', '/opt/android/aapt'))
        return respond('200 OK', result)
    except Exception:
        # Never log presigned URLs, shared secrets, APK content or subprocess output.
        return respond('422 Unprocessable Entity', {'error': 'verification_failed'})
