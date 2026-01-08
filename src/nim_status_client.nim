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

import app/global/global_singleton
import app/global/local_app_settings
import app/boot/app_controller

featureGuard KEYCARD_ENABLED:
  import keycard_go

  var keycardServiceQObjPointer: pointer
  var keycardServiceV2QObjPointer: pointer

when defined(macosx) and defined(arm64):
  import posix

when defined(windows):
    {.link: "../status.o".}

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
  # Outputs logs in the node tab
  for output in defaultChroniclesStream.outputs.fields():
    when output is DynamicOutput:
      output.writer =
        proc (logLevel: LogLevel, msg: LogOutputStr) {.gcsafe, raises: [].} =
          try:
            if signalsManagerQObjPointer != nil:
              signal_handler(signalsManagerQObjPointer, ($(%* {"type": "chronicles-log", "event": msg})).cstring, "receiveChroniclesLogEvent")
          except:
            logLoggingFailure(cstring(msg), getCurrentException())
    elif output is FileOutput:
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
    if signalsManagerQObjPointer != nil:
      signal_handler(signalsManagerQObjPointer, p0, "receiveSignal")
  status_go.setSignalEventCallback(callbackStatusGo)

  featureGuard KEYCARD_ENABLED:
    var callbackKeycardGo: keycard_go.KeycardSignalCallback = proc(p0: cstring) {.cdecl.} =
      if keycardServiceV2QObjPointer != nil:
        signal_handler(keycardServiceV2QObjPointer, p0, "receiveKeycardSignalV2")
      if keycardServiceQObjPointer != nil:
        signal_handler(keycardServiceQObjPointer, p0, "receiveKeycardSignal")

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
  initializeWebView()
  enableHDPI(uiScaleFilePath)
  tryEnableThreadedRenderer()

  let imageCert = imageServerTLSCert()
  installSelfSignedCertificate(imageCert)

  when defined(android) or defined(ios):
    # Apply dynamic scaling based on device width and DPI. Defaults to 1 for desktop.
    proc statusq_getMobileUIScaleFactor(baseWidth: cfloat, baseDpi: cfloat, baseScale: cfloat): cfloat {.importc, cdecl.}
    var scaleFactor = statusq_getMobileUIScaleFactor(1080.0, 480.0, 0.8)
    # Clamp scale factor between 0.8 and 1.0
    scaleFactor = max(0.8, min(1.0, scaleFactor))

    putEnv("QT_SCALE_FACTOR", $scaleFactor)

  let app = newQGuiApplication()

  # force default language ("en") if not "Settings/Advanced/Enable translations"
  if not singletonInstance.localAppSettings.getTranslationsEnabled():
    if singletonInstance.localAppSettings.getLanguage() != DEFAULT_LAS_KEY_LANGUAGE:
      singletonInstance.localAppSettings.setLanguage(DEFAULT_LAS_KEY_LANGUAGE)

  let singleInstance = newSingleInstance(($keccak256.digest(DATADIR))[0..31], openUri)
  let urlSchemeEvent = newStatusUrlSchemeEventObject()
  # init url manager before app controller
  statusFoundation.initUrlSchemeManager(urlSchemeEvent, singleInstance, openUri)

  let appController = newAppController(statusFoundation)
  let networkAccessFactory = newQNetworkAccessManagerFactory(TMPDIR & "netcache")

  let isProductionQVariant = newQVariant(if defined(production): true else: false)
  let isExperimentalQVariant = newQVariant(isExperimental)
  let signalsManagerQVariant = newQVariant(statusFoundation.signalsManager)

  QResource.registerResource(app.applicationDirPath & resourcesPath)

  if not main_constants.IS_MACOS:
    app.icon(app.applicationDirPath & statusAppIconPath)

  prepareLogging()
  installMessageHandler(logHandlerCallback)

  when defined(USE_QML_SERVER):
    echo "Setting remote import path: ", remoteImportPath
    singletonInstance.engine.addImportPath(remoteImportPath);
  else:
    singletonInstance.engine.addImportPath("qrc:/")
    singletonInstance.engine.addImportPath("qrc:/./imports")
    singletonInstance.engine.addImportPath("qrc:/./app");

  singletonInstance.engine.setNetworkAccessManagerFactory(networkAccessFactory)
  singletonInstance.engine.setRootContextProperty("uiScaleFilePath", newQVariant(uiScaleFilePath))
  singletonInstance.engine.setRootContextProperty("singleInstance", newQVariant(singleInstance))
  singletonInstance.engine.setRootContextProperty("isExperimental", isExperimentalQVariant)
  singletonInstance.engine.setRootContextProperty("fleetSelectionEnabled", newQVariant(FLEET_SELECTION_ENABLED))
  singletonInstance.engine.setRootContextProperty("signals", signalsManagerQVariant)
  singletonInstance.engine.setRootContextProperty("production", isProductionQVariant)

  # Ensure we have the featureFlags instance available from the start
  singletonInstance.engine.setRootContextProperty("featureFlagsRootContextProperty", newQVariant(singletonInstance.featureFlags()))

  statusq_registerQmlTypes()

  app.installEventFilter(urlSchemeEvent)

  defer:
    info "shutting down..."
    signalsManagerQObjPointer = nil
    featureGuard KEYCARD_ENABLED:
      keycardServiceQObjPointer = nil
      keycardServiceV2QObjPointer = nil
    isProductionQVariant.delete()
    isExperimentalQVariant.delete()
    signalsManagerQVariant.delete()
    networkAccessFactory.delete()
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
    keycardServiceQObjPointer = cast[pointer](appController.keycardService.vptr)

  setupRemoteSignalsHandling()

  info "app info", version=APP_VERSION, commit=GIT_COMMIT, currentDateTime=now()

  info "starting application controller..."
  appController.start()

  info "starting application..."
  app.exec()

when isMainModule:
  mainProc()
