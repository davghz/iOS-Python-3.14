import bz2
import ctypes
import _decimal
import decimal
import ensurepip
import pip
import compression.zstd as zstd
import hashlib
import json
import lzma
import os
import pathlib
import readline
import curses
import curses.panel
import sqlite3
import ssl
import subprocess
import sys
import tempfile
import urllib.request
import venv
import zlib

assert sys.version_info[:3] == (3, 15, 2)
expected = os.path.realpath('/var/jb/usr/local/python3.15')
assert os.path.realpath(sys.prefix) == expected, sys.prefix
assert ssl.OPENSSL_VERSION.startswith('OpenSSL 3.2.1'), ssl.OPENSSL_VERSION
assert pip.__version__ == '26.3'
assert ensurepip.version() == '26.3'
assert decimal.Decimal('0.1') + decimal.Decimal('0.2') == decimal.Decimal('0.3')
assert hashlib.sha256(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
for module in (lzma, bz2, zlib, zstd):
    assert module.decompress(module.compress(b'rootless python')) == b'rootless python'
assert ctypes.CDLL(None).getpid() == os.getpid()
try:
    ctypes.CFUNCTYPE(ctypes.c_int)(lambda: 42)
except NotImplementedError:
    pass
else:
    raise AssertionError('The stable iPhoneOS callback restriction is missing')
with sqlite3.connect(':memory:') as db:
    assert db.execute('SELECT 6 * 7').fetchone() == (42,)
print('PASS: rootless prefix, OpenSSL 3, hashes, compression, ctypes, SQLite, readline, curses', flush=True)
with urllib.request.urlopen('https://pypi.org/pypi/pip/json', timeout=15) as response:
    assert response.status == 200
    assert json.load(response)['info']['name'] == 'pip'
print('PASS: verified HTTPS to PyPI', flush=True)
assert subprocess.check_output(['/var/jb/bin/sh', '-c', 'printf subprocess-ok'], text=True) == 'subprocess-ok'
print('PASS: Python shell subprocess', flush=True)
with tempfile.TemporaryDirectory(prefix='python315-rootless-') as tmp:
    env = pathlib.Path(tmp) / 'venv'
    venv.create(env, with_pip=True)
    pip_version = subprocess.check_output([env / 'bin/python', '-m', 'pip', '--version'], text=True)
    assert pip_version.startswith('pip 26.3 '), pip_version
    print(pip_version.strip(), flush=True)
print('PASS: virtual environment and pip bootstrap', flush=True)
