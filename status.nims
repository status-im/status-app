# status.nims — the canonical front door: one command from a clean clone to a
# runnable Status dev build (issue 0008; PRD
# docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md).
#
#   nim app status.nims                            # host desktop dev build
#   nim app status.nims --os:ios --cpu:arm64       # signed iOS device app
#   nim app status.nims --os:android --cpu:arm64   # Android debug APK
#   nim run status.nims                            # host build if needed + launch
#   nim help status.nims                           # list tasks
#
# --os/--cpu select the TARGET (host is the default). Kit selection stays
# environment-driven — QMAKE, IPHONE_SDK, QMAKE_DEVELOPMENT_TEAM,
# ANDROID_SDK_ROOT, ANDROID_NDK_ROOT, ARCH — and is validated fail-fast per
# target before any build starts. Place the flags AFTER the file name (the
# canonical spelling above): there nim forwards them to the task untouched;
# before the file name nim consumes them (they are still honored, but nim
# also re-targets its own evaluation of this script — harmless, yet noisier).
#
# The driver only DELEGATES to the existing make recipes (make is frozen:
# new build logic lives in nimscript, none is added to make). Dependency
# bootstrap is inherited from the delegation, not reimplemented: every make
# target used below depends on make's `nimble.paths` setup stamp (see
# `nimble-deps` in the Makefile — nimble.lock + the graph's manifests →
# `nimble setup` into the default store only when stale), and on a clean clone
# the Makefile's .DEFAULT rule auto-runs `git submodule update --init
# --recursive` first. This file is a nimscript driver, NOT a nimble task:
# `nimble <task>` re-pays ~46–48 s of graph revalidation per warm invocation
# on this manifest (measured 2026-07-06); `nim <task> status.nims` starts in
# about a second.

import std/[os, strutils]

# Shared kit/overlay discovery (issue 0013): qmake lookup + develop-overlay
# parsing live in status_env.nims so config.nims derives the exact same
# values the driver validates.
include "status_env.nims"

# --- invocation parsing ------------------------------------------------------

proc fail(msg: string) =
  quit("\nstatus.nims ERROR: " & msg, 1)

proc argvAll(): seq[string] =
  ## Full process argv minus the nim binary. nimscript has no
  ## commandLineParams(); paramStr covers the whole nim command line.
  for i in 1 .. paramCount():
    result.add paramStr(i)

proc taskArgv(): seq[string] =
  ## The params after this script's file name — the task's own arguments.
  var afterFile = false
  for p in argvAll():
    if afterFile:
      result.add p
    elif p.extractFilename == "status.nims":
      afterFile = true

proc flagVal(p, name: string): string =
  ## "--os:ios" / "--os=ios" → "ios"; "" when p is not that flag.
  for sep in [':', '=']:
    let prefix = "--" & name & sep
    if p.startsWith(prefix):
      return p[prefix.len .. ^1]

type Target = object
  os: string          # "host", "ios" or "android"
  cpu: string         # nim CPU name ("" = target default)
  extra: seq[string]  # unrecognized task arguments (rejected)

proc normalizedCpu(v: string): string =
  ## Accept both nim CPU names and the common ABI spellings.
  case v.toLowerAscii
  of "arm64", "aarch64": "arm64"
  of "amd64", "x86_64": "amd64"
  of "arm", "armv7": "arm"
  of "i386", "x86": "i386"
  else: fail "unknown --cpu value '" & v &
    "' (expected arm64, amd64/x86_64, arm or i386)."; ""

proc parseTarget(): Target =
  result.os = "host"
  # --os/--cpu are honored wherever they appear on the nim command line
  # (after the file nim forwards them untouched; before it nim consumes them
  # but they remain visible in argv). Everything else after the file name is
  # an unrecognized argument.
  for p in argvAll():
    let osv = flagVal(p, "os")
    let cpuv = flagVal(p, "cpu")
    if osv.len > 0:
      result.os = osv.toLowerAscii
    elif cpuv.len > 0:
      result.cpu = normalizedCpu(cpuv)
  for p in taskArgv():
    if p.len > 0 and flagVal(p, "os").len == 0 and flagVal(p, "cpu").len == 0:
      result.extra.add p
  # Spelling the build host explicitly is the host target.
  if result.os in ["macosx", "macos", "linux", "windows"]:
    let hostName = if result.os == "macos": "macosx" else: result.os
    if hostName != buildOS:
      fail "--os:" & result.os & " is not this build host (" & buildOS &
        ") — cross-desktop builds are not supported; supported cross targets" &
        " are --os:ios and --os:android."
    result.os = "host"
  if result.os notin ["host", "ios", "android"]:
    fail "unknown --os value '" & result.os &
      "' (expected ios, android, or omit for the host desktop build)."

proc rejectExtras(t: Target, taskName: string) =
  if t.extra.len > 0:
    fail "unrecognized arguments for '" & taskName & "': " &
      t.extra.join(" ") & "\nOnly --os:<ios|android> and --cpu:<cpu> are accepted."

# --- kit-environment validation (fail fast, name the exact variables) --------
# kitHint / qmakeExe / qmakeQuery come from status_env.nims (shared with
# config.nims).

proc requireXspec(t: Target, expected, kitName: string): string =
  ## Returns the validated qmake path. The make build derives its target OS
  ## from the QMAKE kit's XSPEC, so a kit/--os mismatch must die here — with
  ## the wrong kit make happily builds for the wrong platform into shared
  ## build dirs (the classic Android-QMAKE-on-a-desktop-build failure).
  result = qmakeExe()
  let xspec = qmakeQuery(result, "QMAKE_XSPEC")
  if xspec != expected:
    fail "the selected target needs a " & kitName & " Qt kit, but QMAKE (" &
      result & ") is the '" & xspec & "' kit.\n" & kitHint

proc requireEnvDirs(vars: openArray[string], target: string) =
  var missing: seq[string]
  for v in vars:
    if getEnv(v).len == 0:
      missing.add v
  if missing.len > 0:
    fail "missing environment for the " & target & " target: " &
      missing.join(", ") & "\n" & kitHint
  for v in vars:
    if not dirExists(getEnv(v)):
      fail v & "='" & getEnv(v) & "' is not a directory."

proc validateHost(t: Target) =
  let expected =
    case buildOS
    of "macosx": "macx-clang"
    of "linux": "linux-g++"
    of "windows": "win32-msvc"
    else: ""
  if expected.len > 0:
    discard requireXspec(t, expected, "desktop (" & buildOS & ")")
  if t.cpu.len > 0 and t.cpu != buildCPU:
    fail "--cpu:" & t.cpu & " on the host desktop target has no effect: the" &
      " desktop architecture follows the Qt kit. Select the " & t.cpu &
      " kit via QMAKE instead (the Makefile then cross-compiles)."

proc validateIos(t: Target) =
  discard requireXspec(t, "macx-ios-clang", "iOS")
  let sdk = getEnv("IPHONE_SDK")
  if sdk.len == 0:
    fail "missing environment for the iOS target: IPHONE_SDK\n" &
      "Set IPHONE_SDK=iphoneos (device; also needs QMAKE_DEVELOPMENT_TEAM)" &
      " or IPHONE_SDK=iphonesimulator.\n" & kitHint
  if sdk notin ["iphoneos", "iphonesimulator"]:
    fail "IPHONE_SDK='" & sdk & "' (expected iphoneos or iphonesimulator)."
  # The mobile build derives ARCH from IPHONE_SDK (iphoneos → arm64,
  # simulator → x86_64), so a contradicting --cpu must die here.
  if t.cpu == "arm64" and sdk != "iphoneos":
    fail "--cpu:arm64 is the iOS device build; it needs IPHONE_SDK=iphoneos" &
      " (IPHONE_SDK is '" & sdk & "')."
  if t.cpu == "amd64" and sdk != "iphonesimulator":
    fail "--cpu:amd64 is the iOS simulator build; it needs" &
      " IPHONE_SDK=iphonesimulator (IPHONE_SDK is '" & sdk & "')."
  if t.cpu.len > 0 and t.cpu notin ["arm64", "amd64"]:
    fail "--cpu:" & t.cpu & " is not an iOS architecture (arm64 = device," &
      " amd64 = simulator)."
  if sdk == "iphoneos" and getEnv("QMAKE_DEVELOPMENT_TEAM").len == 0:
    fail "missing environment for the iOS device target:" &
      " QMAKE_DEVELOPMENT_TEAM (the Apple team id that signs the app).\n" &
      kitHint

proc validateAndroid(t: Target) =
  let qmake = requireXspec(t, "android-clang", "Android")
  requireEnvDirs(["ANDROID_SDK_ROOT", "ANDROID_NDK_ROOT"], "Android")
  if t.cpu.len > 0:
    # The mobile build takes the ABI from ARCH (arm64 / arm / x86_64); the
    # Qt Android kit is per-ABI, so cross-check it against --cpu too.
    let (arch, kitDir) =
      case t.cpu
      of "arm64": ("arm64", "android_arm64_v8a")
      of "arm": ("arm", "android_armv7")
      of "amd64": ("x86_64", "android_x86_64")
      else: ("", "")
    if arch.len == 0:
      fail "--cpu:" & t.cpu & " is not a supported Android architecture" &
        " (arm64, arm or amd64/x86_64)."
    let prefix = qmakeQuery(qmake, "QT_INSTALL_PREFIX")
    if "android_" in prefix and kitDir notin prefix:
      fail "--cpu:" & t.cpu & " needs the " & kitDir & " Qt kit, but QMAKE (" &
        qmake & ") is another Android ABI's kit.\n" & kitHint
    putEnv("ARCH", arch)
  # Dev-build scope: an unsigned debug APK. Release packaging (assembleRelease
  # needs STATUS_APP_KEYSTORE_PATH + friends) stays a make/CI concern; export
  # GRADLE_TARGETS yourself to override.
  if getEnv("GRADLE_TARGETS").len == 0:
    putEnv("GRADLE_TARGETS", "assembleDebug")

# --- delegation ---------------------------------------------------------------

# Defined with the develop-mode machinery below; app/run gate through it.
proc developModeMakeArgs(): string

proc ncpu(): string =
  let probe = if buildOS == "macosx": "sysctl -n hw.ncpu" else: "nproc"
  let (output, rc) = gorgeEx(probe)
  if rc == 0 and output.strip.len > 0: output.strip else: "4"

proc runMake(target: string, extraArgs = "") =
  exec "cd " & quoteShell(thisDir()) & " && make -j" & ncpu() & extraArgs &
    " " & target

# --- prl-to-pc, the executed consumer interface (issue 0015) ------------------
#
# prl-to-pc publishes `qt_pkgconfig.nims` at its package root and we EXECUTE it:
# `include`/`import` resolve at parse time while nimble.paths' --path switches
# only apply at script runtime, and the package root is a dynamic store path
# (`pkgs2/prl_to_pc-<version>-<checksum>`), so no config or driver script can
# ever name that file at parse time.
#
# Two calls per host build: `tools` (builds the wrapper + generator into the
# repo-local scratch — the store copy stays byte-identical) and `env`, whose
# output is cached in .prl-to-pc-build/qt-pkgconfig.env. config.nims replays
# that cache instead of forking a subprocess per nim invocation.
# qtPcBuildDir / qtPcEnvCache / qtPkgConfigKey come from status_env.nims.

proc nimEval(script: string): string =
  ## `nim e` on a foreign package's script. --skipParentCfg is mandatory: the
  ## script lives under this repo (develop checkout) or under the store, and
  ## Nim's parent-dir config walk would otherwise hand it THIS repo's
  ## config.nims — which reads the very cache we are about to write.
  quoteShell(getCurrentCompilerExe()) & " e --skipParentCfg:on --hints:off " &
    quoteShell(script)

proc nimblePathsStale(): bool =
  ## Same key make's setup stamp uses. The driver must know the resolution
  ## before it can locate prl-to-pc, but a full `make nimble-deps` costs a
  ## ~2.3 s Makefile parse, so gate it on an mtime scan (a few milliseconds).
  let paths = thisDir() / "nimble.paths"
  if not fileExists(paths):
    return true
  if hostOS == "windows":
    return false # `test -nt` is POSIX-shell only; the stamp still runs in make
  for input in ["nimble.lock", "nim_status_client.nimble", overlayFile,
                "vendor/status-go/statusgo.nimble"]:
    let p = thisDir() / input
    if fileExists(p):
      let (_, rc) = gorgeEx("test " & quoteShell(p) & " -nt " & quoteShell(paths))
      if rc == 0:
        return true

proc prlToPcScript(): string =
  ## Fails fast when prl-to-pc is unresolved, or resolved to a copy that
  ## predates the nimscript interface (i.e. an old pin).
  let root = prlToPcRoot()
  if root.len == 0:
    fail "prl-to-pc is not resolved yet (no prl_to_pc entry in nimble.paths)." &
      "\nRun `make nimble-deps` — or just re-run this command; it resolves" &
      " the graph itself on a fresh clone."
  result = root / "qt_pkgconfig.nims"
  if not fileExists(result):
    fail "the resolved prl-to-pc copy has no qt_pkgconfig.nims:\n  " & root &
      "\nThat interface arrived in prl-to-pc v0.3.0 (issue 0015). Bump the" &
      " prl-to-pc requires in nim_status_client.nimble, or `nim develop" &
      " status.nims prl-to-pc` onto a checkout that carries it."

proc prepareQtPkgconfig() =
  ## Build prl-to-pc's tools, then cache its `env` answer. Host targets only:
  ## the interim mobile make legs consume the same knowledge through
  ## <root>/qt-pkgconfig.mk, which the root Makefile still includes.
  if nimblePathsStale():
    runMake "nimble-deps"
  let script = prlToPcScript()
  let buildDir = thisDir() / qtPcBuildDir
  # prl-to-pc compiles its tools with `nim`; hand it the compiler that is
  # running this driver rather than whatever the caller's PATH holds.
  putEnv("QT_PC_NIM", getCurrentCompilerExe())
  exec nimEval(script) & " tools " & quoteShell(buildDir) & " " &
    quoteShell(thisDir() / "nimble.paths")

  let qmake = qmakeExe()
  let key = qtPkgConfigKey(qmake, prlToPcRoot(),
    qmakeQuery(qmake, "QT_INSTALL_PREFIX"))
  let cache = thisDir() / qtPcEnvCache
  if fileExists(cache) and ("\nkey=" & key & "\n") in readFile(cache):
    return
  let (output, rc) = gorgeEx(nimEval(script) & " env " & quoteShell(buildDir))
  if rc != 0:
    fail "prl-to-pc's `env` failed for this Qt kit:\n" & output
  # gorgeEx merges stderr into the output, so validate the shape rather than
  # caching whatever noise a future nim/config might print.
  for line in output.splitLines:
    let l = line.strip
    if l.len == 0: continue
    let i = l.find('=')
    if i <= 0 or l[0] notin {'A' .. 'Z'}:
      fail "prl-to-pc's `env` printed a line that is not KEY=VAL:\n  " & l &
        "\nFull output:\n" & output
  writeFile(cache,
    "# Qt pkg-config environment, printed by prl-to-pc's `qt_pkgconfig.nims" &
    " env`\n# and cached by `nim app status.nims` (issue 0015). Generated —" &
    " do not edit.\n" &
    "key=" & key & "\n" & output.strip & "\n")

task app, "Build the Status dev build: host by default, --os:ios / --os:android (+ --cpu) for mobile":
  let t = parseTarget()
  rejectExtras(t, "app")
  # Develop-mode gating (issue 0009): divergence guard + the FORCE arms for
  # developed vendors run before make takes over; default mode adds nothing.
  let devArgs = developModeMakeArgs()
  case t.os
  of "ios":
    validateIos(t)
    runMake "mobile-build", devArgs
  of "android":
    validateAndroid(t)
    runMake "mobile-build", devArgs
  else:
    validateHost(t)
    prepareQtPkgconfig()
    runMake "nim_status_client", devArgs

task buildArtifacts, "Build every artifact the client links/loads except the client compile itself (internal: nimble's before-build hook — issue 0013)":
  let t = parseTarget()
  rejectExtras(t, "buildArtifacts")
  if t.os != "host":
    fail "buildArtifacts is host-only (nimble build/run is the host front" &
      " door; mobile builds go through `nim app status.nims --os:...`)."
  validateHost(t)
  let devArgs = developModeMakeArgs()
  prepareQtPkgconfig()
  runMake "client-deps", devArgs

task run, "Build if needed and launch the host dev build (StatusDev.app on macOS)":
  let t = parseTarget()
  rejectExtras(t, "run")
  if t.os != "host":
    fail "'run' launches the host desktop build only; for mobile use" &
      " `make mobile-run` (a driver mobile run may come with issue 0009+)."
  validateHost(t)
  let devArgs = developModeMakeArgs()
  prepareQtPkgconfig()
  runMake "run", devArgs

task qtPkgconfigGenerate, "Regenerate the active Qt kit's committed .pc tree in a prl-to-pc develop checkout (never a build step; refuses on a store copy)":
  # The kit comes from QMAKE, not from --os: regenerating the iOS or Android
  # tree from a desktop host is exactly why a maintainer runs this.
  if taskArgv().len > 0:
    fail "'qtPkgconfigGenerate' takes no arguments; it regenerates the tree" &
      " for the kit QMAKE selects. Got: " & taskArgv().join(" ")
  let script = prlToPcScript()
  putEnv("QT_PC_NIM", getCurrentCompilerExe())
  exec nimEval(script) & " generate " & quoteShell(thisDir() / qtPcBuildDir) &
    " " & quoteShell(thisDir() / "nimble.paths")

# --- develop mode (issue 0009; mechanism: ADR 0004 nimble.paths overlay) -----
#
# Vendors stay pinned dependencies; `develop <vendor>` materializes a real git
# checkout under vendor/<name> and records it in the gitignored overlay file
# below. The overlay joins make's setup-stamp key, so the next build re-runs
# `nimble setup` and then `nim applyOverlay status.nims` (invoked from the
# stamp recipe) rewrites the developed vendor's entries in the generated
# nimble.paths to the checkout — derived copies (vendor/status-go/nimble.paths)
# inherit through the existing cmp-gated copy rules. Resolution still reads
# the PINNED manifest (ADR 0004's known limit): a diverging checkout manifest
# fails the build loudly (see guardDivergence) instead of drifting silently.

# overlayFile / readOverlay come from status_env.nims (shared with config.nims).

type VendorFlavor = enum
  vfNimbleGraph  # pinned URL#hash requires in the nimble graph; overlay rewrites nimble.paths
  vfCmake        # pinned FetchContent GIT_TAG; develop = FETCHCONTENT_SOURCE_DIR redirect (issue 0011)

type Vendor = object
  name: string          # `develop <name>` key (the package/project name; CONTEXT.md)
  flavor: VendorFlavor
  pinManifest: string   # repo-relative manifest that owns the pin (requires "URL#hash")
  repoName: string      # git repo basename the pin's requires points at (pin lookup key)
  pkgName: string       # nimble package name (identifies <store>/pkgs2/<pkg>-… entries)
  manifestName: string  # the vendor's own manifest: the divergence-compare target
  checkoutDir: string   # repo-relative develop checkout location
  developBranch: string # local branch created at the pin on a fresh clone
  srcDir: string        # manifest srcDir that store materialization HOISTS to the
                        # entry root ("" = none): the checkout keeps modules under
                        # this subdir, so the overlay rewrite must remap store
                        # roots onto <checkout>/<srcDir> (nimqml)
  clientRebuild: bool   # vendor Nim sources compile INTO nim_status_client → force a client rebuild while developed
  forceTouch: seq[string]  # files touched before every build while developed (make FORCE arm)
  forceRemove: seq[string] # artifact globs removed before every build while developed (make FORCE arm)
  flipRemove: seq[string]  # artifact globs removed ONCE per develop/undevelop flip: artifacts
                           # whose make prerequisites live under the vendor ROOT (checkout vs
                           # store), so a mode flip can leave them newer than the other mode's
                           # sources and mtime tracking alone would keep them stale (prl-to-pc
                           # wrapper/generator after undevelop of pushed edits)

# Rebuild gating while developed = ADR-0003's FORCE + compare-before-copy arm:
# the vendor sub-build runs every build (it owns incremental) and cmp-gated
# copies keep dependents from relinking on identical bytes.
const vendorTable = [
  Vendor(name: "statusgo", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "status-go",
    pkgName: "statusgo", manifestName: "statusgo.nimble",
    checkoutDir: "vendor/status-go", developBranch: "develop",
    # The status_go wrapper compiles into the client; libstatus has no real
    # make prerequisites, so removing it is what forces the sub-make (which
    # is internally incremental) to re-delegate.
    clientRebuild: true, forceTouch: @[],
    forceRemove: @["vendor/status-go/build/bin/libstatus.*"]),
  Vendor(name: "sds", flavor: vfNimbleGraph,
    pinManifest: "@statusgo/statusgo.nimble", repoName: "nim-sds",
    pkgName: "sds", manifestName: "sds.nimble",
    checkoutDir: "vendor/nim-sds", developBranch: "develop",
    # libsds is a shared library loaded at runtime — no client rebuild.
    # Touching the derived nimble.paths copy forces the $(NIMSDS_LIBFILE)
    # recipe (the statusgo.nims sds engine): an overlaid resolution builds the
    # checkout in place and cmp-mirrors artifacts into .sds-build/, the layout
    # every Makefile reads. "@statusgo/…" = inside the active statusgo root
    # (checkout while developed, scratch/store copy otherwise — issue 0010).
    clientRebuild: false, forceTouch: @["@statusgo/nimble.paths"],
    forceRemove: @[]),
  Vendor(name: "seaqt", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "nim-seaqt",
    pkgName: "seaqt", manifestName: "seaqt.nimble",
    # developBranch per the 0012 grill: the pin is the tip of upstream branch
    # smo-6.4 (the Status-specific generation, also tagged
    # qt-6.4-seaqt-gen-5bc1bc58…) — NOT the force-pushed qt-6.4 line.
    checkoutDir: "vendor/nim-seaqt", developBranch: "smo-6.4",
    # The generated bindings (and their C++ shims, via {.compile.}) build
    # INTO the client: REBUILD_NIM is the whole FORCE arm — no vendor
    # artifacts exist.
    clientRebuild: true, forceTouch: @[], forceRemove: @[]),
  Vendor(name: "nimqml", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "nimqml-seaqt",
    pkgName: "nimqml", manifestName: "nimqml.nimble",
    # The pin is an ancestor of upstream master (no other line exists).
    checkoutDir: "vendor/nimqml-seaqt", developBranch: "master",
    # Pure Nim compiled into the client, same FORCE arm as seaqt. srcDir:
    # store copies are hoisted (modules at the entry root), the checkout
    # keeps them under src/ — the overlay remaps accordingly.
    srcDir: "src",
    clientRebuild: true, forceTouch: @[], forceRemove: @[]),
  Vendor(name: "prl-to-pc", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "prl-to-pc",
    pkgName: "prl_to_pc", manifestName: "prl_to_pc.nimble",
    # developBranch main per the 0014 grill. Consumed as package-root FILES:
    # the driver executes <root>/qt_pkgconfig.nims every build (issue 0015)
    # and make still includes <root>/qt-pkgconfig.mk for the interim
    # mobile/nim-test legs — nothing nim-imports it, so a developed checkout
    # needs neither a client rebuild nor a per-build FORCE arm. A mode flip
    # changes the package root, which invalidates the cached `env` answer (its
    # key carries the root) and may change the tool sources; flipRemove drops
    # both artifacts so neither mode can ever consume the other's.
    checkoutDir: "vendor/prl-to-pc", developBranch: "main",
    clientRebuild: false, forceTouch: @[], forceRemove: @[],
    flipRemove: @[".prl-to-pc-build/.pcwrap/*",
                  ".prl-to-pc-build/.pcwrap/.*.key",
                  ".prl-to-pc-build/qt-pkgconfig.env"]),
  Vendor(name: "status-keycard-qt", flavor: vfCmake,
    pinManifest: "cmake/status-keycard-qt/CMakeLists.txt",
    repoName: "status-keycard-qt",
    pkgName: "", manifestName: "CMakeLists.txt",
    checkoutDir: "vendor/status-keycard-qt", developBranch: "develop",
    # A shared library loaded at runtime — no client rebuild. The make target
    # has no real prerequisites, so removing the built lib is what re-runs
    # cmake (the configure re-reads the overlay-derived FETCHCONTENT_SOURCE_
    # DIR_* redirect pair; the cmake build is internally incremental).
    clientRebuild: false, forceTouch: @[],
    forceRemove: @["build/status-keycard-qt/*/libstatus-keycard-qt.*"]),
  Vendor(name: "keycard-qt", flavor: vfCmake,
    pinManifest: "@keycard-parent",  # status-keycard-qt's own CMakeLists owns this pin
    repoName: "keycard-qt",
    pkgName: "", manifestName: "CMakeLists.txt",
    checkoutDir: "vendor/keycard-qt", developBranch: "develop",
    # Nested content, no parent cascade: edits rebuild THROUGH the parent's
    # cmake build (keycard-qt is compiled static and re-linked into
    # libstatus-keycard-qt), so the FORCE arm is the parent's artifact.
    clientRebuild: false, forceTouch: @[],
    forceRemove: @["build/status-keycard-qt/*/libstatus-keycard-qt.*"]),
]

proc vendorByName(name: string): Vendor =
  var known: seq[string]
  for v in vendorTable:
    if v.name == name:
      return v
    known.add v.name
  fail "unknown vendor '" & name & "' (known vendors: " & known.join(", ") & ")."

proc vendorRootIn(v: Vendor, entry: string): string =
  ## The vendor's package root inside a resolved nimble.paths entry
  ## ("" = the entry is not this vendor's). Matches both store copies
  ## (<store>/pkgs2/<pkg>-<version>-<checksum>[/srcdir]) and entries already
  ## pointing into the checkout (idempotent re-application; a develop-mode
  ## statusgo resolution).
  let checkoutAbs = thisDir() / v.checkoutDir
  if entry == checkoutAbs or entry.startsWith(checkoutAbs & $DirSep):
    return checkoutAbs
  let marker = DirSep & "pkgs2" & DirSep & v.pkgName & "-"
  let i = entry.find(marker)
  if i < 0 or i + marker.len >= entry.len or entry[i + marker.len] notin {'0' .. '9'}:
    return ""
  let rootEnd = entry.find(DirSep, start = i + marker.len)
  if rootEnd < 0: entry else: entry[0 ..< rootEnd]

# --- statusgo root resolution (issue 0010) -----------------------------------
#
# statusgo is a pinned URL#hash dependency: in default mode it resolves to a
# read-only store copy, and the build runs in a scratch copy of it at
# .statusgo-build (maintained by the prepareStatusgo task below). While
# developed (issue 0009) the vendor/status-go checkout is both. Anything that
# needs "the statusgo tree" must pick by mode, via these two views:
#   - the MANIFEST root (pin parsing, divergence baseline): store copy or
#     checkout — never the scratch (it may not exist yet).
#   - the BUILD root (nimble.paths beside statusgo.nims, artifacts under
#     build/bin): scratch copy or checkout.

# statusgoScratchDir / statusgoDeveloped / statusgoBuildRoot come from
# status_env.nims (shared with config.nims).

proc statusgoStoreRoot(): string =
  ## The statusgo store entry in the generated nimble.paths ("" when the
  ## resolution is absent or points at the checkout).
  let pathsFile = thisDir() / "nimble.paths"
  if not fileExists(pathsFile):
    return ""
  let sg = vendorByName("statusgo")
  for line in readFile(pathsFile).splitLines:
    const pre = "--path:\""
    if line.startsWith(pre) and line.endsWith("\""):
      let root = vendorRootIn(sg, line[pre.len .. ^2])
      if root.len > 0 and (DirSep & "pkgs2" & DirSep) in root:
        return root

proc statusgoManifestRoot(): string =
  ## Where statusgo.nimble (the sds pin owner) is read from.
  if statusgoDeveloped() and fileExists(thisDir() / "vendor/status-go/statusgo.nimble"):
    return thisDir() / "vendor/status-go"
  result = statusgoStoreRoot()
  if result.len == 0:
    # No resolution yet: fall back to a present checkout (fresh develop flip,
    # pre-first-build), else there is nothing to read from.
    if fileExists(thisDir() / "vendor/status-go/statusgo.nimble"):
      return thisDir() / "vendor/status-go"
    fail "statusgo is not resolved yet (no statusgo entry in nimble.paths" &
      " and no vendor/status-go checkout). Run `nim app status.nims` or" &
      " `make nimble-deps` first."

proc expandVendorPath(f: string): string =
  ## Vendor-table paths may address the active statusgo build root via the
  ## "@statusgo/" prefix; everything else is repo-relative.
  if f.startsWith("@statusgo/"):
    statusgoBuildRoot() / f["@statusgo/".len .. ^1]
  else:
    thisDir() / f

proc repoBasename(url: string): string =
  result = url.strip(chars = {'/'}, leading = false).rsplit('/', maxsplit = 1)[^1]
  if result.endsWith(".git"):
    result = result[0 .. ^5]

proc cmakePinManifestPath(v: Vendor): string =
  ## Where a cmake-flavor vendor's pin-owning CMakeLists lives. The sentinel
  ## "@keycard-parent" = status-keycard-qt's OWN CMakeLists (it owns the
  ## nested keycard-qt pin — issue 0011): the develop checkout when present,
  ## else the pinned sources FetchContent materialized under a build tree
  ## (_deps). Returns "" when no copy exists anywhere yet.
  if v.pinManifest != "@keycard-parent":
    return thisDir() / v.pinManifest
  let checkout = thisDir() / "vendor/status-keycard-qt/CMakeLists.txt"
  if fileExists(checkout):
    return checkout
  let (found, rc) = gorgeEx("ls " &
    thisDir() / "build/status-keycard-qt/*/_deps/status-keycard-qt-src/CMakeLists.txt" &
    " " &
    thisDir() / "mobile/build/*/qt*/status-keycard-qt/_deps/status-keycard-qt-src/CMakeLists.txt" &
    " 2>/dev/null")
  if rc == 0 and found.strip.len > 0:
    return found.strip.splitLines[0]

proc parseCmakePin(manifestPath: string, v: Vendor): tuple[url, rev: string] =
  ## FetchContent pins: the GIT_REPOSITORY whose repo basename matches
  ## v.repoName, and the GIT_TAG that follows it in the same declare block.
  var url = ""
  for rawLine in readFile(manifestPath).splitLines:
    let l = rawLine.strip
    if l.startsWith("GIT_REPOSITORY"):
      let u = l.splitWhitespace()[^1]
      url = if repoBasename(u) == v.repoName: u else: ""
    elif l.startsWith("GIT_TAG") and url.len > 0:
      return (url, l.splitWhitespace()[^1])
  fail "no FetchContent GIT_REPOSITORY/GIT_TAG pin for '" & v.repoName &
    "' found in " & manifestPath & " — the vendor table and the pin-owning" &
    " CMakeLists are out of sync."

proc pinOf(v: Vendor): tuple[url, rev: string] =
  ## The vendor's pin, parsed live from the owning manifest so a pin flip
  ## (e.g. issue 0010's statusgo file:// → URL#hash) needs no driver change.
  ## file:// pins return rev = "" (the checkout IS what resolution reads).
  if v.flavor == vfCmake:
    let mp = cmakePinManifestPath(v)
    if mp.len == 0:
      fail "keycard-qt's pin is owned by status-keycard-qt's CMakeLists, and" &
        " no copy of it exists yet (no vendor/status-keycard-qt checkout and" &
        " no fetched sources under build/status-keycard-qt/*/_deps). Run" &
        " `nim app status.nims` once (fetches the pinned sources), or" &
        " `nim develop status.nims status-keycard-qt`."
    return parseCmakePin(mp, v)
  let manifestPath =
    if v.pinManifest.startsWith("@statusgo/"):
      statusgoManifestRoot() / v.pinManifest["@statusgo/".len .. ^1]
    else:
      thisDir() / v.pinManifest
  for line in readFile(manifestPath).splitLines:
    let l = line.strip
    if not l.startsWith("requires"):
      continue
    # extract the quoted requirement spec(s) on the line
    var spec = ""
    var inQuote = false
    for c in l:
      if c == '"':
        if inQuote and spec.len > 0:
          let base = spec.split('#')[0].strip(chars = {'/'}, leading = false)
          var repo = base.rsplit('/', maxsplit = 1)[^1]
          if repo.endsWith(".git"):
            repo = repo[0 .. ^5]
          if repo == v.repoName:
            return (base, if '#' in spec: spec.split('#')[1] else: "")
          spec = ""
        inQuote = not inQuote
      elif inQuote:
        spec.add c
  fail "no requires line for '" & v.repoName & "' found in " & v.pinManifest &
    " — the vendor table and the pin-owning manifest are out of sync."

proc shortRev(rev: string): string =
  ## Abbreviate #hash pins for messages; #branch pins pass through.
  rev[0 ..< min(8, rev.len)]

proc writeOverlay(names: seq[string]) =
  ## The file stays in place once created (even with no entries): it is a
  ## $(wildcard) prerequisite of make's setup stamp, so rewriting it is what
  ## invalidates the stamp and schedules regeneration + overlay application.
  var content = "# Vendors in develop mode (one per line) — managed by\n" &
    "# `nim develop status.nims <vendor>` / `nim undevelop status.nims <vendor>`.\n"
  for n in names:
    content &= n & "\n"
  writeFile(thisDir() / overlayFile, content)

proc rewriteEntries(content: string, v: Vendor): tuple[content: string, matched: int] =
  ## Rewrites the vendor's path entries in nimble.paths content to the
  ## checkout, preserving every other line byte-for-byte.
  let checkoutAbs = thisDir() / v.checkoutDir
  var lines: seq[string]
  for line in content.splitLines:
    const pre = "--path:\""
    if line.startsWith(pre) and line.endsWith("\""):
      let p = line[pre.len .. ^2]
      let root = vendorRootIn(v, p)
      if root.len > 0:
        inc result.matched
        var rest = p[root.len .. ^1]
        # srcDir-hoisted store copies (nimqml): the store entry root IS the
        # module root, but the checkout keeps modules under <srcDir> — remap
        # the bare root onto it. (The warm-setup "<root>/src" variant already
        # carries the right suffix and passes through; idempotent either way.)
        if v.srcDir.len > 0 and rest.len == 0:
          rest = $DirSep & v.srcDir
        lines.add pre & checkoutAbs & rest & "\""
        continue
    lines.add line
  result.content = lines.join("\n")

proc pinnedManifestContent(v: Vendor, rev: string): string =
  ## The vendor manifest at the pinned revision, read from the checkout's own
  ## git history — byte-identical to what `nimble setup` materialized in the
  ## store (resolution reads THIS, not the checkout's working tree; ADR 0004).
  let cmd = "git -C " & quoteShell(thisDir() / v.checkoutDir) & " show " &
    quoteShell(rev & ":" & v.manifestName)
  let (output, rc) = gorgeEx(cmd)
  if rc != 0:
    fail "cannot read the pinned manifest of developed vendor '" & v.name &
      "':\n  " & cmd & "\nfailed with:\n" & output &
      "\nIs the pinned revision still in the checkout's history?"
  output

proc guardDivergence(v: Vendor, rev: string) =
  ## ADR 0004's one forbidden failure mode is silent drift: dependency
  ## resolution reads the PINNED manifest, so a checkout whose own manifest
  ## diverged must fail the build loudly, with the escape hatch spelled out.
  if v.flavor == vfCmake:
    # The FETCHCONTENT_SOURCE_DIR redirect makes cmake read the checkout's
    # own CMakeLists — build-config edits (incl. nested pins) TAKE effect,
    # so the silent-drift mode this guard exists for cannot occur.
    return
  if rev.len == 0:
    # Interim file:// pin (statusgo until issue 0010): resolution already
    # reads the checkout's manifest itself — nothing to diverge from.
    return
  let checkoutManifest = thisDir() / v.checkoutDir / v.manifestName
  if not fileExists(checkoutManifest):
    fail "developed vendor '" & v.name & "' has no " & v.manifestName &
      " in its checkout (" & v.checkoutDir & ") — not a " & v.name & " checkout?"
  if readFile(checkoutManifest).strip == pinnedManifestContent(v, rev).strip:
    return
  fail "developed vendor '" & v.name & "' has a DIVERGED manifest.\n\n" &
    v.checkoutDir & "/" & v.manifestName & " no longer matches the pinned" &
    " revision " & shortRev(rev) & " — but dependency resolution reads the" &
    " PINNED manifest, not the checkout's (ADR 0004), so requires-edits in" &
    " the checkout would NOT take effect and the build would drift silently." &
    "\n\nEither revert the manifest edit:\n" &
    "  git -C " & v.checkoutDir & " diff " & shortRev(rev) & " -- " & v.manifestName & "\n" &
    "  git -C " & v.checkoutDir & " checkout " & shortRev(rev) & " -- " & v.manifestName & "\n" &
    "or use the file:// escape hatch (machine-local manifest edit; restore" &
    " the pin before shipping):\n" &
    "  1. In " & v.pinManifest & " replace the '" & v.repoName & "' URL#hash" &
    " requires with:\n" &
    "       requires \"file://" & thisDir() / v.checkoutDir & "\"\n" &
    "     (ABSOLUTE path — relative file:// silently drops the package).\n" &
    "  2. Mind the nimble 0.22.3 walls (vendor/status-go/AGENTS.md): a" &
    " sibling URL#hash requires in the SAME manifest makes BOTH vanish from" &
    " the resolution (disable siblings while flipped), and file:// requires" &
    " are only legal at top level or inside file://-reached packages (chains" &
    " of file:// are fine).\n" &
    "  3. Build (nimble then resolves the checkout with ITS manifest), and" &
    " restore the pinned URL before committing."

proc overlayApplied(v: Vendor): bool =
  ## True when the generated nimble.paths no longer carries store entries for
  ## the vendor (i.e. the overlay rewrite took effect). A manual `nimble
  ## setup` outside make regenerates the file WITHOUT the overlay — the
  ## driver detects that here and re-invalidates the stamp.
  if v.flavor == vfCmake:
    # cmake vendors are not in the nimble graph: their redirect is re-derived
    # from the overlay by every vendor-recipe configure, never from nimble.paths.
    return true
  let pathsFile = thisDir() / "nimble.paths"
  if not fileExists(pathsFile):
    return true # no resolution yet — the stamp recipe will generate + apply
  for line in readFile(pathsFile).splitLines:
    const pre = "--path:\""
    if line.startsWith(pre) and line.endsWith("\""):
      let p = line[pre.len .. ^2]
      let root = vendorRootIn(v, p)
      if root.len > 0 and root != thisDir() / v.checkoutDir:
        return false
  true

proc developModeMakeArgs(): string =
  ## Pre-delegation develop-mode work for `app`/`run`: the divergence guard,
  ## stamp re-invalidation when a manual `nimble setup` dropped the overlay,
  ## and the per-vendor FORCE arms. Returns extra make arguments.
  let devs = readOverlay()
  if devs.len == 0:
    return ""
  var clientRebuild = false
  for name in devs:
    let v = vendorByName(name)
    if not dirExists(thisDir() / v.checkoutDir):
      fail "vendor '" & v.name & "' is in develop mode but its checkout (" &
        v.checkoutDir & ") is missing. Run `nim develop status.nims " &
        v.name & "` to re-materialize it, or `nim undevelop status.nims " &
        v.name & " --force` to return to the pin."
    if v.flavor == vfNimbleGraph:
      let (_, rev) = pinOf(v)
      guardDivergence(v, rev)
      if not overlayApplied(v):
        # nimble.paths was regenerated without the overlay (manual `nimble
        # setup`); make the overlay file newer than it so the stamp recipe
        # re-runs setup + applyOverlay.
        exec "touch " & quoteShell(thisDir() / overlayFile)
    for f in v.forceTouch:
      let p = expandVendorPath(f)
      if fileExists(p):
        exec "touch " & quoteShell(p)
    for g in v.forceRemove:
      exec "rm -f " & expandVendorPath(g)
    if v.clientRebuild:
      clientRebuild = true
  if clientRebuild: " REBUILD_NIM=true" else: ""

proc invalidateOnModeFlip(v: Vendor) =
  ## Mode flips move a clientRebuild vendor's artifact dir (pinned scratch ↔
  ## checkout), and the desktop client bakes that dir as an rpath at link
  ## time — an existing binary would keep loading the OTHER mode's library.
  ## Dropping the binary forces a relink on the next build (the make rule has
  ## no prerequisite that tracks the artifact dir).
  if v.clientRebuild:
    exec "rm -f " & quoteShell(thisDir() / "bin" / "nim_status_client")
  if v.flavor == vfCmake:
    # The vendor recipe only runs when its lib is missing, and the redirect
    # is a configure-time value: drop the artifacts so the NEXT build
    # reconfigures with the new mode's FETCHCONTENT_SOURCE_DIR_* values
    # (undevelop especially — nothing else would re-run the recipe).
    for g in v.forceRemove:
      exec "rm -f " & expandVendorPath(g)
  for g in v.flipRemove:
    exec "rm -f " & expandVendorPath(g)

proc gitOut(dir, args: string): string =
  let (output, rc) = gorgeEx("git -C " & quoteShell(dir) & " " & args)
  if rc != 0:
    fail "git -C " & dir & " " & args & " failed:\n" & output
  output.strip

proc developArgv(taskName: string, allowForce = false): tuple[vendor: string, force: bool] =
  for p in taskArgv():
    if allowForce and p == "--force":
      result.force = true
    elif p.startsWith("-"):
      fail "unrecognized flag for '" & taskName & "': " & p &
        (if allowForce: " (only --force is accepted)." else: ".")
    elif result.vendor.len == 0:
      result.vendor = p
    else:
      fail "'" & taskName & "' takes exactly one vendor name (got '" &
        result.vendor & "' and '" & p & "')."
  if result.vendor.len == 0:
    var known: seq[string]
    for v in vendorTable:
      known.add v.name
    fail "usage: nim " & taskName & " status.nims <vendor>" &
      (if allowForce: " [--force]" else: "") &
      "\nKnown vendors: " & known.join(", ")

task develop, "Materialize a vendor as an editable checkout and switch the build to it":
  let (name, _) = developArgv("develop")
  let v = vendorByName(name)
  let (url, rev) = pinOf(v)
  let checkoutAbs = thisDir() / v.checkoutDir
  if dirExists(checkoutAbs):
    # An existing checkout is NEVER clobbered — whatever state it carries is
    # the developer's; develop just flips the overlay to it.
    if not dirExists(checkoutAbs / ".git") and not fileExists(checkoutAbs / ".git"):
      fail v.checkoutDir & " exists but is not a git checkout — move it away" &
        " or delete it, then re-run develop to clone the pin."
    let head = gitOut(checkoutAbs, "rev-parse --short HEAD")
    echo "develop: reusing the existing checkout at " & v.checkoutDir &
      " (HEAD " & head & (if rev.len > 0 and not rev.startsWith(head): "; pin " &
      shortRev(rev) else: "") & ") — never clobbered."
  else:
    if rev.len == 0:
      fail v.name & " is pinned by a local file:// path (" & url &
        ") but that directory is missing — the interim pin expects the" &
        " checkout to exist (git submodule update --init?)."
    echo "develop: cloning " & url & " into " & v.checkoutDir & " …"
    exec "git clone " & quoteShell(url) & " " & quoteShell(checkoutAbs)
    # A branch at the pinned revision (detached HEAD is hostile to the
    # commit/push/PR workflow develop mode exists for). -B: on a fresh clone
    # the only local branch is the remote default — repointing it is safe.
    exec "git -C " & quoteShell(checkoutAbs) & " checkout -B " &
      quoteShell(v.developBranch) & " " & quoteShell(rev)
  if v.flavor == vfNimbleGraph and rev.len > 0 and
      fileExists(checkoutAbs / v.manifestName) and
      readFile(checkoutAbs / v.manifestName).strip != pinnedManifestContent(v, rev).strip:
    echo "develop: WARNING — " & v.checkoutDir & "/" & v.manifestName &
      " already diverges from the pinned revision; the next build will fail" &
      " with the escape-hatch instructions (ADR 0004 divergence guard)."
  var devs = readOverlay()
  if v.name in devs:
    echo "develop: '" & v.name & "' is already in develop mode (overlay: " &
      overlayFile & "); nothing to change."
  else:
    devs.add v.name
    writeOverlay devs # invalidates the setup stamp (overlay joins its key)
    invalidateOnModeFlip v
    echo "develop: '" & v.name & "' recorded in " & overlayFile & "."
  if v.flavor == vfCmake:
    echo "develop: the next `nim app status.nims` redirects the '" & v.name &
      "' FetchContent to " & v.checkoutDir & " and rebuilds it every build."
  else:
    echo "develop: the next `nim app status.nims` re-resolves (nimble setup)," &
      " applies the overlay, and builds from " & v.checkoutDir & "."

task undevelop, "Return a developed vendor to its pin (--force to skip the dirty/unpushed checks)":
  let (name, force) = developArgv("undevelop", allowForce = true)
  let v = vendorByName(name)
  var devs = readOverlay()
  if v.name notin devs:
    echo "undevelop: '" & v.name & "' is not in develop mode; nothing to do."
  else:
    let checkoutAbs = thisDir() / v.checkoutDir
    if dirExists(checkoutAbs) and not force:
      # Exiting develop mode must never lose work: refuse while the checkout
      # has uncommitted changes or commits no remote knows about.
      let dirty = gitOut(checkoutAbs, "status --porcelain")
      if dirty.len > 0:
        fail "the " & v.name & " checkout (" & v.checkoutDir & ") has" &
          " UNCOMMITTED changes:\n" & dirty & "\nCommit or stash them" &
          " (the checkout stays in place either way), or re-run with" &
          " --force to exit develop mode anyway (your files are kept," &
          " just no longer built)."
      let unpushed = gitOut(checkoutAbs,
        "log --branches --not --remotes --oneline")
      if unpushed.len > 0:
        fail "the " & v.name & " checkout (" & v.checkoutDir & ") has" &
          " UNPUSHED commits:\n" & unpushed & "\nPush them, or re-run with" &
          " --force to exit develop mode anyway (the commits stay in the" &
          " checkout's git history; the checkout dir is left in place)."
    var kept: seq[string]
    for n in devs:
      if n != v.name:
        kept.add n
    writeOverlay kept # invalidates the setup stamp → pin resolution returns
    invalidateOnModeFlip v
    echo "undevelop: '" & v.name & "' returned to its pin. The checkout at " &
      v.checkoutDir & " is left in place (inert; delete it whenever you like)."
    echo "undevelop: the next `nim app status.nims` re-resolves and builds" &
      " from the pinned copy again."

task vendors, "List vendors: pin, flavor, and develop state":
  let t = parseTarget()
  rejectExtras(t, "vendors")
  let devs = readOverlay()
  for v in vendorTable:
    var url = ""
    var rev = ""
    var pinUnavailable = false
    if v.flavor == vfCmake and cmakePinManifestPath(v).len == 0:
      # keycard-qt's pin owner (status-keycard-qt's CMakeLists) is not
      # materialized anywhere yet — don't fail the whole listing over it.
      pinUnavailable = true
    else:
      let pin = pinOf(v)
      url = pin.url
      rev = pin.rev
    var state = if v.name in devs: "develop" else: "default"
    if v.name in devs and not overlayApplied(v):
      state &= " (overlay pending — applied by the next build)"
    var checkout = "no checkout"
    let checkoutAbs = thisDir() / v.checkoutDir
    if dirExists(checkoutAbs):
      let (head, rc) = gorgeEx("git -C " & quoteShell(checkoutAbs) &
        " rev-parse --short HEAD")
      let (dirty, _) = gorgeEx("git -C " & quoteShell(checkoutAbs) &
        " status --porcelain")
      checkout = v.checkoutDir & (if rc == 0: " @ " & head.strip else: "") &
        (if dirty.strip.len > 0: " (dirty)" else: " (clean)")
    echo v.name & "  [" & (if v.flavor == vfNimbleGraph: "nimble-graph" else: "cmake") &
      ", " & state & "]"
    if pinUnavailable:
      echo "  pin:      owned by status-keycard-qt's CMakeLists — visible" &
        " after the first build (or `develop status-keycard-qt`)"
    else:
      echo "  pin:      " & url & (if rev.len > 0: "#" & rev else: " (interim local pin)")
    echo "  checkout: " & checkout

task applyOverlay, "Apply the develop-mode overlay to the generated nimble.paths (internal: make's setup-stamp recipe runs this after every `nimble setup`)":
  let devs = readOverlay()
  if devs.len > 0:
    let pathsFile = thisDir() / "nimble.paths"
    if not fileExists(pathsFile):
      fail "nimble.paths does not exist — applyOverlay must run right after" &
        " `nimble setup` (make nimble-deps does this)."
    let before = readFile(pathsFile)
    var content = before
    for name in devs:
      let v = vendorByName(name)
      if not dirExists(thisDir() / v.checkoutDir):
        fail "vendor '" & v.name & "' is in develop mode but its checkout (" &
          v.checkoutDir & ") is missing. Run `nim develop status.nims " &
          v.name & "` to re-materialize it, or `nim undevelop status.nims " &
          v.name & " --force` to return to the pin."
      if v.flavor == vfCmake:
        # Not in the nimble graph: nothing to rewrite in nimble.paths — the
        # redirect is applied by the vendor recipe's cmake configure instead.
        continue
      let (_, rev) = pinOf(v)
      guardDivergence(v, rev)
      let (rewritten, matched) = rewriteEntries(content, v)
      if matched == 0:
        fail "the generated nimble.paths has no entries for developed" &
          " vendor '" & v.name & "' — the resolution does not include it" &
          " (stale store? run `make nimble-deps` after wiping nimble.paths)."
      content = rewritten
      echo "applyOverlay: " & v.name & " → " & v.checkoutDir &
        " (" & $matched & " path entr" & (if matched == 1: "y" else: "ies") & ")"
    if content != before:
      writeFile(pathsFile, content)

# --- pinned statusgo scratch engine (issue 0010) ------------------------------
#
# Default mode resolves statusgo to a READ-ONLY store copy; libstatus/libsds
# builds need a writable tree (nimble.paths beside statusgo.nims, .sds-build,
# build/bin, go generate outputs). prepareStatusgo maintains that tree at
# .statusgo-build: wiped and re-copied only when the resolved store path or
# the caller's artifact key changes — this IS the pinned-mode rebuild stamp
# (store path ⊃ pin revision + manifest checksum; the platform sentinel covers
# target-triple flips; --key carries the flag set). While the scratch is
# up-to-date and artifacts exist, the Makefiles skip the status-go sub-make
# entirely (the stamp-skip default arm; ADR 0004). Developed statusgo keeps
# ADR 0003's FORCE + compare-before-copy semantics in the checkout instead.

task prepareStatusgo, "Maintain the pinned-statusgo scratch copy (.statusgo-build) — internal: make runs this before statusgo builds":
  var key = ""
  for p in taskArgv():
    let k = flagVal(p, "key")
    if k.len > 0:
      key = k
  if statusgoDeveloped():
    echo "prepareStatusgo: statusgo is developed — building the checkout, no scratch."
  else:
    let storeRoot = statusgoStoreRoot()
    if storeRoot.len == 0:
      fail "statusgo has no store entry in nimble.paths — run `make" &
        " nimble-deps` (or `nim app status.nims`) so the resolution exists" &
        " before building."
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
      # Store trees can be read-only; the build writes into the copy.
      exec "chmod -R u+w " & quoteShell(scratch)
      writeFile(originFile, storeRoot)
      if key.len > 0:
        writeFile(keyFile, key)
    elif key.len > 0 and (not fileExists(keyFile) or readFile(keyFile) != key):
      # Same pin, different build-flag set (e.g. desktop debug flip, another
      # mobile SDK): drop the artifacts and FORCE dependents by touching the
      # scratch nimble.paths (prereq of the sds engine and, via cmp-copies,
      # of the mobile status-go rule) — the sub-makes then rebuild in place.
      echo "prepareStatusgo: build flags changed (" & key & ") — dropping artifacts"
      exec "rm -f " & scratch / "build" / "bin" / "libstatus.*"
      if fileExists(scratch / "nimble.paths"):
        exec "touch " & quoteShell(scratch / "nimble.paths")
      writeFile(keyFile, key)
    else:
      echo "prepareStatusgo: scratch up-to-date (pin unchanged)"
