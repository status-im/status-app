#!/usr/bin/env python3
# Drop unused Qt libs from the androiddeployqt output and keep only the libs that must be
# System.load()ed (DT_NEEDED closure of the app libs, or carrying JNI_OnLoad) in Qt's eager
# load lists. Everything else stays packaged and is dlopen()ed on demand by Qt.
# Libs matching the lazy file stay packaged but are never loaded eagerly, even when they
# carry a JNI_OnLoad (the app calls it on first use).
# usage: trim_qt_deploy.py <android-build> <llvm-readelf> <abi> <deny-file> <main-lib-name> [<lazy-file>]
import re
import subprocess
import sys
from pathlib import Path

build, readelf, abi, deny_file, main_lib = sys.argv[1:6]
lazy_file = sys.argv[6] if len(sys.argv) > 6 else None
libdir = Path(build) / 'libs' / abi
libsxml = Path(build) / 'res' / 'values' / 'libs.xml'


def patterns(path):
    out = []
    for line in Path(path).read_text().splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            out.append(re.compile(line))
    return out


deny = patterns(deny_file)
lazy = patterns(lazy_file) if lazy_file else []


def is_lazy(name):
    return any(p.search(name) for p in lazy)

dropped = set()
for f in sorted(libdir.glob('*.so')):
    if any(p.search(f.name) for p in deny):
        dropped.add(f.name)
        f.unlink()
print('trim: dropped %d libs' % len(dropped))


def dynamic(f):
    out = subprocess.run([readelf, '--dynamic', '--dyn-syms', '-W', str(f)],
                         capture_output=True, text=True, check=True).stdout
    needed = re.findall(r'\(NEEDED\)\s+Shared library: \[(.+?)\]', out)
    jni = re.search(r'\s(GLOBAL|WEAK)\s+DEFAULT\s+\d+\s+JNI_OnLoad$', out, re.M) is not None
    return needed, jni


present = {f.name: dynamic(f) for f in libdir.glob('*.so')}
broken = sorted((n, d) for n, (needed, _) in present.items() for d in needed if d in dropped)
if broken:
    sys.exit('trim: kept libs need dropped libs: %s' % broken)


def soname(name):
    return 'lib%s.so' % name


xml = libsxml.read_text()


def array(name):
    m = re.search(r'(<array name="%s">)(.*?)(</array>)' % name, xml, re.S)
    return m


bundled = re.findall(r'<item>%s;([^<]+)</item>' % abi, array('bundled_libs').group(2))
local_m = re.search(r'(<array name="load_local_libs">\s*<item>%s;)([^<]*)(</item>)' % abi, xml)
local = [l for l in local_m.group(2).split(':')
         if l and (libdir / l).exists() and not is_lazy(l)] if local_m else []


def closure(roots):
    keep, todo = set(), list(roots)
    while todo:
        n = todo.pop()
        if n in keep or n not in present or is_lazy(n):
            continue
        keep.add(n)
        todo += present[n][0]
    return keep


# Bundled libs nothing loads at startup (OpenSSL, keycard) stay packaged for a later dlopen()
roots = local + [soname('%s_%s' % (main_lib, abi))]
roots += [n for n, (_, jni) in present.items() if jni]
keep = closure(roots)
eager_needs_lazy = sorted((n, d) for n in keep for d in present[n][0] if is_lazy(d))
if eager_needs_lazy:
    sys.exit('trim: eager libs need lazy libs: %s' % eager_needs_lazy)
lazy_bundled = [n for n in bundled if soname(n) not in keep]

qt = array('qt_libs')


def filt(m):
    name = m.group(1)
    return m.group(0) if soname(name) in keep or name == 'c++_shared' else ''


qt_body = re.sub(r'\s*<item>%s;([^<]+)</item>' % abi, filt, qt.group(2))
xml = xml[:qt.start(2)] + qt_body + '\n    ' + xml[qt.end(2):]
if local_m:
    xml = re.sub(r'(<array name="load_local_libs">\s*<item>%s;)[^<]*' % abi,
                 lambda m: m.group(1) + ':'.join(local), xml)
bl = array('bundled_libs')
bl_body = re.sub(r'\s*<item>%s;([^<]+)</item>' % abi,
                 lambda m: '' if m.group(1) in lazy_bundled else m.group(0), bl.group(2))
xml = xml[:bl.start(2)] + bl_body + xml[bl.end(2):]
libsxml.write_text(xml)
print('trim: lazy bundled_libs =', ' '.join(lazy_bundled))
print('trim: eager qt_libs =', ' '.join(re.findall(r'<item>%s;([^<]+)</item>' % abi, qt_body)))
print('trim: load_local_libs =', ':'.join(local))
lazy_kept = sorted(n for n in present if is_lazy(n))
print('trim: lazy (packaged, loaded on first use) =', ' '.join(lazy_kept))
