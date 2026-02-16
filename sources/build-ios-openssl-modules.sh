#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

WORK_ROOT="${WORK_ROOT:-/Users/davgz/theos-python315-deb/work}"
PY_BUILD="${PY_BUILD:-$WORK_ROOT/py314-ios-full}"
PY_SRC="${PY_SRC:-$WORK_ROOT/Python-3.14.3}"
IOS_SDK="${IOS_SDK:-/Users/davgz/theos/sdks/iPhoneOS13.7.sdk}"

OPENSSL_ROOT="$WORK_ROOT/ios-openssl"
OPENSSL_SRC="$OPENSSL_ROOT/src/openssl-1.1.1n"
OPENSSL_TGZ="$OPENSSL_ROOT/src/openssl-1.1.1n.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/old/1.1.1/openssl-1.1.1n.tar.gz"

TARGET_IP="${TARGET_IP:-172.20.10.9}"
TARGET_USER="${TARGET_USER:-root}"
TARGET_PASS="${TARGET_PASS:-}"

mkdir -p "$OPENSSL_ROOT/src" "$OPENSSL_ROOT/lib" "$OPENSSL_ROOT/include"

if [[ ! -f "$OPENSSL_ROOT/lib/libssl.1.1.dylib" || ! -f "$OPENSSL_ROOT/lib/libcrypto.1.1.dylib" ]]; then
  if [[ -z "$TARGET_PASS" ]]; then
    echo "Missing iOS OpenSSL dylibs and TARGET_PASS is not set."
    echo "Set TARGET_PASS to pull /usr/lib/libssl.1.1.dylib and libcrypto.1.1.dylib from device."
    exit 1
  fi
  /opt/homebrew/bin/sshpass -p "$TARGET_PASS" /usr/bin/scp \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$TARGET_USER@$TARGET_IP:/usr/lib/libssl.1.1.dylib" \
    "$OPENSSL_ROOT/lib/libssl.1.1.dylib"
  /opt/homebrew/bin/sshpass -p "$TARGET_PASS" /usr/bin/scp \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$TARGET_USER@$TARGET_IP:/usr/lib/libcrypto.1.1.dylib" \
    "$OPENSSL_ROOT/lib/libcrypto.1.1.dylib"
fi

ln -sf libssl.1.1.dylib "$OPENSSL_ROOT/lib/libssl.dylib"
ln -sf libcrypto.1.1.dylib "$OPENSSL_ROOT/lib/libcrypto.dylib"

if [[ ! -f "$OPENSSL_TGZ" ]]; then
  curl -L --fail --retry 3 "$OPENSSL_URL" -o "$OPENSSL_TGZ"
fi
if [[ ! -d "$OPENSSL_SRC" ]]; then
  tar -xzf "$OPENSSL_TGZ" -C "$OPENSSL_ROOT/src"
fi

(
  cd "$OPENSSL_SRC"
  export CROSS_TOP="/Users/davgz/theos/sdks"
  export CROSS_SDK="$(basename "$IOS_SDK")"
  export CC="clang -target arm64-apple-ios13.0 -isysroot $IOS_SDK -miphoneos-version-min=13.0"
  ./Configure ios64-cross no-shared no-tests --prefix=/tmp/openssl-ios >/dev/null 2>&1
  make -j8 build_generated >/dev/null 2>&1
)

rsync -a --delete "$OPENSSL_SRC/include/" "$OPENSSL_ROOT/include/"

COMMON_FLAGS=( -target arm64-apple-ios13.0 -isysroot "$IOS_SDK" -miphoneos-version-min=13.0 )
CFLAGS=(
  -fno-strict-overflow -Wsign-compare -Wunreachable-code -DNDEBUG -g -O3 -Wall
  -std=c11 -Wextra -Wno-unused-parameter -Wno-missing-field-initializers
  -Wstrict-prototypes -Werror=implicit-function-declaration -fvisibility=hidden
  -Werror=unguarded-availability
  -I"$PY_SRC/Include/internal" -I"$PY_SRC/Include/internal/mimalloc"
  -I"$PY_BUILD/Objects" -I"$PY_BUILD/Include" -I"$PY_BUILD/Python" -I"$PY_BUILD"
  -I"$PY_SRC/Include" -I"$IOS_SDK/usr/include" -DPy_BUILD_CORE_BUILTIN
)

cd "$PY_BUILD"
/usr/bin/clang "${COMMON_FLAGS[@]}" -I"$OPENSSL_ROOT/include" "${CFLAGS[@]}" \
  -c "$PY_SRC/Modules/_ssl.c" -o Modules/_ssl.o
/usr/bin/clang "${COMMON_FLAGS[@]}" -I"$OPENSSL_ROOT/include" "${CFLAGS[@]}" \
  -c "$PY_SRC/Modules/_hashopenssl.c" -o Modules/_hashopenssl.o

# Use bundle_loader instead of deprecated dynamic_lookup on iOS.
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/_ssl.o -L"$OPENSSL_ROOT/lib" -lssl -lcrypto \
  -o Modules/_ssl.cpython-314-arm64-iphoneos.so
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/_hashopenssl.o -L"$OPENSSL_ROOT/lib" -lcrypto \
  -o Modules/_hashlib.cpython-314-arm64-iphoneos.so

DEST_DIR="$REPO_DIR/layout/usr/local/python3.14/lib/python3.14/lib-dynload"
mkdir -p "$DEST_DIR"
cp Modules/_ssl.cpython-314-arm64-iphoneos.so "$DEST_DIR/"
cp Modules/_hashlib.cpython-314-arm64-iphoneos.so "$DEST_DIR/"

echo "Built and staged:"
echo "  $DEST_DIR/_ssl.cpython-314-arm64-iphoneos.so"
echo "  $DEST_DIR/_hashlib.cpython-314-arm64-iphoneos.so"
