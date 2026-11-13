#!/usr/bin/env python3
"""Relocate the stable port and rebuild its OpenSSL modules for rootless iOS."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def output(*args):
    return subprocess.check_output([str(a) for a in args], text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--openssl', type=Path, required=True,
                        help='Extracted matching rootless OpenSSL and libffi runtime/dev packages')
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True,
                        help='CPython 3.14.3 source matching the stable binary')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    assert output('dpkg-deb', '-f', args.input, 'Package').strip() == 'com.davgz.python314'
    assert output('dpkg-deb', '-f', args.input, 'Version').strip() == '3.14.3-10'
    prefix = '/var/jb/usr/local/python3.14'
    openssl = args.openssl.resolve() / 'var/jb/usr'
    source = args.source.resolve()
    clang = output('xcrun', '-f', 'clang').strip()
    with tempfile.TemporaryDirectory(prefix='python314-rootless-') as tmp:
        work = Path(tmp)
        original = work / 'original'
        run('dpkg-deb', '-x', args.input.resolve(), original)
        stage = work / 'pkg'
        pyroot = stage / prefix.lstrip('/')
        pyroot.parent.mkdir(parents=True)
        shutil.copytree(original / 'usr/local/python3.14', pyroot, symlinks=True)
        # Include the stable branch's newer CLI stdout/stderr fix.
        shutil.copy2(repo / 'overlay/usr/local/python3.14/lib/python3.14/sitecustomize.py',
                     pyroot / 'lib/python3.14/sitecustomize.py')
        for path in pyroot.rglob('*'):
            if path.is_symlink():
                target = os.readlink(path)
                if target.startswith('/usr/local/python3.14'):
                    path.unlink()
                    path.symlink_to('/var/jb' + target)
            elif path.is_file():
                if path.suffix == '.pyc' or path.name == '.DS_Store':
                    path.unlink()
                    continue
                data = path.read_bytes()
                if b'\0' not in data and b'/usr/local/python3.14' in data:
                    path.write_bytes(data.replace(b'/usr/local/python3.14', prefix.encode()))
        modules = pyroot / 'lib/python3.14/lib-dynload'
        common = ['-target', 'arm64-apple-ios15.0', '-isysroot', str(args.sdk.resolve()),
                  '-miphoneos-version-min=15.0']
        includes = [pyroot / 'include/python3.14', source / 'Include',
                    source / 'Include/internal', source / 'Include/internal/mimalloc',
                    openssl / 'include']
        for module, src in (('_ssl', '_ssl.c'), ('_hashlib', '_hashopenssl.c')):
            obj = work / (module + '.o')
            run(clang, *common, '-O2', '-fPIC', '-fvisibility=hidden',
                '-DPy_BUILD_CORE_BUILTIN', '-std=c11',
                *[f'-I{p}' for p in includes], '-c', source / 'Modules' / src, '-o', obj)
            libraries = ['-lssl', '-lcrypto'] if module == '_ssl' else ['-lcrypto']
            run(clang, *common, '-bundle', '-bundle_loader', pyroot / 'bin/python3.14',
                obj, f'-L{openssl / "lib"}', *libraries, '-Wl,-rpath,/var/jb/usr/lib',
                '-o', modules / (module + '.cpython-314-arm64-iphoneos.so'))
        # libffi.6 from the rootful build is absent on iOS 15. Use Procursus
        # libffi.8 and retain the stable port's callback restriction.
        ctypes_source = work / 'ctypes'
        shutil.copytree(source / 'Modules/_ctypes', ctypes_source)
        callback = ctypes_source / 'callbacks.c'
        callback_text = callback.read_text()
        if 'ctypes callbacks are not supported on iPhoneOS in this build' not in callback_text:
            marker = '    ffi_abi cc;\n\n'
            assert callback_text.count(marker) == 1
            guard = '''#if defined(__APPLE__) && TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    PyErr_SetString(PyExc_NotImplementedError,
                    "ctypes callbacks are not supported on iPhoneOS in this build");
    return NULL;
#endif

'''
            callback_text = '#include <TargetConditionals.h>\n' + callback_text.replace(marker, marker + guard)
            callback.write_text(callback_text)
        objects = []
        for name in ('_ctypes', 'callbacks', 'callproc', 'stgdict', 'cfield', 'malloc_closure'):
            obj = work / ('ctypes_' + name + '.o')
            run(clang, *common, '-O2', '-fPIC', '-fvisibility=hidden', '-std=c11',
                '-DUSING_MALLOC_CLOSURE_DOT_C=1', '-DHAVE_FFI_CLOSURE_ALLOC=1',
                '-DHAVE_FFI_PREP_CLOSURE_LOC=1', '-DHAVE_FFI_PREP_CIF_VAR=1',
                '-DHAVE_DYLD_SHARED_CACHE_CONTAINS_PATH=1',
                *[f'-I{p}' for p in includes], '-c', ctypes_source / (name + '.c'), '-o', obj)
            objects.append(obj)
        run(clang, *common, '-bundle', '-bundle_loader', pyroot / 'bin/python3.14',
            *objects, f'-L{openssl / "lib"}', '-lffi', '-Wl,-rpath,/var/jb/usr/lib',
            '-o', modules / '_ctypes.cpython-314-arm64-iphoneos.so')
        # Keep Apple system libraries intact; relocate the jailbreak libraries.
        replacements = {
            '/usr/local/lib/liblzma.5.dylib': '/var/jb/usr/lib/liblzma.5.dylib',
            '/usr/lib/libreadline.8.dylib': '/var/jb/usr/lib/libreadline.8.dylib',
            '/usr/lib/libncursesw.6.dylib': '/var/jb/usr/lib/libncursesw.6.dylib',
            '/usr/lib/libpanelw.6.dylib': '/var/jb/usr/lib/libpanelw.6.dylib',
        }
        entitlements = work / 'cli.plist'
        entitlements.write_bytes(plistlib.dumps({
            'platform-application': True,
            'com.apple.private.security.no-container': True,
            'com.apple.private.skip-library-validation': True,
        }))
        for path in [pyroot / 'bin/python3.14', *modules.glob('*.so')]:
            deps = output('otool', '-L', path)
            for old, new in replacements.items():
                if old in deps:
                    run('install_name_tool', '-change', old, new, path)
            assert 'libssl.1.1' not in deps and 'libcrypto.1.1' not in deps
            run('ldid', '-S' + str(entitlements), path)
        bindir = stage / 'var/jb/usr/bin'
        bindir.mkdir(parents=True)
        for command in ('python3.14', 'python3', 'python3.14-config', 'python3-config',
                        'pip', 'pip3', 'pip3.14', 'pydoc3', 'pydoc3.14'):
            (bindir / command).symlink_to('../local/python3.14/bin/' + command)
        control = stage / 'DEBIAN'
        control.mkdir()
        (control / 'control').write_text('''Package: com.davgz.python314
Name: Python 3.14 (Rootless)
Version: 3.14.3-12+rootless
Architecture: iphoneos-arm64
Maintainer: davgz
Depends: firmware (>= 15.0), libssl3 (>= 3.2.1), libffi8 (>= 3.4.6), liblzma5, libreadline8, libncursesw6, dash, ca-certificates
Section: Languages
Description: CPython 3.14.3 and pip for rootless iOS
 Relocates the stable iOS port under /var/jb and rebuilds SSL against OpenSSL 3.
''')
        destination = repo / 'packages/com.davgz.python314_3.14.3-12+rootless_iphoneos-arm64.deb'
        run('dpkg-deb', '--root-owner-group', '-Zgzip', '-b', stage, destination)
        print('Built:', destination)


if __name__ == '__main__':
    main()
