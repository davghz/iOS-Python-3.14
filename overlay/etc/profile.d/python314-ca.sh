#!/bin/sh

CA_BUNDLE="/usr/local/python3.14/lib/python3.14/site-packages/pip/_vendor/certifi/cacert.pem"

if [ -z "${SSL_CERT_FILE:-}" ] && [ -f "$CA_BUNDLE" ]; then
  export SSL_CERT_FILE="$CA_BUNDLE"
fi

if [ -z "${REQUESTS_CA_BUNDLE:-}" ] && [ -f "$CA_BUNDLE" ]; then
  export REQUESTS_CA_BUNDLE="$CA_BUNDLE"
fi

if [ -z "${CURL_CA_BUNDLE:-}" ] && [ -f "$CA_BUNDLE" ]; then
  export CURL_CA_BUNDLE="$CA_BUNDLE"
fi
