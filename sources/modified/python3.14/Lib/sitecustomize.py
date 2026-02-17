"""Package-level Python startup customizations for iOS."""

import os
import sys
from os.path import isfile

_CA_CANDIDATES = (
    "/usr/local/python3.14/lib/python3.14/site-packages/pip/_vendor/certifi/cacert.pem",
    "/usr/local/python3.14/lib/python3.14/site-packages/certifi/cacert.pem",
)

if not os.environ.get("SSL_CERT_FILE"):
    for _path in _CA_CANDIDATES:
        if isfile(_path):
            os.environ["SSL_CERT_FILE"] = _path
            os.environ.setdefault("REQUESTS_CA_BUNDLE", _path)
            os.environ.setdefault("CURL_CA_BUNDLE", _path)
            break


def _is_systemlog_stream(stream):
    cls = getattr(stream, "__class__", None)
    return bool(
        cls
        and getattr(cls, "__module__", "") == "_apple_support"
        and getattr(cls, "__name__", "") == "SystemLog"
    )


def _restore_stdio_for_shell_context():
    if not (
        _is_systemlog_stream(getattr(sys, "stdout", None))
        or _is_systemlog_stream(getattr(sys, "stderr", None))
    ):
        return
    try:
        os.fstat(1)
        os.fstat(2)
    except OSError:
        return
    try:
        stdout = open(
            1,
            "w",
            buffering=1,
            encoding="utf-8",
            errors="backslashreplace",
            closefd=False,
        )
        stderr = open(
            2,
            "w",
            buffering=1,
            encoding="utf-8",
            errors="backslashreplace",
            closefd=False,
        )
    except OSError:
        return
    sys.stdout = stdout
    sys.stderr = stderr
    if _is_systemlog_stream(getattr(sys, "__stdout__", None)):
        sys.__stdout__ = stdout
    if _is_systemlog_stream(getattr(sys, "__stderr__", None)):
        sys.__stderr__ = stderr


_restore_stdio_for_shell_context()
