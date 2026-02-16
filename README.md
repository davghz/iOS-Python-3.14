# iOS Python 3.14 Package

This repo builds a Theos `.deb` for CPython 3.14 on jailbroken iOS.

## What this package includes

- CPython `3.14.3`
- `pip 26.0.1`
- Install prefix: `/usr/local/python3.14`
- Source patchset for CPython rebuilds: `sources/patches/python3.14/`
- Source docs/scripts/checksums: `sources/README.md`, `sources/*.sh`, `sources/SHA256SUMS`
- iOS OpenSSL extension modules: `_ssl` and `_hashlib`

## iOS-specific fixes in this repo

- `_scproxy` compatibility stub (`overlay/usr/local/python3.14/lib/python3.14/_scproxy.py`)
  - Fixes `pip` startup on iOS where `_scproxy` C extension is unavailable.
  - Source-level patch tracked at `sources/patches/python3.14/0001-ios-add-scproxy-stub.patch`.
- iOS OpenSSL modules (`layout/.../lib-dynload/_ssl*.so`, `layout/.../lib-dynload/_hashlib*.so`)
  - Built using `sources/build-ios-openssl-modules.sh`.
  - Uses non-deprecated iOS linking (`-bundle_loader`) instead of `dynamic_lookup`.
- `postinst` ad-hoc signing (`overlay/DEBIAN/postinst`)
  - Signs Mach-O files in Python `bin/` and `lib-dynload/` using `ldid -S` after install.
  - Prevents immediate process kills from unsigned binaries/modules.

## Build

From this directory:

```sh
make package FINALPACKAGE=1
```

Output package path:

- `packages/com.davgz.python314_3.14.3-3_iphoneos-arm.deb`
- `packages/com.davgz.python314_3.14.3-4_iphoneos-arm.deb`

## Install on device with Theos

Theos remote install uses `ssh` directly. If you still use password auth,
wrap `ssh` with `sshpass`:

```sh
WRAPDIR=/tmp/theos-ssh-wrap
mkdir -p "$WRAPDIR"
cat > "$WRAPDIR/ssh" <<'EOF'
#!/bin/sh
exec /opt/homebrew/bin/sshpass -p alpine /usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
EOF
chmod 755 "$WRAPDIR/ssh"
PATH="$WRAPDIR:$PATH" make install THEOS_DEVICE_IP=172.20.10.9 THEOS_DEVICE_USER=root
```

## Verification notes

On iOS, Python is configured with `use_system_logger` by default, so CLI output
is redirected to Apple system logging instead of your SSH terminal.

Use exit codes (or file-based checks) for verification:

```sh
/usr/local/python3.14/bin/python3.14 -V; echo $?
/usr/local/python3.14/bin/pip --version; echo $?
/usr/local/python3.14/bin/python3.14 -c "import pip; open('/tmp/pipver','w').write(pip.__version__)" && cat /tmp/pipver
```

Expected after install: both commands exit `0`.

## Source code for others

The repo tracks the Python source modifications directly:

- Patchset: `sources/patches/python3.14/`
- Modified file mirror: `sources/modified/python3.14/`

Use `sources/fetch-sources.sh` + `sources/apply-python-patches.sh` to fetch
upstream and materialize a patched tree for rebuilds.

Use `sources/build-ios-openssl-modules.sh` to rebuild and stage the `_ssl` and
`_hashlib` extension modules for iOS.
