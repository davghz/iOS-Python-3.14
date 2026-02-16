#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

WORK_ROOT="${WORK_ROOT:-/Users/davgz/theos-python315-deb/work}"
PY_BUILD="${PY_BUILD:-$WORK_ROOT/py314-ios-full}"
PY_SRC="${PY_SRC:-$WORK_ROOT/Python-3.14.3}"
IOS_SDK="${IOS_SDK:-/Users/davgz/theos/sdks/iPhoneOS13.7.sdk}"
IOS_EXTRA="${IOS_EXTRA:-$WORK_ROOT/ios-extra}"

TARGET_IP="${TARGET_IP:-172.20.10.9}"
TARGET_USER="${TARGET_USER:-root}"
TARGET_PASS="${TARGET_PASS:-}"

SOABI_SUFFIX="cpython-314-arm64-iphoneos.so"
DEST_DIR="$REPO_DIR/layout/usr/local/python3.14/lib/python3.14/lib-dynload"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

ssh_test_file() {
  local remote_path="$1"
  /opt/homebrew/bin/sshpass -p "$TARGET_PASS" /usr/bin/ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$TARGET_USER@$TARGET_IP" "test -f '$remote_path'"
}

scp_file() {
  local remote_path="$1"
  local local_path="$2"
  /opt/homebrew/bin/sshpass -p "$TARGET_PASS" /usr/bin/scp \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$TARGET_USER@$TARGET_IP:$remote_path" "$local_path"
}

scp_dir() {
  local remote_path="$1"
  local local_path="$2"
  /opt/homebrew/bin/sshpass -p "$TARGET_PASS" /usr/bin/scp -r \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$TARGET_USER@$TARGET_IP:$remote_path" "$local_path"
}

fetch_remote_file_if_missing() {
  local remote_path="$1"
  local local_path="$2"
  if [[ -f "$local_path" ]]; then
    return 0
  fi
  if [[ -z "$TARGET_PASS" ]]; then
    echo "Missing $local_path and TARGET_PASS is not set."
    echo "Set TARGET_PASS to pull files from device."
    exit 1
  fi
  if ! ssh_test_file "$remote_path"; then
    echo "Device file not found: $remote_path"
    exit 1
  fi
  mkdir -p "$(dirname -- "$local_path")"
  scp_file "$remote_path" "$local_path"
}

fetch_remote_file_first_if_missing() {
  local local_path="$1"
  shift
  if [[ -f "$local_path" ]]; then
    return 0
  fi
  if [[ -z "$TARGET_PASS" ]]; then
    echo "Missing $local_path and TARGET_PASS is not set."
    echo "Set TARGET_PASS to pull files from device."
    exit 1
  fi
  local remote_path
  for remote_path in "$@"; do
    if ssh_test_file "$remote_path"; then
      mkdir -p "$(dirname -- "$local_path")"
      scp_file "$remote_path" "$local_path"
      return 0
    fi
  done
  echo "Device file not found in candidates: $*"
  exit 1
}

fetch_remote_dir_if_missing() {
  local remote_path="$1"
  local local_path="$2"
  if [[ -d "$local_path" ]]; then
    return 0
  fi
  if [[ -z "$TARGET_PASS" ]]; then
    echo "Missing $local_path and TARGET_PASS is not set."
    echo "Set TARGET_PASS to pull include directories from device."
    exit 1
  fi
  mkdir -p "$(dirname -- "$local_path")"
  scp_dir "$remote_path" "$local_path"
}

need_cmd /usr/bin/clang
need_cmd /usr/bin/ssh
need_cmd /usr/bin/scp
need_cmd /opt/homebrew/bin/sshpass

mkdir -p "$IOS_EXTRA/include" "$IOS_EXTRA/lib" "$DEST_DIR"

# Runtime libraries
fetch_remote_file_first_if_missing "$IOS_EXTRA/lib/libffi.6.dylib" \
  "/usr/lib/libffi.6.dylib" "/usr/lib/libffi.dylib"
fetch_remote_file_if_missing "/usr/lib/libffi.dylib" "$IOS_EXTRA/lib/libffi.dylib"
fetch_remote_file_first_if_missing "$IOS_EXTRA/lib/liblzma.5.dylib" \
  "/usr/local/lib/liblzma.5.dylib" "/usr/lib/liblzma.5.dylib" "/usr/lib/liblzma.dylib"
fetch_remote_file_first_if_missing "$IOS_EXTRA/lib/libreadline.8.dylib" \
  "/usr/lib/libreadline.8.dylib" "/usr/lib/libreadline.dylib"
fetch_remote_file_if_missing "/usr/lib/libreadline.dylib" "$IOS_EXTRA/lib/libreadline.dylib"
fetch_remote_file_first_if_missing "$IOS_EXTRA/lib/libncursesw.6.dylib" \
  "/usr/lib/libncursesw.6.dylib" "/usr/lib/libncursesw.dylib"
fetch_remote_file_if_missing "/usr/lib/libncursesw.dylib" "$IOS_EXTRA/lib/libncursesw.dylib"
fetch_remote_file_first_if_missing "$IOS_EXTRA/lib/libpanelw.6.dylib" \
  "/usr/lib/libpanelw.6.dylib" "/usr/lib/libpanelw.dylib"
fetch_remote_file_if_missing "/usr/lib/libpanelw.dylib" "$IOS_EXTRA/lib/libpanelw.dylib"

# Development headers
fetch_remote_file_if_missing "/usr/include/ffi.h" "$IOS_EXTRA/include/ffi.h"
fetch_remote_file_if_missing "/usr/include/ffitarget.h" "$IOS_EXTRA/include/ffitarget.h"
fetch_remote_file_if_missing "/usr/include/lzma.h" "$IOS_EXTRA/include/lzma.h"
fetch_remote_dir_if_missing "/usr/include/lzma" "$IOS_EXTRA/include/lzma"
fetch_remote_dir_if_missing "/usr/include/readline" "$IOS_EXTRA/include/readline"
fetch_remote_file_if_missing "/usr/include/curses.h" "$IOS_EXTRA/include/curses.h"
fetch_remote_file_if_missing "/usr/include/panel.h" "$IOS_EXTRA/include/panel.h"
fetch_remote_file_if_missing "/usr/include/ncurses.h" "$IOS_EXTRA/include/ncurses.h"
fetch_remote_dir_if_missing "/usr/include/ncursesw" "$IOS_EXTRA/include/ncursesw"

ln -sf liblzma.5.dylib "$IOS_EXTRA/lib/liblzma.dylib"

COMMON_FLAGS=(-target arm64-apple-ios13.0 -isysroot "$IOS_SDK" -miphoneos-version-min=13.0)
BASE_CFLAGS=(
  -fno-strict-overflow -Wsign-compare -Wunreachable-code -DNDEBUG -g -O3 -Wall
  -std=c11 -Wextra -Wno-unused-parameter -Wno-missing-field-initializers
  -Wstrict-prototypes -Werror=implicit-function-declaration -fvisibility=hidden
  -Werror=unguarded-availability
  -I"$PY_SRC/Include/internal" -I"$PY_SRC/Include/internal/mimalloc"
  -I"$PY_BUILD/Objects" -I"$PY_BUILD/Include" -I"$PY_BUILD/Python" -I"$PY_BUILD"
  -I"$PY_SRC/Include" -I"$IOS_SDK/usr/include" -I"$IOS_EXTRA/include"
  -I"$IOS_EXTRA/include/ncursesw"
)
CTYPES_CFLAGS=(
  -DUSING_MALLOC_CLOSURE_DOT_C=1
  -DUSING_APPLE_OS_LIBFFI=1
  -DHAVE_FFI_CLOSURE_ALLOC=1
  -DHAVE_FFI_PREP_CLOSURE_LOC=1
  -DHAVE_FFI_PREP_CIF_VAR=1
)

cd "$PY_BUILD"

# _ctypes
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" "${CTYPES_CFLAGS[@]}" -c "$PY_SRC/Modules/_ctypes/_ctypes.c" -o Modules/_ctypes__ctypes.o
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" "${CTYPES_CFLAGS[@]}" -c "$PY_SRC/Modules/_ctypes/callbacks.c" -o Modules/_ctypes__callbacks.o
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" "${CTYPES_CFLAGS[@]}" -c "$PY_SRC/Modules/_ctypes/callproc.c" -o Modules/_ctypes__callproc.o
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" "${CTYPES_CFLAGS[@]}" -c "$PY_SRC/Modules/_ctypes/stgdict.c" -o Modules/_ctypes__stgdict.o
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" "${CTYPES_CFLAGS[@]}" -c "$PY_SRC/Modules/_ctypes/cfield.c" -o Modules/_ctypes__cfield.o
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" "${CTYPES_CFLAGS[@]}" -c "$PY_SRC/Modules/_ctypes/malloc_closure.c" -o Modules/_ctypes__malloc_closure.o
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/_ctypes__ctypes.o Modules/_ctypes__callbacks.o Modules/_ctypes__callproc.o \
  Modules/_ctypes__stgdict.o Modules/_ctypes__cfield.o Modules/_ctypes__malloc_closure.o \
  -L"$IOS_EXTRA/lib" -lffi -o "Modules/_ctypes.$SOABI_SUFFIX"

# _lzma
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" -c "$PY_SRC/Modules/_lzmamodule.c" -o Modules/_lzma.o
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/_lzma.o -L"$IOS_EXTRA/lib" -llzma -o "Modules/_lzma.$SOABI_SUFFIX"

# readline
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" -c "$PY_SRC/Modules/readline.c" -o Modules/readline.o
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/readline.o -L"$IOS_EXTRA/lib" -lreadline -lncursesw -o "Modules/readline.$SOABI_SUFFIX"

# curses
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" \
  -DHAVE_NCURSESW_CURSES_H=1 -DHAVE_TERM_H=1 \
  -c "$PY_SRC/Modules/_cursesmodule.c" -o Modules/_curses.o
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/_curses.o -L"$IOS_EXTRA/lib" -lncursesw -o "Modules/_curses.$SOABI_SUFFIX"

# curses panel
/usr/bin/clang "${COMMON_FLAGS[@]}" "${BASE_CFLAGS[@]}" \
  -DHAVE_NCURSESW_CURSES_H=1 -DHAVE_NCURSESW_PANEL_H=1 \
  -c "$PY_SRC/Modules/_curses_panel.c" -o Modules/_curses_panel.o
/usr/bin/clang "${COMMON_FLAGS[@]}" -bundle -bundle_loader "$PY_BUILD/python.exe" \
  Modules/_curses_panel.o -L"$IOS_EXTRA/lib" -lpanelw -lncursesw -o "Modules/_curses_panel.$SOABI_SUFFIX"

cp "Modules/_ctypes.$SOABI_SUFFIX" "$DEST_DIR/"
cp "Modules/_lzma.$SOABI_SUFFIX" "$DEST_DIR/"
cp "Modules/readline.$SOABI_SUFFIX" "$DEST_DIR/"
cp "Modules/_curses.$SOABI_SUFFIX" "$DEST_DIR/"
cp "Modules/_curses_panel.$SOABI_SUFFIX" "$DEST_DIR/"

echo "Built and staged:"
echo "  $DEST_DIR/_ctypes.$SOABI_SUFFIX"
echo "  $DEST_DIR/_lzma.$SOABI_SUFFIX"
echo "  $DEST_DIR/readline.$SOABI_SUFFIX"
echo "  $DEST_DIR/_curses.$SOABI_SUFFIX"
echo "  $DEST_DIR/_curses_panel.$SOABI_SUFFIX"
