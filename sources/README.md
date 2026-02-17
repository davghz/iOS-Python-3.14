# Python Source Mods

This directory tracks the Python source changes used for the iOS build.

## What is in git

- `patches/python3.14/*.patch`: patchset applied on top of CPython 3.14.3
- `modified/python3.14/`: direct copy of modified source files
- `fetch-sources.sh`: fetches upstream CPython/pip archives
- `apply-python-patches.sh`: recreates a patched CPython tree
- `build-ios-openssl-modules.sh`: builds `_ssl` and `_hashlib` for iOS
- `build-ios-optional-modules.sh`: builds `_ctypes`, `_lzma`, `readline`, `_curses`, `_curses_panel` for iOS
- `build-unsafe-callbacks-deb.sh`: repacks a full base `.deb` into unsafe callback variant
- `stage-libtest.sh`: stages `Lib/test` into package layout
- `SHA256SUMS`: checksums for the fetched upstream archives

Upstream archives are fetched into `sources/upstream/` but are not required to
be committed to git.

Current Python patchset includes:

- `_scproxy` stub for iOS compatibility (pip/urllib startup path)
- `sitecustomize.py` CA-bundle wiring for default HTTPS verification
- `sitecustomize.py` stdio restore for SSH/TTY shells when iOS SystemLog streams are active
- iPhoneOS non-interactive TTY skips for `Lib/test/test_readline.py` and `Lib/test/test_curses.py`
- iPhoneOS skips for unstable ctypes callback tests in `Lib/test/test_ctypes`
- iPhoneOS runtime guard in `Modules/_ctypes/callbacks.c` to disable crash-prone callbacks
- optional unsafe patch (`0007`) to re-enable `_ctypes` callbacks on iPhoneOS for experimentation
  - current observed behavior on iPhone10,3 / iOS 13.2.3: callback invocation still SIGBUS-es

## Recreate patched CPython source

```sh
./fetch-sources.sh
./apply-python-patches.sh
```

Patched source output path:

- `sources/work/Python-3.14.3`

## Build iOS SSL extension modules

```sh
TARGET_PASS=alpine ./build-ios-openssl-modules.sh
```

This builds and stages:

- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/_ssl.cpython-314-arm64-iphoneos.so`
- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/_hashlib.cpython-314-arm64-iphoneos.so`

## Build iOS optional extension modules

```sh
TARGET_PASS=alpine ./build-ios-optional-modules.sh
```

This builds and stages:

- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/_ctypes.cpython-314-arm64-iphoneos.so`
- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/_lzma.cpython-314-arm64-iphoneos.so`
- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/readline.cpython-314-arm64-iphoneos.so`
- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/_curses.cpython-314-arm64-iphoneos.so`
- `layout/usr/local/python3.14/lib/python3.14/lib-dynload/_curses_panel.cpython-314-arm64-iphoneos.so`

`_ctypes` is compiled with Apple libffi closure/cif feature flags so callback
paths use `ffi_closure_alloc`/`ffi_prep_closure_loc`/`ffi_prep_cif_var` on iOS.

## Stage Lib/test for regrtest support

```sh
./stage-libtest.sh
```

This stages:

- `layout/usr/local/python3.14/lib/python3.14/test/`

## Verify fetched archives

```sh
shasum -a 256 -c SHA256SUMS
```
