# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

import std/os
import std/strutils

# Shared kit/overlay discovery (issue 0013 phase A): the exact procs the
# driver (status.nims) uses, so derived values can never drift from what the
# driver validates.
include "status_env.nims"

# `nimble setup` builds dependency package binaries; if the dependency store
# ever sits inside the repo (a manual `--localdeps` run creates nimbledeps/),
# Nim's parent-dir config walk hands those compiles this file. Everything
# below is app-specific — link inputs relative to the app root (openssl
# bottles), rpath flags from app env vars, chronicles defines, cache layout —
# and poisons a dependency's own build (e.g. `bottles/openssl@3/...` on a
# dnsclient link line), so it only applies when the project being compiled is
# ours, not a dependency's. (The dependency store lives out of tree, so this
# guard is normally inert.)
if not projectPath().startsWith(thisDir() / "nimbledeps"):
  # nimble 0.22.3 emits unusable nimble.paths entries for srcDir-HOISTED store
  # copies, breaking their imports. The shape varies by run: the setup that
  # MATERIALIZES the store copy srcDir-hoists it (module files at the entry
  # root) and emits the root, while a warm re-setup re-derives the entry from
  # the manifest's srcDir and emits root/src — which no longer exists in the
  # hoisted copy (wall: vendor/status-go AGENTS.md). Hits isaac (srcDir "src",
  # resolved transitively via uuids) and nimqml (srcDir "src", direct pin).
  # Point at whichever directory actually holds the modules (the store lives
  # outside the repo; the dir's hash suffix changes with the pins, hence scan).
  when withDir(thisDir(), system.fileExists("nimble.paths")):
    for line in readFile(thisDir() & "/nimble.paths").splitLines:
      let entry = line.strip.replace("--path:", "").strip(chars = {'"'})
      for pkg in ["isaac", "nimqml"]:
        if (DirSep & pkg & "-") in entry:
          if dirExists(entry & "/src"):
            switch("path", entry & "/src")
          elif entry.endsWith(DirSep & "src") and not dirExists(entry):
            switch("path", entry[0 ..< entry.len - 4])

  # Nested-git-worktree guard (issue 0013): when this checkout sits inside
  # another status-desktop checkout (e.g. .claude/worktrees/<name>), the
  # ENCLOSING checkout's nim.cfg (`path = "src"`) puts ITS src on the module
  # search path via Nim's parent-dir config walk — and any compile that also
  # receives our src as a COMMAND-LINE --path (nimble's bin compile passes
  # the root package's srcDir) then resolves every app module to the
  # PARENT's sources: CLI --path is processed before configs, so the
  # enclosing checkout's entry outranks it, and the build silently compiles
  # the other checkout. Exclude every ancestor checkout's src explicitly
  # (ours is re-added by nim.cfg and/or the command line).
  # The same walk also evaluates every ancestor's config.nims — and checkouts
  # on branches that predate the rpath empty-env guard (e.g. release/2.38.x)
  # emit a bare `-rpath` per unset make variable, which ld mis-parses (it
  # consumes the next -rpath flag as the value and treats the leftover path
  # as an input file: "cannot open file: /StatusQ"). config files can't undo
  # an ancestor's passL flags, so fail fast with the remedy instead of
  # letting the link die minutes later.
  var unguardedAncestorCfg = ""
  var ancestorDir = thisDir().parentDir
  while ancestorDir.len > 1:
    if fileExists(ancestorDir / "src" / "nim_status_client.nim"):
      switch("excludePath", ancestorDir / "src")
      let ancestorCfg = ancestorDir / "config.nims"
      if fileExists(ancestorCfg) and
          "\"-rpath\" & \" \" & getEnv(" in readFile(ancestorCfg):
        unguardedAncestorCfg = ancestorCfg
    ancestorDir = ancestorDir.parentDir
  if unguardedAncestorCfg.len > 0:
    for envName in ["QT_LIBDIR", "STATUSGO_LIBDIR", "STATUSKEYCARDGO_LIBDIR",
                    "STATUSQ_INSTALL_PATH"]:
      if getEnv(envName).len == 0:
        statusEnvFail "this checkout is nested inside another status-desktop " &
          "checkout whose config.nims lacks the rpath empty-env guard:\n  " &
          unguardedAncestorCfg & "\nWith " & envName & " unset it injects a " &
          "bare -rpath that breaks the link (ld eats the next flag; " &
          "\"cannot open file: /StatusQ\").\nFix one of:\n" &
          "  - port master's guarded rpath block into that config.nims, or\n" &
          "  - build via `make run` / `nim app status.nims` (they export the " &
          "env), or\n  - export the four variables above before `nimble build/run`."

  # The status_go wrapper (shipped inside the statusgo package, resolved via
  # the app's nimble graph) auto-links the static libstatus/libsds it builds
  # for standalone consumers. This app links the shared flavors with its own
  # explicit flags, so opt out.
  switch("define", "statusGoNoAutoLink")

  # --- desktop-client detection (issue 0013 phase A) --------------------------
  # The client compile gets its FULL flag set here — make's recipe and
  # nimble's bin compile both invoke a bare `nim c src/nim_status_client.nim`
  # against this file, so the three front doors (make / nimble / bare nim)
  # produce the same build by construction. Everything the flags need is
  # env-or-derived: make keeps exporting its values (they win when present,
  # and STATUS_BUILD_ENV_ASSERT=1 verifies derived == exported); without the
  # env — nimble build/run, bare nim c — the same values are derived from the
  # repo layout, nimble.paths/nimble.overlay and `qmake -query`.
  # Mobile client compiles (--os:ios/--os:android) keep their make-owned flag
  # sets: this issue targets the HOST build. Windows stays make-owned too
  # (PRD: Windows validation out of scope).
  let isDesktopClient = projectPath().splitFile.name == "nim_status_client" and
      not (defined(ios) or defined(android)) and hostOS != "windows"
  # Release is the canonical dev-build flavor on every path: nimble's bin
  # compile passes -d:release itself, make exports INCLUDE_DEBUG_SYMBOLS.
  let clientRelease = isDesktopClient and getEnv("INCLUDE_DEBUG_SYMBOLS") != "true"

  # Keep a separate nimcache per USE_SIMULATED_KEYCARD mode. That flag toggles -d:useSimulatedKeycard,
  # which adds/removes the KeycardTest* imports from libstatus-keycard-qt; sharing one cache let stale
  # (simulated) codegen leak into a non-simulated build -> dyld "Symbol not found: _KeycardTestCreateCard".
  let kcSuffix = when defined(useSimulatedKeycard): "-simkeycard" else: ""
  if defined(release) or clientRelease:
    switch("nimcache", "nimcache/release" & kcSuffix & "/$projectName")
  else:
    switch("nimcache", "nimcache/debug" & kcSuffix & "/$projectName")

  # Flavor selection must precede the per-OS block: -d:release is a SPECIAL
  # define that also flips debug-info defaults, so it has to be processed
  # BEFORE switch("debugger", "native") re-enables debug info — the same
  # order the command-line spelling produces (nimble passes -d:release ahead
  # of every config; make used to). Setting it after the debugger switch
  # silently strips the binary's debug map (found via a 6 MB __LINKEDIT /
  # 415k-vs-133k symbol asymmetry between the nimble and make outputs).
  if clientRelease and not defined(release):
    switch("define", "release")
  elif isDesktopClient and not clientRelease:
    switch("define", "debug")

  switch("threads", "on")
  switch("opt", "speed") # -O3
  switch("define", "ssl") # needed by the stdlib to enable SSL procedures
  switch("define", "useOpenSSL3")
  switch("parallelBuild", "0")  # 0 == auto nr. of cores

  if hostOS == "macosx":
    echo "Building for macOS"
    switch("dynlibOverrideAll") # don't use dlopen()
    switch("tlsEmulation", "off")
    switch("debugger", "native") # passes "-g" to the C compiler
    switch("passL", "-lstdc++")
    # DYLD_LIBRARY_PATH doesn't always work when running/packaging so set rpath
    # note: macdeployqt rewrites rpath appropriately when building the .app bundle
    # guards: empty outside the app build (e.g. nimble setup compiling dep tools).
    # An empty value would emit a bare "-rpath " (no path), which the linker
    # mis-parses — it consumes the next -rpath flag as its argument and leaves a
    # real path dangling as an input file ("ld: file cannot be mmap()ed").
    # The desktop client gets env-or-derived rpaths in its own block below —
    # these env-only arms cover every other compile make drives (nim tests).
    if not isDesktopClient:
      for rpathDir in [getEnv("QT_LIBDIR"), getEnv("STATUSGO_LIBDIR"), getEnv("STATUSKEYCARD_QT_LIBDIR")]:
        if rpathDir.len > 0:
          switch("passL", "-rpath " & rpathDir)
      let statusqInstallPath = getEnv("STATUSQ_INSTALL_PATH")
      if statusqInstallPath.len > 0:
        switch("passL", "-rpath " & statusqInstallPath & "/StatusQ")
    # statically link these libs (absolute: the link must not depend on the
    # invoker's cwd — nimble and bare nim compiles run outside make)
    switch("passL", thisDir() & "/bottles/openssl@3/lib/libcrypto.a")
    switch("passL", thisDir() & "/bottles/openssl@3/lib/libssl.a")
    # https://code.videolan.org/videolan/VLCKit/-/issues/232
    switch("passL", "-Wl,-no_compact_unwind")
    # set the minimum supported macOS version to 14.0
    switch("passC", "-mmacosx-version-min=14.0")
  elif hostOS == "windows":
    echo "Building for Windows"
    switch("app", "gui")
    switch("tlsEmulation", "off")
    when defined(debug):
      switch("debugger", "native")
      switch("passL", "-g")
    # `-Wl,-as-needed` is a GNU-ld flag. The main client is built with clang-cl
    # (MSVC ABI) so it can link the MSVC-built Qt; lld-link doesn't understand it.
    # Keep it only for the gcc/mingw builds (e.g. the standalone Windows launcher).
    when defined(gcc):
      switch("passL", "-Wl,-as-needed")
  elif hostOS == "linux":
    echo "Building for Linux"
    switch("dynlibOverrideAll") # don't use dlopen()
    # Force PIC codegen at link time. With LTO (-flto=auto) GCC re-generates code
    # during the link and defaults to -fPIE semantics, which enable
    # -fdirect-access-external-data; -fPIC disables it. Without this, direct access
    # to external data makes the linker emit COPY relocations for Qt's exported
    # metaobjects (QObject::staticMetaObject et al), placing a *second* copy inside
    # the executable. QQmlMetaType::canConvert() identifies QObject-derived types by
    # walking the metaobject superdata chain and comparing pointers, so the duplicate
    # makes every C++ QObject subclass fail to assign into a QObject list, e.g.
    # 'Cannot assign object of type "qqsfpm::QQmlSortFilterProxyModel" ... expected "QObject"'.
    # Keep this ahead of -Wl,-as-needed; it costs no optimisation (LTO stays on).
    switch("passL", "-fPIC")
    # don't link libraries we're not actually using
    switch("passL", "-Wl,-as-needed")
    # dynamically link these libs, since we're opting out of dlopen()
    switch("passL", "-l:libcrypto.so.3")
    switch("passL", "-l:libssl.so.3")
    switch("debugger", "native") # passes "-g" to the C compiler
  else:
    echo "Building for OS: " & hostOS
    switch("passL", "-Wl,-as-needed")
    switch("dynlibOverrideAll") # don't use dlopen()

  switch("define", "chronicles_line_numbers") # useful when debugging=
  switch("define", "chronicles_timestamps=RfcUtcTime")
  switch("define", "chronicles_sinks=textlines[stdout],textlines[file,nocolors]")
  switch("define", "chronicles_runtime_filtering=on")
  switch("define", "chronicles_default_output_device=dynamic")
  switch("define", "chronicles_log_level=trace")

  # Compatibility include path for the pinned (Qt 6.4-generated) nim-seaqt
  # bindings: gen_qvariant.cpp does `#include <QVariantConstPointer>`, a convenience
  # header Qt removed after 6.4 (absent in 6.11+). seaqt_compat/ is APP-owned and
  # provides a shim of that name so the *generated code stays pristine* and still
  # compiles on newer Qt. Global passC flags reach {.compile.}'d store sources, so
  # this works unchanged for the nimble-store copy (0012 spike Q3).
  switch("passC", "-I" & thisDir() & "/seaqt_compat")

  when defined(ios) or defined(macosx):
    switch("passC", "-Wno-error=implicit-function-declaration")

  switch("passC", "-fno-omit-frame-pointer")
  switch("passL", "-fno-omit-frame-pointer")
  # The compiler doth protest too much, methinks, about all these cases where it can't
  # do its (N)RVO pass: https://github.com/nim-lang/RFCs/issues/230
  switch("warning", "ObservableStores:off")

  # Too many false positives for "Warning: method has lock level <unknown>, but another method has 0 [LockLevel]"
  switch("warning", "LockLevel:off")

  # No clean workaround for this warning in certain cases, waiting for better upstream support
  switch("warning", "BareExcept:off")

  # We assume this as a good practive to keep `else` even if all cases are covered
  switch("warning", "UnreachableElse:off")

  when defined(gcRefc):
    # Those are popular to miss in our app, and quickly make build log unreadable, so we want to prevent them
    switch("warningAsError", "UseBase:on")
    switch("warningAsError", "UnusedImport:on")
    switch("warningAsError", "Deprecated:on")
    switch("warningAsError", "HoleEnumConv:on")

  # Workaround for https://github.com/nim-lang/Nim/issues/23429
  switch("warning", "UseBase:on")
  switch("warning", "UnusedImport:on")
  switch("warning", "Deprecated:on")
  switch("warning", "HoleEnumConv:on")

  when defined(gcc):
    # GCC 14+ introduces new strictness for pointer types that not all nim libraries are compatible with
    switch("passc", "-Wno-error=incompatible-pointer-types")

  # https://github.com/rui314/mold
  when findExe("mold").len > 0 and defined(linux):
    switch("passL", "-fuse-ld=mold")

  switch("define", "reRepRangeLimit=256")

  # --- the desktop client's full flag set (issue 0013 phase A) ---------------
  if isDesktopClient:
    let repo = thisDir()

    # Every make-exported value is env-or-derived: env wins when present
    # (the make path), otherwise the same value is derived here (nimble/bare
    # paths). STATUS_BUILD_ENV_ASSERT=1 turns silent preference into a hard
    # comparison — the bring-up parity check.
    proc envOr(name, derived: string): string =
      let env = getEnv(name)
      if env.len == 0:
        return derived
      if getEnv("STATUS_BUILD_ENV_ASSERT") == "1" and env != derived:
        statusEnvFail "env/derived parity broken for " & name &
          ":\n  exported: " & env & "\n  derived:  " & derived
      env

    # make exports MACOSX_DEPLOYMENT_TARGET=14.0 (variables block); clang
    # reads it at LINK time and it decides ObjC-metadata section placement
    # (__DATA vs __DATA_CONST) — without it the nimble/bare link targets the
    # host OS and the binaries diverge. putEnv propagates to the linker
    # subprocess. Keep in sync with the Makefile + the version-min passC.
    if hostOS == "macosx" and getEnv("MACOSX_DEPLOYMENT_TARGET").len == 0:
      putEnv("MACOSX_DEPLOYMENT_TARGET", "14.0")

    # (release/debug flavor is set at the top of this file — order vs
    # debugger:native matters.)
    switch("mm", "orc")
    switch("define", "useMalloc")
    switch("outdir", repo / "bin")

    # Cross-arch desktop (an x86_64 Qt kit on an arm64 mac) keeps the make
    # rule's contract: exporting QT_ARCH=x86_64 selects the cross build.
    if hostOS == "macosx" and hostCPU == "arm64" and
        getEnv("QT_ARCH").len > 0 and getEnv("QT_ARCH") != "arm64":
      switch("cpu", "amd64")
      switch("os", "MacOSX")
      switch("passL", "-arch x86_64")
      switch("passC", "-arch x86_64")

    # One qmake subprocess per client compile (full -query dump); everything
    # Qt-shaped derives from it.
    let qmake = qmakeExe()
    let qdump = qmakeQueryAll(qmake)
    let qtLibDir = envOr("QT_LIBDIR", qdump.qmakeProp("QT_INSTALL_LIBS"))
    let qtVersion = qdump.qmakeProp("QT_VERSION")
    let qtPrefix = qdump.qmakeProp("QT_INSTALL_PREFIX")

    # Artifact locations follow the develop-mode overlay exactly like the
    # Makefiles do (nimble.overlay → scratch copy vs vendor checkout).
    let sgRoot = statusgoBuildRoot()
    let statusgoLibDir = envOr("STATUSGO_LIBDIR", sgRoot / "build/bin")
    let nimsdsLibDir = envOr("NIMSDS_LIBDIR", sgRoot / ".sds-build/build")
    let statusqInstall = envOr("STATUSQ_INSTALL_PATH", repo / "bin")
    let statusqLibPath = statusqInstall / "StatusQ"
    let statusqExtraLibs = repo / "ui/StatusQ/build/Qt" & qtVersion & "/lib"
    let keycardLibDir = envOr("STATUSKEYCARD_QT_LIBDIR",
      repo / "build/status-keycard-qt" / (if hostOS == "macosx": "macos" else: "linux"))
    let dosLibDir = envOr("DOTHERSIDE_LIBDIR",
      repo / "vendor/DOtherSide/build/Qt" & qtVersion & "/lib")
    let qrcodegen = repo / "vendor/QR-Code-generator/c/libqrcodegen.a"

    # seaqt resolves Qt at compile time via gorge("pkg-config Qt6..."): the
    # make path exports the wrapper env (vendor/prl-to-pc/qt-pkgconfig.mk);
    # off-make paths get the identical environment injected here — putEnv in
    # config.nims propagates to every compile-time gorge of this nim process.
    let pcWrapperDir = repo / "vendor/prl-to-pc/.pcwrap"
    let pcKit = qtPrefix.lastPathPart
    let pcVer = qtPrefix.parentDir.lastPathPart
    let pcFileDir = repo / "vendor/prl-to-pc" / pcVer / pcKit / "lib/pkgconfig"
    if getEnv("PKG_CONFIG_PATH").len == 0:
      if not fileExists(pcWrapperDir / "pkg-config"):
        statusEnvFail "the Qt pkg-config wrapper is missing (" &
          pcWrapperDir / "pkg-config" & ").\nRun `make qt-pkgconfig` once — " &
          "`nim app status.nims` and `nimble build` do this for you."
      if not dirExists(pcFileDir):
        statusEnvFail "no committed Qt .pc tree for this kit (" & pcFileDir &
          ").\nGenerate + commit it with `make qt-pkgconfig-generate` " &
          "(see vendor/prl-to-pc/qt-pkgconfig.mk)."
      putEnv("PKG_CONFIG_PATH", pcFileDir)
      putEnv("PKG_CONFIG_PREFIX_OVERRIDE", "Qt*=" & qtPrefix)
      putEnv("PATH", pcWrapperDir & ":" & getEnv("PATH"))

    # App version defines (previously injected by make's recipe): derived so
    # every path agrees. DESKTOP_VERSION intentionally skips version.sh's
    # `git fetch --tags` (a per-compile network call); make still fetches on
    # its own schedule for packaging.
    proc gitOut(args: string): string =
      let (output, rc) = gorgeEx("git -C " & quoteShell(repo) & " " & args)
      if rc == 0: output.strip else: ""
    switch("define", "DESKTOP_VERSION=" & gitOut("describe --tags"))
    switch("define", "GIT_COMMIT=" & gitOut("log --pretty=format:%h -n 1"))
    var statusgoVersion = ""
    if statusgoDeveloped():
      let (v, rc) = gorgeEx("make -C " & quoteShell(repo / "vendor/status-go") &
        " version -s")
      if rc == 0: statusgoVersion = v.strip
    elif fileExists(repo / "nimble.paths"):
      # Pinned store copies have no .git: the version is the pin revision,
      # recorded in the store entry's nimblemeta.json (same derivation as the
      # Makefile's STATUSGO_VERSION).
      for line in readFile(repo / "nimble.paths").splitLines:
        const pre = "--path:\""
        if line.startsWith(pre) and (DirSep & "pkgs2" & DirSep & "statusgo-") in line:
          let root = line[pre.len .. ^2]
          let meta = root / "nimblemeta.json"
          if fileExists(meta):
            for mline in readFile(meta).splitLines:
              if "\"vcsRevision\"" in mline:
                let rev = mline.split('"')[3]
                statusgoVersion = rev[0 ..< min(10, rev.len)]
                break
          break
    switch("define", "STATUSGO_VERSION=" & statusgoVersion)

    # Resource-layout / optional make knobs (exported by make; defaults match
    # the dev build).
    for tok in getEnv("RESOURCES_LAYOUT", "-d:development").splitWhitespace:
      if tok.startsWith("-d:"):
        switch("define", tok[3 .. ^1])
      else:
        statusEnvFail "unsupported RESOURCES_LAYOUT token: " & tok
    let kdfIterations = getEnv("KDF_ITERATIONS")
    if kdfIterations.len > 0 and kdfIterations != "0":
      switch("define", "KDF_ITERATIONS=" & kdfIterations)
    if getEnv("OUTPUT_CSV") == "true":
      switch("define", "output_csv")

    # Link inputs, in the order the make recipe used to pass them.
    if hostOS == "macosx":
      switch("passL", "-framework Foundation -framework AppKit -framework Security -framework IOKit -framework CoreServices -framework LocalAuthentication")
      # Fix for failures due to 'can't allocate code signature data for'
      switch("passL", "-headerpad_max_install_names")
      switch("passL", "-F" & qtLibDir)
    else:
      switch("passL", "-L" & qtLibDir)
    switch("passL", dosLibDir / "libDOtherSideStatic.a")
    # The Qt modules the app links beyond what the seaqt bindings pull in
    # themselves (the former QT_SEAQT_EXTRA_LIBS make var).
    let (seaqtQtLibs, seaqtRc) = gorgeEx(
      "pkg-config --libs Qt6Core Qt6Qml Qt6Gui Qt6Quick Qt6QuickControls2 " &
      "Qt6Widgets Qt6Svg Qt6Multimedia Qt6WebView Qt6WebChannel")
    if seaqtRc != 0:
      statusEnvFail "pkg-config failed to resolve the Qt link libraries:\n" &
        seaqtQtLibs & "\nIs the committed .pc tree present for this kit (" &
        pcFileDir & ")?"
    switch("passL", seaqtQtLibs)
    switch("passL", "-L" & statusgoLibDir)
    switch("passL", "-lstatus")
    switch("passL", "-L" & statusqLibPath)
    switch("passL", "-L" & statusqExtraLibs)
    switch("passL", "-lStatusQ")
    switch("passL", "-L" & keycardLibDir)
    switch("passL", "-lstatus-keycard-qt")
    switch("passL", qrcodegen)
    switch("passL", "-lm")
    switch("passL", "-L" & nimsdsLibDir)
    switch("passL", "-lsds")

    # rpaths (macOS): the four the make path always baked, plus libsds and
    # StatusQ's cmake lib dir so the bare binary resolves every @rpath
    # dependency without DYLD_LIBRARY_PATH (issue 0013 phase C groundwork;
    # macdeployqt rewrites rpaths when bundling, so packaging is unaffected).
    if hostOS == "macosx":
      for rpath in [qtLibDir, statusgoLibDir, keycardLibDir, statusqLibPath,
                    nimsdsLibDir, statusqExtraLibs]:
        switch("passL", "-rpath" & " " & rpath)
