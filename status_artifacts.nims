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
# 1. `stale(outputs, inputs)` — an mtime scan with make's semantics: rebuild
#    when an output is missing, or when any input is NEWER than the oldest
#    output. Used for artifacts whose inputs are files we can enumerate
#    (resources.rcc, libsds, the client binary, the `nimble setup` product).
#    Costs one subprocess per call, whatever the input count.
#
#    Limits, both inherited from `test -nt` and both documented here rather
#    than worked around: second-granularity comparison (an edit landing inside
#    the same second as the output's mtime is missed — make compares
#    nanoseconds), and POSIX-shell only, so on Windows `stale()` always
#    reports stale.
#
# 2. The **key file** — keyed invalidation for artifacts whose inputs are not
#    files but a *configuration*: the resolved store path, the target triple,
#    the flag set. The build writes the key next to the artifact; a build
#    whose key differs drops the artifact. Established by the status-go
#    scratch engine (`.statusgo-build/.statusgo-origin`,
#    `.statusgo-artifact-key`; issue 0010) and reused here for the client
#    binary (`.status-client.key`, which absorbs make's `.qmake_previous`).
#
# A cmake artifact's BUILD step is gated by neither: `cmake --build` runs every
# time and cmake's own incrementality (including its check-build-system
# re-configure) IS the no-op path, exactly as under make. Its CONFIGURE step is
# gated by pattern 2 on the argument list — the one input cmake cannot see.
#
# `stale(outputs, [])` is the degenerate "the artifact exists ⇒ it is fresh"
# gate (libstatus, whose freshness is owned by the key file next to the scratch
# copy). It is pattern 1, not a third pattern; spell it that way.

# --- staleness (pattern 1) ----------------------------------------------------

proc stale(outputs, inputs: openArray[string]): bool =
  ## True when any output is missing, or any input is newer than the OLDEST
  ## output. Paths are absolute. Empty `inputs` means "exists ⇒ fresh".
  ##
  ## nimscript has no mtime API (`os.getLastModificationTime` is an `{.error.}`
  ## on the NimScript target — walls doc), so this shells out exactly once: the
  ## inputs stream through the shell's own `-nt` test on a heredoc, which costs
  ## no exec per file and has no ARG_MAX ceiling.
  if outputs.len == 0:
    return true
  for o in outputs:
    if not fileExists(o) and not dirExists(o):
      return true
  if inputs.len == 0:
    return false
  if hostOS == "windows":
    return true # `test -nt` is POSIX-shell only; always rebuild there
  var cmd = "ref=$(ls -td --"
  for o in outputs:
    cmd &= " " & quoteShell(o)
  cmd &= " | tail -1)\n" &
    "while IFS= read -r f; do\n" &
    "  if [ \"$f\" -nt \"$ref\" ]; then echo __STATUS_STALE__; exit 0; fi\n" &
    "done <<'__STATUS_INPUTS__'\n" &
    inputs.join("\n") & "\n__STATUS_INPUTS__\nexit 0\n"
  let (output, rc) = gorgeEx(cmd)
  if rc != 0:
    fail "the staleness scan failed (outputs: " & outputs.join(" ") & "):\n" & output
  "__STATUS_STALE__" in output

# --- keyed invalidation (pattern 2) -------------------------------------------

proc keyStale(keyFile, key: string): bool =
  not fileExists(keyFile) or readFile(keyFile).strip != key

proc writeKey(keyFile, key: string) =
  mkDir keyFile.parentDir
  writeFile(keyFile, key)

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

proc buildType(): string =
  if getEnv("QML_DEBUG", "false") != "false": "Debug" else: "Release"

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
  if not fileExists(buildDir / "CMakeCache.txt") or keyStale(keyFile, cfg):
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
  "vendor/DOtherSide",           # cmake artifact (dead on master; rides the generic proc)
  "vendor/QR-Code-generator",    # C source, {.compile.}d by src/app/global/utils/qrcodegen.nim
  "vendor/SortFilterProxyModel", # add_subdirectory'd by ui/StatusQ/CMakeLists.txt
]

proc initSubmodules() =
  ## Targeted, never blanket-recursive: only the submodules the HOST desktop
  ## build consumes. (fcitx5-qt is Linux packaging, mobile/vendors/openssl is
  ## mobile, nimbus-build-system dies in issue 0018.)
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

proc nimbleSetupIfStale() =
  ## The setup stamp is not preserved but RELOCATED (issue 0016): `nimble
  ## setup` re-runs only when its product (nimble.paths) is stale w.r.t. the
  ## lock, the manifests in the graph and the develop overlay — exactly the key
  ## make's `$(NIMBLE_SETUP_STAMP)` rule used.
  ##
  ## Ordering is load-bearing and must survive: `nimble setup` FIRST, then the
  ## overlay is applied to the freshly generated nimble.paths (ADR 0004). Note
  ## that applying the overlay rewrites nimble.paths, which is also what makes
  ## the stamp fresh — the same `touch` make's recipe ended with.
  var inputs: seq[string]
  for f in ["nimble.lock", "nim_status_client.nimble", overlayFile,
            "vendor/status-go/statusgo.nimble"]:
    if fileExists(thisDir() / f):
      inputs.add thisDir() / f
  if not stale([thisDir() / "nimble.paths"], inputs):
    return
  if findExe("nimble").len == 0:
    fail "nimble is not on PATH (see BUILDING.md) — it resolves the whole" &
      " dependency graph, including the pinned Nim compiler."
  echo "\e[92mResolving:\e[39m nimble graph (lock/manifests/overlay changed)"
  let (output, rc) = gorgeEx("cd " & quoteShell(thisDir()) & " && nimble setup")
  if rc != 0:
    fail "`nimble setup` failed:\n" & output & "\nIf a .nimble manifest" &
      " changed, regenerate the lock with `nimble lock` (a full solve, takes" &
      " minutes) and retry."
  echo output.strip
  applyOverlayNow()

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
  let origin = if fileExists(originFile): readFile(originFile) else: ""
  if origin != storeRoot or not fileExists(scratch / "statusgo.nims"):
    echo "prepareStatusgo: refreshing " & statusgoScratchDir & " from " & storeRoot
    if dirExists(scratch):
      exec "chmod -R u+w " & quoteShell(scratch)
      rmDir scratch
    exec "cp -R " & quoteShell(storeRoot) & " " & quoteShell(scratch)
    exec "chmod -R u+w " & quoteShell(scratch)
    writeFile(originFile, storeRoot)
    if key.len > 0:
      writeFile(keyFile, key)
  elif key.len > 0 and keyStale(keyFile, key):
    echo "prepareStatusgo: build flags changed (" & key & ") — dropping artifacts"
    exec "rm -f " & scratch / "build" / "bin" / "libstatus.*"
    if fileExists(scratch / "nimble.paths"):
      exec "touch " & quoteShell(scratch / "nimble.paths")
    writeKey(keyFile, key)
  else:
    echo "prepareStatusgo: scratch up-to-date (pin unchanged)"

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
  var inputs = @[statusgoBuildRoot() / "nimble.paths"]
  let devManifest = thisDir() / "vendor/status-go/statusgo.nimble"
  if fileExists(devManifest):
    inputs.add devManifest # a nim-sds pin bump must invalidate the built lib
  if not stale([nimsdsLibFile()], inputs):
    return
  echo "\e[92mBuilding:\e[39m libsds"
  exec "cd " & quoteShell(statusgoBuildRoot()) & " && " &
    quoteShell(nimExe()) & " libsds statusgo.nims"

proc buildLibstatus() =
  ## status-go owns its own build system (a Go/make project vendored as a
  ## pinned nimble package). The driver treats it exactly like a cmake vendor:
  ## it decides WHEN, status-go decides HOW. `statusgo-shared-library` has no
  ## nimscript task upstream, so this is the one sub-build the driver still
  ## delegates to a foreign Makefile — never to THIS repo's Makefile.
  ## In pinned mode the artifact's existence is the whole gate (the scratch
  ## engine's key file already covers pin and flag changes; a develop-mode
  ## checkout gets its FORCE arm from developModeForce()).
  if not stale([statusgoLibFile()], []):
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
  let (version, _) = gorgeEx("cd " & quoteShell(thisDir()) & " && ./scripts/version.sh")
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
  cmakeArtifact("StatusQ", thisDir() / "ui/StatusQ", statusqBuildPath(),
    ["-DCMAKE_INSTALL_PREFIX=" & thisDir() / "bin",
     "-DSTATUSQ_BUILD_SANITY_CHECKER=OFF",
     "-DSTATUSQ_BUILD_TESTS=OFF"],
    target = "StatusQ", install = true)

proc buildDOtherSide() =
  var args = @["-DENABLE_DOCS=OFF", "-DENABLE_TESTS=OFF"]
  if hostOS == "windows":
    args.add "-DENABLE_DYNAMIC_LIBS=ON"
    args.add "-DENABLE_STATIC_LIBS=OFF"
  else:
    args.add "-DENABLE_DYNAMIC_LIBS=OFF"
    args.add "-DENABLE_STATIC_LIBS=ON"
  if getEnv("QML_DEBUG", "false") != "false":
    args.add "-DQML_DEBUG_PORT=" & getEnv("QML_DEBUG_PORT", "49152")
  if getEnv("MONITORING", "false") != "false":
    args.add "-DMONITORING:BOOL=ON"
    args.add "-DMONITORING_QML_ENTRY_POINT:STRING=/../monitoring/Main.qml"
  cmakeArtifact("DOtherSide", thisDir() / "vendor/DOtherSide",
    thisDir() / "vendor/DOtherSide/build/Qt" & qtProp("QT_VERSION"), args)

proc keycardBuildDir(): string =
  thisDir() / "build/status-keycard-qt" /
    (case hostOS
     of "macosx": "macos"
     of "windows": "windows"
     else: "linux")

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
  ## The directories `ui/generate-rcc.go` itself prunes. resources.rcc's inputs
  ## are exactly what that generator walks, so the scan must prune them too.

proc uiSources(): seq[string] =
  ## make's UI_SOURCES, with two corrections that `stale()` forces:
  ##
  ## - the generator's pruned directories are excluded. make's glob included
  ##   `ui/StatusQ/**`, where StatusQ's own cmake CONFIGURE rewrites
  ##   `build/Qt<ver>/TestConfig.generated.qrc` on every run — an input that is
  ##   newer than resources.rcc on every build, i.e. a permanently stale target.
  ## - `.qm` joins the pattern: the generator embeds the compiled catalogs, and
  ##   since translations stopped being a build step (issue 0016) nothing else
  ##   would notice a `nim compileTranslations status.nims` run.
  var prune = ""
  for d in rccSkipDirs:
    prune &= " -not -path 'ui/" & d & "/*' -not -path 'ui/*/" & d & "/*'"
  let findCmd =
    if hostOS == "macosx":
      "find -E ui -type f -iregex '.*(qmldir|qml|qrc|js|qm)$'"
    else:
      "find ui -type f -regextype egrep -iregex '.*(qmldir|qml|qrc|js|qm)$'"
  let (output, rc) = gorgeEx("cd " & quoteShell(thisDir()) & " && " & findCmd &
    prune & " -not -iname 'resources.qrc'")
  if rc != 0:
    fail "could not enumerate the UI sources:\n" & output
  for line in output.splitLines:
    if line.strip.len > 0:
      result.add thisDir() / line.strip

proc buildResources() =
  let rcc = thisDir() / "resources.rcc"
  if not stale([rcc], uiSources()):
    return
  echo "\e[92mBuilding:\e[39m resources.rcc"
  rmFile rcc
  rmFile thisDir() / "ui/resources.qrc"
  exec "cd " & quoteShell(thisDir()) &
    " && go run ui/generate-rcc.go -source=ui -output=ui/resources.qrc"
  exec "cd " & quoteShell(thisDir()) & " && rcc -binary " &
    (if debugSymbols(): "--no-compress " else: "") &
    "ui/resources.qrc -o ./resources.rcc"

# --- the client binary ---------------------------------------------------------

proc clientBinary(): string =
  thisDir() / "bin" / (if hostOS == "windows": "nim_status_client.exe"
                       else: "nim_status_client")

proc clientKey(): string =
  ## Keyed invalidation (pattern 2), absorbing make's `.qmake_previous`: the
  ## client bakes the kit's libdirs as rpaths and its flag set comes from
  ## config.nims' env-or-derived knobs, none of which are files `stale()` can
  ## see. A changed key forces a relink.
  [qmakeExe(), qtArch(), $debugSymbols(),
   getEnv("RESOURCES_LAYOUT", "-d:development"), getEnv("KDF_ITERATIONS"),
   getEnv("OUTPUT_CSV")].join("|")

proc clientSources(): seq[string] =
  let (output, rc) = gorgeEx("cd " & quoteShell(thisDir()) & " && find src -type f")
  if rc != 0:
    fail "could not enumerate the client sources:\n" & output
  for line in output.splitLines:
    if line.strip.len > 0:
      result.add thisDir() / line.strip
  # The flag set itself is an input (issue 0013 put it in config.nims).
  for f in ["config.nims", "status_env.nims", "nimble.paths"]:
    if fileExists(thisDir() / f):
      result.add thisDir() / f

proc buildClient(force: bool) =
  ## `force` is the replacement for make's REBUILD_NIM: a developed vendor
  ## whose Nim sources compile INTO the client (seaqt, nimqml, the statusgo
  ## wrapper) skips the mtime gate entirely.
  let bin = clientBinary()
  let keyFile = thisDir() / ".status-client.key"
  let key = clientKey()
  if not force and not keyStale(keyFile, key) and not stale([bin], clientSources()):
    return
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

# --- the ordered call list ------------------------------------------------------

proc buildHostArtifacts(force: bool) =
  ## Everything bin/nim_status_client links or loads, except the client compile
  ## itself. This is `buildArtifacts` — nimble's before-build hook — and the
  ## first half of `nim app status.nims`.
  ##
  ## Order matters: bootstrap before resolution (a fresh clone has neither
  ## submodules nor a store), resolution before anything that reads
  ## nimble.paths (prl-to-pc's package root, statusgo's store entry), the
  ## platform sentinel before any shared artifact is touched.
  bootstrap()
  nimbleSetupIfStale()
  prepareQtPkgconfig()
  exportBuildEnv()
  platformCleanup()
  buildStatusgo()
  buildStatusQ()
  buildDOtherSide()
  buildKeycardQt()
  buildResources()
