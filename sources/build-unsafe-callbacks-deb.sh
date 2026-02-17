#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

BASE_DEB="${BASE_DEB:-$REPO_DIR/packages/com.davgz.python314_3.14.3-10_iphoneos-arm.deb}"
UNSAFE_VERSION="${UNSAFE_VERSION:-3.14.3-11+unsafe1}"
OUT_DEB="${OUT_DEB:-$REPO_DIR/packages/com.davgz.python314-unsafe-callbacks_${UNSAFE_VERSION}_iphoneos-arm.deb}"

CTYPES_SO="${CTYPES_SO:-$REPO_DIR/layout/usr/local/python3.14/lib/python3.14/lib-dynload/_ctypes.cpython-314-arm64-iphoneos.so}"
SITECUSTOMIZE="${SITECUSTOMIZE:-$REPO_DIR/overlay/usr/local/python3.14/lib/python3.14/sitecustomize.py}"

for cmd in dpkg-deb perl; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd"
    exit 1
  }
done

if [[ ! -f "$BASE_DEB" ]]; then
  echo "Base deb missing: $BASE_DEB"
  exit 1
fi
if [[ ! -f "$CTYPES_SO" ]]; then
  echo "Built _ctypes module missing: $CTYPES_SO"
  echo "Run ./sources/build-ios-optional-modules.sh first."
  exit 1
fi
if [[ ! -f "$SITECUSTOMIZE" ]]; then
  echo "sitecustomize missing: $SITECUSTOMIZE"
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/python314-unsafe.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

dpkg-deb -R "$BASE_DEB" "$WORK_DIR/pkg"

install -m 0755 "$CTYPES_SO" \
  "$WORK_DIR/pkg/usr/local/python3.14/lib/python3.14/lib-dynload/_ctypes.cpython-314-arm64-iphoneos.so"
install -m 0644 "$SITECUSTOMIZE" \
  "$WORK_DIR/pkg/usr/local/python3.14/lib/python3.14/sitecustomize.py"

CONTROL="$WORK_DIR/pkg/DEBIAN/control"
perl -0pi -e 's/^Package:\s*.*/Package: com.davgz.python314-unsafe-callbacks/m' "$CONTROL"
perl -0pi -e 's/^Name:\s*.*/Name: Python 3.14 for iOS (Unsafe Callbacks)/m' "$CONTROL"
perl -0pi -e "s/^Version:\\s*.*/Version: ${UNSAFE_VERSION}/m" "$CONTROL"
perl -0pi -e 's/^Description:\s*.*/Description: CPython 3.14.3 with pip 26.0.1 for jailbroken iOS devices (UNSAFE ctypes callback variant; may crash)./m' "$CONTROL"
if ! grep -q '^Conflicts:' "$CONTROL"; then
  printf 'Conflicts: com.davgz.python314\n' >> "$CONTROL"
fi
if ! grep -q '^Replaces:' "$CONTROL"; then
  printf 'Replaces: com.davgz.python314\n' >> "$CONTROL"
fi

mkdir -p "$(dirname -- "$OUT_DEB")"
rm -f "$OUT_DEB"
dpkg-deb -b "$WORK_DIR/pkg" "$OUT_DEB" >/dev/null

echo "Built unsafe package:"
echo "  $OUT_DEB"
