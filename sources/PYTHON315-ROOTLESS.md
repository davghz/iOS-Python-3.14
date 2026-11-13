# Python 3.15.2 and pip 26.3 on rootless iOS

This repository also packages the latest stable CPython **3.15.2** and pip
**26.3** as native arm64 CLI programs. The repository name retains its original
3.14 history. The 3.15 package uses `/var/jb/usr/local/python3.15` and the
`iphoneos-arm64` package architecture, with an iOS 15.0 deployment target.

The source is the official [Python 3.15.2 release](https://www.python.org/downloads/release/python-3152/).
The build script verifies its published SHA256, builds a matching macOS Python
for cross-build tools, and then builds the iOS interpreter and extension modules.
It verifies the pip wheel SHA256 and upgrades both the installed pip and
ensurepip's bundled wheel to 26.3, including pip in newly created virtualenvs.

Build requirements are macOS with Xcode, Python 3, `dpkg-deb`, `ldid`, and a
native rootless dependency prefix containing matching headers/libraries for:

- OpenSSL 3.2.1 (`libssl-dev` and `libssl3`)
- libffi 3.4.6 (`libffi-dev` and `libffi8`)
- zstd 1.5.5 (`libzstd-dev` and `libzstd1`)
- lzma, readline 8, ncurses 6, and panel

Use the authenticated Procursus package index when downloading dependency
packages, and extract their `var/jb/usr/include` and `var/jb/usr/lib` trees to
the dependency prefix's `include` and `lib` directories. Use native iOS dylibs.
The builder disables host pkg-config to avoid accidentally linking macOS libraries.

Download the [pip 26.3 wheel from PyPI](https://pypi.org/project/pip/26.3/#files), then run:

```sh
python3 sources/build-python315-rootless.py \
  --work /path/to/python315-build \
  --dependencies /path/to/native-dependencies \
  --sdk /path/to/iPhoneOS18.5.sdk \
  --pip-wheel /path/to/pip-26.3-py3-none-any.whl \
  --jobs 2 --activate-defaults
```

The resulting `packages/com.davgz.python315_3.15.2-1+rootless_iphoneos-arm64.deb`
includes versioned `python3.15` and `pip3.15` commands. `--activate-defaults`
also installs `python3`, `pip`, `pip3`, `python3-config`, and `pydoc3` links,
with a `Replaces` declaration for the older 3.14 package. The 3.14 runtime and
`python3.14` remain available for rollback. Omit that flag to validate a versioned
3.15 package before switching defaults.

The CLI build retains Darwin-style subprocess support while targeting iOS. Its
configure cache disables APIs unavailable on iOS: getentropy, system, sendfile,
and clock_settime. It uses `/dev/urandom` for Python randomness and retains fork/
spawn subprocess support. The private `_scproxy` shim and CLI stdout/stderr
restoration from the stable port are preserved. ctypes callback construction
remains explicitly disabled; ordinary ctypes calls work.

All executables and extension modules are signed with standard CLI entitlements.
OpenSSL, libffi, ncurses, readline, lzma, and zstd use rootless library paths.
The decimal accelerator uses upstream's bundled libmpdec. Optional gdbm and
Tkinter are excluded; the package is intended for command-line use.

Run `python3.15 sources/python315-smoke.py` on the device to validate the prefix,
versions, hashes, SSL, ctypes, decimal, compression including zstd, SQLite,
readline/curses, HTTPS to PyPI, subprocesses, and virtualenv pip bootstrap.
