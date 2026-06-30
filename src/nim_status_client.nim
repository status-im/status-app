import
  std/[os, json, strformat, strutils, times],
  nimqml,
  chronicles,
  nimcrypto/keccak,
  regex

import status_go
import app/core/main
import constants as main_constants
import statusq_bridge
import dotherside_ext
import app/global/single_instance

import seaqt/QtGui/gen_qguiapplication
import seaqt/qsslconfiguration
import seaqt/qsslcertificate
import seaqt/QtCore/gen_qnamespace

import app/global/global_singleton
import app/global/local_app_settings
import app/global/app_lifecycle
import app/boot/app_controller

featureGuard KEYCARD_ENABLED:
  import keycard_go

  var keycardServiceV2QObjPointer: pointer

when defined(macosx) and defined(arm64):
  import posix

when defined(useSimulatedKeycard):
  import app_service/service/keycardV2/test_controller
  var keycardTestControllerInstance: KeycardTestController

when defined(windows):
    {.link: "../status.o".}

when defined(ios):
  # nim-seaqt's QGuiApplication/QCoreApplication constructors call
  # commandLineParams() to synthesise Qt's argv. On a --app:staticlib build
  # (iOS) Nim's std/cmdline still compiles paramStr/paramCount, which reference
  # the runtime globals `cmdCount`/`cmdLine`. Those are normally emitted by the
  # C main() Nim generates for executables — but a staticlib has no main(), so
  # the symbols are undefined at the final Xcode link. Define them here (empty:
  # an iOS app has no meaningful argv). Android (--app:lib) doesn't hit this:
  # std/cmdline suppresses that branch for appType == "lib".
  {.emit: """/*INCLUDESECTION*/
int cmdCount = 0;
char** cmdLine = 0;
""".}

when defined(USE_QML_SERVER):
  # get the host OS and localhost IP
  # the host OS is the OS that compiles the app, not the OS that runs the app
  const USE_QML_SERVER{.strdefine.} = "8081"
  const isWindows = gorgeEx("wmic os get Caption").exitCode == 0
  const isMacOS = gorge("sw_vers -productName") == "macOS"
  const localhost = staticExec(
    when isWindows:
      "powershell -Command \"(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetConnectionProfile).InterfaceAlias | Where-Object { $_.IPAddress -notlike '169.*' } | Select-Object -First 1).IPAddress\""
    elif isMacOS:
      "ipconfig getifaddr en0"
    else:
      "hostname -I | cut -d' ' -f1"
  ).strip()

  const remoteImportPath = "http://" & localhost & ":" & USE_QML_SERVER

logScope:
  topics = "status-app"

var signalsManagerQObjPointer: pointer

proc isExperimental(): string =
  result = if getEnv("EXPERIMENTAL") == "1": "1" else: "0" # value explicity passed to avoid trusting input

proc determineResourcePath(): string =
  result = if defined(windows) and defined(production): "/../resources/resources.rcc" else: "/../resources.rcc"

proc determineOpenUri(): string =
  if OPENURI.len > 0:
    result = OPENURI

proc determineStatusAppIconPath(): string =
  if main_constants.IS_MACOS or defined(windows):
    return "" # not used in macOS and Windows

  # update the linux icon
  if defined(production):
    return "/../status.png"

  return "/../status-dev.png"

proc prepareLogging() =
  for output in defaultChroniclesStream.outputs.fields():
    when output is FileOutput:
      let formattedDate = now().format("yyyyMMdd'_'HHmmss")
      let logFile = fmt"app_{formattedDate}.log"
      discard output.open(LOGDIR & logFile, fmAppend)

  let defaultLogLvl = if defined(production): chronicles.LogLevel.INFO else: chronicles.LogLevel.DEBUG
  # default log level can be overriden by LOG_LEVEL env parameter
  let logLvl = try: parseEnum[chronicles.LogLevel](main_constants.LOG_LEVEL)
               except: defaultLogLvl

  setLogLevel(logLvl)

proc setupRemoteSignalsHandling() =
  # Please note that this must use the `cdecl` calling convention because
  # it will be passed as a regular C function to statusgo_backend. This means that
  # we cannot capture any local variables here (we must rely on globals)
  var callbackStatusGo: status_go.SignalCallback = proc(p0: cstring) {.cdecl.} =
    if isShuttingDown(): return
    if signalsManagerQObjPointer != nil:
      signal_handler(signalsManagerQObjPointer, p0, "receiveSignal")
  status_go.setSignalEventCallback(callbackStatusGo)

  featureGuard KEYCARD_ENABLED:
    var callbackKeycardGo: keycard_go.KeycardSignalCallback = proc(p0: cstring) {.cdecl.} =
      if isShuttingDown():
        return
      when defined(useSimulatedKeycard):
        if test_controller.shouldIgnoreKeycardLibSignals():
          return

      if keycardServiceV2QObjPointer != nil:
        signal_handler(keycardServiceV2QObjPointer, p0, "receiveKeycardSignalV2")

    keycard_go.setSignalEventCallback(callbackKeycardGo)

proc ensureDirectories*(dataDir, tmpDir, logDir: string) =
  createDir(dataDir)
  createDir(tmpDir)
  createDir(logDir)

proc logHandlerCallback(messageType: cint, message: cstring, category: cstring, file: cstring, function: cstring, line: cint) {.cdecl, exportc.} =
  # Initialize Nim GC stack bottom for foreign threads
  # https://status-im.github.io/nim-style-guide/interop.html#calling-nim-code-from-other-languages
  when declared(setupForeignThreadGc):
    setupForeignThreadGc()
  when declared(nimGC_setStackBottom):
    var locals {.volatile, noinit.}: pointer
    locals = addr(locals)
    nimGC_setStackBottom(locals)

  var text = $message
  let fileString = $file

  if fileString != "" and text.startsWith(fileString):
    text = text[fileString.len..^1]              # Remove filepath
    text = text.replace(re2"[:0-9]+:\s*", "")  # Remove line, column, colons and space separator

  logScope:
    chroniclesLineNumbers = false
    topics = "qt"
    category = $category
    file = fileString & ":" & $line
    text

  case int(messageType):
    of 0: # QtDebugMsg
      debug "qt message"
    of 1: # QtWarningMsg
      warn "qt warning"
    of 2: # QtCriticalMsg
      error "qt error"
    of 3: # QtFatalMsg
      fatal "qt fatal error"
    of 4: # QtInfoMsg
      info "qt message"
    else:
      warn "qt message of unknown type", messageType = int(messageType)

proc mainProc() =

  when defined(macosx) and defined(arm64):
    var signalStack: cstring = cast[cstring](allocShared(SIGSTKSZ))
    var ss: ptr Stack = cast[ptr Stack](allocShared0(sizeof(Stack)))
    var ss2: ptr Stack = nil
    ss.ss_sp = signalStack
    ss.ss_flags = 0
    ss.ss_size = SIGSTKSZ
    if sigaltstack(ss[], ss2[]) < 0:
        echo("sigaltstack error!")
        quit()

    var sa: ptr Sigaction = cast[ptr Sigaction](allocShared0(sizeof(Sigaction)))
    var sa2: Sigaction

    sa.sa_handler = SIG_DFL
    sa.sa_flags = SA_ONSTACK

    if sigaction(SIGURG, sa[], addr sa2) < 0:
        echo("sigaction error!")
        quit()

  if main_constants.IS_MACOS and defined(production):
    setCurrentDir(getAppDir())

  ensureDirectories(DATADIR, TMPDIR, LOGDIR)

  let isExperimental = isExperimental()
  let resourcesPath = determineResourcePath()
  let openUri = determineOpenUri()
  let statusAppIconPath = determineStatusAppIconPath()

  let statusFoundation = newStatusFoundation()
  let uiScaleFilePath = joinPath(DATADIR, "ui-scale")
  # Required by the WalletConnectSDK view right after creating the QGuiApplication instance
  statusq_initializeWebEngine()
  # Enable HDPI PassThrough rounding policy (replaces dos_qguiapplication_enable_hdpi)
  gen_qguiapplication.QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
    cint(HighDpiScaleFactorRoundingPolicyEnum.PassThrough))
  # Enable threaded renderer (replaces dos_qguiapplication_try_enable_threaded_renderer)
  putEnv("QSG_RENDER_LOOP", "threaded")

  # Install self-signed certificate (replaces dos_add_self_signed_certificate)
  let imageCert = imageServerTLSCert()
  block:
    var defaultConfig = QSslConfiguration.defaultConfiguration()
    var certList = defaultConfig.caCertificates()
    # fromData with no format arg defaults to QSsl::Pem (same as the original dos_add_self_signed_certificate)
    var newCerts = QSslCertificate.fromData(
      imageCert.toOpenArrayByte(0, imageCert.len - 1))
    for c in newCerts.mitems:
      certList.add(move(c))
    var sysCerts = QSslConfiguration.systemCaCertificates()
    for c in sysCerts.mitems:
      certList.add(move(c))
    defaultConfig.setCaCertificates(certList)
    QSslConfiguration.setDefaultConfiguration(defaultConfig)

  let app = newQGuiApplication()
  singletonInstance.setApplication(app)

  let singleInstance = newSingleInstance(($keccak256.digest(DATADIR))[0..31], openUri)
  let urlSchemeEvent = newStatusUrlSchemeEventObject()
  urlSchemeEvent.setInstance()
  # init url manager before app controller
  statusFoundation.initUrlSchemeManager(urlSchemeEvent, singleInstance, openUri)

  let appController = newAppController(statusFoundation)

  let isProductionQVariant = newQVariant(if defined(production): true else: false)
  let isExperimentalQVariant = newQVariant(isExperimental)
  let signalsManagerQVariant = newQVariant(statusFoundation.signalsManager)

  QResource.registerResource(app.applicationDirPath & resourcesPath)

  if not main_constants.IS_MACOS:
    app.icon(app.applicationDirPath & statusAppIconPath)

  prepareLogging()
  statusq_installMessageHandler(logHandlerCallback)

  when defined(USE_QML_SERVER):
    echo "Setting remote import path: ", remoteImportPath
    singletonInstance.engine.addImportPath(remoteImportPath);
  else:
    singletonInstance.engine.addImportPath("qrc:/")
    singletonInstance.engine.addImportPath("qrc:/./imports")
    singletonInstance.engine.addImportPath("qrc:/./app");

  statusq_setupNetworkAccessManagerFactory(singletonInstance.engine.vptr, (TMPDIR & "netcache").cstring)
  singletonInstance.engine.setRootContextProperty("uiScaleFilePath", newQVariant(uiScaleFilePath))
  singletonInstance.engine.setRootContextProperty("singleInstance", newQVariant(singleInstance))
  singletonInstance.engine.setRootContextProperty("isExperimental", isExperimentalQVariant)
  singletonInstance.engine.setRootContextProperty("fleetSelectionEnabled", newQVariant(FLEET_SELECTION_ENABLED))
  singletonInstance.engine.setRootContextProperty("signals", signalsManagerQVariant)
  singletonInstance.engine.setRootContextProperty("production", isProductionQVariant)

  # Ensure we have the featureFlags instance available from the start
  singletonInstance.engine.setRootContextProperty("featureFlagsRootContextProperty", newQVariant(singletonInstance.featureFlags()))

  when defined(useSimulatedKeycard):
    keycardTestControllerInstance = newKeycardTestController()
    singletonInstance.engine.setRootContextProperty("keycardTestController", newQVariant(keycardTestControllerInstance))

  statusq_registerQmlTypes()

  app.installEventFilter(urlSchemeEvent)

  defer:
    info "shutting down..."
    signalsManagerQObjPointer = nil
    featureGuard KEYCARD_ENABLED:
      keycardServiceV2QObjPointer = nil
    isProductionQVariant.delete()
    isExperimentalQVariant.delete()
    signalsManagerQVariant.delete()
    appController.delete()
    statusFoundation.delete()
    singleInstance.delete()
    app.delete()

  featureGuard SINGLE_STATUS_INSTANCE_ENABLED:
    # Checks below must be always after "defer", in case anything fails destructors will freed a memory.
    if singleInstance.secondInstance():
      info "Terminating the app as the second instance"
      quit()

  # We need these global variables in order to be able to access the application
  # from the non-closure callback passed to `statusgo_backend.setSignalEventCallback`
  signalsManagerQObjPointer = cast[pointer](statusFoundation.signalsManager.vptr)
  featureGuard KEYCARD_ENABLED:
    keycardServiceV2QObjPointer = cast[pointer](appController.keycardServiceV2.vptr)

  setupRemoteSignalsHandling()

  info "app info", version=APP_VERSION, commit=GIT_COMMIT, currentDateTime=now()

  info "starting application controller..."
  appController.start()

  info "starting application..."
  app.exec()

when isMainModule:
  mainProc()
