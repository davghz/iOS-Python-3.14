#!/usr/bin/env python3
"""Build CPython 3.15.2 and pip 26.3 for rootless iOS 15 CLI use."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

VERSION = '3.15.2'
SOURCE_URL = f'https://www.python.org/ftp/python/{VERSION}/Python-{VERSION}.tar.xz'
SOURCE_SHA256 = '8b5536d280142ecf6cdfe15d12a21ba1c65e300bbf7b28a8d0cdb849575797de'
PIP_VERSION = '26.3'
PIP_SHA256 = 'f3b60b20ffaadd4415ed7957212a38ac63fa4c5fa375bd0f4a797777940fad13'


def execute(command, cwd=None, env=None, log=None):
    if log:
        with Path(log).open('w') as stream:
            subprocess.run([str(x) for x in command], cwd=cwd, env=env,
                           stdout=stream, stderr=subprocess.STDOUT, check=True)
    else:
        subprocess.run([str(x) for x in command], cwd=cwd, env=env, check=True)


def fetch(url, destination, digest):
    if not destination.exists():
        with urllib.request.urlopen(url) as response:
            destination.write_bytes(response.read())
    if hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
        raise ValueError(f'Checksum mismatch: {destination}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--dependencies', type=Path, required=True,
                        help='Native iOS dependency prefix with include/ and lib/')
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--pip-wheel', type=Path, required=True)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--skip-build', action='store_true', help='Package an existing completed build')
    parser.add_argument('--activate-defaults', action='store_true', help='Also install default python3/pip links')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    dependencies = args.dependencies.resolve()
    sdk = args.sdk.resolve()
    wheel = args.pip_wheel.resolve()
    if hashlib.sha256(wheel.read_bytes()).hexdigest() != PIP_SHA256:
        raise ValueError('Expected the verified pip 26.3 wheel from PyPI')
    archive = work / f'Python-{VERSION}.tar.xz'
    fetch(SOURCE_URL, archive, SOURCE_SHA256)
    source = work / f'Python-{VERSION}'
    native_source = work / f'Python-{VERSION}-ios'
    if not source.exists():
        with tarfile.open(archive) as source_archive:
            source_archive.extractall(work, filter='data')
    if not native_source.exists():
        shutil.copytree(source, native_source)
    callback = native_source / 'Modules/_ctypes/callbacks.c'
    text = callback.read_text()
    if 'ctypes callbacks are not supported on iPhoneOS in this build' not in text:
        marker = '    ffi_abi cc;\n\n'
        if text.count(marker) != 1:
            raise ValueError('Unexpected ctypes callback source; review the stable callback patch')
        guard = '''#if defined(__APPLE__) && TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    PyErr_SetString(PyExc_NotImplementedError,
                    "ctypes callbacks are not supported on iPhoneOS in this build");
    return NULL;
#endif

'''
        callback.write_text('#include <TargetConditionals.h>\n' + text.replace(marker, marker + guard))
    overlay = repo / 'overlay/usr/local/python3.14/lib/python3.14'
    shutil.copy2(overlay / '_scproxy.py', native_source / 'Lib/_scproxy.py')
    ensurepip = native_source / 'Lib/ensurepip'
    for old_wheel in (ensurepip / '_bundled').glob('pip-*.whl'):
        old_wheel.unlink()
    shutil.copy2(wheel, ensurepip / '_bundled' / wheel.name)
    init = ensurepip / '__init__.py'
    init.write_text(re.sub(r'^_PIP_VERSION = .*$', f'_PIP_VERSION = "{PIP_VERSION}"',
                           init.read_text(), flags=re.M))
    host = work / 'host'
    host.mkdir(exist_ok=True)
    native = work / 'ios'
    native.mkdir(exist_ok=True)
    compiler = f'clang -target arm64-apple-ios15.0 -isysroot {sdk} -miphoneos-version-min=15.0'
    native_env = dict(os.environ, CC=compiler, CFLAGS='-O2 -g0',
                      CPPFLAGS=f'-I{dependencies}/include -I{dependencies}/include/ncursesw',
                      LDFLAGS=f'-L{dependencies}/lib -Wl,-rpath,/var/jb/usr/lib',
                      PKG_CONFIG='/usr/bin/false', LIBFFI_CFLAGS=f'-I{dependencies}/include',
                      LIBFFI_LIBS=f'-L{dependencies}/lib -lffi',
                      ac_cv_file__dev_ptmx='yes', ac_cv_file__dev_ptc='no',
                      ac_cv_func_getentropy='no', ac_cv_func_system='no',
                      ac_cv_func_sendfile='no', ac_cv_func_clock_settime='no')
    shared_link = compiler + f' -bundle -bundle_loader {native}/python.exe'
    make_args = ['make', f'-j{args.jobs}', 'LDSHARED=' + shared_link]
    if not args.skip_build:
        if not (host / 'Makefile').exists():
            execute([source / 'configure', f'--prefix={work}/host-install',
                     '--without-ensurepip', '--disable-test-modules'], host,
                    log=work / 'host-configure.log')
        execute(['make', f'-j{args.jobs}'], host, log=work / 'host-build.log')
        build_triplet = subprocess.check_output([source / 'config.guess'], text=True).strip()
        # A resumed build may have probed optional compression before its headers
        # were staged. Refresh only these dependency discovery cache entries.
        cache = native / 'config.cache'
        if cache.exists():
            keys = ('ac_cv_search_ZDICT_finalizeDictionary', 'py_cv_module__zstd',
                    'ac_cv_header_zstd_h', 'ac_cv_header_zdict_h')
            cache.write_text(''.join(line for line in cache.read_text().splitlines(True)
                                     if not line.startswith(tuple(key + '=' for key in keys))))
        execute([native_source / 'configure', '-C', '--host=arm-apple-darwin',
                 '--build=' + build_triplet, f'--with-build-python={host}/python.exe',
                 '--prefix=/var/jb/usr/local/python3.15', '--without-ensurepip',
                 '--with-remote-debug', '--disable-ipv6', '--disable-test-modules',
                 '--without-system-libmpdec',
                 f'--with-openssl={dependencies}'], native, native_env,
                work / 'ios-configure.log')
        setup = native / 'Modules/Setup.local'
        if '\n_scproxy\n' not in setup.read_text():
            with setup.open('a') as stream:
                stream.write('\n*disabled*\n_scproxy\n')
        execute(make_args, native, native_env, work / 'ios-build.log')
    package(args, repo, work, native, native_env, make_args, wheel, overlay)


def package(args, repo, work, native, native_env, make_args, wheel, overlay):
    stage = work / 'pkg'
    if stage.exists():
        shutil.rmtree(stage)
    execute([*make_args, f'DESTDIR={stage}', 'altinstall'], native, native_env,
            work / 'ios-install.log')
    pyroot = stage / 'var/jb/usr/local/python3.15'
    stdlib = pyroot / 'lib/python3.15'
    (stdlib / 'site-packages').mkdir(exist_ok=True)
    with zipfile.ZipFile(wheel) as pip_archive:
        pip_archive.extractall(stdlib / 'site-packages')
    custom = (overlay / 'sitecustomize.py').read_text().replace('/usr/local/python3.14',
                                                             '/var/jb/usr/local/python3.15')
    (stdlib / 'sitecustomize.py').write_text(custom)
    for cache in pyroot.rglob('*.pyc'):
        cache.unlink()
    (pyroot / 'bin/pip3.15').write_text('#!/var/jb/bin/sh\nexec /var/jb/usr/local/python3.15/bin/python3.15 -m pip "$@"\n')
    (pyroot / 'bin/pip3.15').chmod(0o755)
    bindir = stage / 'var/jb/usr/bin'
    bindir.mkdir(parents=True, exist_ok=True)
    for command in ('python3.15', 'python3.15-config', 'pip3.15', 'pydoc3.15'):
        (bindir / command).symlink_to('../local/python3.15/bin/' + command)
    if args.activate_defaults:
        for command, target in [('python3', 'python3.15'), ('pip', 'pip3.15'),
                                ('pip3', 'pip3.15'), ('python3-config', 'python3.15-config'),
                                ('pydoc3', 'pydoc3.15')]:
            (bindir / command).symlink_to(target)
    entitlements = work / 'cli-entitlements.plist'
    entitlements.write_bytes(plistlib.dumps({'platform-application': True,
        'com.apple.private.security.no-container': True,
        'com.apple.private.skip-library-validation': True}))
    for binary in [pyroot / 'bin/python3.15', *(stdlib / 'lib-dynload').glob('*.so')]:
        execute(['ldid', '-S' + str(entitlements), binary])
    control = stage / 'DEBIAN'
    control.mkdir()
    metadata = '''Package: com.davgz.python315
Name: Python 3.15 (Rootless)
Version: 3.15.2-1+rootless
Architecture: iphoneos-arm64
Maintainer: davgz
Depends: firmware (>= 15.0), libssl3 (>= 3.2.1), libffi8 (>= 3.4.6), liblzma5, libzstd1, libreadline8, libncursesw6, dash, ca-certificates
Section: Languages
Description: CPython 3.15.2 and pip 26.3 for rootless iOS
 Native iOS CLI build with rootless OpenSSL, libffi, and standard CLI entitlements.
'''
    if args.activate_defaults:
        metadata += 'Replaces: com.davgz.python314\n'
    (control / 'control').write_text(metadata)
    destination = repo / 'packages/com.davgz.python315_3.15.2-1+rootless_iphoneos-arm64.deb'
    execute(['dpkg-deb', '--root-owner-group', '-Zgzip', '-b', stage, destination])
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix('.deb.sha256').write_text(digest + '  ' + destination.name + '\n')
    print('Built:', destination)


if __name__ == '__main__':
    main()
