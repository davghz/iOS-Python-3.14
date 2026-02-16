#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ARCHIVE="$BASE_DIR/upstream/Python-3.14.3.tgz"
WORK_DIR="$BASE_DIR/work"
SRC_DIR="$WORK_DIR/Python-3.14.3"
PATCH_DIR="$BASE_DIR/patches/python3.14"

if [ ! -f "$ARCHIVE" ]; then
  echo "Missing $ARCHIVE"
  echo "Run ./fetch-sources.sh first."
  exit 1
fi

rm -rf "$SRC_DIR"
mkdir -p "$WORK_DIR"
tar -xzf "$ARCHIVE" -C "$WORK_DIR"

for patch in "$PATCH_DIR"/*.patch; do
  [ -f "$patch" ] || continue
  (cd "$SRC_DIR" && patch -p1 < "$patch")
done

echo "Patched source tree ready at: $SRC_DIR"
