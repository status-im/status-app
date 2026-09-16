# status_env.nims — build-environment discovery shared by the driver
# (status.nims) and the compiler config (config.nims). config.nims derives
# every build value itself, so the procs the driver uses for kit discovery and
# validation must be includable from both files. An include, not a module:
# both consumers are nimscript files nim evaluates standalone, and the
# manifest pulls status.nims in by include too.
#
# Everything here must stay side-effect free at top level: the file is
# evaluated for every nim compile of the app (via config.nims), for every
# driver task dispatch and for every nimble evaluation of the root manifest.

import std/[os, strutils]

when not declared(statusEnvFail):
  proc statusEnvFail(msg: string) =
    quit("\nstatus build ERROR: " & msg, 1)

when not declared(kitHint):
  const kitHint = """
Kit examples (adjust the Qt version/paths to your installs):
  host     QMAKE=~/Qt/6.11.0/macos/bin/qmake
  iOS      QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos \
           QMAKE_DEVELOPMENT_TEAM=<your Apple team id>
  Android  QMAKE=~/Qt/6.11.0/android_arm64_v8a/bin/qmake \
           ANDROID_SDK_ROOT=<sdk> ANDROID_NDK_ROOT=<ndk>"""

when not declared(qmakeExe):
  proc qmakeExe(): string =
    ## The active Qt kit's qmake: $QMAKE, else the first qmake on PATH.
    ## Fails fast with the kit hint — every consumer needs a real kit.
    result = getEnv("QMAKE")
    if result.len == 0:
      result = findExe("qmake")
      if result.len == 0:
        statusEnvFail "QMAKE is not set and no qmake is on PATH.\n" & kitHint
    elif not fileExists(result):
      statusEnvFail "QMAKE points at '" & result & "', which does not exist.\n" & kitHint

when not declared(qmakeQuery):
  proc qmakeQuery(exe, what: string): string =
    let (output, rc) = gorgeEx(quoteShell(exe) & " -query " & what)
    if rc != 0:
      statusEnvFail "'" & exe & " -query " & what & "' failed:\n" & output
    output.strip

when not declared(qmakeQueryAll):
  proc qmakeQueryAll(exe: string): seq[tuple[key, val: string]] =
    ## One-exec dump of every qmake -query property (KEY:value per line):
    ## config.nims runs per nim compile, so kit discovery must cost a single
    ## subprocess, not one per property.
    let (output, rc) = gorgeEx(quoteShell(exe) & " -query")
    if rc != 0:
      statusEnvFail "'" & exe & " -query' failed:\n" & output
    for line in output.splitLines:
      let i = line.find(':')
      if i > 0:
        result.add (line[0 ..< i], line[i + 1 .. ^1].strip)

when not declared(qmakeProp):
  proc qmakeProp(dump: seq[tuple[key, val: string]], key: string): string =
    for (k, v) in dump:
      if k == key:
        return v
    statusEnvFail "qmake -query dump has no '" & key & "' property."

# --- develop-mode overlay + statusgo roots (ADR 0007) ------------------------
# The overlay file records vendors in develop mode. The statusgo SOURCE tree
# (store copy vs checkout) and the statusgo OUTPUT directory are two different
# things, and only the source tree follows the overlay: status-go and nim-sds
# are built IN PLACE from whatever the resolution points at, and every artifact
# lands in the one output directory below, in both modes. config.nims only ever
# needs the output directory, so the source-root lookup lives in status.nims.

when not declared(overlayFile):
  const overlayFile = "nimble.overlay"  # gitignored; joins the make setup-stamp key

when not declared(statusgoOutDir):
  const statusgoOutDir = ".statusgo-build"  # gitignored OUTPUTS at the repo root

when not declared(readOverlay):
  proc readOverlay(): seq[string] =
    if not fileExists(thisDir() / overlayFile):
      return
    for line in readFile(thisDir() / overlayFile).splitLines:
      let l = line.strip
      if l.len > 0 and not l.startsWith("#"):
        result.add l

when not declared(statusgoDeveloped):
  proc statusgoDeveloped(): bool =
    "statusgo" in readOverlay()

when not declared(statusgoBuildRoot):
  proc statusgoBuildRoot(): string =
    ## Where statusgo's build OUTPUTS live: libstatus + its header under
    ## build/bin, libsds + the header contract under .sds-build (the layout
    ## statusgo.nims produces under STATUSGO_BUILD_DIR). The same directory in
    ## every mode, so a developed checkout stays clean. The Makefiles derive
    ## the same path; keep them in sync.
    thisDir() / statusgoOutDir

when not declared(prlToPcRoot):
  proc prlToPcRoot(): string =
    ## The prl-to-pc package root: qt_pkgconfig.nims, qt-pkgconfig.mk and the
    ## committed Qt .pc trees live there. The develop checkout when the overlay
    ## says so, else the store entry from the generated nimble.paths ("" when
    ## the resolution does not exist yet). The Makefile derives the same answer
    ## as PRL_TO_PC_ROOT; keep them in sync.
    if "prl-to-pc" in readOverlay() and
        dirExists(thisDir() / "vendor/prl-to-pc"):
      return thisDir() / "vendor/prl-to-pc"
    let pathsFile = thisDir() / "nimble.paths"
    if not fileExists(pathsFile):
      return ""
    for line in readFile(pathsFile).splitLines:
      const pre = "--path:\""
      if line.startsWith(pre) and line.endsWith("\""):
        let entry = line[pre.len .. ^2]
        let marker = DirSep & "pkgs2" & DirSep & "prl_to_pc-"
        let i = entry.find(marker)
        if i >= 0:
          # The package root is the store entry itself: the manifest declares
          # no srcDir, so entries are never suffixed.
          let rootEnd = entry.find(DirSep, i + marker.len)
          return if rootEnd < 0: entry else: entry[0 ..< rootEnd]

# --- cmake build flavor (shared with config.nims' Windows arm) ---------------
# The Windows client links artifacts out of cmake's per-config subdirectories
# (`lib/Release`, `lib/Debug`), so the compiler config must derive the same
# flavor the driver hands cmake.

when not declared(qmlDebug):
  proc qmlDebug(): bool = getEnv("QML_DEBUG", "false") != "false"

when not declared(buildType):
  proc buildType(): string =
    ## The cmake build type every artifact is configured with.
    if qmlDebug(): "Debug" else: "Release"

when not declared(winCfgSuffix):
  proc winCfgSuffix(): string =
    ## The per-config leg cmake appends to its output directories on Windows
    ## (multi-config generator), and nothing anywhere else.
    if hostOS == "windows": "/" & buildType() else: ""

# --- artifact directories (one definition, driver + config.nims) -------------
# On Windows the cmake BUILD dir and the LINK dir are different directories
# (the per-config `winCfg` leg), so they are two procs, not one.

when not declared(keycardBuildDir):
  proc keycardBuildDir(): string =
    ## The cmake `-B` tree. NOT the link dir on Windows — see keycardLibDir.
    ## The simulated backend gets its own tree: its codegen must never leak
    ## into a real-keycard build.
    thisDir() / "build/status-keycard-qt" /
      (case hostOS
       of "macosx": "macos"
       of "windows": "windows"
       else: "linux") &
      (if getEnv("USE_SIMULATED_KEYCARD") == "true": "-simulated-keycard" else: "")

when not declared(keycardLibDir):
  proc keycardLibDir(): string =
    ## The built shared library's directory (STATUSKEYCARD_QT_LIBDIR).
    keycardBuildDir() & winCfgSuffix()

# --- the Qt pkg-config environment cache -------------------------
# prl-to-pc owns kit derivation and the System/Generated probe; its
# `qt_pkgconfig.nims env` prints the resulting environment. Running that per
# nim invocation would fork a subprocess for every compile (nimsuggest
# included), so the driver runs it once per build and caches the answer here.
# config.nims only replays the cache: it derives no .pc path, no kit, no
# version, and it must not assume a pkg-config wrapper exists (System-mode
# kits have none).

when not declared(qtPcBuildDir):
  const qtPcBuildDir = ".prl-to-pc-build/.pcwrap"  # gitignored; tools never land in the store

when not declared(qtPcEnvCache):
  const qtPcEnvCache = ".prl-to-pc-build/qt-pkgconfig.env"  # gitignored

when not declared(qtPkgConfigKey):
  proc qtPkgConfigKey(qmake, prlRoot, qtPrefix: string): string =
    ## Everything the cached environment depends on. All three are in hand at
    ## both call sites, so a stale cache is detected without spawning
    ## anything.
    qmake & "|" & prlRoot & "|" & qtPrefix

when not declared(qtPkgConfigEnv):
  proc qtPkgConfigEnv(key: string): seq[tuple[k, v: string]] =
    let cache = thisDir() / qtPcEnvCache
    const rerun = "\nRun `./status app` (or `nimble build` — its" &
      " before-build hook does this for you); they ask prl-to-pc for the" &
      " environment and cache it."
    if not fileExists(cache):
      statusEnvFail "the Qt pkg-config environment cache is missing (" &
        qtPcEnvCache & ")." & rerun
    var keyed = false
    for line in readFile(cache).splitLines:
      let l = line.strip
      if l.len == 0 or l.startsWith("#"):
        continue
      let i = l.find('=')
      if i <= 0:
        statusEnvFail "malformed line in " & qtPcEnvCache & ": '" & l & "'." & rerun
      let name = l[0 ..< i]
      let val = l[i + 1 .. ^1]
      if name == "key":
        keyed = true
        if val != key:
          statusEnvFail "the Qt pkg-config environment cache (" & qtPcEnvCache &
            ") was built for another Qt kit, another prl-to-pc copy or another" &
            " qmake:\n  cached: " & val & "\n  wanted: " & key & rerun
      else:
        result.add (name, val)
    if not keyed:
      statusEnvFail "the Qt pkg-config environment cache (" & qtPcEnvCache &
        ") carries no key line." & rerun

when not declared(applyQtPkgConfigEnv):
  proc applyQtPkgConfigEnv(qmake, qtPrefix: string) =
    ## Replay the cached environment into this nim process, so every
    ## compile-time `gorge("pkg-config Qt6…")` (seaqt's) and every `exec` /
    ## `gorgeEx` child resolves the active kit. Two consumers: config.nims
    ## inside its `isDesktopClient` block, and the driver before it compiles
    ## the Nim test suite, which is not that client.
    ##
    ## Both composed variables prepend and are idempotent: on the make path
    ## qt-pkgconfig.mk has already exported the same values, and re-applying
    ## them must not stack duplicates.
    for (name, val) in qtPkgConfigEnv(qtPkgConfigKey(qmake, prlToPcRoot(), qtPrefix)):
      case name
      of "PKG_CONFIG_PATH":
        let cur = getEnv("PKG_CONFIG_PATH")
        if cur.len == 0: putEnv(name, val)
        elif not cur.startsWith(val): putEnv(name, val & ":" & cur)
      of "PKG_CONFIG_PREFIX_OVERRIDE", "PKG_CONFIG_ARCH":
        putEnv(name, val)
      of "QT_PC_PATH_PREPEND":
        let cur = getEnv("PATH")
        if not cur.startsWith(val & ":"): putEnv("PATH", val & ":" & cur)
      else:
        discard  # QT_PC_MODE / QT_PC_REASON / QT_PC_PREFIX: diagnostics only

when not declared(qtSeaqtExtraLibs):
  proc qtSeaqtExtraLibs(): string =
    ## The Qt modules the binary links beyond what the seaqt bindings pull in
    ## themselves. Needs applyQtPkgConfigEnv() first. The Windows client does
    ## not link these, so config.nims' Windows arm does not call this.
    let (output, rc) = gorgeEx(
      "pkg-config --libs Qt6Core Qt6Qml Qt6Gui Qt6Quick Qt6QuickControls2 " &
      "Qt6Widgets Qt6Svg Qt6Multimedia Qt6WebView Qt6WebChannel")
    if rc != 0:
      statusEnvFail "pkg-config failed to resolve the Qt link libraries:\n" &
        output & "\nPKG_CONFIG_PATH is " & getEnv("PKG_CONFIG_PATH") & " (from" &
        " prl-to-pc's `env`; see " & qtPcEnvCache & ")."
    output.strip
