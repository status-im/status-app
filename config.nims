# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

import std/os
import std/strutils

# Kit and overlay discovery, the same procs the driver (status.nims) uses, so
# derived values cannot drift from what the driver validates.
include "status_env.nims"

# Everything below is app-specific — link inputs relative to the app root,
# rpath flags from app env vars, chronicles defines, cache layout — and would
# poison a dependency's own build. If the dependency store ever sits inside the
# repo (a `--localdeps` run creates nimbledeps/), Nim's parent-dir config walk
# hands those compiles this file, so apply it only to this project.
if not projectPath().startsWith(thisDir() / "nimbledeps"):
  # nimble 0.22.3 emits unusable nimble.paths entries for srcDir-hoisted store
  # copies (isaac, nimqml), and the shape varies by run: the setup that
  # materializes the copy hoists the modules to the entry root and emits that
  # root, while a warm re-setup emits root/src, which the hoisted copy has no
  # longer. Point at whichever directory actually holds the modules; the entry
  # names carry a hash suffix that changes with the pins, hence the scan.
  when withDir(thisDir(), system.fileExists("nimble.paths")):
    for line in readFile(thisDir() & "/nimble.paths").splitLines:
      let entry = line.strip.replace("--path:", "").strip(chars = {'"'})
      for pkg in ["isaac", "nimqml"]:
        if (DirSep & pkg & "-") in entry:
          if dirExists(entry & "/src"):
            switch("path", entry & "/src")
          elif entry.endsWith(DirSep & "src") and not dirExists(entry):
            switch("path", entry[0 ..< entry.len - 4])

  # Nested-checkout guard: when this checkout sits inside another
  # status-desktop checkout, Nim's parent-dir config walk puts the enclosing
  # checkout's src on the module search path (its nim.cfg says `path = "src"`).
  # A command-line --path is processed before configs, so on a compile that
  # passes our src that way (nimble's bin compile) the ancestor's entry
  # outranks it and the build silently compiles the other checkout: exclude
  # every ancestor's src explicitly.
  #
  # The same walk evaluates every ancestor's config.nims, and a checkout
  # without the rpath empty-env guard emits a bare `-rpath` per unset
  # variable, which ld mis-parses (it eats the next flag: "cannot open file:
  # /StatusQ"). A config cannot undo an ancestor's passL flags, so fail fast
  # with the remedy.
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
          "  - build via `make run` / `./status app` (they export the " &
          "env), or\n  - export the four variables above before `nimble build/run`."

  # The status_go wrapper (shipped inside the statusgo package) auto-links the
  # static libstatus/libsds it builds for standalone consumers. This app links
  # the shared flavors with its own explicit flags, so opt out.
  switch("define", "statusGoNoAutoLink")

  # --- desktop-client detection ----------------------------------------------
  # The client compile gets its full flag set here, so every front door (the
  # driver, nimble's bin compile, a bare `nim c src/nim_status_client.nim`)
  # produces the same build. Every value is env-or-derived: an exported value
  # wins when present (STATUS_BUILD_ENV_ASSERT=1 verifies derived == exported),
  # otherwise the same value is derived from the repo layout,
  # nimble.paths/nimble.overlay and `qmake -query`.
  #
  # This block owns the HOST build on every platform, Windows included; mobile
  # client compiles (--os:ios/--os:android) keep their make-owned flag sets.
  let isDesktopClient = projectPath().splitFile.name == "nim_status_client" and
      not (defined(ios) or defined(android))
  # Release is the dev-build flavor on every path: nimble's bin compile passes
  # -d:release itself, make exports INCLUDE_DEBUG_SYMBOLS.
  let clientRelease = isDesktopClient and getEnv("INCLUDE_DEBUG_SYMBOLS") != "true"

  # Keep a separate nimcache per USE_SIMULATED_KEYCARD mode. That flag toggles -d:useSimulatedKeycard,
  # which adds/removes the KeycardTest* imports from libstatus-keycard-qt; sharing one cache let stale
  # (simulated) codegen leak into a non-simulated build -> dyld "Symbol not found: _KeycardTestCreateCard".
  # The define itself is switched below, from USE_SIMULATED_KEYCARD, so the
  # env var decides the cache too.
  let simulatedKeycard = defined(useSimulatedKeycard) or
      getEnv("USE_SIMULATED_KEYCARD") == "true"
  let kcSuffix = if simulatedKeycard: "-simkeycard" else: ""
  if defined(release) or clientRelease:
    switch("nimcache", "nimcache/release" & kcSuffix & "/$projectName")
  else:
    switch("nimcache", "nimcache/debug" & kcSuffix & "/$projectName")

  # Flavor selection must precede the per-OS block: -d:release also flips
  # debug-info defaults, so it has to be processed before switch("debugger",
  # "native") re-enables them — the order a command-line -d:release produces.
  # Setting it afterwards silently strips the binary's debug map.
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
    # Guard against empty env vars (e.g. nimble setup compiling dep tools): an
    # empty value would emit a bare "-rpath " (no path), which the linker
    # mis-parses — it consumes the next -rpath flag as its argument and leaves a
    # real path dangling as an input file ("ld: file cannot be mmap()ed").
    # The desktop client gets env-or-derived rpaths in its own block below;
    # these arms cover every other compile.
    if not isDesktopClient:
      for rpathDir in [getEnv("QT_LIBDIR"), getEnv("STATUSGO_LIBDIR"), getEnv("STATUSKEYCARD_QT_LIBDIR")]:
        if rpathDir.len > 0:
          switch("passL", "-rpath " & rpathDir)
      let statusqInstallPath = getEnv("STATUSQ_INSTALL_PATH")
      if statusqInstallPath.len > 0:
        switch("passL", "-rpath " & statusqInstallPath & "/StatusQ")
    # statically link these libs (absolute: the link must not depend on the
    # invoker's cwd)
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

  # Compatibility include path for the pinned (Qt 6.8-generated) nim-seaqt
  # bindings: gen_qvariant.cpp does `#include <QVariantConstPointer>`, a convenience
  # header Qt removed after 6.4 (absent in 6.11+). seaqt_compat/ is app-owned and
  # provides a shim of that name so the *generated code stays pristine* and still
  # compiles on newer Qt. Global passC flags reach {.compile.}'d store sources, so
  # this applies to the read-only store copy too.
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

  # --- the desktop client's full flag set -------------------------------------
  if isDesktopClient:
    let repo = thisDir()

    # Env wins when present, otherwise the same value is derived here.
    # STATUS_BUILD_ENV_ASSERT=1 turns that preference into a hard comparison.
    proc envOr(name, derived: string): string =
      let env = getEnv(name)
      if env.len == 0:
        return derived
      if getEnv("STATUS_BUILD_ENV_ASSERT") == "1" and env != derived:
        statusEnvFail "env/derived parity broken for " & name &
          ":\n  exported: " & env & "\n  derived:  " & derived
      env

    # clang reads MACOSX_DEPLOYMENT_TARGET at LINK time and it decides
    # ObjC-metadata section placement (__DATA vs __DATA_CONST); without it the
    # link targets the host OS instead. putEnv propagates to the linker
    # subprocess. Keep in sync with the Makefile and the version-min passC.
    if hostOS == "macosx" and getEnv("MACOSX_DEPLOYMENT_TARGET").len == 0:
      putEnv("MACOSX_DEPLOYMENT_TARGET", "14.0")

    # (release/debug flavor is set at the top of this file: the order against
    # debugger:native matters.)
    switch("mm", "orc")
    switch("define", "useMalloc")
    switch("outdir", repo / "bin")

    # Cross-arch desktop: exporting QT_ARCH=x86_64 on an arm64 mac selects the
    # x86_64 Qt kit's build.
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

    # Artifact locations follow the develop-mode overlay, like the Makefiles.
    # On Windows cmake writes shared libraries into a per-config subdirectory,
    # so StatusQ and status-keycard-qt gain a `/<BuildType>` leg;
    # `winCfgSuffix()` and `keycardLibDir()` come from status_env.nims, which
    # the driver uses for the same directories.
    let winCfg = winCfgSuffix()
    let sgRoot = statusgoBuildRoot()
    let statusgoLibDir = envOr("STATUSGO_LIBDIR", sgRoot / "build/bin")
    let nimsdsLibDir = envOr("NIMSDS_LIBDIR", sgRoot / ".sds-build/build")
    let statusqInstall = envOr("STATUSQ_INSTALL_PATH", repo / "bin")
    let statusqBuild = repo / "ui/StatusQ/build/Qt" & qtVersion
    let statusqLibPath =
      if hostOS == "windows": statusqBuild / "lib" & winCfg
      else: statusqInstall / "StatusQ"
    let statusqExtraLibs = statusqBuild / "lib"
    let keycardDefault = keycardLibDir()   # status_env.nims, shared with the driver
    let keycardLibDir = envOr("STATUSKEYCARD_QT_LIBDIR", keycardDefault)

    # seaqt resolves Qt at compile time via gorge("pkg-config Qt6..."), and
    # prl-to-pc owns the environment that makes that resolve the active kit.
    # This file only replays the answer the driver cached: no .pc path, no kit,
    # no Qt version, and no assumption that a wrapper exists (System-mode kits
    # ship usable .pc and get none). putEnv here propagates to every
    # compile-time gorge of this nim process.
    applyQtPkgConfigEnv(qmake, qtPrefix)

    # App version defines, derived so every front door agrees. DESKTOP_VERSION
    # deliberately skips version.sh's `git fetch --tags`, a per-compile network
    # call; make still fetches on its own schedule for packaging.
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
      # recorded in the store entry's nimblemeta.json (the Makefile's
      # STATUSGO_VERSION derives it the same way).
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

    # Resource layout and the optional knobs; the defaults are the dev build's.
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
    # QML debugging, the monitoring tool and the simulated keycard. Each is a
    # clientFlagEnv entry in the driver, so flipping one relinks the client.
    if qmlDebug():
      switch("define", "qmldebug")
      switch("define", "qmlDebugPort=" & getEnv("QML_DEBUG_PORT", "49152"))
      switch("passC", "-DQT_QML_DEBUG")
    if getEnv("MONITORING", "false") != "false":
      switch("define", "monitoring")
    if simulatedKeycard:
      switch("define", "useSimulatedKeycard")

    if hostOS == "windows":
      # --- the Windows client's flag set ------------------------------------
      # The client links Qt's MSVC build, so it is compiled with clang
      # targeting the MSVC ABI and linked with lld-link. These flags apply to
      # the client only: `src/nim_windows_launcher.nim` is built with the
      # default mingw/gcc toolchain, which is why they live inside
      # `isDesktopClient`. A debug Windows client must not be link-time
      # optimized, so lto follows the release flavor.
      if clientRelease:
        switch("define", "lto")
      switch("define", "sslVersion=3-x64")
      switch("cc", "clang")
      let realClang = findExe("clang")
      if realClang.len == 0:
        statusEnvFail "the Windows client is compiled with clang (MSVC ABI, to" &
          " link Qt's msvc build) but no `clang` is on PATH."
      switch("clang.exe", realClang)
      switch("clang.linkerexe", realClang)
      switch("passC", "--target=x86_64-pc-windows-msvc -fms-runtime-lib=dll")
      switch("passL", "--target=x86_64-pc-windows-msvc -fuse-ld=lld -fms-runtime-lib=dll")
      # clang (--target=*-windows-msvc) locates the MSVC toolchain and Windows
      # SDK itself via vswhere, but its env probe takes precedence over that:
      # a LIB/INCLUDE/LIBPATH/VCINSTALLDIR inherited from the shell overrides
      # it with stale paths and breaks the link ("could not open
      # 'msvcrt.lib'"), even a valid VCINSTALLDIR. Strip them so clang always
      # self-detects; delEnv from a config propagates to the compiler's own
      # children.
      for staleVar in ["LIB", "INCLUDE", "LIBPATH", "VCINSTALLDIR"]:
        delEnv(staleVar)
      # lld-link links the IMPORT library, not the .dll (passing the .dll gives
      # "bad file type"). The driver synthesizes one per Go c-shared lib
      # (genImportLib), named status.lib / sds.lib to match the -l flags
      # below.
      switch("passL", "-L" & statusgoLibDir)
      switch("passL", "-lstatus")
      switch("passL", "-L" & statusqLibPath)
      switch("passL", "-L" & statusqExtraLibs)
      switch("passL", "-lStatusQ")
      switch("passL", "-L" & keycardLibDir)
      switch("passL", "-lstatus-keycard-qt")
      # No -lm: math lives in the CRT and lld-link has no `m.lib`.
      switch("passL", "-L" & nimsdsLibDir)
      switch("passL", "-lsds")
      switch("passL", "-luser32")
    else:
      if hostOS == "macosx":
        switch("passL", "-framework Foundation -framework AppKit -framework Security -framework IOKit -framework CoreServices -framework LocalAuthentication")
        # Fix for failures due to 'can't allocate code signature data for'
        switch("passL", "-headerpad_max_install_names")
        switch("passL", "-F" & qtLibDir)
      else:
        switch("passL", "-L" & qtLibDir)
        if hostOS == "linux":
          # GNU ld resolves transitive shared-lib deps (libStatusQ.so ->
          # libQt6WebEngineQuick.so.6) through -rpath-link, not -L; without it
          # linking fails when Qt lives outside the system library paths.
          switch("passL", "-Wl,-rpath-link," & qtLibDir)
      # The Qt modules the app links beyond what the seaqt bindings pull in
      # themselves; the Windows arm above does not link these. status_env.nims
      # owns the definition, and the driver's `tests` task links the same set.
      switch("passL", qtSeaqtExtraLibs())
      switch("passL", "-L" & statusgoLibDir)
      switch("passL", "-lstatus")
      switch("passL", "-L" & statusqLibPath)
      switch("passL", "-L" & statusqExtraLibs)
      switch("passL", "-lStatusQ")
      switch("passL", "-L" & keycardLibDir)
      switch("passL", "-lstatus-keycard-qt")
      # QR-Code-generator is {.compile.}d by src/app/global/utils/qrcodegen.nim:
      # no static library, no link flag. -lm stays, its C source needs libm.
      switch("passL", "-lm")
      switch("passL", "-L" & nimsdsLibDir)
      switch("passL", "-lsds")

    # rpaths (macOS): every directory the bare binary must resolve an @rpath
    # dependency from without DYLD_LIBRARY_PATH. macdeployqt rewrites rpaths
    # when bundling, so packaging is unaffected.
    if hostOS == "macosx":
      for rpath in [qtLibDir, statusgoLibDir, keycardLibDir, statusqLibPath,
                    nimsdsLibDir, statusqExtraLibs]:
        switch("passL", "-rpath" & " " & rpath)
