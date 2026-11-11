"""Privileged synthetic Auth issuance, for disposable PostgreSQL tests only."""
import subprocess


def issue_pin_nonce(db, user, nonce='123456', age='10 seconds'):
    subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', db, '-c',
                    f"update auth.users set reauthentication_token=encode(extensions.digest(email || '{nonce}','sha224'),'hex'), reauthentication_sent_at=now()-interval '{age}' where id='{user}'"],
                   check=True, capture_output=True, text=True)
