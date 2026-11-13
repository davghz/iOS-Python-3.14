# Rootless iOS 15

The rootless package keeps CPython **3.14.3** and pip **26.0.1**. It targets
an `iphoneos-arm64` bootstrap on iOS 15 or later, with its private prefix at
`/var/jb/usr/local/python3.14` and command links in `/var/jb/usr/bin`.

Build on macOS using Xcode, Python 3, `dpkg-deb`, and `ldid`:

```sh
python3 sources/build-rootless-deb.py \
  --input packages/com.davgz.python314_3.14.3-10_iphoneos-arm.deb \
  --openssl /path/to/extracted-dependencies \
  --sdk /path/to/iPhoneOS18.5.sdk \
  --source /path/to/Python-3.14.3
```

The dependency directory must contain the extracted rootless Procursus packages
`libssl-dev`/`libssl3` **3.2.1** and `libffi-dev`/`libffi8` **3.4.6**. Their
headers and dylibs should be under `var/jb/usr/include` and `var/jb/usr/lib`.
Use matching development/runtime package versions from the authenticated
Procursus index. The script uses the iOS 15 deployment target.

Output: `packages/com.davgz.python314_3.14.3-12+rootless_iphoneos-arm64.deb`.
Install the declared dependencies through APT before installing this package.

The builder relocates scripts, configuration, certificate paths, and command
links; rebuilds `_ssl`/`_hashlib` against OpenSSL 3; and rebuilds `_ctypes`
against libffi 8. It relocates readline, ncurses, panel, and lzma load paths
and signs all Mach-O files with standard CLI entitlements. The stable port's
iPhoneOS ctypes callback restriction remains enabled. No experimental callback
variant is installed.

Validated as `mobile` on an iPhone X with rootless palera1n and iOS 15.6.1:
version/prefix, pip, OpenSSL, hashes, compression, SQLite, ctypes, readline,
curses/panel, verified HTTPS to PyPI, shell subprocesses, and a temporary
virtual environment with pip. Run `python3 sources/rootless-smoke.py` on the
device to repeat the runtime checks.
