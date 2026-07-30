# Keep a separate nimcache per USE_SIMULATED_KEYCARD mode. That flag toggles -d:useSimulatedKeycard,
# which adds/removes the KeycardTest* imports from libstatus-keycard-qt; sharing one cache let stale
# (simulated) codegen leak into a non-simulated build -> dyld "Symbol not found: _KeycardTestCreateCard".
let kcSuffix = when defined(useSimulatedKeycard): "-simkeycard" else: ""
if defined(release):
  switch("nimcache", "nimcache/release" & kcSuffix & "/$projectName")
else:
  switch("nimcache", "nimcache/debug" & kcSuffix & "/$projectName")

--threads:on
--opt:speed # -O3
--define:ssl # needed by the stdlib to enable SSL procedures
--define:useOpenSSL3
--parallelBuild:0  # 0 == auto nr. of cores

if hostOS == "macosx":
  echo "Building for macOS"
  --dynlibOverrideAll # don't use dlopen()
  --tlsEmulation:off
  --debugger:native # passes "-g" to the C compiler
  switch("passL", "-lstdc++")
  # DYLD_LIBRARY_PATH doesn't always work when running/packaging so set rpath
  # note: macdeployqt rewrites rpath appropriately when building the .app bundle
  # Guard against empty env vars: an empty value would emit a bare "-rpath " (no
  # path), which the linker mis-parses — it consumes the next -rpath flag as its
  # argument and leaves a real path dangling as an input file
  # ("ld: file cannot be mmap()ed"). Only emit the flag when the dir is non-empty.
  for rpathDir in [getEnv("QT_LIBDIR"), getEnv("STATUSGO_LIBDIR"), getEnv("STATUSKEYCARD_QT_LIBDIR")]:
    if rpathDir.len > 0:
      switch("passL", "-rpath " & rpathDir)
  let statusqInstallPath = getEnv("STATUSQ_INSTALL_PATH")
  if statusqInstallPath.len > 0:
    switch("passL", "-rpath " & statusqInstallPath & "/StatusQ")
  # statically link these libs
  switch("passL", "bottles/openssl@3/lib/libcrypto.a")
  switch("passL", "bottles/openssl@3/lib/libssl.a")
  # https://code.videolan.org/videolan/VLCKit/-/issues/232
  switch("passL", "-Wl,-no_compact_unwind")
  # set the minimum supported macOS version to 14.0
  switch("passC", "-mmacosx-version-min=14.0")
elif hostOS == "windows":
  echo "Building for Windows"
  --app:gui
  --tlsEmulation:off
  when defined(debug):
    --debugger:native
    switch("passL", "-g")
  # `-Wl,-as-needed` is a GNU-ld flag. The main client is built with clang-cl
  # (MSVC ABI) so it can link the MSVC-built Qt; lld-link doesn't understand it.
  # Keep it only for the gcc/mingw builds (e.g. the standalone Windows launcher).
  when defined(gcc):
    switch("passL", "-Wl,-as-needed")
elif hostOS == "linux":
  echo "Building for Linux"
  --dynlibOverrideAll # don't use dlopen()
  # don't link libraries we're not actually using
  switch("passL", "-Wl,-as-needed")
  # dynamically link these libs, since we're opting out of dlopen()
  switch("passL", "-l:libcrypto.so.3")
  switch("passL", "-l:libssl.so.3")
  --debugger:native # passes "-g" to the C compiler
else:
  echo "Building for OS: " & hostOS
  switch("passL", "-Wl,-as-needed")
  --dynlibOverrideAll # don't use dlopen()

--define:chronicles_line_numbers # useful when debugging=
switch("define", "chronicles_timestamps=RfcUtcTime")
switch("define", "chronicles_sinks=textlines[stdout],textlines[file,nocolors]")
switch("define", "chronicles_runtime_filtering=on")
switch("define", "chronicles_default_output_device=dynamic")
switch("define", "chronicles_log_level=trace")

# Compatibility include path for the vendored (Qt 6.4-generated) nim-seaqt
# bindings: gen_qvariant.cpp does `#include <QVariantConstPointer>`, a convenience
# header Qt removed after 6.4 (absent in 6.11+). seaqt_compat/ provides a shim of
# that name so the *generated code stays pristine* and still compiles on newer Qt.
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
