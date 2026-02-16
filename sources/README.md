# Python Source Mods

This directory tracks the Python source changes used for the iOS build.

## What is in git

- `patches/python3.14/*.patch`: patchset applied on top of CPython 3.14.3
- `modified/python3.14/`: direct copy of modified source files
- `fetch-sources.sh`: fetches upstream CPython/pip archives
- `apply-python-patches.sh`: recreates a patched CPython tree
- `build-ios-openssl-modules.sh`: builds `_ssl` and `_hashlib` for iOS
- `SHA256SUMS`: checksums for the fetched upstream archives

Upstream archives are fetched into `sources/upstream/` but are not required to
be committed to git.

Current Python patchset includes:

- `_scproxy` stub for iOS compatibility (pip/urllib startup path)
- `sitecustomize.py` CA-bundle wiring for default HTTPS verification

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

## Verify fetched archives

```sh
shasum -a 256 -c SHA256SUMS
```
