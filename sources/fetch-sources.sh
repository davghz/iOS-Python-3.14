#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UPSTREAM_DIR="$BASE_DIR/upstream"

PYTHON_URL="https://www.python.org/ftp/python/3.14.3/Python-3.14.3.tgz"
PIP_URL="https://files.pythonhosted.org/packages/source/p/pip/pip-26.0.1.tar.gz"

mkdir -p "$UPSTREAM_DIR"

curl -L --fail --retry 3 "$PYTHON_URL" -o "$UPSTREAM_DIR/Python-3.14.3.tgz"
curl -L --fail --retry 3 "$PIP_URL" -o "$UPSTREAM_DIR/pip-26.0.1.tar.gz"

(
  cd "$BASE_DIR"
  shasum -a 256 upstream/Python-3.14.3.tgz upstream/pip-26.0.1.tar.gz > SHA256SUMS
)

echo "Downloaded Python 3.14.3 and pip 26.0.1 sources."
echo "Wrote checksums to $BASE_DIR/SHA256SUMS."
