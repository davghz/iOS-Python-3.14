"""Package-level Python startup customizations for iOS."""

import os
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
