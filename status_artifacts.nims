# status_artifacts.nims — every non-Nim artifact bin/nim_status_client links
# or loads, built by the driver itself (issue 0016; PRD
# docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md).
#
# Included by status.nims AFTER status_env.nims and after the driver's own
# helpers (fail / nimExe / ncpu / prepareQtPkgconfig). `buildArtifacts` — the
# `nimble build` before-build hook since issue 0013 — is now an ordered list
# of the procedures below instead of a delegation to make's `client-deps`.
#
# NOT included by config.nims. That is deliberate: config.nims is evaluated on
# EVERY nim invocation (nimsuggest included), so it must never touch the
# filesystem to decide whether something needs rebuilding. Keeping `stale()`
# on the driver side makes that mistake impossible by construction (settled
# 2026-07-10). Issue 0017's client compile reuses it from here.
#
# ---------------------------------------------------------------------------
# THE TWO GATING PATTERNS — there are exactly two, and no others may be added
# ---------------------------------------------------------------------------
#
# Both are **key files**: the build records a key next to the artifact, and a
# build whose key differs rebuilds. They differ only in where the key comes
# from.
#
# 1. `stale(keyFile, outputs, key)` with `key = contentKey(...)` — the key is a
#    digest of the CONTENT of the artifact's file inputs (resources.rcc, libsds,
#    the client binary, the `nimble setup` product). Rebuild when an output is
#    missing or the recorded digest differs.
#
#    Issue 0016 spelled this as an mtime scan over the shell's `test -nt`.
#    Issue 0017 replaced it with a content key, for three reasons:
#      - `-nt` is a POSIX-shell builtin, so `stale()` returned unconditionally
#        true on Windows: every gated artifact rebuilt on every build (0016's
#        disclosed regression).
#      - mtime is simply the wrong question across a develop/undevelop flip.
#        Restoring identical sources rebuilt; checking out older-but-different
#        sources did not.
#      - `test -nt` compares SECONDS, so an edit landing inside the output's own
#        second was missed. make compares nanoseconds; a content key compares
#        bytes and has no granularity at all.
#
#    `stale(outputs)` — the one-argument OVERLOAD — is the degenerate "the
#    artifact exists ⇒ it is fresh" gate (libstatus, whose freshness is owned by
#    the key file next to the scratch copy). It is pattern 1, not a third
#    pattern, and it is a real overload rather than a sentinel argument.
#
# 2. The **configuration key** — keyed invalidation for artifacts whose inputs
#    are not files but a *configuration*: the resolved store path, the target
#    triple, the flag set, a cmake configure's argument list. Established by the
#    status-go scratch engine (`.statusgo-build/.statusgo-origin`,
#    `.statusgo-artifact-key`; issue 0010) and reused for every cmake configure
#    (`<buildDir>/.status-cmake.key`).
#
#    `keyStale(keyFile, key, witness)` is the ONE spelling. `witness` is the
#    artifact whose existence the key vouches for (a cmake cache, a scratch
#    tree): a missing witness is stale however well the key matches. There is
#    no bare `fileExists` gate anywhere in this file.
#
# The client binary uses BOTH key sources in one key file (`.status-client.key`,
# which absorbs make's `.qmake_previous`): its configuration key (qmake + the
# flag env) concatenated with the content key of its sources.
#
# A cmake artifact's BUILD step is gated by neither: `cmake --build` runs every
# time and cmake's own incrementality (including its check-build-system
# re-configure) IS the no-op path, exactly as under make. Its CONFIGURE step is
# gated by pattern 2 on the argument list — the one input cmake cannot see.
# (The issue's "invoked unconditionally" wording was amended for this: three
# unconditional configures put the no-op at 14–17 s against a ~7 s criterion.)
#
# Bootstrap — `initSubmodules()` and `fetchBottles()` — is NOT gating. It
# materializes inputs that a fresh clone lacks and that nothing in the build
# can invalidate (a git submodule tracks its own revision; a brew bottle is
# content-addressed by its flavor). It tests for presence, and that is all it
# can ever do. Kept out of the two patterns deliberately, and out of the
# rebuild-decision audit.

# --- keyed invalidation (pattern 2) -------------------------------------------

proc keyStale(keyFile, key: string, witness = ""): bool =
  ## True when the recorded key differs from `key`, when no key was ever
  ## recorded, or when `witness` — the artifact the key vouches for — is gone.
  ## The witness arm is what keeps a bare `fileExists` out of the call sites:
  ## a key file that survived an `rm -rf` of its build tree must not read fresh.
  if witness.len > 0 and not fileExists(witness) and not dirExists(witness):
    return true
  not fileExists(keyFile) or readFile(keyFile).strip != key

proc writeKey(keyFile, key: string) =
  mkDir keyFile.parentDir
  writeFile(keyFile, key)

# --- staleness (pattern 1): a portable CONTENT key ----------------------------

proc contentKey(findCmd: string, extra: openArray[string] = []): string =
  ## A digest of the CONTENT of an input set, computed in ONE subprocess.
  ##
  ## `findCmd` is a `find(1)` invocation relative to the repo root (this proc
  ## appends `-print0`); `extra` names additional absolute paths. A path in
  ## `extra` that does not exist is dropped — its disappearance changes the
  ## digest, which is exactly the invalidation we want.
  ##
  ## An EMPTY input set is a hard error, never a digest. `find <nothing> |
  ## xargs -0 -r cksum | sort | cksum` prints a perfectly well-formed
  ## `4294967295 0`, so an artifact whose inputs all vanished would otherwise
  ## record a stable key and read FRESH forever (resources.rcc would never
  ## rebuild again). Every call site's input set is non-empty in a healthy
  ## tree, so an empty one means a broken scan — the same reasoning as the shape
  ## check below. The digest's second field is the byte count of the `cksum`
  ## lines, so `<crc> 0` ⇔ "zero files hashed" exactly.
  ##
  ## `xargs -0 -r` is load-bearing for that guard. GNU xargs runs its utility
  ## ONCE even on empty input unless `--no-run-if-empty` (`-r`) is given, so on
  ## Linux a vanished set would run `cksum </dev/null` → `4294967295 0`, and the
  ## outer `cksum` of that non-empty line yields `3871339299 13` — well-formed,
  ## bytes≠0, guard bypassed, empty set FRESH forever. With `-r` the pipeline
  ## stays empty and the final `cksum` is `4294967295 0`, which the guard
  ## catches. `-r` is a documented no-op on BSD/macOS xargs (which already skips
  ## the utility on empty input), so it is safe everywhere.
  ##
  ## The obvious spelling of a content key — `hash(readFile(f))` per input, in
  ## the nimscript VM, as the walls doc sketches — is unaffordable here:
  ## measured 2026-07-10, the 1762 inputs / 11.7 MB of `src/` + the rcc set cost
  ## **13–16 s**, against a whole-build no-op budget of ~5 s. The VM's string
  ## hash runs one byte at a time. So the digest is produced where the input
  ## list is already produced: one `find`, piped into `cksum`, folded by a
  ## second `cksum`. It reads every byte, costs 0.3 s (src) / 0.9 s (ui), and
  ## spends exactly one subprocess — the same count as the mtime scan it
  ## replaced.
  ##
  ## Residual portability limit, stated rather than hidden: the digest needs a
  ## POSIX shell with `find`, `xargs`, `sort` and `cksum`. So does the input
  ## enumeration it subsumes, and so does every `scripts/*.sh` the build already
  ## runs, and the root Makefile's `SHELL := bash`. On Windows that is msys2 —
  ## the same environment the Windows build has always required. What is gone is
  ## the `-nt` BUILTIN dependency, which is what made `stale()` unconditionally
  ## true there.
  ##
  ## `sort` makes the digest independent of readdir order. A path containing a
  ## newline would split a `cksum` line and is not supported (no such path
  ## exists in this tree, and `find`'s own output is already line-oriented).
  var emit: seq[string]
  if findCmd.len > 0:
    # `|| exit 1` is required, not decorative. When an `extra` list follows, the
    # emitted group is `{ find … -print0; printf … }` and a brace group's exit
    # status is its LAST command's — printf's — so a failing `find` would be
    # masked and pipefail could never see it. Making `find` exit the (subshell)
    # pipe-stage on failure is what lets pipefail reject a truncated scan.
    emit.add findCmd & " -print0 || exit 1"
  var present: seq[string]
  for f in extra:
    if fileExists(f):
      present.add f
  if present.len > 0:
    var p = "printf '%s\\0'"
    for f in present:
      p &= " " & quoteShell(f)
    emit.add p
  if emit.len == 0:
    fail "the content-key scan has no inputs at all (findCmd='" & findCmd &
      "', " & $extra.len & " extra path(s), none present). An empty input set" &
      " cannot produce a meaningful key — refusing to record one."
  # `set -o pipefail` where the shell HAS it, without dying where it does not.
  # /bin/sh is dash on Debian/Ubuntu (the flatpak CI image), where `set -o
  # pipefail` is an unknown option to a POSIX *special builtin* and therefore
  # kills the whole non-interactive shell — `2>/dev/null` hides the message and
  # the digest never appears (rc=2). Probing it in a SUBSHELL first is fatal to
  # nothing: the subshell dies, `&&` short-circuits, and the pipeline runs
  # unprotected exactly as it must on a shell that lacks the option.
  # Together with `find … || exit 1` above (which propagates find's failure past
  # the brace group's printf), pipefail ensures a failing `find` cannot yield a
  # well-formed digest of a truncated input set.
  let cmd = "cd " & quoteShell(thisDir()) &
    " && (set -o pipefail) 2>/dev/null && set -o pipefail; { " & emit.join("; ") &
    "; } | xargs -0 -r cksum | sort | cksum"
  let (output, rc) = gorgeEx(cmd)
  let key = output.strip
  # gorgeEx merges stderr into the output (walls doc), so validate the SHAPE:
  # `cksum` prints exactly "<crc> <bytes>". Anything else is a broken scan.
  var wellFormed = rc == 0 and key.len > 0 and '\n' notin key
  var bytes = ""
  if wellFormed:
    let parts = key.splitWhitespace()
    wellFormed = parts.len == 2
    for p in parts:
      for c in p:
        if c notin {'0' .. '9'}: wellFormed = false
    if wellFormed:
      bytes = parts[1]
  if not wellFormed:
    fail "the content-key scan failed:\n  " & cmd & "\n" & output
  if bytes == "0":
    # Zero bytes of `cksum` output = zero files matched. Well-formed, and a lie:
    # recording it would freeze the artifact as permanently fresh.
    fail "the content-key scan matched NO files (digest '" & key & "'):\n  " &
      cmd & "\nEvery input of this artifact has disappeared; the tree is" &
      " broken (or the scan's spec is wrong)."
  key

proc missing(outputs: openArray[string]): bool =
  if outputs.len == 0:
    return true
  for o in outputs:
    if not fileExists(o) and not dirExists(o):
      return true

proc stale(outputs: openArray[string]): bool =
  ## Pattern 1, degenerate form: "the artifact exists ⇒ it is fresh". The only
  ## user is libstatus, whose freshness is owned by the key file next to the
  ## scratch copy. Spelled as its own overload rather than as a magic empty
  ## `keyFile`/`key` pair (issue 0017 review, M1).
  missing(outputs)

proc stale(keyFile: string, outputs: openArray[string], key: string): bool =
  ## Pattern 1. True when any output is missing, or when the recorded content
  ## key of the inputs differs from `key`.
  ##
  ## A caller that rebuilds must `writeKey(keyFile, key)` afterwards — the key
  ## is recorded by the build, never by the check.
  if missing(outputs):
    return true
  keyStale(keyFile, key)

# --- shared build environment --------------------------------------------------

var qtDumpCache: seq[tuple[key, val: string]]

proc qtDump(): seq[tuple[key, val: string]] =
  ## One `qmake -query` dump per driver invocation.
  if qtDumpCache.len == 0:
    qtDumpCache = qmakeQueryAll(qmakeExe())
  qtDumpCache

proc qtProp(key: string): string = qtDump().qmakeProp(key)

var unameCache: seq[tuple[flag, val: string]]

proc uname(flag: string): string =
  ## Cached: the sentinel key, the cross-desktop probe and QT_ARCH's default
  ## all want it, and a driver no-op must not pay a subprocess per lookup.
  for (f, v) in unameCache:
    if f == flag:
      return v
  let (output, rc) = gorgeEx("uname " & flag)
  if rc != 0:
    fail "`uname " & flag & "` failed:\n" & output
  result = output.strip
  unameCache.add (flag, result)

proc qtArch(): string =
  ## make's QT_ARCH (macOS only: `?= $(shell uname -m)`), the cross-desktop knob.
  result = getEnv("QT_ARCH")
  if result.len == 0 and hostOS == "macosx":
    result = uname("-m")

proc crossDesktop(): bool =
  hostOS == "macosx" and uname("-m") == "arm64" and qtArch() notin ["", "arm64"]

proc libExt(): string =
  case hostOS
  of "macosx": "dylib"
  of "windows": "dll"
  else: "so"

proc debugSymbols(): bool = getEnv("INCLUDE_DEBUG_SYMBOLS") == "true"

proc platformTarget(): string =
  ## The platform sentinel's key (ADR 0003). Must stay byte-identical to the
  ## root Makefile's `$(host_os)-$(or $(QT_ARCH),$(shell uname -m))`, because
  ## the still-make-driven mobile legs write the same `.platform-target` file.
  let arch = if qtArch().len > 0: qtArch() else: uname("-m")
  uname("-s").toLowerAscii & "-" & arch

## qmlDebug() / buildType() live in status_env.nims: config.nims' Windows client
## arm needs the same cmake flavor to find `lib/<Release|Debug>` (issue 0017).

proc exportBuildEnv() =
  ## What the root Makefile exported into every artifact recipe. cmake reads
  ## CFLAGS at configure time and `rcc`/`lrelease`/`lupdate` are found through
  ## PATH, so the driver must export the same values or it silently builds
  ## against a different SDK / a different Qt's tools.
  putEnv("QTDIR", qtProp("QT_INSTALL_PREFIX"))
  var path = getEnv("PATH")
  for d in [qtProp("QT_INSTALL_BINS"), qtProp("QT_HOST_BINS"),
            qtProp("QT_HOST_LIBEXECS"), qmakeExe().parentDir]:
    if d.len > 0 and not (path & ":").contains(d & ":"):
      path = d & ":" & path
  putEnv("PATH", path)
  if hostOS == "macosx":
    # Keep in sync with config.nims' `-mmacosx-version-min` passC and the
    # BOTTLE_MACOS_VERSION the bottle fetch picks.
    putEnv("MACOSX_DEPLOYMENT_TARGET", "14.0")
    var cflags = "-mmacosx-version-min=14.0"
    putEnv("CGO_CFLAGS", cflags)
    if debugSymbols():
      cflags &= " -g"
    putEnv("CFLAGS", cflags)

# --- the ONE generic cmake procedure ------------------------------------------

proc commonCmakeArgs(): seq[string] =
  ## make's COMMON_CMAKE_CONFIG_PARAMS.
  result.add "-DCMAKE_PREFIX_PATH=" & qtProp("QT_INSTALL_PREFIX")
  if hostOS == "windows":
    result.add "-A"
    result.add "x64"
  if crossDesktop():
    result.add "-DCMAKE_OSX_ARCHITECTURES=x86_64"

proc cmakeArtifact(label, source, buildDir: string,
                   configureArgs: openArray[string] = [],
                   target = "", install = false) =
  ## Configure + build (+ optionally install) one cmake artifact. The BUILD
  ## step is invoked unconditionally: cmake's own incrementality is the no-op
  ## path, and this driver does not reimplement dependency tracking cmake
  ## already does. That includes re-configuration — every generator emits a
  ## check-build-system rule, so `cmake --build` re-runs the configure itself
  ## when a CMakeLists.txt changed.
  ##
  ## The one thing cmake cannot notice is a change in the configure ARGUMENTS
  ## (a develop redirect flip, a build-type flip, another Qt kit). That is the
  ## key-file pattern's job — gating pattern 2 — and it is why the configure
  ## does not simply run every time: StatusQ's configure alone costs ~5 s, the
  ## whole no-op budget.
  ##
  ## `configureArgs` are appended AFTER commonCmakeArgs, so an artifact can
  ## override a common `-D` (the translations project needs the HOST Qt prefix,
  ## not the target one) — the last definition wins in the cmake cache.
  ##
  ## The 0011 FETCHCONTENT_SOURCE_DIR_<NAME> contract lives at the call sites:
  ## always pass the redirect PAIR, an empty value meaning "use the pin". A
  ## flip therefore changes this key, and the redirect can never go stale.
  var cfg = "cmake -S " & quoteShell(source) & " -B " & quoteShell(buildDir) &
    " -Wno-dev -DCMAKE_BUILD_TYPE=" & buildType()
  for a in commonCmakeArgs():
    cfg &= " " & quoteShell(a)
  for a in configureArgs:
    cfg &= " " & quoteShell(a)
  let keyFile = buildDir / ".status-cmake.key"
  if keyStale(keyFile, cfg, witness = buildDir / "CMakeCache.txt"):
    echo "\e[92mConfiguring:\e[39m " & label
    exec cfg
    writeKey(keyFile, cfg)
  echo "\e[92mBuilding:\e[39m " & label
  var b = "cmake --build " & quoteShell(buildDir) & " --config " & buildType() &
    " -j" & ncpu()
  if target.len > 0:
    b &= " --target " & quoteShell(target)
  exec b
  if install:
    exec "cmake --install " & quoteShell(buildDir)

# --- bootstrap (submodules + brew bottles) ------------------------------------

const hostSubmodules = [
  "vendor/QR-Code-generator",    # C source, {.compile.}d by src/app/global/utils/qrcodegen.nim
  "vendor/SortFilterProxyModel", # add_subdirectory'd by ui/StatusQ/CMakeLists.txt
]

proc initSubmodules() =
  ## Targeted, never blanket-recursive: only the submodules the HOST desktop
  ## build consumes. (fcitx5-qt is Linux packaging, mobile/vendors/openssl is
  ## mobile; nimbus-build-system is gone — issue 0018.)
  var missing: seq[string]
  for s in hostSubmodules:
    let dotGit = thisDir() / s / ".git"
    if not fileExists(dotGit) and not dirExists(dotGit):
      missing.add s
  if missing.len == 0:
    return
  echo "\e[92mBootstrapping:\e[39m submodules " & missing.join(" ")
  exec "git -C " & quoteShell(thisDir()) & " submodule update --init -- " &
    missing.join(" ")

proc fetchBottles() =
  ## macOS only: the statically linked OpenSSL 3 the client and
  ## status-keycard-qt both consume.
  ##
  ## Bootstrap, not gating (see the header): a bottle is content-addressed by
  ## its flavor, so a present one is by definition the right one and nothing in
  ## the build can invalidate it. Presence is the only question there is.
  if hostOS != "macosx":
    return
  if dirExists(thisDir() / "bottles/openssl@3"):
    return
  let flavor = if qtArch() == "arm64": "arm64_sonoma" else: "sonoma"
  echo "\e[92mFetching:\e[39m openssl@3 bottle (" & flavor & ")"
  exec "cd " & quoteShell(thisDir()) &
    " && ./scripts/fetch-brew-bottle.sh openssl@3 " & flavor

proc bootstrap() =
  initSubmodules()
  fetchBottles()

# --- dependency resolution (the relocated setup stamp) ------------------------

const setupKeyFile = ".status-setup.key"  # gitignored

proc nimbleSetupIfStale() =
  ## The setup stamp is not preserved but RELOCATED (issue 0016): `nimble
  ## setup` re-runs only when its product (nimble.paths) is stale w.r.t. the
  ## lock, the manifests in the graph and the develop overlay — exactly the key
  ## make's `$(NIMBLE_SETUP_STAMP)` rule used.
  ##
  ## Ordering is load-bearing and must survive: `nimble setup` FIRST, then the
  ## overlay is applied to the freshly generated nimble.paths (ADR 0007).
  ##
  ## Since the gate became a content key (issue 0017) the stamp no longer *is*
  ## nimble.paths' mtime, which closes the walls doc's `applyOverlay` trap: a
  ## hand-run `nimble setup` / `nim applyOverlay status.nims` rewrites
  ## nimble.paths but does NOT record the inputs' key, so the next build still
  ## resolves. It used to silently skip.
  var inputs: seq[string]
  for f in ["nimble.lock", "nim_status_client.nimble", overlayFile,
            "vendor/status-go/statusgo.nimble"]:
    if fileExists(thisDir() / f):
      inputs.add thisDir() / f
  let keyFile = thisDir() / setupKeyFile
  let key = contentKey("", inputs)
  if not stale(keyFile, [thisDir() / "nimble.paths"], key):
    return
  if findExe("nimble").len == 0:
    fail "nimble is not on PATH (see BUILDING.md) — it resolves the whole" &
      " dependency graph, including the pinned Nim compiler."
  echo "\e[92mResolving:\e[39m nimble graph (lock/manifests/overlay changed)"
  # WALL (2026-09-15, nimble 0.22.3, Linux): when the pinned store compiler's
  # own directory (`pkgs2/nim-<ver>-<sha>/bin`) is ANYWHERE on PATH — exactly
  # what env.sh's hoist puts there, and in any position: reproduced first,
  # last, and behind another nim — `nimble setup` under a lock skips the solver
  # and clones every `#hash`-pinned package by vcsRevision through
  # download.nim's cloneSpecificRevision, which createDir()s the
  # quoteShell()ed temp path and then quoteShell()s it AGAIN for `git -C`;
  # every such path contains `#`, so git sees a name that was never created
  # ("cannot change to '…uuids…#1a8111cc…_1a8111cc…'"). With that directory
  # absent from PATH nimble solves and installs from its pkgcache and never
  # enters that proc. So the call gets a PATH with the store directory
  # filtered out and the SAME binary in front through a symlink outside the
  # store: nimble still reports "using pkgs2/nim-… for compilation" — the pin
  # is not weakened, only nimble's PATH scan is. Upstream ask (nimble #9).
  # Windows keeps the plain call (symlinks; unverified host).
  var envPrefix = ""
  if hostOS != "windows":
    let shim = getEnv("TMPDIR", "/tmp") / "status-nim-shim"
    mkDir shim
    exec "ln -sfn " & quoteShell(nimExe()) & " " & quoteShell(shim / "nim")
    var kept: seq[string]
    for entry in getEnv("PATH").split(':'):
      if (DirSep & "pkgs2" & DirSep & "nim-") notin entry:
        kept.add entry
    envPrefix = "PATH=" & quoteShell(shim & ":" & kept.join(":")) & " "
  let (output, rc) = gorgeEx("cd " & quoteShell(thisDir()) & " && " & envPrefix &
    "nimble setup")
  if rc != 0:
    fail "`nimble setup` failed:\n" & output & "\nIf a .nimble manifest" &
      " changed, regenerate the lock with `nimble lock` (a full solve, takes" &
      " minutes) and retry."
  echo output.strip
  applyOverlayNow()
  writeKey(keyFile, key)

# --- the platform sentinel (ADR 0003) -----------------------------------------

proc platformCleanup() =
  exec "cd " & quoteShell(thisDir()) &
    " && scripts/platform_pre_build_cleanup.sh " & quoteShell(platformTarget())

# --- status-go: scratch copy, libsds, libstatus -------------------------------

proc statusgoArtifactKey(): string =
  ## Keyed invalidation (pattern 2): the flag set the scratch copy's artifacts
  ## were built with. Byte-identical to the key make's `statusgo-scratch` rule
  ## passed, so a tree built by either front door stays valid for the other.
  "desktop-" & libExt() & "-" & (if qtArch().len > 0: qtArch() else: "host") &
    "-dbg" & (if debugSymbols(): "true" else: "false")

proc prepareStatusgoScratch(key: string) =
  ## Default mode resolves statusgo to a READ-ONLY store copy; libstatus/libsds
  ## need a writable tree. Wipe+re-copy only when the resolved store path
  ## changes (that path embeds the pin revision AND the manifest checksum);
  ## drop artifacts only when the flag key changes.
  if statusgoDeveloped():
    echo "prepareStatusgo: statusgo is developed — building the checkout, no scratch."
    return
  let storeRoot = statusgoStoreRoot()
  if storeRoot.len == 0:
    fail "statusgo has no store entry in nimble.paths — the resolution must" &
      " exist before building (did `nimble setup` run?)."
  let scratch = thisDir() / statusgoScratchDir
  let originFile = scratch / ".statusgo-origin"
  let keyFile = scratch / ".statusgo-artifact-key"
  # Two keys, two scopes: the ORIGIN key (the resolved store path — which
  # embeds the pin revision and the manifest checksum) decides whether the
  # whole scratch tree is the right tree; its witness is the copy's own
  # statusgo.nims. The ARTIFACT key (the flag set) decides only whether the
  # artifacts inside a correct tree are still valid.
  if keyStale(originFile, storeRoot, witness = scratch / "statusgo.nims"):
    echo "prepareStatusgo: refreshing " & statusgoScratchDir & " from " & storeRoot
    if dirExists(scratch):
      exec "chmod -R u+w " & quoteShell(scratch)
      rmDir scratch
    exec "cp -R " & quoteShell(storeRoot) & " " & quoteShell(scratch)
    exec "chmod -R u+w " & quoteShell(scratch)
    writeKey(originFile, storeRoot)
    if key.len > 0:
      writeKey(keyFile, key)
  elif key.len > 0 and keyStale(keyFile, key):
    echo "prepareStatusgo: build flags changed (" & key & ") — dropping artifacts"
    exec "rm -f " & scratch / "build" / "bin" / "libstatus.*"
    if fileExists(scratch / "nimble.paths"):
      exec "touch " & quoteShell(scratch / "nimble.paths")
    writeKey(keyFile, key)
  else:
    echo "prepareStatusgo: scratch up-to-date (pin unchanged)"

# NAMING CONVENTION (issue 0018 review, I2): every key file the driver writes at
# the REPO ROOT is `.status-<artifact>.key` — .status-client.key, .status-rcc.key,
# .status-setup.key, .status-libsds.key. That makes `rm -f .status-*.key` a TOTAL
# glob, which is why `make clean` no longer carries a hand-kept list to drift out
# of step with these consts (the libsds key used to be spelled `.libsds.key`, and
# the Makefile's list was the only place that knew). Key files that live INSIDE a
# build tree (<buildDir>/.status-cmake.key, <scratch>/.statusgo-artifact-key) are
# exempt: they are removed with the tree they gate, and no clean rule names them.
const libsdsKeyFile = ".status-libsds.key"  # gitignored; at the repo root (see buildLibsds)

proc nimsdsLibDir(): string = statusgoBuildRoot() / ".sds-build/build"
proc nimsdsIncDir(): string = statusgoBuildRoot() / ".sds-build/library"
proc nimsdsLibFile(): string = nimsdsLibDir() / ("libsds." & libExt())
proc statusgoLibDir(): string = statusgoBuildRoot() / "build/bin"
proc statusgoLibFile(): string = statusgoLibDir() / ("libstatus." & libExt())

proc syncStatusgoPaths() =
  ## statusgo.nims locates nim-sds through a nimble.paths beside itself; under
  ## the single graph that file is a COPY of the app's resolution. Copy only on
  ## content change, or the libsds artifact is invalidated by no-op setups.
  let dst = statusgoBuildRoot() / "nimble.paths"
  exec "cd " & quoteShell(thisDir()) & " && cmp -s nimble.paths " &
    quoteShell(dst) & " || cp nimble.paths " & quoteShell(dst)

proc buildLibsds() =
  ## A developed nim-sds is FORCED: its sources live in the checkout, which is
  ## not among the inputs below (enumerating a whole vendor tree per build costs
  ## more than the sub-build's own no-op). Under 0016's mtime gate the same job
  ## was done by the sds vendor's `forceTouch` arm — a `touch` of the derived
  ## nimble.paths — which a content key correctly ignores.
  let force = "sds" in readOverlay()
  var inputs = @[statusgoBuildRoot() / "nimble.paths"]
  let devManifest = thisDir() / "vendor/status-go/statusgo.nimble"
  if fileExists(devManifest):
    inputs.add devManifest # a nim-sds pin bump must invalidate the built lib
  # The key file lives at the REPO root, beside the driver's other key files —
  # never under statusgoBuildRoot(): in develop mode that root is the
  # vendor/status-go checkout, and a build would leave it permanently dirty
  # (issue 0017 review, I3). Nothing else reads it, so relocating costs one
  # extra libsds sub-build on the first build after this lands.
  let keyFile = thisDir() / libsdsKeyFile
  let key = contentKey("", inputs)
  if not force and not stale(keyFile, [nimsdsLibFile()], key):
    return
  echo "\e[92mBuilding:\e[39m libsds"
  exec "cd " & quoteShell(statusgoBuildRoot()) & " && " &
    quoteShell(nimExe()) & " libsds statusgo.nims"
  writeKey(keyFile, key)

proc buildLibstatus() =
  ## status-go owns its own build system (a Go/make project vendored as a
  ## pinned nimble package). The driver treats it exactly like a cmake vendor:
  ## it decides WHEN, status-go decides HOW. `statusgo-shared-library` has no
  ## nimscript task upstream, so this is the one sub-build the driver still
  ## delegates to a foreign Makefile — never to THIS repo's Makefile.
  ## In pinned mode the artifact's existence is the whole gate (the scratch
  ## engine's key file already covers pin and flag changes; a develop-mode
  ## checkout gets its FORCE arm from applyDevelopModeArms()).
  if not stale([statusgoLibFile()]):
    return
  echo "\e[92mBuilding:\e[39m status-go"
  # protoc-gen-go is a `go generate` prerequisite of status-go's own build.
  exec "go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.1"
  var env = "NIM_SDS_LIB_DIR=" & quoteShell(nimsdsLibDir()) &
    " NIM_SDS_INC_DIR=" & quoteShell(nimsdsIncDir())
  if not debugSymbols():
    env &= " CGO_CFLAGS=-O3"
  if crossDesktop():
    env &= " GOBIN_SHARED_LIB_CFLAGS=" &
      quoteShell("CGO_ENABLED=1 GOOS=darwin GOARCH=amd64")
  # stdout ONLY: version.sh runs `git fetch --tags`, whose progress lines go
  # to stderr, and gorgeEx merges the two streams — the day origin moved, the
  # "version" carried " + abc...def branch -> origin/branch (forced update)"
  # lines and status-go's `sh -c "echo $SENTRY_CONTEXT_VERSION > …"` generate
  # step died on the "(". make's $(shell) never saw stderr (2026-09-15).
  let (version, _) = gorgeEx("cd " & quoteShell(thisDir()) &
    " && ./scripts/version.sh 2>/dev/null")
  exec env & " make -C " & quoteShell(statusgoBuildRoot()) &
    " statusgo-shared-library SHELL=/bin/sh" &
    " SENTRY_CONTEXT_NAME=status-desktop" &
    " SENTRY_CONTEXT_VERSION=" & quoteShell(version.strip)

proc buildStatusgo() =
  if statusgoDeveloped():
    # 24h staleness pre-clean: only a mutable checkout can go stale (a pinned
    # store copy cannot — the scratch engine's origin key covers it).
    exec "cd " & quoteShell(thisDir()) &
      " && bash ./scripts/force-rebuild-status-go.sh " & quoteShell(statusgoLibFile())
  prepareStatusgoScratch(statusgoArtifactKey())
  syncStatusgoPaths()
  buildLibsds()
  buildLibstatus()

# --- cmake artifacts -----------------------------------------------------------

proc statusqBuildPath(): string =
  thisDir() / "ui/StatusQ/build/Qt" & qtProp("QT_VERSION")

proc buildStatusQ() =
  var args = @["-DCMAKE_INSTALL_PREFIX=" & thisDir() / "bin",
               "-DSTATUSQ_BUILD_SANITY_CHECKER=OFF",
               "-DSTATUSQ_BUILD_TESTS=OFF"]
  # The QML monitoring tool lives in StatusQ since master dropped DOtherSide
  # (2026-07); make's STATUSQ_CMAKE_CONFIG_PARAMS arm, ported.
  if getEnv("MONITORING", "false") != "false":
    args.add "-DMONITORING:BOOL=ON"
    args.add "-DMONITORING_QML_ENTRY_POINT:STRING=/../monitoring/Main.qml"
  cmakeArtifact("StatusQ", thisDir() / "ui/StatusQ", statusqBuildPath(), args,
    target = "StatusQ", install = true)

## keycardBuildDir/keycardLibDir live in status_env.nims: config.nims links
## against exactly these directories, and the driver's private copies had
## already drifted from it (they missed the Windows per-config leg). One
## definition, two consumers (issue 0017 review, I5).

proc developRedirect(vendor, checkoutDir: string): string =
  ## Issue 0011's contract, preserved verbatim: the FETCHCONTENT_SOURCE_DIR_*
  ## pair is ALWAYS passed; an EMPTY value means "use the pin". Passing only
  ## the developed half would leave a stale redirect in the cmake cache across
  ## an undevelop.
  let developed = vendor in readOverlay()
  "-DFETCHCONTENT_SOURCE_DIR_" & vendor.toUpperAscii & "=" &
    (if developed: thisDir() / checkoutDir else: "")

proc buildKeycardQt() =
  var args = @["-DBUILD_TESTING=OFF", "-DBUILD_EXAMPLES=OFF",
               "-DBUILD_SHARED_LIBS=ON",
               developRedirect("status-keycard-qt", "vendor/status-keycard-qt"),
               developRedirect("keycard-qt", "vendor/keycard-qt")]
  if hostOS == "macosx":
    args.add "-DOPENSSL_ROOT_DIR=" & thisDir() / "bottles/openssl@3"
    args.add "-DOPENSSL_USE_STATIC_LIBS=ON"
  elif hostOS == "windows":
    args.add "-DOPENSSL_ROOT_DIR=" &
      getEnv("WIN_OPENSSL_ROOT", "C:/ProgramData/scoop/apps/openssl-lts/current")
    args.add "-DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON"
  # The simulated keycard (CI's nightly keycard e2e) is a separate build tree —
  # keycardBuildDir() carries the suffix — so its codegen never leaks into a
  # real-keycard build (master 2026-08).
  if getEnv("USE_SIMULATED_KEYCARD") == "true":
    args.add "-DUSE_SIMULATED_KEYCARD=ON"
  cmakeArtifact("status-keycard-qt", thisDir() / "cmake/status-keycard-qt",
    keycardBuildDir(), args, target = "status-keycard-qt")

proc translationsPrefix(): string =
  ## QT_INSTALL_PREFIX points at the TARGET kit (an Android kit has no
  ## LinguistTools); lupdate/lrelease are host tools.
  let host = qtProp("QT_HOST_PREFIX")
  if host.len > 0: host else: qtProp("QT_INSTALL_PREFIX")

proc buildTranslations(target: string) =
  cmakeArtifact("translations", thisDir() / "ui/i18n",
    thisDir() / "ui/i18n/build",
    ["-DCMAKE_PREFIX_PATH=" & translationsPrefix()], target = target)

# --- Qt resources (rcc) --------------------------------------------------------

const rccSkipDirs = ["StatusQ", "vendor", "tests", "node_modules"]
  ## SOURCE OF TRUTH: `ui/generate-rcc.go`'s own prune list (it skips any
  ## DIRECTORY with one of these names, at ANY depth). resources.rcc's inputs
  ## are exactly what that generator walks, so this scan must prune the same
  ## names at the same depths. Keep the two in sync — a name added there and
  ## missed here only costs spurious rcc rebuilds; the reverse silently stops
  ## regenerating a resource.

const rccKeyFile = ".status-rcc.key"  # gitignored

proc uiFindCmd(): string =
  ## make's UI_SOURCES, with two corrections that the gate forces:
  ##
  ## - the generator's pruned directories are excluded. make's glob included
  ##   `ui/StatusQ/**`, where StatusQ's own cmake CONFIGURE rewrites
  ##   `build/Qt<ver>/TestConfig.generated.qrc` on every run — an input that is
  ##   newer than resources.rcc on every build, i.e. a permanently stale target.
  ##   (A content key would also see the rewrite; cmake stamps a new timestamp
  ##   comment into it.)
  ## - `.qm` joins the pattern: the generator embeds the compiled catalogs, and
  ##   since translations stopped being a build step (issue 0016) nothing else
  ##   would notice a `nim compileTranslations status.nims` run.
  ##
  ## `*/<name>/*` is depth-independent, like the generator's `filepath.SkipDir`
  ## on a directory basename. A depth-limited prune leaves deeper matches in
  ## the input set and reintroduces the spurious-staleness bug above.
  var prune = ""
  for d in rccSkipDirs:
    prune &= " -not -path '*/" & d & "/*'"
  result =
    if hostOS == "macosx":
      "find -E ui -type f -iregex '.*(qmldir|qml|qrc|js|qm)$'"
    else:
      "find ui -type f -regextype egrep -iregex '.*(qmldir|qml|qrc|js|qm)$'"
  result &= prune & " -not -iname 'resources.qrc'"

proc buildResources() =
  let rcc = thisDir() / "resources.rcc"
  let keyFile = thisDir() / rccKeyFile
  let key = contentKey(uiFindCmd())
  if not stale(keyFile, [rcc], key):
    return
  echo "\e[92mBuilding:\e[39m resources.rcc"
  rmFile rcc
  rmFile thisDir() / "ui/resources.qrc"
  exec "cd " & quoteShell(thisDir()) &
    " && go run ui/generate-rcc.go -source=ui -output=ui/resources.qrc"
  exec "cd " & quoteShell(thisDir()) & " && rcc -binary " &
    (if debugSymbols(): "--no-compress " else: "") &
    "ui/resources.qrc -o ./resources.rcc"
  writeKey(keyFile, key)

# --- the client binary ---------------------------------------------------------

proc clientBinary(): string =
  thisDir() / "bin" / (if hostOS == "windows": "nim_status_client.exe"
                       else: "nim_status_client")

const clientFlagEnv = [
  ## EVERY environment variable `config.nims` reads inside its `isDesktopClient`
  ## block that moves a compile or link flag. `envOr(NAME, derived)` prefers the
  ## exported value, so exporting one — or changing it — changes the binary
  ## while leaving every file `stale()` watches untouched. Keep this list in
  ## step with config.nims; a missing entry is a silently stale binary.
  "INCLUDE_DEBUG_SYMBOLS",   # release/debug flavor + nimcache dir
  "QT_ARCH",                 # cross-desktop: --cpu/--os/-arch
  "RESOURCES_LAYOUT",        # -d:development / -d:production
  "KDF_ITERATIONS",          # -d:KDF_ITERATIONS
  "OUTPUT_CSV",              # -d:output_csv
  "QML_DEBUG",               # -d:qmldebug + -DQT_QML_DEBUG (and cmake's build type)
  "QML_DEBUG_PORT",          # -d:qmlDebugPort
  "MONITORING",              # -d:monitoring
  "USE_SIMULATED_KEYCARD",   # -d:useSimulatedKeycard + its own nimcache
  "QT_LIBDIR",               # -F/-L + rpath
  "STATUSGO_LIBDIR",         # -L + rpath
  "NIMSDS_LIBDIR",           # -L + rpath
  "STATUSQ_INSTALL_PATH",    # -L + rpath
  "STATUSKEYCARD_QT_LIBDIR", # -L + rpath
  "MACOSX_DEPLOYMENT_TARGET",# decides ObjC-metadata section placement at link
]

proc clientKey(): string =
  ## Keyed invalidation (pattern 2), absorbing make's `.qmake_previous`: the
  ## client bakes the kit's libdirs as rpaths and its flag set comes from
  ## config.nims' env-or-derived knobs, none of which are files `stale()` can
  ## see. A changed key forces a relink.
  ##
  ## QMAKE joins them: it is what `.qmake_previous` tracked, and every derived
  ## Qt value (libdir, version, the .pc tree) hangs off it.
  result = qmakeExe()
  for name in clientFlagEnv:
    result &= "|" & name & "=" & getEnv(name)

proc clientSourcesKey(): string =
  ## The content key of everything the client compile reads outside the nimble
  ## graph. The flag set itself is an input (issue 0013 put it in config.nims),
  ## and so is the resolution it reads — plus prl-to-pc's cached `env`, which
  ## decides what `pkg-config --libs Qt6…` puts on the link line (issue 0015).
  var extra: seq[string]
  for f in ["config.nims", "status_env.nims", "nimble.paths", qtPcEnvCache]:
    extra.add thisDir() / f
  contentKey("find src -type f", extra)

proc pinnedNimEntry(): tuple[version, checksum: string] =
  ## The nim store entry THIS resolution names: the version from the manifest's
  ## `requires "nim == X"` (the pin itself) and, when the lock records it, the
  ## checksum that completes the store entry's directory name
  ## (`pkgs2/nim-<version>-<checksum>`). nimble.paths carries no nim entry —
  ## the compiler is not a `--path:` — so the lock is where the resolution
  ## writes it down (`packages.nim.checksums.sha1`, verified 2026-07-12: it IS
  ## the store directory's checksum).
  let manifest = thisDir() / "nim_status_client.nimble"
  if fileExists(manifest):
    for line in readFile(manifest).splitLines:
      let l = line.strip
      if not l.startsWith("requires"):
        continue
      let parts = l.split('"')
      # The requirement NAME must be exactly "nim" (issue 0018 review, R4): a
      # `requires "nimcrypto == 0.6.0"` line ordered first would otherwise match
      # on "starts with nim" + "contains ==" and pin the guard to the wrong
      # package's version.
      if parts.len >= 2 and "==" in parts[1] and
          parts[1].split("==")[0].strip == "nim":
        result.version = parts[1].split("==")[1].strip
        break
  let lock = thisDir() / "nimble.lock"
  if result.version.len > 0 and fileExists(lock):
    var inNim = false
    for raw in readFile(lock).splitLines:
      let l = raw.strip
      if raw.startsWith("    \"") and l.endsWith("{"):
        inNim = l.startsWith("\"nim\":")   # a package block starts here
        continue
      if inNim and l.startsWith("\"sha1\":"):
        let parts = l.split('"')
        if parts.len >= 4:
          result.checksum = parts[3]
        break

proc guardPinnedCompiler() =
  ## The compiler about to compile the client MUST be the pinned store entry
  ## (issue 0018 review, adjudication A1 — it amends the PRD's "no version
  ## guard" decision).
  ##
  ## The PRD's reasoning was "a bootstrapped shell cannot drift". True only
  ## while `~/.nimble/bin/nim` happens to BE the pin: `nimble shellenv` lists
  ## $NIMBLE_DIR/bin BEFORE the pinned `pkgs2/nim-<ver>-<checksum>/bin` (0018
  ## §7), and choosenim (or `nimble install nim@X`) repoints that symlink — so
  ## a hand-typed `eval "$(nimble shellenv)"` can silently compile the client
  ## with another compiler. `env.sh` hoists the pin; this guard is what catches
  ## the shell that did not use it.
  ##
  ## It lives in the DRIVER, never in config.nims: nimsuggest evaluates
  ## config.nims with ITS OWN compiler (an editor's nimsuggest is not the pin),
  ## so a guard there would false-positive on every keystroke. And it runs only
  ## when a client compile is actually about to happen — two small file reads,
  ## no subprocess, nothing on the no-op path.
  ##
  ## It cannot fire under `nimble build`/`nimble run`: nimble compiles the
  ## client itself (this proc is not on that path) and injects the pinned
  ## compiler into the PATH of the tasks and hooks it does run.
  let exe = nimExe()
  if getEnv("STATUS_NIM").len > 0:
    echo "note: STATUS_NIM overrides the pinned compiler (" & exe & ")."
    return
  let (version, checksum) = pinnedNimEntry()
  if version.len == 0:
    return  # no `requires "nim == X"` in the manifest: nothing to assert
  let entry = "nim-" & version & (if checksum.len > 0: "-" & checksum else: "")
  let marker = $DirSep & "pkgs2" & $DirSep & entry
  if (if checksum.len > 0: (marker & $DirSep) in exe else: (marker & "-") in exe):
    return
  fail "the Nim that is about to compile the client is NOT the pinned" &
    " compiler.\n" &
    "  running: " & exe & "\n" &
    "  pinned:  <store>/pkgs2/" & entry & "/bin/nim" &
    "   (nim_status_client.nimble: requires \"nim == " & version & "\")\n\n" &
    "Bootstrap the shell so the pin wins the PATH race:\n" &
    "  nimble setup && source ./env.sh\n\n" &
    "A bare `eval \"$(nimble shellenv)\"` is NOT enough: it puts" &
    " $NIMBLE_DIR/bin — whose `nim` symlink choosenim can repoint — ahead of" &
    " the pinned pkgs2 entry (issue 0018 §7). `nimble build` / `nimble run`" &
    " need no bootstrap at all: nimble injects the pin itself.\n" &
    "STATUS_NIM=<path> deliberately overrides this check."

proc buildClient(force: bool) =
  ## `force` is the replacement for make's REBUILD_NIM: a developed vendor
  ## whose Nim sources compile INTO the client (seaqt, nimqml, the statusgo
  ## wrapper) skips the gate entirely, and so does `nim app status.nims --force`.
  ##
  ## ONE key file carries both key sources (see the header): the configuration
  ## key (qmake + the flag env, which move link flags and baked rpaths without
  ## touching a file) and the content key of the sources.
  let bin = clientBinary()
  let keyFile = thisDir() / ".status-client.key"
  let key = clientKey() & "\n" & clientSourcesKey()
  if not force and not stale(keyFile, [bin], key):
    return
  guardPinnedCompiler()
  echo "\e[92mBuilding:\e[39m " & bin.extractFilename
  exec "cd " & quoteShell(thisDir()) & " && " & quoteShell(nimExe()) &
    " c src/nim_status_client.nim"
  if hostOS == "macosx":
    # The Go-built libstatus and the cmake keycard lib carry bare install
    # names; rewrite them to @rpath so the baked rpaths resolve them. Same
    # fixups the manifest's `after build` hook runs for `nimble build`.
    exec "install_name_tool -change libstatus.dylib @rpath/libstatus.dylib " &
      quoteShell(bin)
    exec "install_name_tool -change libstatus-keycard-qt.dylib" &
      " @rpath/libstatus-keycard-qt.dylib " & quoteShell(bin)
  writeKey(keyFile, key)

# --- the Nim test suite (issue 0017) ------------------------------------------

## applyQtPkgConfigEnv() and qtSeaqtExtraLibs() live in status_env.nims: this
## file used to carry byte-copies of config.nims' env-replay block and its
## pkg-config gorgeEx (issue 0017 review, I4). config.nims replays the cached
## env only inside its `isDesktopClient` block, and the Nim test suite is not
## that client — so the driver applies the same one definition before it invokes
## `nim` on a test.

proc nimTestFiles(): seq[string] =
  let (output, rc) = gorgeEx("cd " & quoteShell(thisDir()) &
    " && find test/nim -type f -name '*.nim' | sort")
  if rc != 0:
    fail "could not enumerate the Nim tests (test/nim/*.nim):\n" & output
  for line in output.splitLines:
    if line.strip.len > 0:
      result.add line.strip

# These stand up real StatusQ machinery — signal_handler /
# statusq_invoke_method_queued, ModelQuery/ModelUtils, SFPM proxy chains, or
# full modal QML trees in an offscreen engine — so they link libStatusQ and
# need it built first. (make's NIM_TESTS_LINK_STATUSQ, ported from
# makefiles/nim-tests.mk when the Makefile stopped invoking nim.)
const nimTestsLinkStatusQ = [
  "asset_proxy_chain_bench",
  "collectibles_selector_bench",
  "collectibles_selector_model_bench",
  "send_handler_adaptors_bench",
  "send_handler_lookup_bench",
  "send_modal_instantiation_bench",
  "services_pause_bridge_test",
  "signal_handler_test",
  "swap_key_harvest_bench",
  "swap_modal_instantiation_bench",
  "typed_completion_test",
  "url_scheme_event_test",
]

# Model-spy tests call inspection accessors gated behind
# `when defined(testing) or defined(QT_MODEL_SPY)` or assert on the granular
# signals model_sync records only under QT_MODEL_SPY. The define is applied
# per-file, NOT globally (make's NIM_TESTS_MODEL_SPY).
const nimTestsModelSpy = [
  "assets_adaptor_model_test",
  "collectibles_selector_model_test",
  "grouped_account_assets_model_test",
  "market_leaderboard_model_test",
  "member_model_test",
  "model_sync_move_test",
  "model_sync_unified_test",
  "token_groups_model_test",
  "token_lists_model_test",
  "token_selector_model_bench",
  "token_selector_model_test",
  "token_selector_producer_view_test",
]

proc isBench(t: string): bool =
  ## Naming convention (makefiles/nim-tests.mk): benchmarks end in `_bench.nim`;
  ## everything else is a test.
  t.endsWith("_bench.nim")

proc runNimTests(only: seq[string], benches: bool) =
  ## `make nim-test-run/%` + `tests-nim` / `benches-nim`, moved to the driver.
  ##
  ## The driver owns the library-path environment, which is the whole reason
  ## this could not stay a make one-liner: make's recipe exported
  ## `LD_LIBRARY_PATH` only, so on macOS the freshly linked test binary died at
  ## startup with `Library not loaded: @rpath/libsds.dylib` (reproduced
  ## 2026-07-10 on `make nim-test-run/test/nim/utils_test.nim`). Compile and run
  ## are therefore separate steps here, and the run gets the same library path
  ## `launchHostApp` gives the app.
  ##
  ## The flag set is make's, minus the `-d:DESKTOP_VERSION` / `-d:GIT_COMMIT` /
  ## `-d:STATUSGO_VERSION` trio: those are `{.strdefine.}`s with defaults
  ## (src/constants.nim) that no test asserts on, and re-deriving them here
  ## would be a second copy of config.nims' derivation.
  applyQtPkgConfigEnv(qmakeExe(), qtProp("QT_INSTALL_PREFIX"))
  let qtLibDir = qtProp("QT_INSTALL_LIBS")
  # config.nims' non-client arms bake one rpath per env var that is SET; make
  # exported these. Only the two libraries the tests actually link need one.
  # (The client's key is untouched: this task never compiles the client.)
  putEnv("QT_LIBDIR", qtLibDir)
  putEnv("STATUSGO_LIBDIR", statusgoLibDir())

  var flags = @["c", "--mm:refc", "--outdir:./bin"]
  if debugSymbols():
    flags.add "-d:debug"
  else:
    flags.add "-d:release"
    flags.add "-d:lto"
  if hostOS == "macosx":
    flags.add "--passL:-framework Foundation -framework AppKit -framework" &
      " Security -framework IOKit -framework CoreServices -framework" &
      " LocalAuthentication"
    flags.add "--passL:-headerpad_max_install_names"
    flags.add "--passL:-F" & qtLibDir
  else:
    flags.add "--passL:-L" & qtLibDir
    if hostOS == "linux":
      flags.add "--passL:-Wl,-rpath-link," & qtLibDir  # see config.nims
  flags.add "--passL:" & qtSeaqtExtraLibs()
  flags.add "--passL:-L" & nimsdsLibDir()
  flags.add "--passL:-lsds"
  flags.add "--passL:-L" & statusgoLibDir()
  flags.add "--passL:-lstatus"

  let statusqLibPath = thisDir() / "bin/StatusQ"
  var libPath = ""
  for d in [qtLibDir, nimsdsLibDir(), statusgoLibDir(), statusqLibPath]:
    libPath &= d & ":"
  let libPathVar = if hostOS == "macosx": "DYLD_LIBRARY_PATH" else: "LD_LIBRARY_PATH"

  # Tests run by default; benchmarks only with --benches (make's tests-nim vs
  # benches-nim). A NAMED benchmark is always allowed.
  let allFiles = nimTestFiles()
  var tests: seq[string]
  if only.len > 0:
    for t in allFiles:
      for o in only:
        if o == t or o == t.extractFilename or o == t.splitFile.name:
          tests.add t
    if tests.len == 0:
      fail "no test matches " & only.join(" ") & "\nKnown tests:\n  " &
        allFiles.join("\n  ")
  else:
    for t in allFiles:
      if benches or not isBench(t):
        tests.add t

  # StatusQ-linking suites need libStatusQ built and on the rpath (config.nims'
  # non-client arm bakes STATUSQ_INSTALL_PATH/StatusQ when the var is set).
  var needStatusQ = false
  for t in tests:
    if t.splitFile.name in nimTestsLinkStatusQ:
      needStatusQ = true
  if needStatusQ:
    putEnv("STATUSQ_INSTALL_PATH", thisDir() / "bin")
    buildStatusQ()

  # Per-test nimcache: parallel CI builds of the suite must not race on one
  # cache (make's NIMCACHE_BASE).
  let nimcacheBase = getEnv("WORKSPACE_TMP", thisDir() / "build") / "nimcache"

  # The suite is a Nim compile like any other, and it links the same libraries
  # the client does: the compiler that runs it must be the pin too (issue 0018
  # review, R3 — buildClient() was the only guarded compile). After the cheap
  # gates (a bad test name must still fail on its own message), before the first
  # compile, STATUS_NIM override honored inside the guard.
  guardPinnedCompiler()

  var cmd = quoteShell(nimExe())
  for f in flags:
    cmd &= " " & quoteShell(f)
  for t in tests:
    let name = t.splitFile.name
    var perTest = " " & quoteShell("--nimcache:" & nimcacheBase & "-" & name)
    if name in nimTestsLinkStatusQ:
      perTest &= " " & quoteShell("--passL:-L" & statusqLibPath) &
        " " & quoteShell("--passL:-lStatusQ")
    if name in nimTestsModelSpy:
      perTest &= " -d:QT_MODEL_SPY"
    echo "\e[92mBuilding:\e[39m " & t
    exec "cd " & quoteShell(thisDir()) & " && " & cmd & perTest & " " & quoteShell(t)
    let bin = thisDir() / "bin" / t.splitFile.name
    echo "\e[92mRunning:\e[39m " & bin.extractFilename
    exec "cd " & quoteShell(thisDir()) & " && " & libPathVar & "=" &
      quoteShell(libPath & getEnv(libPathVar)) & " " & quoteShell(bin)
  echo "\e[92mNim tests:\e[39m " & $tests.len & " suite(s) green"

# --- the Windows launcher (issue 0017) ----------------------------------------

proc buildWindowsLauncher(compileOnly: bool) =
  ## `make nim_windows_launcher`, moved to the driver. The launcher is the small
  ## GUI shim that `pkg-windows` ships as `Status.exe` next to `bin/Status.exe`;
  ## it shellExecuteW's the real client so the console window never appears.
  ##
  ## Built with the DEFAULT cc (mingw/gcc), never with the client's
  ## clang/MSVC-ABI flag set — those live inside config.nims' `isDesktopClient`
  ## block precisely so this compile does not inherit them.
  ##
  ## PORTED, UNVERIFIED on a non-Windows host: `--os:windows` reaches the C
  ## backend (verified: `--compileOnly` emits the Windows C sources) but the
  ## link needs an x86_64-w64-mingw32 toolchain this machine does not carry.
  ## `nim windowsLauncher status.nims --compileOnly` is the check a non-Windows
  ## host can run.
  # The launcher ships INSIDE the Windows package, so the compiler that builds
  # it is asserted against the pin exactly like the client's (issue 0018 review,
  # R3). No gate precedes it — this task always compiles.
  guardPinnedCompiler()
  var cmd = "cd " & quoteShell(thisDir()) & " && " & quoteShell(nimExe()) &
    " c -d:debug --outdir:./bin" &
    " --passL:\"-static-libgcc -Wl,-Bstatic,--whole-archive -lwinpthread" &
    " -Wl,--no-whole-archive\""
  if hostOS != "windows":
    cmd &= " --os:windows --cpu:amd64"
  if compileOnly:
    cmd &= " --compileOnly:on --nimcache:" &
      quoteShell(thisDir() / "nimcache/windows-launcher")
  echo "\e[92mBuilding:\e[39m nim_windows_launcher"
  exec cmd & " src/nim_windows_launcher.nim"

# --- Windows import libraries (issue 0017) ------------------------------------

proc genImportLib(header, dll, outLib: string) =
  ## lld-link (MSVC ABI, needed to link Qt's msvc build) cannot link a `.dll`
  ## directly — unlike mingw's ld it needs an import library. status-go and
  ## nim-sds ship only `.dll` + `.h`, so synthesize one from each header. The
  ## names match the `-l` flags config.nims puts on the client link line, and
  ## they land in the directories already on `-L`.
  ##
  ## Keyed on the DLL's content: a rebuilt DLL with new exports needs a new
  ## import library. (make keyed it on the DLL's mtime.)
  let keyFile = outLib.parentDir / ("." & outLib.extractFilename & ".key")
  let key = contentKey("", [dll])
  if not stale(keyFile, [outLib], key):
    return
  echo "\e[92mBuilding:\e[39m import lib: " & outLib.extractFilename
  exec "cd " & quoteShell(thisDir()) & " && bash scripts/gen-import-lib.sh " &
    quoteShell(header) & " " & quoteShell(dll.extractFilename) & " " &
    quoteShell(outLib)
  writeKey(keyFile, key)

proc buildWindowsImportLibs() =
  if hostOS != "windows":
    return
  genImportLib(statusgoLibDir() / "libstatus.h", statusgoLibFile(),
    statusgoLibDir() / "status.lib")
  genImportLib(nimsdsIncDir() / "libsds.h", nimsdsLibFile(),
    nimsdsLibDir() / "sds.lib")

# --- the ordered call list ------------------------------------------------------

proc prepareHostBuild() =
  ## The prologue EVERY host Nim compile needs: a resolved graph, the Qt
  ## pkg-config environment, the build env, a clean platform sentinel, and the
  ## status-go libraries (+ their Windows import libraries) that both the client
  ## and the Nim test suite link.
  ##
  ## Order matters: bootstrap before resolution (a fresh clone has neither
  ## submodules nor a store), resolution before anything that reads
  ## nimble.paths (prl-to-pc's package root, statusgo's store entry), the
  ## platform sentinel before any shared artifact is touched.
  ##
  ## One definition (issue 0017 review, M7): the `tests` task used to
  ## re-implement this sequence and omitted buildWindowsImportLibs — harmless on
  ## macOS, a broken link on Windows, where the suite's `-lstatus`/`-lsds` need
  ## the synthesized import libraries too.
  bootstrap()
  nimbleSetupIfStale()
  prepareQtPkgconfig()
  exportBuildEnv()
  platformCleanup()
  buildStatusgo()
  buildWindowsImportLibs()  # no-op off Windows; needs libstatus + libsds

proc buildHostArtifacts() =
  ## Everything bin/nim_status_client links or loads, except the client compile
  ## itself. This is `buildArtifacts` — nimble's before-build hook — and the
  ## first half of `nim app status.nims`.
  ##
  ## It takes no `force`: every artifact here owns its own gate, and the ONLY
  ## thing `--force` ever forced is the client compile (buildClient). A developed
  ## vendor's FORCE arms are applied by applyDevelopModeArms(), before this runs.
  prepareHostBuild()
  buildStatusQ()
  buildKeycardQt()
  buildResources()
