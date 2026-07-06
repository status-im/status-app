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
# `nimble setup` into APP_NIMBLE_DIR only when stale), and on a clean clone
# the Makefile's .DEFAULT rule auto-runs `git submodule update --init
# --recursive` first. This file is a nimscript driver, NOT a nimble task:
# `nimble <task>` re-pays ~46–48 s of graph revalidation per warm invocation
# on this manifest (measured 2026-07-06); `nim <task> status.nims` starts in
# about a second.

import std/[os, strutils]

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

const kitHint = """
Kit examples (adjust the Qt version/paths to your installs):
  host     QMAKE=~/Qt/6.11.0/macos/bin/qmake
  iOS      QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos \
           QMAKE_DEVELOPMENT_TEAM=<your Apple team id>
  Android  QMAKE=~/Qt/6.11.0/android_arm64_v8a/bin/qmake \
           ANDROID_SDK_ROOT=<sdk> ANDROID_NDK_ROOT=<ndk>"""

proc qmakeExe(): string =
  result = getEnv("QMAKE")
  if result.len == 0:
    result = findExe("qmake")
    if result.len == 0:
      fail "QMAKE is not set and no qmake is on PATH.\n" & kitHint
  elif not fileExists(result):
    fail "QMAKE points at '" & result & "', which does not exist.\n" & kitHint

proc qmakeQuery(exe, what: string): string =
  let (output, rc) = gorgeEx(quoteShell(exe) & " -query " & what)
  if rc != 0:
    fail "'" & exe & " -query " & what & "' failed:\n" & output
  output.strip

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

proc ncpu(): string =
  let probe = if buildOS == "macosx": "sysctl -n hw.ncpu" else: "nproc"
  let (output, rc) = gorgeEx(probe)
  if rc == 0 and output.strip.len > 0: output.strip else: "4"

proc runMake(target: string) =
  exec "cd " & quoteShell(thisDir()) & " && make -j" & ncpu() & " " & target

task app, "Build the Status dev build: host by default, --os:ios / --os:android (+ --cpu) for mobile":
  let t = parseTarget()
  rejectExtras(t, "app")
  case t.os
  of "ios":
    validateIos(t)
    runMake "mobile-build"
  of "android":
    validateAndroid(t)
    runMake "mobile-build"
  else:
    validateHost(t)
    runMake "nim_status_client"

task run, "Build if needed and launch the host dev build (StatusDev.app on macOS)":
  let t = parseTarget()
  rejectExtras(t, "run")
  if t.os != "host":
    fail "'run' launches the host desktop build only; for mobile use" &
      " `make mobile-run` (a driver mobile run may come with issue 0009+)."
  validateHost(t)
  runMake "run"

# --- develop mode (issue 0009 implements these) -------------------------------

const developPending = """'$1' is not implemented yet — issue 0009 (develop-mode core) delivers it
via the nimble.paths overlay (docs/adr/0004-develop-mode-via-paths-overlay.md).
Until then use the documented escape hatch: a machine-local ABSOLUTE file://
requires pointing at your checkout (restore the pinned URL before shipping)."""

task develop, "Materialize a vendor as an editable checkout and switch the build to it (issue 0009)":
  # TODO(0009): materialize vendor/<name> at the pin, record it in the
  # gitignored overlay file, rewrite that vendor's nimble.paths entries.
  fail developPending % ["develop"]

task undevelop, "Return a developed vendor to its pin (issue 0009)":
  # TODO(0009): refuse while the checkout is dirty/unpushed unless --force;
  # drop the overlay entry and restore the pinned resolution.
  fail developPending % ["undevelop"]

task vendors, "List vendors and their mode (issue 0009)":
  # TODO(0009): report pin vs develop-checkout state per vendor.
  fail developPending % ["vendors"]
