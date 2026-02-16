#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

WORK_SRC="${WORK_SRC:-$SCRIPT_DIR/work/Python-3.14.3}"
UPSTREAM_TGZ="${UPSTREAM_TGZ:-$SCRIPT_DIR/upstream/Python-3.14.3.tgz}"
DEST_DIR="$REPO_DIR/layout/usr/local/python3.14/lib/python3.14/test"

TMP_DIR=""
cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if [[ -d "$WORK_SRC/Lib/test" ]]; then
  SRC_DIR="$WORK_SRC/Lib/test"
elif [[ -f "$UPSTREAM_TGZ" ]]; then
  TMP_DIR="$(mktemp -d)"
  tar -xzf "$UPSTREAM_TGZ" -C "$TMP_DIR" "Python-3.14.3/Lib/test"
  SRC_DIR="$TMP_DIR/Python-3.14.3/Lib/test"
else
  echo "Missing test sources."
  echo "Provide $WORK_SRC/Lib/test or $UPSTREAM_TGZ."
  exit 1
fi

mkdir -p "$(dirname -- "$DEST_DIR")"
rm -rf "$DEST_DIR"
rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
find "$DEST_DIR" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "$DEST_DIR" -type f -name "*.pyc" -delete

echo "Staged Lib/test to:"
echo "  $DEST_DIR"
