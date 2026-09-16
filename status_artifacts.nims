# status_artifacts.nims — every non-Nim artifact bin/nim_status_client links
# or loads, built by the driver itself.
#
# Included by status.nims AFTER status_env.nims and after the driver's own
# helpers (fail / nimExe / ncpu / prepareQtPkgconfig).
#
# Never included by config.nims: config.nims is evaluated on every nim
# invocation (nimsuggest included), so it must not touch the filesystem to
# decide whether something needs rebuilding. `stale()` lives here instead.
#
# --- the two gating patterns -------------------------------------------------
#
# Both are key files: the build records a key next to the artifact, and a build
# whose key differs rebuilds. They differ in where the key comes from.
#
# 1. `stale(keyFile, outputs, key)` with `key = contentKey(...)`: the key is a
#    digest of the CONTENT of the artifact's file inputs. Rebuild when an
#    output is missing or the recorded digest differs.
#
#    Content, not mtime: `test -nt` is a POSIX-shell builtin (unconditionally
#    true on Windows), it compares whole seconds, and mtime is the wrong
#    question across a develop/undevelop flip — restoring identical sources
#    rebuilds, checking out older-but-different sources does not.
#
#    `stale(outputs)`, the one-argument overload, is the degenerate "the
#    artifact exists ⇒ it is fresh" gate (libstatus, whose freshness is owned
#    by the key files beside its outputs).
#
# 2. The configuration key, for artifacts whose inputs are not files but a
#    configuration: the resolved store path, the target triple, the flag set, a
#    cmake configure's argument list (`.statusgo-build/.statusgo-origin`,
#    `.statusgo-artifact-key`, `<buildDir>/.status-cmake.key`).
#
#    `keyStale(keyFile, key, witness)` is the one spelling. `witness` is the
#    artifact whose existence the key vouches for: a missing witness is stale
#    however well the key matches, which is why no bare `fileExists` gate
#    appears in this file.
#
# The client binary uses both key sources in one key file
# (`.status-client.key`): its configuration key (qmake + the flag env)
# concatenated with the content key of its sources.
#
# A cmake artifact's BUILD step is gated by neither: `cmake --build` runs every
# time and cmake's own incrementality (including its check-build-system
# re-configure) is the no-op path. Its CONFIGURE step is gated by pattern 2 on
# the argument list — the one input cmake cannot see — because an unconditional
# configure costs more than the whole no-op budget.
#
# Bootstrap — `initSubmodules()` and `fetchBottles()` — is not gating: it
# materializes inputs a fresh clone lacks and that nothing in the build can
# invalidate (a submodule tracks its own revision, a brew bottle is
# content-addressed by its flavor), so presence is the only question.

# --- keyed invalidation (pattern 2) -------------------------------------------

proc keyStale(keyFile, key: string, witness = ""): bool =
  ## True when the recorded key differs from `key`, when no key was ever
  ## recorded, or when `witness` — the artifact the key vouches for — is gone:
  ## a key file that survived an `rm -rf` of its build tree must not read
  ## fresh.
  if witness.len > 0 and not fileExists(witness) and not dirExists(witness):
    return true
  not fileExists(keyFile) or readFile(keyFile).strip != key

proc writeKey(keyFile, key: string) =
  mkDir keyFile.parentDir
  writeFile(keyFile, key)

# --- staleness (pattern 1): a portable CONTENT key ----------------------------

proc contentKey(findCmd: string, extra: openArray[string] = []): string =
  ## A digest of the CONTENT of an input set, computed in one subprocess.
  ##
  ## `findCmd` is a `find(1)` invocation relative to the repo root (this proc
  ## appends `-print0`); `extra` names additional absolute paths. A path in
  ## `extra` that does not exist is dropped, so its disappearance changes the
  ## digest.
  ##
  ## An EMPTY input set is a hard error, never a digest: the pipeline prints a
  ## well-formed `4294967295 0` for it, so an artifact whose inputs all
  ## vanished would record a stable key and read fresh forever. The digest's
  ## second field is the byte count of the `cksum` lines, so `<crc> 0` means
  ## "zero files hashed" exactly.
  ##
  ## `xargs -0 -r` is load-bearing for that guard: without `-r`, GNU xargs runs
  ## `cksum </dev/null` on empty input and the outer `cksum` folds that into a
  ## well-formed digest with a non-zero byte count. `-r` is a no-op on
  ## BSD/macOS xargs, which already skips the utility on empty input.
  ##
  ## Hashing each input inside the nimscript VM is unaffordable — its string
  ## hash runs one byte at a time, and src/ alone would cost several times the
  ## whole no-op budget. One `find` piped into `cksum` and folded by a second
  ## `cksum` reads every byte in a fraction of a second and spends a single
  ## subprocess.
  ##
  ## The digest needs a POSIX shell with `find`, `xargs`, `sort` and `cksum`.
  ## On Windows that is msys2, which the Windows build already requires.
  ##
  ## `sort` makes the digest independent of readdir order. A path containing a
  ## newline would split a `cksum` line and is not supported.
  var emit: seq[string]
  if findCmd.len > 0:
    # `|| exit 1` is load-bearing: with an `extra` list the emitted group is
    # `{ find … -print0; printf … }`, and a brace group's exit status is its
    # last command's, so a failing `find` would be masked from pipefail.
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
  # `set -o pipefail` where the shell has it, without dying where it does not:
  # in dash it is an unknown option to a POSIX special builtin and kills the
  # whole non-interactive shell, so it is probed in a subshell first. With it,
  # a failing `find` cannot yield a well-formed digest of a truncated input
  # set.
  let cmd = "cd " & quoteShell(thisDir()) &
    " && (set -o pipefail) 2>/dev/null && set -o pipefail; { " & emit.join("; ") &
    "; } | xargs -0 -r cksum | sort | cksum"
  let (output, rc) = gorgeEx(cmd)
  let key = output.strip
  # gorgeEx merges stderr into the output, so validate the shape: `cksum`
  # prints exactly "<crc> <bytes>", and anything else is a broken scan.
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
    # Zero bytes of `cksum` output means zero files matched: well-formed, and
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
  ## user is libstatus, whose freshness is owned by the key files beside its
  ## outputs.
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
  ## all want it, and a no-op build must not pay a subprocess per lookup.
  for (f, v) in unameCache:
    if f == flag:
      return v
  let (output, rc) = gorgeEx("uname " & flag)
  if rc != 0:
    fail "`uname " & flag & "` failed:\n" & output
  result = output.strip
  unameCache.add (flag, result)

proc qtArch(): string =
  ## The cross-desktop knob; macOS defaults it to `uname -m`.
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
  ## root Makefile's `$(host_os)-$(or $(QT_ARCH),$(shell uname -m))`: the
  ## make-driven mobile legs write the same `.platform-target` file.
  let arch = if qtArch().len > 0: qtArch() else: uname("-m")
  uname("-s").toLowerAscii & "-" & arch

## qmlDebug() / buildType() live in status_env.nims: config.nims' Windows
## client arm needs the same cmake flavor to find `lib/<Release|Debug>`.

proc exportBuildEnv() =
  ## The environment every artifact build needs. cmake reads CFLAGS at
  ## configure time and `rcc`/`lrelease`/`lupdate` are found through PATH, so
  ## without these the build silently uses a different SDK or another Qt's
  ## tools.
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
  ## The cmake flags every artifact configure shares.
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
  ## step runs unconditionally: cmake's own incrementality is the no-op path,
  ## and every generator emits a check-build-system rule, so `cmake --build`
  ## re-runs the configure itself when a CMakeLists.txt changed.
  ##
  ## What cmake cannot notice is a change in the configure ARGUMENTS (a develop
  ## redirect flip, a build-type flip, another Qt kit); that is gating pattern
  ## 2's job. The configure is gated rather than unconditional because a single
  ## one costs about the whole no-op budget.
  ##
  ## `configureArgs` are appended AFTER commonCmakeArgs, so an artifact can
  ## override a common `-D` (the translations project needs the HOST Qt
  ## prefix): the last definition wins in the cmake cache.
  ##
  ## The FETCHCONTENT_SOURCE_DIR_<NAME> contract lives at the call sites: the
  ## redirect is always passed, an empty value meaning "use the pin", so a flip
  ## changes this key and the redirect can never go stale.
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
  "vendor/status-keycard-qt",    # the cmake project buildKeycardQt configures
]

proc initSubmodules() =
  ## Targeted, never blanket-recursive: only the submodules the host desktop
  ## build consumes (fcitx5-qt is Linux packaging, mobile/vendors/openssl is
  ## mobile).
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
  ## status-keycard-qt both consume. Bootstrap, not gating — a bottle is
  ## content-addressed by its flavor, so presence is the only question.
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
  ## `nimble setup` re-runs only when its product (nimble.paths) is stale
  ## against the lock, the manifests in the graph and the develop overlay.
  ##
  ## Ordering is load-bearing: `nimble setup` first, then the overlay is
  ## applied to the freshly generated nimble.paths (ADR 0007).
  ##
  ## The gate is a content key, not nimble.paths' mtime: a hand-run `nimble
  ## setup` or `./status applyOverlay` rewrites nimble.paths without
  ## recording the inputs' key, so the next build still resolves.
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
  try:
    exec "cd " & quoteShell(thisDir()) & " && nimble setup"
  except OSError:
    fail "`nimble setup` failed — see the error above. If a .nimble" &
      " manifest changed, regenerate the lock with `nimble lock` (a full" &
      " solve, takes minutes) and retry."
  applyOverlayNow()
  writeKey(keyFile, key)

# --- the platform sentinel (ADR 0003) -----------------------------------------

proc platformCleanup() =
  exec "cd " & quoteShell(thisDir()) &
    " && scripts/platform_pre_build_cleanup.sh " & quoteShell(platformTarget())

# --- status-go: outputs, libsds, libstatus ------------------------------------
#
# Nothing is copied: status-go and nim-sds are built IN PLACE from whatever the
# resolution points at — read-only store copies in default mode — because both
# packages keep every output under a caller-chosen directory. That directory is
# .statusgo-build/ at the repo root, and it holds only outputs: libstatus + its
# header, the generated cbindings entry point, libsds + the header contract,
# the nimcaches and the two key files.

proc statusgoArtifactKey(): string =
  ## Keyed invalidation (pattern 2): the flag set the outputs were built with.
  ## Byte-identical to the key make's `statusgo-out` rule passes, so artifacts
  ## built by either front door stay valid for the other.
  "desktop-" & libExt() & "-" & (if qtArch().len > 0: qtArch() else: "host") &
    "-dbg" & (if debugSymbols(): "true" else: "false")

# Every key file the driver writes at the REPO ROOT is named
# `.status-<artifact>.key`, which makes `make clean`'s `rm -f .status-*.key` a
# total glob — no hand-kept list to drift out of step with these consts. Key
# files inside a build tree (<buildDir>/.status-cmake.key,
# <out>/.statusgo-artifact-key) are removed with the tree they gate.
const libsdsKeyFile = ".status-libsds.key"  # gitignored; at the repo root

proc nimsdsLibDir(): string = statusgoBuildRoot() / ".sds-build/build"
proc nimsdsIncDir(): string = statusgoBuildRoot() / ".sds-build/library"
proc nimsdsLibFile(): string = nimsdsLibDir() / ("libsds." & libExt())
proc statusgoLibDir(): string = statusgoBuildRoot() / "build/bin"
proc statusgoLibFile(): string = statusgoLibDir() / ("libstatus." & libExt())

proc prepareStatusgoOut(key: string) =
  ## Maintains the OUTPUT directory; nothing is copied. Two keys, two scopes:
  ## the ORIGIN key (the resolved SOURCE root, which embeds the pin revision
  ## and the manifest checksum) decides whether the outputs belong to the
  ## statusgo tree now being built, and the ARTIFACT key (the flag set) decides
  ## whether they were built with the right flags. The origin key's witness is
  ## libstatus itself: a key file that survived an `rm -f` of the artifacts
  ## must not read fresh.
  let src = statusgoSourceRoot()
  let outDir = statusgoBuildRoot()
  let originFile = outDir / ".statusgo-origin"
  let keyFile = outDir / ".statusgo-artifact-key"
  if keyStale(originFile, src, witness = statusgoLibFile()):
    if fileExists(originFile) and readFile(originFile).strip != src:
      echo "prepareStatusgo: outputs were built from " &
        readFile(originFile).strip & " — wiping " & statusgoOutDir
      rmDir outDir
    mkDir outDir
    writeKey(originFile, src)
    if key.len > 0:
      writeKey(keyFile, key)
  elif key.len > 0 and keyStale(keyFile, key):
    echo "prepareStatusgo: build flags changed (" & key & ") — dropping artifacts"
    exec "rm -f " & outDir / "build" / "bin" / "libstatus.*"
    writeKey(keyFile, key)
  else:
    echo "prepareStatusgo: outputs up-to-date (pin unchanged)"

proc statusgoTaskEnv(): string =
  ## The whole contract statusgo.nims asks for: where outputs go, which
  ## resolution to build against, and a `nim` on PATH. The last one is not
  ## ours to remove: status-go's own tasks shell out to a bare `nim` for
  ## nim-sds, so the resolved compiler is handed down to them here rather than
  ## by a shell the developer is expected to have bootstrapped.
  ## nimble.paths is handed over by path: copying it next to statusgo.nims
  ## would write into the shared package store.
  "PATH=" & quoteShell(nimExe().parentDir) & ":$PATH" &
    " STATUSGO_BUILD_DIR=" & quoteShell(statusgoBuildRoot()) &
    " STATUSGO_NIMBLE_PATHS=" & quoteShell(thisDir() / "nimble.paths") & " "

proc buildLibsds() =
  ## A developed nim-sds is FORCED: its sources live in the checkout, which is
  ## not among the inputs below, because enumerating a whole vendor tree per
  ## build costs more than the sub-build's own no-op.
  let force = "sds" in readOverlay()
  var inputs = @[thisDir() / "nimble.paths"]
  let devManifest = thisDir() / "vendor/status-go/statusgo.nimble"
  if fileExists(devManifest):
    inputs.add devManifest # a nim-sds pin bump must invalidate the built lib
  # The artifact key joins the content key because the flag-change arm of
  # prepareStatusgoOut() drops libstatus only: libsds is compiled with the same
  # flag set and must not survive a flip.
  let keyFile = thisDir() / libsdsKeyFile
  let key = contentKey("", inputs) & "|" & statusgoArtifactKey()
  if not force and not stale(keyFile, [nimsdsLibFile()], key):
    return
  echo "\e[92mBuilding:\e[39m libsds"
  exec statusgoTaskEnv() & quoteShell(nimExe()) & " libsds " &
    quoteShell(statusgoSourceRoot() / "statusgo.nims")
  writeKey(keyFile, key)

proc buildLibstatus() =
  ## status-go owns its own build system (a Go/make project shipped as a
  ## pinned nimble package): the driver decides when, status-go decides how.
  ## `statusgo-shared-library` has no nimscript task upstream, so this is the
  ## one sub-build delegated to a foreign Makefile.
  ##
  ## In pinned mode the artifact's existence is the whole gate: the key files
  ## cover pin and flag changes, and a develop-mode checkout gets its FORCE arm
  ## from applyDevelopModeArms().
  if not stale([statusgoLibFile()]):
    return
  echo "\e[92mBuilding:\e[39m status-go"
  var env = "NIM_SDS_LIB_DIR=" & quoteShell(nimsdsLibDir()) &
    " NIM_SDS_INC_DIR=" & quoteShell(nimsdsIncDir())
  if not debugSymbols():
    env &= " CGO_CFLAGS=-O3"
  if crossDesktop():
    env &= " GOBIN_SHARED_LIB_CFLAGS=" &
      quoteShell("CGO_ENABLED=1 GOOS=darwin GOARCH=amd64")
  # stdout only: version.sh runs `git fetch --tags`, whose progress lines go to
  # stderr, and gorgeEx merges the two streams into the "version" string.
  let (version, _) = gorgeEx("cd " & quoteShell(thisDir()) &
    " && ./scripts/version.sh 2>/dev/null")
  # STATUS_GO_VERSION is the DESKTOP version on purpose: status-go derives it
  # from `git describe` in its own tree, which a store copy does not have, and
  # the desktop version is what the app reports.
  # GENERATE_PREREQ=: the generated Go sources are committed in status-go, so
  # the consumer build needs no protoc/mockgen — and `make generate` would try
  # to write into the read-only store copy.
  exec env & " make -C " & quoteShell(statusgoSourceRoot()) &
    " statusgo-shared-library SHELL=/bin/sh" &
    " STATUS_GO_BUILD_DIR=" & quoteShell(statusgoBuildRoot() / "build") &
    " GENERATE_PREREQ=" &
    " STATUS_GO_VERSION=" & quoteShell(version.strip) &
    " SENTRY_CONTEXT_NAME=status-desktop" &
    " SENTRY_CONTEXT_VERSION=" & quoteShell(version.strip)

proc buildStatusgo() =
  if statusgoDeveloped():
    # 24h staleness pre-clean: only a mutable checkout can go stale, a pinned
    # store copy is covered by the origin key.
    exec "cd " & quoteShell(thisDir()) &
      " && bash ./scripts/force-rebuild-status-go.sh " & quoteShell(statusgoLibFile())
  prepareStatusgoOut(statusgoArtifactKey())
  buildLibsds()
  buildLibstatus()

# --- cmake artifacts -----------------------------------------------------------

proc statusqBuildPath(): string =
  thisDir() / "ui/StatusQ/build/Qt" & qtProp("QT_VERSION")

proc buildStatusQ() =
  var args = @["-DCMAKE_INSTALL_PREFIX=" & thisDir() / "bin",
               "-DSTATUSQ_BUILD_SANITY_CHECKER=OFF",
               "-DSTATUSQ_BUILD_TESTS=OFF"]
  # The QML monitoring tool lives in StatusQ.
  if getEnv("MONITORING", "false") != "false":
    args.add "-DMONITORING:BOOL=ON"
    args.add "-DMONITORING_QML_ENTRY_POINT:STRING=/../monitoring/Main.qml"
  cmakeArtifact("StatusQ", thisDir() / "ui/StatusQ", statusqBuildPath(), args,
    target = "StatusQ", install = true)

## keycardBuildDir/keycardLibDir live in status_env.nims: config.nims links
## against exactly these directories, including the Windows per-config leg.

proc developRedirect(vendor, checkoutDir: string): string =
  ## The FETCHCONTENT_SOURCE_DIR_* variable is always passed, an empty value
  ## meaning "use the pin": passing it only while developed would leave a stale
  ## redirect in the cmake cache across an undevelop.
  let developed = vendor in readOverlay()
  "-DFETCHCONTENT_SOURCE_DIR_" & vendor.toUpperAscii & "=" &
    (if developed: thisDir() / checkoutDir else: "")

proc buildKeycardQt() =
  # The sources are the vendor/status-keycard-qt submodule; the nested
  # keycard-qt pin is owned by that project's own CMakeLists, which
  # FetchContents it.
  var args = @["-DBUILD_TESTING=OFF", "-DBUILD_EXAMPLES=OFF",
               "-DBUILD_SHARED_LIBS=ON",
               developRedirect("keycard-qt", "vendor/keycard-qt")]
  if hostOS == "macosx":
    args.add "-DOPENSSL_ROOT_DIR=" & thisDir() / "bottles/openssl@3"
    args.add "-DOPENSSL_USE_STATIC_LIBS=ON"
  elif hostOS == "windows":
    args.add "-DOPENSSL_ROOT_DIR=" &
      getEnv("WIN_OPENSSL_ROOT", "C:/ProgramData/scoop/apps/openssl-lts/current")
    args.add "-DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON"
  # Its own build tree: keycardBuildDir() carries the suffix.
  if getEnv("USE_SIMULATED_KEYCARD") == "true":
    args.add "-DUSE_SIMULATED_KEYCARD=ON"
  cmakeArtifact("status-keycard-qt", thisDir() / "vendor/status-keycard-qt",
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
  ## `ui/generate-rcc.go`'s own prune list: it skips any directory with one of
  ## these names, at any depth, and resources.rcc's inputs are exactly what
  ## that generator walks. Keep the two in sync: a name missing here costs
  ## spurious rcc rebuilds, a name missing there silently stops regenerating a
  ## resource.

const rccKeyFile = ".status-rcc.key"  # gitignored

proc uiFindCmd(): string =
  ## resources.rcc's input set:
  ##
  ## - the generator's pruned directories are excluded. Including
  ##   `ui/StatusQ/**` would pull in `build/Qt<ver>/TestConfig.generated.qrc`,
  ##   which StatusQ's cmake configure rewrites on every run — a permanently
  ##   stale input.
  ## - `.qm` is in the pattern: the generator embeds the compiled catalogs, and
  ##   translations are not a build step, so nothing else would notice a
  ##   `./status compileTranslations` run.
  ##
  ## `*/<name>/*` is depth-independent, like the generator's `filepath.SkipDir`
  ## on a directory basename; a depth-limited prune would leave deeper matches
  ## in the input set.
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
  ## Every environment variable config.nims reads inside its `isDesktopClient`
  ## block that moves a compile or link flag. `envOr(NAME, derived)` prefers
  ## the exported value, so exporting or changing one changes the binary while
  ## leaving every file `stale()` watches untouched. Keep this list in step
  ## with config.nims: a missing entry is a silently stale binary.
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
  ## Keyed invalidation (pattern 2): the client bakes the kit's libdirs as
  ## rpaths and its flag set comes from config.nims' env-or-derived knobs, none
  ## of which are files `stale()` can see. A changed key forces a relink.
  ##
  ## QMAKE joins them because every derived Qt value (libdir, version, the .pc
  ## tree) hangs off it.
  result = qmakeExe()
  for name in clientFlagEnv:
    result &= "|" & name & "=" & getEnv(name)

proc clientSourcesKey(): string =
  ## The content key of everything the client compile reads outside the nimble
  ## graph: its sources, the flag set (config.nims), the resolution it reads,
  ## and prl-to-pc's cached `env`, which decides what `pkg-config --libs
  ## Qt6…` puts on the link line.
  var extra: seq[string]
  for f in ["config.nims", "status_env.nims", "nim.cfg", "nimble.paths",
            qtPcEnvCache]:
    extra.add thisDir() / f
  contentKey("find src seaqt_compat -type f", extra)

proc pinnedNimVersion(): string =
  ## The Nim version this repository pins, read from the manifest's
  ## `requires "nim == X"` — the one place it is written. The compiler is not
  ## a `--path:`, so nimble.paths carries no nim entry; the manifest is the
  ## driver's source of truth, exactly as it is `./status`'s.
  for line in readFile(thisDir() / "nim_status_client.nimble").splitLines:
    let l = line.strip
    if not l.startsWith("requires"):
      continue
    let a = l.find('"')
    if a < 0:
      continue
    let b = l.find('"', a + 1)
    if b < 0:
      continue
    let spec = l[a + 1 ..< b]           # e.g. `nim == 2.2.10`
    let eq = spec.find("==")
    if eq >= 0 and spec[0 ..< eq].strip == "nim":
      return spec[eq + 2 .. ^1].strip

proc guardPinnedCompiler() =
  ## The compiler about to compile the client must be the version the manifest
  ## pins. `./status` asserts the same thing before it execs the driver, so
  ## this catches only a hand-run `./status app` in a shell whose
  ## `nim` is something else.
  ##
  ## It lives in the driver, never in config.nims: nimsuggest evaluates
  ## config.nims with its own compiler and a guard there would fire on every
  ## keystroke. It runs only when a client compile is about to happen — one
  ## file read, no subprocess, nothing on the no-op path.
  ##
  ## NimVersion is the compiler evaluating this script, which is the compiler
  ## nimExe() hands the client sources to.
  let exe = nimExe()
  if getEnv("STATUS_NIM").len > 0:
    echo "note: STATUS_NIM overrides the pinned compiler (" & exe & ")."
    return
  let want = pinnedNimVersion()
  if want.len == 0 or NimVersion == want:
    return
  fail "the Nim that is about to compile the client is NOT the pinned" &
    " version.\n" &
    "  running: " & exe & " (" & NimVersion & ")\n" &
    "  pinned:  " & want &
    "   (nim_status_client.nimble: requires \"nim == " & want & "\")\n\n" &
    "Build through the front door — `./status app` — which resolves the" &
    " pinned compiler with `nimble path nim` and execs it.\n" &
    "STATUS_NIM=<path> deliberately overrides this check."

proc buildClient(force: bool) =
  ## `force` skips the gate entirely: `./status app --force`, or a
  ## developed vendor whose Nim sources compile INTO the client (seaqt, nimqml,
  ## the statusgo wrapper).
  ##
  ## One key file carries both key sources (see the header): the configuration
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
    # names; rewrite them to @rpath so the baked rpaths resolve them. The
    # manifest's `after build` hook runs the same fixups for `nimble build`.
    exec "install_name_tool -change libstatus.dylib @rpath/libstatus.dylib " &
      quoteShell(bin)
    exec "install_name_tool -change libstatus-keycard-qt.dylib" &
      " @rpath/libstatus-keycard-qt.dylib " & quoteShell(bin)
  writeKey(keyFile, key)

# --- the Nim test suite ------------------------------------------

## applyQtPkgConfigEnv() and qtSeaqtExtraLibs() live in status_env.nims:
## config.nims replays the cached env only inside its `isDesktopClient` block,
## and the Nim test suite is not that client, so the driver applies the same
## definition before it invokes `nim` on a test.

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
# need it built first.
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
# `when defined(testing) or defined(QT_MODEL_SPY)`, or assert on the granular
# signals model_sync records only under QT_MODEL_SPY. The define is applied
# per file, never globally.
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
  ## Benchmarks end in `_bench.nim`; everything else is a test.
  t.endsWith("_bench.nim")

proc runNimTests(only: seq[string], benches: bool) =
  ## Compile and run are separate steps: the run needs the same library path
  ## `launchHostApp` gives the app (on macOS a freshly linked test binary
  ## otherwise dies with `Library not loaded: @rpath/libsds.dylib`).
  ##
  ## The flag set carries no `-d:DESKTOP_VERSION` / `-d:GIT_COMMIT` /
  ## `-d:STATUSGO_VERSION`: those are `{.strdefine.}`s with defaults
  ## (src/constants.nim) that no test asserts on, and deriving them here would
  ## duplicate config.nims.
  applyQtPkgConfigEnv(qmakeExe(), qtProp("QT_INSTALL_PREFIX"))
  let qtLibDir = qtProp("QT_INSTALL_LIBS")
  # config.nims' non-client arms bake one rpath per env var that is set, and
  # only the two libraries the tests link need one. The client's key is
  # untouched: this task never compiles the client.
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

  # Tests run by default, benchmarks only with --benches. A named benchmark is
  # always allowed.
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
  # cache.
  let nimcacheBase = getEnv("WORKSPACE_TMP", thisDir() / "build") / "nimcache"

  # The suite links the same libraries the client does, so the compiler that
  # builds it must be the pin too. After the cheap gates, so a bad test name
  # still fails on its own message; before the first compile.
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

# --- the Windows launcher ----------------------------------------

proc buildWindowsLauncher(compileOnly: bool) =
  ## The small GUI shim `pkg-windows` ships as `Status.exe` next to
  ## `bin/Status.exe`; it shellExecuteW's the real client so the console window
  ## never appears.
  ##
  ## Built with the default cc (mingw/gcc), never with the client's
  ## clang/MSVC-ABI flag set — those live inside config.nims' `isDesktopClient`
  ## block so this compile does not inherit them.
  ##
  ## On a non-Windows host `--os:windows` reaches the C backend, but the link
  ## needs an x86_64-w64-mingw32 toolchain; `--compileOnly` is the check such a
  ## host can run.
  # The launcher ships inside the Windows package, so its compiler is asserted
  # against the pin like the client's. This task always compiles.
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

# --- Windows import libraries ------------------------------------

proc genImportLib(header, dll, outLib: string) =
  ## lld-link (MSVC ABI, needed to link Qt's msvc build) cannot link a `.dll`
  ## directly — unlike mingw's ld it needs an import library. status-go and
  ## nim-sds ship only `.dll` + `.h`, so synthesize one from each header. The
  ## names match the `-l` flags config.nims puts on the client link line, and
  ## they land in the directories already on `-L`.
  ##
  ## Keyed on the DLL's content: a rebuilt DLL with new exports needs a new
  ## import library.
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
  ## The prologue every host Nim compile needs: a resolved graph, the Qt
  ## pkg-config environment, the build env, a clean platform sentinel, and the
  ## status-go libraries (plus their Windows import libraries) that both the
  ## client and the Nim test suite link.
  ##
  ## Order matters: bootstrap before resolution (a fresh clone has neither
  ## submodules nor a store), resolution before anything that reads
  ## nimble.paths (prl-to-pc's package root, statusgo's store entry), the
  ## platform sentinel before any shared artifact is touched.
  ##
  ## The `tests` task shares this sequence rather than re-implementing it:
  ## omitting buildWindowsImportLibs is harmless on macOS but a broken link on
  ## Windows, where the suite's `-lstatus`/`-lsds` need the synthesized import
  ## libraries too.
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
  ## first half of `./status app`.
  ##
  ## It takes no `force`: every artifact here owns its own gate, and `--force`
  ## forces only the client compile (buildClient). A developed vendor's FORCE
  ## arms are applied by applyDevelopModeArms(), before this runs.
  prepareHostBuild()
  buildStatusQ()
  buildKeycardQt()
  buildResources()
