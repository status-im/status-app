# status_env.nims — shared build-environment discovery for the driver
# (status.nims) and the compiler config (config.nims). Issue 0013 phase A:
# config.nims derives every make-exported value itself, so the exact same
# procs the driver uses for kit discovery/validation must be includable from
# both files (an include, not a module: both consumers are nimscript files
# that nim evaluates standalone, and the manifest pulls status.nims in via
# include — a shared include keeps one evaluation context everywhere).
#
# Everything here must stay side-effect free at top level: this file is
# evaluated for every nim compile of the app (via config.nims), for every
# driver task dispatch, and for every nimble evaluation of the root manifest.

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
    ## One-exec dump of every qmake -query property (KEY:value per line) —
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

# --- develop-mode overlay + statusgo roots (ADR 0004 / issue 0010) -----------
# The overlay file records vendors in develop mode; the statusgo build root
# (scratch copy vs checkout) follows it. config.nims needs the same answers
# the driver and the Makefiles derive, from the same single source.

when not declared(overlayFile):
  const overlayFile = "nimble.overlay"  # gitignored; joins the make setup-stamp key

when not declared(statusgoScratchDir):
  const statusgoScratchDir = ".statusgo-build"  # gitignored scratch at the repo root

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
    ## Where statusgo builds run and artifacts live (Makefiles derive the same
    ## path themselves; keep all three in sync).
    if statusgoDeveloped(): thisDir() / "vendor/status-go"
    else: thisDir() / statusgoScratchDir
