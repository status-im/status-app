# status.nims — one command from a clean clone to a runnable Status dev build.
#
#   ./status app                            # host desktop dev build
#   ./status app --force                    # ... and recompile the client
#   ./status app --os:ios --cpu:arm64       # signed iOS device app
#   ./status app --os:android --cpu:arm64   # Android debug APK
#   ./status run                            # host build if needed + launch
#   ./status tests [<test name>]            # the Nim test suite
#   ./status windowsLauncher                # bin/nim_windows_launcher.exe
#   ./status help                           # list tasks
#
# `./status` is the launcher: it resolves the nimble graph when it has to,
# asks `nimble path nim` for the compiler that resolution names and execs it
# on this file. Nothing is sourced and PATH is never rewritten.
#
# --os/--cpu select the TARGET (host is the default). Kit selection is
# environment-driven — QMAKE, IPHONE_SDK, QMAKE_DEVELOPMENT_TEAM,
# ANDROID_SDK_ROOT, ANDROID_NDK_ROOT, ARCH — and validated per target before
# any build starts. Place the flags AFTER the file name: there nim forwards
# them to the task untouched; before it nim consumes them and also re-targets
# its own evaluation of this script.
#
# The host desktop build runs no make: the driver bootstraps (submodules, brew
# bottles), resolves the nimble graph, builds every artifact the client links
# or loads (status_artifacts.nims) and compiles the client itself. make drives
# the mobile legs, packaging, CI helpers and status-go's own vendored Makefile.
#
# The driver owns every Nim compile: the client, the Nim test suite and the
# Windows launcher. The root Makefile invokes no `nim c` / `nim e`.
#
# A nimscript driver, not a nimble task: `nimble <task>` re-pays tens of
# seconds of graph revalidation per warm invocation on this manifest;
# `./status <task>` starts in about a second.

import std/[os, strutils]

# qmake lookup and develop-overlay parsing live in status_env.nims, so
# config.nims derives the same values the driver validates.
include "status_env.nims"

# --- invocation parsing ------------------------------------------------------

proc fail(msg: string) =
  quit("\nstatus.nims ERROR: " & msg, 1)

proc argvAll(): seq[string] =
  ## Full process argv minus the nim binary: nimscript has no
  ## commandLineParams(), and paramStr covers the whole nim command line.
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
  force: bool         # --force: rebuild the client even when its key is fresh
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
  # --os/--cpu are honored wherever they appear on the nim command line: nim
  # consumes the ones before the file name, but they stay visible in argv.
  # Everything else after the file name is an unrecognized argument.
  for p in argvAll():
    let osv = flagVal(p, "os")
    let cpuv = flagVal(p, "cpu")
    if osv.len > 0:
      result.os = osv.toLowerAscii
    elif cpuv.len > 0:
      result.cpu = normalizedCpu(cpuv)
  for p in taskArgv():
    if p == "--force":
      result.force = true
    elif p.len > 0 and flagVal(p, "os").len == 0 and flagVal(p, "cpu").len == 0:
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

proc rejectExtras(t: Target, taskName: string, allowForce = false) =
  if t.force and not allowForce:
    fail "'" & taskName & "' does not accept --force (only 'app' and 'run'" &
      " do — it forces the client compile)."
  if t.extra.len > 0:
    fail "unrecognized arguments for '" & taskName & "': " &
      t.extra.join(" ") & "\nOnly --os:<ios|android>, --cpu:<cpu>" &
      (if allowForce: " and --force" else: "") & " are accepted."

# --- kit-environment validation (fail fast, name the exact variables) --------
# kitHint / qmakeExe / qmakeQuery come from status_env.nims (shared with
# config.nims).

proc requireXspec(t: Target, expected, kitName: string): string =
  ## Returns the validated qmake path. The target OS follows the QMAKE kit's
  ## XSPEC, so a kit/--os mismatch must die here: with the wrong kit the build
  ## targets the wrong platform into shared build dirs.
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
  # plus STATUS_APP_KEYSTORE_PATH and friends) is a make/CI concern; export
  # GRADLE_TARGETS to override.
  if getEnv("GRADLE_TARGETS").len == 0:
    putEnv("GRADLE_TARGETS", "assembleDebug")

# --- delegation ---------------------------------------------------------------
#
# Only the mobile legs delegate to make.

# Defined further down; status_artifacts.nims and the tasks call into them.
proc applyDevelopModeArms(): bool
proc statusgoStoreRoot(): string
proc statusgoSourceRoot(): string
proc applyOverlayNow()

proc ncpu(): string =
  let probe = if buildOS == "macosx": "sysctl -n hw.ncpu" else: "nproc"
  let (output, rc) = gorgeEx(probe)
  if rc == 0 and output.strip.len > 0: output.strip else: "4"

proc runMake(target: string, extraArgs = "") =
  exec "cd " & quoteShell(thisDir()) & " && make -j" & ncpu() & extraArgs &
    " " & target

# --- prl-to-pc, the executed consumer interface ------------------
#
# prl-to-pc publishes `qt_pkgconfig.nims` at its package root and the driver
# EXECUTES it: include/import resolve at parse time while nimble.paths' --path
# switches apply only at script runtime, and the package root is a dynamic
# store path (`pkgs2/prl_to_pc-<version>-<checksum>`), so no config or driver
# script can name that file at parse time.
#
# Two calls per host build: `tools` (builds the wrapper + generator into the
# repo-local scratch) and `env`, whose output is cached in
# .prl-to-pc-build/qt-pkgconfig.env; config.nims replays that cache instead of
# forking a subprocess per nim invocation.

proc nimExe(): string =
  ## The Nim compiler to hand to anything this driver shells out to. This file
  ## is both a `nim <task> status.nims` driver and (via the manifest's
  ## `include "status.nims"`) a nimble task script, and the two contexts
  ## disagree: under nimble, getCurrentCompilerExe() is nimble's evaluator, not
  ## the pinned compiler, while the pinned `<store>/pkgs2/nim-<ver>-…/bin` is
  ## injected onto PATH for tasks and hooks. `--define:NimbleVersion=…` is the
  ## discriminator. selfExe()/querySetting(libPath) name the evaluator in both
  ## contexts and must not be used here.
  result = getEnv("STATUS_NIM")
  if result.len > 0:
    return
  when defined(NimbleVersion):
    result = findExe("nim")
    if result.len > 0:
      return
  result = getCurrentCompilerExe()
  if result.len == 0:
    result = findExe("nim")
  if result.len == 0:
    fail "no Nim compiler found: neither STATUS_NIM, nor the running" &
      " compiler, nor `nim` on PATH."

proc nimEval(script: string): string =
  ## `nim e` on a foreign package's script. --skipParentCfg is mandatory:
  ## Nim's parent-dir config walk would otherwise hand the script THIS repo's
  ## config.nims, which reads the very cache the script is about to write.
  quoteShell(nimExe()) & " e --skipParentCfg:on --hints:off " &
    quoteShell(script)

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
      "\nThat interface arrived in prl-to-pc v0.3.0. Bump the" &
      " prl-to-pc requires in nim_status_client.nimble, or `nim develop" &
      " status.nims prl-to-pc` onto a checkout that carries it."

proc prepareQtPkgconfig() =
  ## Build prl-to-pc's tools, then cache its `env` answer. Host targets only:
  ## the mobile make legs read the same knowledge from <root>/qt-pkgconfig.mk.
  ## Callers must have resolved the graph first (nimbleSetupIfStale): the
  ## package root is read from the generated nimble.paths.
  let script = prlToPcScript()
  let buildDir = thisDir() / qtPcBuildDir
  # prl-to-pc compiles its tools with `nim`: hand it the compiler running this
  # driver, not whatever the caller's PATH holds.
  putEnv("QT_PC_NIM", nimExe())
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
  # A System-mode kit (.pc files usable as shipped) builds no tools, so `tools`
  # above never created the scratch dir the cache lives in. Create it here,
  # whichever mode ran.
  mkDir cache.parentDir
  writeFile(cache,
    "# Qt pkg-config environment, printed by prl-to-pc's `qt_pkgconfig.nims" &
    " env`\n# and cached by `./status app`. Generated —" &
    " do not edit.\n" &
    "key=" & key & "\n" & output.strip & "\n")

# The artifact engine: one procedure per artifact, the generic cmake
# procedure, and the two gating patterns. Included here because it uses
# fail/nimExe/ncpu/prepareQtPkgconfig above and is used by the tasks below.
# Never included by config.nims (its header explains why).
include "status_artifacts.nims"

proc launchHostApp(args: string) =
  ## Launch the host dev build. The binary bakes every @rpath it needs, so the
  ## library paths below only cover a partially relinked tree.
  let bin = clientBinary()
  var libPath = ""
  for d in [qtProp("QT_INSTALL_LIBS"), nimsdsLibDir(), statusgoLibDir(),
            keycardLibDir(), thisDir() / "bin/StatusQ", statusqBuildPath() / "lib"]:
    libPath &= d & ":"
  if hostOS == "windows":
    # Windows has no rpath: the loader searches the .exe's own directory, so
    # every shared library the client links must be staged next to it.
    echo "\e[92mStaging:\e[39m bin/ (Windows has no rpath)"
    let binDir = thisDir() / "bin"
    exec "cp -f -R " & quoteShell(statusqBuildPath() / "bin" / buildType()) & "/* " &
      quoteShell(binDir) & "/"
    for f in [statusgoLibDir() / "libstatus.dll",
              keycardLibDir() / "status-keycard-qt.dll",
              nimsdsLibDir() / "libsds.dll"]:
      exec "cp -f " & quoteShell(f) & " " & quoteShell(binDir) & "/"
    # The MSVC/UCRT runtime the clang-cl-built client needs, from the system
    # (msys2 mounts C:\ at /c). `api-ms-win-crt-*` is a glob: no quoteShell.
    for f in ["/c/Windows/System32/ucrtbase.dll",
              "/c/Windows/System32/vcruntime140.dll",
              "/c/Windows/System32/vcruntime140_1.dll",
              "/c/Windows/System32/downlevel/api-ms-win-crt-*.dll"]:
      exec "cp -f " & f & " " & quoteShell(binDir) & "/"
    echo "\e[92mRunning:\e[39m bin/nim_status_client.exe"
    exec "cd " & quoteShell(binDir) & " && ./nim_status_client.exe " & args
  elif hostOS == "macosx":
    let contents = thisDir() / "bin/StatusDev.app/Contents"
    mkDir contents / "MacOS"
    mkDir contents / "Resources"
    cpFile(thisDir() / "Info.dev.plist", contents / "Info.plist")
    cpFile(thisDir() / "status-dev.icns", contents / "Resources/status-dev.icns")
    cpFile(thisDir() / "resources/macos/dev/Assets.car", contents / "Resources/Assets.car")
    cpFile(thisDir() / "resources.rcc", contents / "resources.rcc")
    # The monitoring tool loads MONITORING_QML_ENTRY_POINT="/../monitoring/Main.qml"
    # relative to the app binary dir (Contents/MacOS -> Contents/monitoring).
    if getEnv("MONITORING", "false") != "false":
      rmDir contents / "monitoring"
      cpDir thisDir() / "monitoring", contents / "monitoring"
    exec "cd " & quoteShell(contents / "MacOS") & " && ln -fs ../../../nim_status_client ./"
    # `fileicon` is a nicety, not a build input.
    exec "fileicon set " & quoteShell(bin) & " " &
      quoteShell(thisDir() / "status-dev.icns") & " || true"
    echo "\e[92mRunning:\e[39m bin/StatusDev.app/Contents/MacOS/nim_status_client"
    exec "DYLD_LIBRARY_PATH=" & quoteShell(libPath & getEnv("DYLD_LIBRARY_PATH")) &
      " " & quoteShell(contents / "MacOS/nim_status_client") & " " & args
  else:
    echo "\e[92mRunning:\e[39m bin/nim_status_client"
    exec "LD_LIBRARY_PATH=" & quoteShell(libPath & getEnv("LD_LIBRARY_PATH")) &
      " " & quoteShell(bin) & " " & args

task app, "Build the Status dev build: host by default, --os:ios / --os:android (+ --cpu) for mobile; --force recompiles the client":
  let t = parseTarget()
  rejectExtras(t, "app", allowForce = true)
  # Nothing in the mobile legs can honor --force, so they reject it. The check
  # must precede applyDevelopModeArms(): that proc mutates the tree (FORCE
  # arms), and a rejected invocation must change nothing.
  if t.force and t.os in ["ios", "android"]:
    fail "'app --os:" & t.os & "' does not accept --force: nothing in the" &
      " mobile leg can honor it.\nmobile/Makefile's client rule is" &
      " prerequisite-driven (STATUS_DESKTOP_NIM_FILES), so an edited source" &
      " rebuilds by itself; a FORCED mobile rebuild is\n" &
      "  make -C mobile clean-nim-status-client\n" &
      "There is no mobile force arm."
  let force = applyDevelopModeArms() or t.force
  case t.os
  of "ios", "android":
    if t.os == "ios": validateIos(t) else: validateAndroid(t)
    if force:
      # A developed vendor whose Nim sources compile into the client sets
      # `force` too; that arm is not user-supplied, so it is reported.
      echo "note: a developed vendor forces a client rebuild on the host leg;" &
        " the mobile leg rebuilds from mobile/Makefile's prerequisites instead."
    runMake "mobile-build"
  else:
    validateHost(t)
    buildHostArtifacts()
    buildClient(force)

task buildArtifacts, "Build every artifact the client links/loads except the client compile itself (internal: nimble's before-build hook)":
  let t = parseTarget()
  # --force forces the CLIENT compile, and this task never compiles the client
  # (nimble's own bin compile follows this hook).
  rejectExtras(t, "buildArtifacts")
  if t.os != "host":
    fail "buildArtifacts is host-only (nimble build/run is the host front" &
      " door; mobile builds go through `./status app --os:...`)."
  validateHost(t)
  discard applyDevelopModeArms()  # divergence guard + FORCE arms
  buildHostArtifacts()

task run, "Build if needed and launch the host dev build (StatusDev.app on macOS); --force recompiles the client":
  let t = parseTarget()
  rejectExtras(t, "run", allowForce = true)
  if t.os != "host":
    fail "'run' launches the host desktop build only; for mobile use" &
      " `make mobile-run`."
  validateHost(t)
  let force = applyDevelopModeArms() or t.force
  buildHostArtifacts()
  buildClient(force)
  launchHostApp("")

task tests, "Run the Nim test suite (test/nim/*.nim); pass a test name to run one; --benches adds the *_bench.nim benchmarks":
  # The suite links libstatus/libsds and the Qt frameworks, so it needs the
  # same artifacts the client does, minus status-keycard-qt and rcc (StatusQ
  # only for the suites in nimTestsLinkStatusQ).
  var only: seq[string]
  var benches = false
  for p in taskArgv():
    if p == "--benches":
      benches = true
    elif p.startsWith("-"):
      fail "unrecognized flag for 'tests': " & p &
        "\nusage: ./status tests [--benches] [<test name> ...]"
    else:
      only.add p
  let t = Target(os: "host")
  validateHost(t)
  discard applyDevelopModeArms()
  prepareHostBuild()   # shared with buildHostArtifacts
  runNimTests(only, benches)

task windowsLauncher, "Build bin/nim_windows_launcher.exe for `make pkg-windows` (--compileOnly stops before the link)":
  var compileOnly = false
  for p in taskArgv():
    if p == "--compileOnly":
      compileOnly = true
    else:
      fail "unrecognized argument for 'windowsLauncher': " & p &
        "\nusage: ./status windowsLauncher [--compileOnly]"
  buildWindowsLauncher(compileOnly)

task compileTranslations, "Compile the Qt translation catalogs (ui/i18n/*.qm) — a maintainer command, NOT a build step":
  let t = parseTarget()
  rejectExtras(t, "compileTranslations")
  validateHost(t)
  exportBuildEnv()
  buildTranslations("compile_application_translations")

task updateTranslations, "Re-extract translatable strings into ui/i18n/*.ts":
  let t = parseTarget()
  rejectExtras(t, "updateTranslations")
  validateHost(t)
  exportBuildEnv()
  buildTranslations("update_application_translations")

task qtPkgconfigGenerate, "Regenerate the active Qt kit's committed .pc tree in a prl-to-pc develop checkout (never a build step; refuses on a store copy)":
  # The kit comes from QMAKE, not from --os: regenerating the iOS or Android
  # tree from a desktop host is the point of this task.
  if taskArgv().len > 0:
    fail "'qtPkgconfigGenerate' takes no arguments; it regenerates the tree" &
      " for the kit QMAKE selects. Got: " & taskArgv().join(" ")
  let script = prlToPcScript()
  putEnv("QT_PC_NIM", nimExe())
  exec nimEval(script) & " generate " & quoteShell(thisDir() / qtPcBuildDir) &
    " " & quoteShell(thisDir() / "nimble.paths")

# --- develop mode (ADR 0007: a nimble.paths overlay) -------------------------
#
# Vendors stay pinned dependencies; `develop <vendor>` materializes a git
# checkout under vendor/<name> and records it in the gitignored overlay file.
# The overlay joins the setup-stamp key, so the next build re-runs `nimble
# setup` and then `./status applyOverlay` rewrites the developed
# vendor's entries in the generated nimble.paths to the checkout. Resolution
# still reads the PINNED manifest, so a diverging checkout manifest fails the
# build loudly (guardDivergence) instead of drifting silently.

type VendorFlavor = enum
  vfNimbleGraph  # pinned URL#hash requires in the nimble graph; overlay rewrites nimble.paths
  vfCmake        # pinned FetchContent GIT_TAG; develop = FETCHCONTENT_SOURCE_DIR redirect

type Vendor = object
  name: string          # `develop <name>` key (the package/project name)
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
  forceRemove: seq[string] # artifact globs removed before every build while developed
  flipRemove: seq[string]  # artifact globs removed once per develop/undevelop flip: artifacts
                           # whose inputs live under the vendor ROOT (checkout vs store), which
                           # a flip can leave newer than the other mode's sources

# Rebuild gating while developed (ADR 0003): the vendor sub-build runs every
# build — it owns incrementality — and cmp-gated copies keep dependents from
# relinking on identical bytes.
const vendorTable = [
  Vendor(name: "statusgo", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "status-go",
    pkgName: "statusgo", manifestName: "statusgo.nimble",
    checkoutDir: "vendor/status-go", developBranch: "develop",
    # libstatus has no file prerequisites, so removing it is what re-runs the
    # internally incremental sub-make.
    clientRebuild: true,
    forceRemove: @[".statusgo-build/build/bin/libstatus.*"]),
  Vendor(name: "sds", flavor: vfNimbleGraph,
    pinManifest: "@statusgo/statusgo.nimble", repoName: "nim-sds",
    pkgName: "sds", manifestName: "sds.nimble",
    checkoutDir: "vendor/nim-sds", developBranch: "develop",
    # libsds is loaded at runtime — no client rebuild. Its FORCE arm lives in
    # buildLibsds() (`"sds" in readOverlay()`), because a content key cannot be
    # forced by touching a file.
    clientRebuild: false, forceRemove: @[]),
  Vendor(name: "seaqt", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "nim-seaqt",
    pkgName: "seaqt", manifestName: "seaqt.nimble",
    # The pin is the tip of upstream branch qt-6.8, which is force-pushed on
    # every regeneration.
    checkoutDir: "vendor/nim-seaqt", developBranch: "qt-6.8",
    # The generated bindings and their {.compile.}d C++ shims build into the
    # client: a client rebuild is the whole FORCE arm, there are no vendor
    # artifacts.
    clientRebuild: true, forceRemove: @[]),
  Vendor(name: "nimqml", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "nimqml-seaqt",
    pkgName: "nimqml", manifestName: "nimqml.nimble",
    checkoutDir: "vendor/nimqml-seaqt", developBranch: "master",
    # Pure Nim compiled into the client, same FORCE arm as seaqt. srcDir:
    # store copies are hoisted (modules at the entry root) while the checkout
    # keeps them under src/, so the overlay remaps accordingly.
    srcDir: "src",
    clientRebuild: true, forceRemove: @[]),
  Vendor(name: "prl-to-pc", flavor: vfNimbleGraph,
    pinManifest: "nim_status_client.nimble", repoName: "prl-to-pc",
    pkgName: "prl_to_pc", manifestName: "prl_to_pc.nimble",
    # Consumed as package-root FILES (the driver executes
    # <root>/qt_pkgconfig.nims, make includes <root>/qt-pkgconfig.mk); nothing
    # nim-imports it, so a developed checkout needs neither a client rebuild
    # nor a per-build FORCE arm. A mode flip changes the package root, which
    # invalidates the cached `env` answer and may change the tool sources, so
    # flipRemove drops both artifacts.
    checkoutDir: "vendor/prl-to-pc", developBranch: "main",
    clientRebuild: false, forceRemove: @[],
    flipRemove: @[".prl-to-pc-build/.pcwrap/*",
                  ".prl-to-pc-build/.pcwrap/.*.key",
                  ".prl-to-pc-build/qt-pkgconfig.env"]),
  # status-keycard-qt itself is not here: it is the vendor/status-keycard-qt
  # SUBMODULE, so the checkout is what the build always compiles.
  Vendor(name: "keycard-qt", flavor: vfCmake,
    # status-keycard-qt's own CMakeLists owns this pin.
    pinManifest: "vendor/status-keycard-qt/CMakeLists.txt",
    repoName: "keycard-qt",
    pkgName: "", manifestName: "CMakeLists.txt",
    checkoutDir: "vendor/keycard-qt", developBranch: "develop",
    # keycard-qt is compiled static and re-linked into libstatus-keycard-qt, so
    # the FORCE arm is that library.
    clientRebuild: false,
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
  ## pointing into the checkout, so re-application is idempotent.
  let checkoutAbs = thisDir() / v.checkoutDir
  if entry == checkoutAbs or entry.startsWith(checkoutAbs & $DirSep):
    return checkoutAbs
  let marker = DirSep & "pkgs2" & DirSep & v.pkgName & "-"
  let i = entry.find(marker)
  if i < 0 or i + marker.len >= entry.len or entry[i + marker.len] notin {'0' .. '9'}:
    return ""
  let rootEnd = entry.find(DirSep, start = i + marker.len)
  if rootEnd < 0: entry else: entry[0 ..< rootEnd]

# --- statusgo root resolution -----------------------------------
#
# statusgo is a pinned URL#hash dependency: in default mode it resolves to a
# read-only store copy, which is built IN PLACE — nothing is copied anywhere.
# While developed the vendor/status-go checkout takes its place. Two roots:
#   - the SOURCE/MANIFEST root (pin parsing, divergence baseline, the tree the
#     sub-builds compile): store copy or checkout, read-only either way.
#   - the BUILD root (every artifact): .statusgo-build, always.

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
      " and no vendor/status-go checkout). Run `./status app` or" &
      " `make nimble-deps` first."

proc statusgoSourceRoot(): string =
  ## The statusgo tree the build READS: the develop checkout, else the
  ## read-only store copy. It is never written to: statusgo.nims and
  ## status-go's Makefile put every output under statusgoBuildRoot(), and only
  ## this root follows the overlay.
  statusgoManifestRoot()

proc expandVendorPath(f: string): string =
  ## Vendor-table paths may address the active statusgo SOURCE root via the
  ## "@statusgo/" prefix; everything else is repo-relative. (Artifact globs
  ## live under the build root and spell it out — there is only one.)
  if f.startsWith("@statusgo/"):
    statusgoSourceRoot() / f["@statusgo/".len .. ^1]
  else:
    thisDir() / f

proc repoBasename(url: string): string =
  result = url.strip(chars = {'/'}, leading = false).rsplit('/', maxsplit = 1)[^1]
  if result.endsWith(".git"):
    result = result[0 .. ^5]

proc cmakePinManifestPath(v: Vendor): string =
  ## Where a cmake-flavor vendor's pin-owning CMakeLists lives. "" while it is
  ## an uninitialised submodule.
  let p = thisDir() / v.pinManifest
  if fileExists(p): p else: ""

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
  ## needs no driver change. A file:// pin returns rev = "": the checkout is
  ## what resolution reads.
  if v.flavor == vfCmake:
    let mp = cmakePinManifestPath(v)
    if mp.len == 0:
      fail "'" & v.name & "' is pinned by " & v.pinManifest & ", which does" &
        " not exist — the submodule that carries it is not initialised. Run" &
        " `./status app` (its bootstrap initialises it) or `git submodule" &
        " update --init vendor/status-keycard-qt`."
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
  ## The file stays in place once created, even with no entries: it is an
  ## input of the setup key, so rewriting it is what schedules regeneration
  ## and overlay application.
  var content = "# Vendors in develop mode (one per line) — managed by\n" &
    "# `./status develop <vendor>` / `./status undevelop <vendor>`.\n"
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
        # module root, while the checkout keeps modules under <srcDir> — remap
        # the bare root onto it. A "<root>/src" entry already carries the right
        # suffix and passes through.
        if v.srcDir.len > 0 and rest.len == 0:
          rest = $DirSep & v.srcDir
        lines.add pre & checkoutAbs & rest & "\""
        continue
    lines.add line
  result.content = lines.join("\n")

proc pinnedManifestContent(v: Vendor, rev: string): string =
  ## The vendor manifest at the pinned revision, read from the checkout's own
  ## git history: that is what resolution reads, not the checkout's working
  ## tree (ADR 0007).
  let cmd = "git -C " & quoteShell(thisDir() / v.checkoutDir) & " show " &
    quoteShell(rev & ":" & v.manifestName)
  let (output, rc) = gorgeEx(cmd)
  if rc != 0:
    fail "cannot read the pinned manifest of developed vendor '" & v.name &
      "':\n  " & cmd & "\nfailed with:\n" & output &
      "\nIs the pinned revision still in the checkout's history?"
  output

proc guardDivergence(v: Vendor, rev: string) =
  ## Dependency resolution reads the PINNED manifest, so a checkout whose own
  ## manifest diverged must fail the build loudly rather than drift silently.
  if v.flavor == vfCmake:
    # The FETCHCONTENT_SOURCE_DIR redirect makes cmake read the checkout's own
    # CMakeLists, so build-config edits (nested pins included) take effect.
    return
  if rev.len == 0:
    # file:// pin: resolution reads the checkout's manifest itself.
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
    " PINNED manifest, not the checkout's (ADR 0007), so requires-edits in" &
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
  ## the vendor, i.e. the overlay rewrite took effect. A hand-run `nimble
  ## setup` regenerates the file without the overlay; this is where that is
  ## detected.
  if v.flavor == vfCmake:
    # cmake vendors are not in the nimble graph: their redirect is re-derived
    # from the overlay by every vendor configure, never from nimble.paths.
    return true
  let pathsFile = thisDir() / "nimble.paths"
  if not fileExists(pathsFile):
    return true # no resolution yet — setup will generate and apply
  for line in readFile(pathsFile).splitLines:
    const pre = "--path:\""
    if line.startsWith(pre) and line.endsWith("\""):
      let p = line[pre.len .. ^2]
      let root = vendorRootIn(v, p)
      if root.len > 0 and root != thisDir() / v.checkoutDir:
        return false
  true

proc isGitCheckout(dir: string): bool =
  ## `git -C <dir>` walks up to the enclosing repository, so a stray vendor
  ## directory with no .git of its own would answer with the desktop repo's
  ## HEAD and working tree.
  dirExists(dir) and (dirExists(dir / ".git") or fileExists(dir / ".git"))

proc applyDevelopModeArms(): bool =
  ## Pre-build develop-mode work for `app`/`run`/`buildArtifacts`: the
  ## divergence guard, setup-key re-invalidation when a hand-run `nimble setup`
  ## dropped the overlay, and the per-vendor FORCE arms. Returns true when a
  ## developed vendor's Nim sources compile INTO the client, i.e. when the
  ## client compile must skip its `stale()` gate.
  ##
  ## It mutates the tree, so call it exactly once per build, before any
  ## artifact runs.
  let devs = readOverlay()
  if devs.len == 0:
    return false
  var clientRebuild = false
  for name in devs:
    let v = vendorByName(name)
    if not isGitCheckout(thisDir() / v.checkoutDir):
      fail "vendor '" & v.name & "' is in develop mode but its checkout (" &
        v.checkoutDir & ") is missing or is not a git checkout. Run `./status develop " &
        v.name & "` to re-materialize it, or `./status undevelop " &
        v.name & " --force` to return to the pin."
    if v.flavor == vfNimbleGraph:
      let (_, rev) = pinOf(v)
      guardDivergence(v, rev)
      if not overlayApplied(v):
        # nimble.paths was regenerated without the overlay: drop the setup key
        # so nimbleSetupIfStale() re-resolves and re-applies it. A content key
        # ignores a `touch`, so the key file has to go.
        rmFile(thisDir() / setupKeyFile)
    for g in v.forceRemove:
      exec "rm -f " & expandVendorPath(g)
    if v.clientRebuild:
      clientRebuild = true
  clientRebuild

proc invalidateOnModeFlip(v: Vendor) =
  ## A mode flip moves a clientRebuild vendor's artifact dir, and the desktop
  ## client bakes that dir as an rpath at link time, so an existing binary
  ## would keep loading the other mode's library. Dropping the binary forces a
  ## relink; nothing else tracks the artifact dir.
  if v.clientRebuild:
    exec "rm -f " & quoteShell(thisDir() / "bin" / "nim_status_client")
  if v.flavor == vfCmake:
    # The vendor recipe only runs when its lib is missing, and the redirect is
    # a configure-time value: drop the artifacts so the next build
    # reconfigures with the new mode's FETCHCONTENT_SOURCE_DIR_* values.
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
    fail "usage: ./status " & taskName & " <vendor>" &
      (if allowForce: " [--force]" else: "") &
      "\nKnown vendors: " & known.join(", ")
  if result.vendor == "status-keycard-qt":
    fail "status-keycard-qt is a git submodule, not a nimble-style vendor:" &
      " vendor/status-keycard-qt IS the checkout every build compiles. Edit" &
      " it in place and commit the new gitlink — there is no develop mode to" &
      " enter or leave. (The NESTED keycard-qt FetchContent still has one:" &
      " `./status " & taskName & " keycard-qt`.)"

task develop, "Materialize a vendor as an editable checkout and switch the build to it":
  let (name, _) = developArgv("develop")
  let v = vendorByName(name)
  let (url, rev) = pinOf(v)
  let checkoutAbs = thisDir() / v.checkoutDir
  if dirExists(checkoutAbs):
    # An existing checkout is never clobbered: develop only flips the overlay
    # to it.
    if not isGitCheckout(checkoutAbs):
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
    # A branch at the pinned revision: detached HEAD is hostile to the
    # commit/push/PR workflow develop mode exists for. -B is safe on a fresh
    # clone, where the only local branch is the remote default.
    exec "git -C " & quoteShell(checkoutAbs) & " checkout -B " &
      quoteShell(v.developBranch) & " " & quoteShell(rev)
  if v.flavor == vfNimbleGraph and rev.len > 0 and
      fileExists(checkoutAbs / v.manifestName) and
      readFile(checkoutAbs / v.manifestName).strip != pinnedManifestContent(v, rev).strip:
    echo "develop: WARNING — " & v.checkoutDir & "/" & v.manifestName &
      " already diverges from the pinned revision; the next build will fail" &
      " with the escape-hatch instructions (ADR 0007 divergence guard)."
  var devs = readOverlay()
  if v.name in devs:
    echo "develop: '" & v.name & "' is already in develop mode (overlay: " &
      overlayFile & "); nothing to change."
  else:
    devs.add v.name
    writeOverlay devs # the overlay joins the setup key, so this invalidates it
    invalidateOnModeFlip v
    echo "develop: '" & v.name & "' recorded in " & overlayFile & "."
  if v.flavor == vfCmake:
    echo "develop: the next `./status app` redirects the '" & v.name &
      "' FetchContent to " & v.checkoutDir & " and rebuilds it every build."
  else:
    echo "develop: the next `./status app` re-resolves (nimble setup)," &
      " applies the overlay, and builds from " & v.checkoutDir & "."

task undevelop, "Return a developed vendor to its pin (--force to skip the dirty/unpushed checks)":
  let (name, force) = developArgv("undevelop", allowForce = true)
  let v = vendorByName(name)
  var devs = readOverlay()
  if v.name notin devs:
    echo "undevelop: '" & v.name & "' is not in develop mode; nothing to do."
  else:
    let checkoutAbs = thisDir() / v.checkoutDir
    if isGitCheckout(checkoutAbs) and not force:
      # Exiting develop mode must not lose work: refuse while the checkout has
      # uncommitted changes or commits no remote knows about.
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
    writeOverlay kept # invalidates the setup key → pin resolution returns
    invalidateOnModeFlip v
    echo "undevelop: '" & v.name & "' returned to its pin. The checkout at " &
      v.checkoutDir & " is left in place (inert; delete it whenever you like)."
    echo "undevelop: the next `./status app` re-resolves and builds" &
      " from the pinned copy again."

proc jsonStringField(content, key: string): string =
  ## First `"<key>": "<value>"` in a JSON text. The driver reads three small
  ## generated files this way rather than carrying a JSON parser.
  let marker = "\"" & key & "\":"
  let i = content.find(marker)
  if i < 0:
    return ""
  let rest = content[i + marker.len .. ^1]
  let a = rest.find('"')
  if a < 0:
    return ""
  let b = rest.find('"', a + 1)
  if b <= a:
    return ""
  rest[a + 1 ..< b]

proc pinnedRevision(vcsRevision, version: string): string =
  ## nimble records a lock entry's revision in vcsRevision, except where it
  ## leaves that empty and the `#<sha>` special version carries it.
  if vcsRevision.len > 0: vcsRevision
  elif version.startsWith("#"): version[1 .. ^1]
  else: ""

proc lockPinnedRevisions(): seq[tuple[name, rev: string]] =
  ## What nimble.lock pins each package at: its vcsRevision, or the `#<sha>`
  ## special version for the entries nimble records without one.
  let lock = thisDir() / "nimble.lock"
  if not fileExists(lock):
    fail "nimble.lock does not exist — there is nothing to audit against."
  var name, rev, version: string
  for raw in readFile(lock).splitLines:
    let l = raw.strip
    if raw.startsWith("    \"") and l.endsWith("{"):
      if name.len > 0:
        result.add (name, pinnedRevision(rev, version))
      name = l.split('"')[1]
      rev = ""
      version = ""
    elif name.len > 0 and l.startsWith("\"vcsRevision\":"):
      rev = jsonStringField(l, "vcsRevision")
    elif name.len > 0 and l.startsWith("\"version\":"):
      version = jsonStringField(l, "version")
  if name.len > 0:
    result.add (name, pinnedRevision(rev, version))

proc storeEntryOf(path: string): string =
  ## The store entry a nimble.paths entry belongs to: the nearest enclosing
  ## directory carrying nimblemeta.json (entries may point at `<entry>/src`).
  var dir = path
  while dir.len > 0:
    if fileExists(dir / "nimblemeta.json"):
      return dir
    let parent = dir.parentDir
    if parent == dir:
      break
    dir = parent

task auditDeps, "Check every resolved store copy against the revision nimble.lock pins":
  let t = parseTarget()
  rejectExtras(t, "auditDeps")
  let pathsFile = thisDir() / "nimble.paths"
  if not fileExists(pathsFile):
    fail "nimble.paths does not exist — run `./status app` or" &
      " `make nimble-deps` first."
  let pinned = lockPinnedRevisions()
  var audited, developed, unpinned, drifted = 0
  var roots: seq[string]
  for line in readFile(pathsFile).splitLines:
    const pre = "--path:\""
    if not (line.startsWith(pre) and line.endsWith("\"")):
      continue
    let entryPath = line[pre.len .. ^2]
    if (DirSep & "pkgs2" & DirSep) notin entryPath:
      # A develop-mode overlay entry or the app's own srcDir: no store copy to
      # compare, and the divergence guard already owns the developed ones.
      if entryPath.startsWith(thisDir() / "vendor"):
        developed.inc
      continue
    let root = storeEntryOf(entryPath)
    if root.len == 0:
      echo "auditDeps: DRIFT — no nimblemeta.json for " & entryPath
      drifted.inc
      continue
    if root in roots:
      continue
    roots.add root
    # Store entries are named <package>-<version>-<checksum>.
    let parts = root.extractFilename.rsplit('-', maxsplit = 2)
    if parts.len != 3:
      echo "auditDeps: DRIFT — unreadable store entry name: " & root
      drifted.inc
      continue
    let name = parts[0]
    let have = jsonStringField(readFile(root / "nimblemeta.json"), "vcsRevision")
    var want = ""
    var known = false
    for p in pinned:
      if p.name == name:
        want = p.rev
        known = true
        break
    if not known:
      echo "auditDeps: DRIFT — '" & name & "' is resolved (" & root &
        ") but nimble.lock has no entry for it."
      drifted.inc
    elif want.len == 0:
      unpinned.inc
    elif want != have:
      echo "auditDeps: DRIFT — '" & name & "'"
      echo "  lock:  " & want
      echo "  store: " & have & " (" & root & ")"
      drifted.inc
    else:
      audited.inc
  echo "auditDeps: " & $audited & " package(s) match the lock, " & $unpinned &
    " pinned by version only, " & $developed & " developed."
  if drifted > 0:
    fail $drifted & " package(s) drifted from nimble.lock. Re-resolve with" &
      " `nimble setup`, or regenerate the lock (`nimble lock`) if a pin moved."

task vendors, "List vendors: pin, flavor, and develop state":
  let t = parseTarget()
  rejectExtras(t, "vendors")
  let devs = readOverlay()
  for v in vendorTable:
    var url = ""
    var rev = ""
    var pinUnavailable = false
    if v.flavor == vfCmake and cmakePinManifestPath(v).len == 0:
      # The submodule carrying the pin is not initialised yet; do not fail the
      # whole listing over it.
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
    if isGitCheckout(checkoutAbs):
      let (head, rc) = gorgeEx("git -C " & quoteShell(checkoutAbs) &
        " rev-parse --short HEAD")
      let (dirty, _) = gorgeEx("git -C " & quoteShell(checkoutAbs) &
        " status --porcelain")
      checkout = v.checkoutDir & (if rc == 0: " @ " & head.strip else: "") &
        (if dirty.strip.len > 0: " (dirty)" else: " (clean)")
    echo v.name & "  [" & (if v.flavor == vfNimbleGraph: "nimble-graph" else: "cmake") &
      ", " & state & "]"
    if pinUnavailable:
      echo "  pin:      owned by " & v.pinManifest & " — visible once that" &
        " submodule is initialised (`./status app`)"
    else:
      echo "  pin:      " & url & (if rev.len > 0: "#" & rev else: " (interim local pin)")
    echo "  checkout: " & checkout

const resolutionMkFile = ".status-resolution.mk"  # gitignored

proc writeResolutionMk() =
  ## The make side's single view of the resolution: which vendors are
  ## developed, and where the two package roots make needs resolved to. Make
  ## `-include`s this instead of scraping nimble.paths and nimble.overlay.
  let devs = readOverlay()
  let statusgoSrc =
    if "statusgo" in devs and dirExists(thisDir() / "vendor/status-go"):
      thisDir() / "vendor/status-go"
    else:
      statusgoStoreRoot()
  var statusgoVersion = ""
  let meta = statusgoStoreRoot() / "nimblemeta.json"
  if statusgoSrc.len > 0 and statusgoSrc == statusgoStoreRoot() and
      fileExists(meta):
    let rev = jsonStringField(readFile(meta), "vcsRevision")
    statusgoVersion = rev[0 ..< min(10, rev.len)]
  let lines = @[
    "# Generated by `./status applyOverlay` — do not edit.",
    "STATUSGO_DEVELOPED := " & (if "statusgo" in devs: "1" else: ""),
    "PRL_TO_PC_DEVELOPED := " & (if "prl-to-pc" in devs: "1" else: ""),
    "KEYCARD_QT_DEVELOPED := " & (if "keycard-qt" in devs: "1" else: ""),
    "STATUSGO_SRC := " & statusgoSrc,
    "PRL_TO_PC_ROOT := " & prlToPcRoot(),
    "STATUSGO_VERSION := " & statusgoVersion,
  ]
  writeFile(thisDir() / resolutionMkFile, lines.join("\n") & "\n")

proc applyOverlayNow() =
  ## Runs immediately after every `nimble setup` (nimbleSetupIfStale), never on
  ## its own: rewriting nimble.paths without recording the setup key would make
  ## the next build skip resolution.
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
      if not isGitCheckout(thisDir() / v.checkoutDir):
        fail "vendor '" & v.name & "' is in develop mode but its checkout (" &
          v.checkoutDir & ") is missing or is not a git checkout. Run `./status develop " &
          v.name & "` to re-materialize it, or `./status undevelop " &
          v.name & " --force` to return to the pin."
      if v.flavor == vfCmake:
        # Not in the nimble graph: the redirect is applied by the vendor's
        # cmake configure instead.
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
  writeResolutionMk()

task applyOverlay, "Apply the develop-mode overlay to the generated nimble.paths (internal: the setup-stamp gate runs this after every `nimble setup`)":
  applyOverlayNow()

# --- the statusgo output directory ------------------------
#
# status-go and nim-sds keep every build output under a caller-chosen
# directory, so the read-only resolved copies are compiled IN PLACE and
# .statusgo-build holds outputs only. prepareStatusgo maintains that directory:
# wiped when the resolved SOURCE root changes, artifacts dropped when the
# artifact key changes. That pair is the pinned-mode rebuild stamp (the store
# path carries pin revision and manifest checksum; the platform sentinel covers
# target-triple flips; --key carries the flag set). Developed statusgo keeps
# ADR 0003's FORCE semantics, with its outputs in the same directory so the
# checkout stays clean.

task prepareStatusgo, "Maintain the statusgo output directory (.statusgo-build) — internal: the mobile make legs run this before statusgo builds":
  var key = ""
  for p in taskArgv():
    let k = flagVal(p, "key")
    if k.len > 0:
      key = k
  prepareStatusgoOut(key)
