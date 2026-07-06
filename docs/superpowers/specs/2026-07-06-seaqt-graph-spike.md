# Spike record — seaqt pair nimble-graph feasibility (issue 0012)

Date: 2026-07-06. Host: macOS arm64, nim 2.2.4, nimble 0.22.3
(42ef70c2), Qt kit `~/Qt/6.11.0/macos` (QMAKE). All experiments in scratch
(`…/scratchpad/seaqt-spike/`) with a SEPARATE store
`NIMBLE_DIR=~/.cache/seaqt-spike-nimbledeps` — the app store was never
touched, nothing was built in the repo tree.

## Pins tested (the SHAs the submodules point at)

- `vendor/nim-seaqt` → `2d95808bdd9f6dd2c212b69a57af4618da241d37`.
  NOTE: this is the tip of upstream branch **`smo-6.4`** (also tagged
  `qt-6.4-seaqt-gen-5bc1bc58…`), NOT of branch `qt-6.4` (whose tip is
  `21c8a80d`). The issue/brief say "qt-6.4 head"; the actual submodule pin is
  what was tested, per the brief's instruction to use the submodule SHAs.
- `vendor/nimqml-seaqt` → `c5e5831ae7d71e09f7061bc7735a8f3e1adc8fb3`
  ("fix: running seaqt on windows (#9)"). Upstream `master` has moved ahead
  (`d699ba8` at spike time); the pin is an ancestor of master — reachable.

Both SHAs verified reachable on github.com (`git ls-remote`).

## How the app consumes the pair today (baseline read)

- `config.nims:31-32` hardcodes `--path` switches:
  `vendor/nimqml-seaqt/src` and `vendor/nim-seaqt`.
- `config.nims:108-112` adds `--passC:-I<repo>/seaqt_compat` — an app-owned
  one-header shim (`QVariantConstPointer`) because the Qt-6.4-generated
  `seaqt/QtCore/gen_qvariant.cpp:37` does `#include <QVariantConstPointer>`,
  a header Qt removed after 6.4.
- The seaqt C++ shims are compiled BY THE NIM CLIENT COMPILE itself: every
  generated module carries `{.compile("gen_X.cpp", QtXCFlags).}` (e.g.
  `seaqt/QtCore/gen_qabstractanimation.nim:36`), plus
  `gen_qobject.nim:67` compiles `../libseaqt-runtime.cpp`. Objects land in
  the app's nimcache; nothing is prebuilt in the vendor dir. nim-seaqt's
  `Makefile` is only a syntax-check helper (`-fsyntax-only`), not a build.
- Qt flags come from `gorge("pkg-config --cflags Qt6X")` in each
  `seaqt/QtX/qtX_pkg.nim` (compile) and `{.passl: QtXLibs}` (link), fed by
  the `vendor/prl-to-pc/qt-pkgconfig.mk` environment (wrapper on PATH +
  `PKG_CONFIG_PATH` + `PKG_CONFIG_PREFIX_OVERRIDE`); the Makefile adds
  `QT_SEAQT_EXTRA_LIBS` (same wrapper, `--libs`) to the client link line
  (Makefile:263, 825).
- nimqml is pure Nim (plus one trivial `notherside.cpp`); its manifest
  carries `srcDir = "src"` and two nimscript TASKS (non-declarative), and
  its seaqt requires is commented out upstream (commit `c10d2e5` "Seaqt dep
  in nimble file breaks sat parser (#6)") — consumers must require both
  packages explicitly.

## Q1 — resolution on nimble 0.22.3: PASS

Scratch consumer (`consumer.nimble`, declarative) with exactly:

```
requires "https://github.com/seaqt/nim-seaqt.git#2d95808bdd9f6dd2c212b69a57af4618da241d37"
requires "https://github.com/seaqt/nimqml-seaqt.git#c5e5831ae7d71e09f7061bc7735a8f3e1adc8fb3"
```

```
rm -rf ~/.cache/seaqt-spike-nimbledeps
NIMBLE_DIR=~/.cache/seaqt-spike-nimbledeps nimble setup   # 20.3 s total, fresh store
```

- No hang, no SAT explosion, no version-table walls: `#hash` specials bind
  directly and skip tag enumeration (as documented in
  vendor/status-go/AGENTS.md). nimqml's non-declarative manifest (tasks) did
  NOT hang — hash-pinned manifests are evaluated once, and the
  declarative-parser wall applies to per-candidate range enumeration.
- Package-name vs repo-name mismatch (repo `nim-seaqt` → package `seaqt`,
  repo `nimqml-seaqt` → package `nimqml`) is a non-issue: nimble names the
  store entry from the manifest.
- Generated `nimble.paths`:

```
--path:"…/pkgs2/seaqt-0.6.4.0-4b05762909502cd88ebb0930db13d1ea4ee49015"
--path:"…/pkgs2/nimqml-0.9.2-1d366a53b7c214229a7cb250be4bd44d65e020ab"
```

- Store materialization: seaqt keeps `seaqt/` + `seaqt.nimble` at the entry
  root (no srcDir; all 850 binding modules, all `gen_*.cpp/.h` present;
  only Makefile/README dropped). nimqml's `src/` contents are HOISTED to the
  entry root (`nimqml.nim`, `nimqml/`, `seaqt/private/…`) — so both `--path`
  entries give the exact same import roots as today's config.nims switches.
- `nimblemeta.json` records `vcsRevision` and
  `specialVersions: ["0.9.2", "#c5e5831…"]` — the store binding future
  setups need.
- `requires "nim >= 2.0.0"` in both manifests pulls a `nim-2.2.4` package
  into a fresh store (harmless; the app graph already pins nim == 2.2.4).

## Q2 — store-copy usability (read-only store): PASS

Shims compile via `{.compile.}` into the CONSUMER's nimcache; nothing writes
into the package dir. Proven with the store chmod'd read-only:

```
chmod -R a-w ~/.cache/seaqt-spike-nimbledeps/pkgs2/{seaqt-*,nimqml-*}
cd …/seaqt-spike/consumer
export PATH="<repo>/vendor/prl-to-pc/.pcwrap:$PATH"
export PKG_CONFIG_PATH="<repo>/vendor/prl-to-pc/6.11.0/macos/lib/pkgconfig"
export PKG_CONFIG_PREFIX_OVERRIDE="Qt*=$HOME/Qt/6.11.0/macos"
nim c --passC:"-I<scratch>/seaqt_compat" --passL:"-lstdc++" -o:smoke smoke.nim
# SuccessX — 100185 lines, 11.4 s; objects in ~/.cache/nim/smoke_d
DYLD_FRAMEWORK_PATH=$HOME/Qt/6.11.0/macos/lib ./smoke
# SMOKE-OK: QApplication + QQmlApplicationEngine constructed, QML loaded
```

The smoke (`import NimQml`; `newQApplication` + `newQQmlApplicationEngine` +
`engine.load(qml)`) pulled modules from BOTH store entries (nimcache object
list shows `…/pkgs2/seaqt-…/seaqt/QtCore|QtGui|QtQml|QtQuick/gen_*.cpp.o`
and `…/pkgs2/nimqml-…/seaqt/private/metaobjectgen.nim` +
`…/nimqml.nim`), including `gen_qvariant.cpp.o` and `libseaqt-runtime.cpp`.
The sds `.sds-build/` scratch-copy fallback is NOT needed.

One nuance: `nimble setup` itself REWRITES `pkgs2/<pkg>/nimblemeta.json`, so
the store must stay owner-writable for nimble (a fully read-only store fails
setup with `cannot open …/nimblemeta.json`). Read-only matters only for the
compile, which is clean.

## Q3 — the compat include path: PASS

`config.nims:108-112` points at `<repo>/seaqt_compat` — an APP-OWNED shim
directory, not part of the seaqt package; no store-relative equivalent is
needed. The flag is a global `--passC`, and Nim applies global passC flags to
`{.compile.}`'d files, so the store copy's `gen_qvariant.cpp` picks it up
exactly like the submodule's did. Both directions proven against the store
copy on Qt 6.11:

- WITH `-I…/seaqt_compat` (a scratch copy of the repo dir, i.e. any absolute
  path works): compiles (Q2 above; `gen_qvariant.cpp.o` present in nimcache).
- WITHOUT it: `…/pkgs2/seaqt-…/seaqt/QtCore/gen_qvariant.cpp:37:10: fatal
  error: 'QVariantConstPointer' file not found`.

Conversion consequence: keep `config.nims`' `-I<repo>/seaqt_compat` as is;
only the two `--path` switches (lines 31-32) are replaced by graph
resolution.

## Q4 — Qt flag discovery from the store: PASS

Discovery is entirely environment-based, with zero package-location
dependence: `gorge("pkg-config --cflags/--libs Qt6X")` finds the
qt-pkgconfig wrapper via PATH and the `.pc` tree via `PKG_CONFIG_PATH`
(absolute, from `vendor/prl-to-pc/qt-pkgconfig.mk`), and `{.compile.}`'s
source path is relative to the module file inside the store. The Q2 smoke IS
the proof: compile flags (`-F…/Qt/6.11.0/macos/lib -I…` visible on the clang
command lines) and link flags were all discovered while every seaqt source
lived in the store. `pkg-config --modversion Qt6Core` → `6.11.0` through the
wrapper. Committed `.pc` trees exist for `macos`, `ios`,
`android_arm64_v8a`, `msvc2022_64` — the mobile legs use the same
absolute-env mechanics (spot-check remains a conversion-phase acceptance
item, per the issue).

## Bonus — full app-graph interaction: PASS

Scratch copy of the REAL `nim_status_client.nimble` (29 requires incl. the
absolute `file://` statusgo, whose sds pin agent 0007 had already flipped to
`alexjba/nim-sds#5c89d61` in the working tree) + `nimble.lock`, with the two
seaqt-pair requires appended, against the same spike store:

```
NIMBLE_DIR=~/.cache/seaqt-spike-nimbledeps nimble setup   # exit 0, 2:11 (mostly downloads)
```

- Result: exit 0; `nimble.paths` has 44 `--path` entries including
  `pkgs2/seaqt-0.6.4.0-4b05762…` and `pkgs2/nimqml-0.9.2-1d366a53…`,
  statusgo as the file:// link to `vendor/status-go`, sds from the store
  (`sds-0.3.0-89a7872…`, 0007's `alexjba/nim-sds#5c89d61` pin), ffi 0.1.4.
  The usual special-version warnings (jwt, bearssl_pkey_decoder, lsquic)
  appear unchanged.
- CONTROL: the identical scratch consumer WITHOUT the two seaqt requires
  resolves to the same graph with exactly 42 entries — the pins add
  precisely the two seaqt-pair paths and perturb nothing else.
- Observed in BOTH arms (i.e. unrelated to the seaqt pins): this
  0007-in-flight tree resolves libp2p 1.15.3 / websock 0.3.0, while the
  committed lock records websock 0.4.0 (libp2p absent from the lock —
  known 0003 wall #5: file://-subtree picks are omitted and warm stores
  mask lock/solve divergence). Flagging for 0007/lock-regeneration; not a
  0012 finding.
- Experimental footnote: the first app-graph run failed with
  `cannot open …/pkgs2/seaqt-…/nimblemeta.json` because the Q2 read-only
  chmod was still in place — `nimble setup` REWRITES each store entry's
  `nimblemeta.json`. The store must stay owner-writable for nimble; it only
  needs to be effectively read-only toward the C/Nim compile (which it is).

## Verdict

**PASS — recommend the issue's pass path** (flip both to `URL#hash` pins,
delete the two submodules staged per the Phase-2 playbook, delete
`config.nims:31-32`, add nimble-graph vendor-table entries so
`develop seaqt` / `develop nimqml` ride the 0009 overlay). All four spike
questions pass with direct evidence, plus the merged app graph resolves with
the pins in place. The seaqt pair is actually the EASIEST nimble-graph
conversion of the iteration, not the riskiest: no sub-build, no artifacts,
no in-package writes — the app's own compile consumes sources straight from
the read-only store, and every path it needs is either graph-resolved
(`nimble.paths`) or app-owned (`seaqt_compat`, qt-pkgconfig env). Residual
risks for the conversion (none spike-blocking): (1) `nimble.lock` must gain
the two entries — regenerate and validate on a CLEAN store (the known
lock-hand-fix pattern from AGENTS.md may apply); (2) mobile spot-check
(store-path cross-compile) is an acceptance item; (3) the nim-seaqt pin sits
on branch `smo-6.4`, not `qt-6.4` — carry the exact submodule SHA and note
the branch in the vendor table so a future `develop seaqt` checks out the
right line; (4) nimqml upstream master has moved past the pin — bumping is a
separate, deliberate decision.
