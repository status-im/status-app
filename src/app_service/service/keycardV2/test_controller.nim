import nimqml

when defined(useSimulatedKeycard):
  import std/[os, osproc, strutils, json, locks, streams]
  import chronicles
  import keycard_go
  import constants as status_const
  import rpc
  import app/core/tasks/[qt, threadpool]

  logScope:
    topics = "keycard-simulator-controller"

  const
    KEYCARD_SIMULATOR_DEFAULT_VERSION = "3.2"
    KEYCARD_SIMULATOR_DEFAULT_SIMULATOR_ADDRESS = "127.0.0.1:9025"
    # Relative to the app executable:
    #   macOS   ../Resources/keycard-simulator
    #   Linux   ../share/keycard-simulator
    #   Windows ../resources/keycard-simulator
    KEYCARD_SIMULATOR_BUNDLED_SUBDIRS = [
      "../Resources/keycard-simulator",
      "../share/keycard-simulator",
      "../resources/keycard-simulator",
    ]
    KEYCARD_SIMULATOR_DEV_DIR = "vendor/status-keycard-qt/test/keycard-simulator"

  var ignoreKeycardLibSignals = false # used to avoid triggering of any keycard actions while setting up the test keycard

  proc shouldIgnoreKeycardLibSignals*(): bool =
    return ignoreKeycardLibSignals

  proc resolveSimDir(): string =
    let envDir = getEnv("STATUS_KEYCARD_SIM_DIR")
    if envDir.len > 0:
      return absolutePath(envDir)
    let appDir = getAppDir()
    for sub in KEYCARD_SIMULATOR_BUNDLED_SUBDIRS:
      let candidate = normalizedPath(appDir / sub)
      if dirExists(candidate):
        return candidate
    return absolutePath(KEYCARD_SIMULATOR_DEV_DIR)

  proc readMainClass(simDir, version: string): string =
    let propsPath = simDir / "versions" / version / "version.properties"
    if not fileExists(propsPath):
      return ""
    for line in lines(propsPath):
      let t = line.strip()
      if t.startsWith("mainClass="):
        return t[len("mainClass=") .. ^1].strip()
    return ""

  proc buildClasspath(simDir, version: string): string =
    var entries = @[simDir / "out" / "core", simDir / "versions" / version / "out"]
    for jar in walkFiles(simDir / "libs" / "common" / "*"):
      entries.add(jar)
    for jar in walkFiles(simDir / "versions" / version / "libs" / "*"):
      entries.add(jar)
    entries.join($PathSep)

  proc ensureSimulatorBuilt(simDir: string): string =
    if dirExists(simDir / "out"):
      return ""
    when defined(windows):
      return "keycard simulator not precompiled (out/ missing)"
    else:
      try:
        let p = startProcess("/bin/bash", workingDir = simDir,
          args = @["-c", "./build.sh"], options = {poParentStreams})
        let code = p.waitForExit()
        p.close()
        if code != 0 or not dirExists(simDir / "out"):
          return "keycard simulator build.sh failed"
        return ""
      except CatchableError as e:
        return "failed to run build.sh: " & e.msg

  const CMD_TIMEOUT_MSEC = 10_000

  func subprocessOpts(): set[ProcessOption] =
    when defined(windows):
      {poUsePath, poStdErrToStdOut, poDaemon}
    else:
      {poUsePath, poStdErrToStdOut}

  proc stopProcess(p: Process) =
    if not p.isNil:
      if p.running:
        p.terminate()
      p.close()

  var simProcessLock: Lock
  var startedSimProcess: Process
  simProcessLock.initLock()

  proc setStartedSimProcess(p: Process) =
    {.cast(gcsafe).}:
      acquire(simProcessLock)
      startedSimProcess = p
      release(simProcessLock)

  proc takeStartedSimProcess(): Process =
    {.cast(gcsafe).}:
      acquire(simProcessLock)
      result = startedSimProcess
      startedSimProcess = nil
      release(simProcessLock)

  proc runTimed(cmd: string; args: seq[string]; timeoutMs: int = CMD_TIMEOUT_MSEC):
      tuple[output: string, exitCode: int] =
    var p: Process
    try:
      p = startProcess(cmd, args = args, options = subprocessOpts())
    except CatchableError:
      return ("", 1)
    try:
      result.exitCode = p.waitForExit(timeoutMs)
      try:
        result.output = p.outputStream.readAll()
      except CatchableError:
        result.output = ""
    finally:
      p.close()

  when defined(windows):
    proc addrListensOnPort(addrPort, port: string): bool =
      let colon = addrPort.rfind(':')
      if colon < 0:
        return false
      addrPort.substr(colon + 1) == port

    proc windowsListeningPids(port: string): seq[string] =
      let (netOut, _) = runTimed("netstat", @["-ano", "-p", "TCP"])
      for line in netOut.splitLines():
        let parts = line.splitWhitespace()
        if parts.len >= 5 and parts[0] == "TCP" and parts[^2] == "LISTENING" and
            addrListensOnPort(parts[1], port):
          let pid = parts[^1]
          if pid.len > 0 and pid != "0" and pid notin result:
            result.add(pid)

    proc windowsImageName(pid: string): string =
      let (outp, _) = runTimed("tasklist", @["/FI", "PID eq " & pid, "/FO", "CSV", "/NH"])
      let line = outp.strip()
      if line.startsWith("\""):
        let endq = line.find('"', 1)
        if endq > 1:
          return line[1 ..< endq]
      let comma = line.find(',')
      if comma > 0:
        return line[0 ..< comma]
      return line
  else:
    proc unixListeningPids(port: string): seq[string] =
      let (outp, _) = runTimed("lsof", @["-ti", "tcp:" & port])
      for line in outp.splitLines():
        let pid = line.strip()
        if pid.len > 0 and pid notin result:
          result.add(pid)

    proc unixCommandLine(pid: string): string =
      let (outp, _) = runTimed("ps", @["-p", pid, "-o", "command="])
      return outp.strip()

  template waitPortReleased(listeningPids: untyped, port: string) =
    for _ in 0 ..< 20:
      if listeningPids(port).len == 0:
        break
      sleep(200)

  proc freeSimulatorPort(port: string): string =
    try:
      when defined(windows):
        for pid in windowsListeningPids(port):
          if windowsImageName(pid).toLowerAscii() != "java.exe":
            return "port " & port & " is in use by a non-simulator process (pid " & pid & ")"
          info "Port held by previous simulator — stopping it", port = port, pid = pid
          discard runTimed("taskkill", @["/PID", pid, "/F"])
        waitPortReleased(windowsListeningPids, port)
      else:
        for pid in unixListeningPids(port):
          if "keycardqt" notin unixCommandLine(pid).toLowerAscii():
            return "port " & port & " is in use by a non-simulator process (pid " & pid & ")"
          info "Port held by previous simulator — stopping it", port = port, pid = pid
          discard runTimed("kill", @["-9", pid])
        waitPortReleased(unixListeningPids, port)
      return ""
    except CatchableError as e:
      return "failed to check simulator port: " & e.msg

  when defined(windows):
    proc findJavaExe(): string =
      let home = getEnv("JAVA_HOME")
      if home.len > 0:
        let fromHome = home / "bin" / "java.exe"
        if fileExists(fromHome):
          return fromHome
      result = findExe("java")
      if result.len > 0:
        return result
      let scoopJavaGlobs = [
        getHomeDir() / "scoop" / "shims" / "java.exe",
        "C:/ProgramData/scoop/shims/java.exe",
        getHomeDir() / "scoop" / "apps" / "*" / "current" / "bin" / "java.exe",
        "C:/ProgramData/scoop/apps/*/current/bin/java.exe",
      ]
      for pattern in scoopJavaGlobs:
        if pattern.contains('*'):
          for javaPath in walkFiles(pattern):
            return javaPath
        elif fileExists(pattern):
          return pattern
      const programFilesRoots = [
        "C:/Program Files/Eclipse Adoptium",
        "C:/Program Files/Microsoft",
        "C:/Program Files/Java",
        "C:/Program Files/Zulu",
        "C:/Program Files/Amazon Corretto",
      ]
      for root in programFilesRoots:
        if not dirExists(root):
          continue
        for javaPath in walkFiles(root / "*" / "bin" / "java.exe"):
          return javaPath
      return ""

  proc spawnSimulator(simDir, version, port, mainClass: string): string =
    when defined(windows):
      let portErr = freeSimulatorPort(port)
      if portErr.len > 0:
        error "keycard simulator port unavailable", err = portErr, port = port
        return portErr
    try:
      when defined(windows):
        let javaExe = findJavaExe()
        if javaExe.len == 0:
          error "java not found for keycard simulator"
          return "java not found in PATH or JAVA_HOME; install a JRE >= 11"
        let classpath = buildClasspath(simDir, version)
        let p = startProcess(
          javaExe,
          workingDir = simDir,
          args = @["-noverify", "-cp", classpath, mainClass, port],
          options = subprocessOpts(),
        )
        setStartedSimProcess(p)
      else:
        let p = startProcess(
          "/bin/bash",
          workingDir = simDir,
          args = @["./run.sh", port, version],
          options = subprocessOpts(),
        )
        setStartedSimProcess(p)
      info "starting keycard simulator", dir = simDir, port = port, version = version
      return ""
    except CatchableError as e:
      error "failed to start keycard simulator", err = e.msg
      return "failed to start keycard simulator: " & e.msg

  type
    LoadCardArg = ref object of QObjectTaskArg
      params: JsonNode

    StartSimulatorArg = ref object of QObjectTaskArg
      simDir: string
      version: string
      port: string
      mainClass: string

  proc loadCardTask(argEncoded: string) {.gcsafe, nimcall.} =
    let arg = decode[LoadCardArg](argEncoded)
    var output = %*{"response": "", "error": ""}
    try:
      output["response"] = %* callRPC("Load", arg.params)
    except Exception as e:
      output["error"] = %* e.msg
    arg.finish(output)

  proc startSimulatorTask(argEncoded: string) {.gcsafe, nimcall.} =
    let arg = decode[StartSimulatorArg](argEncoded)
    var failure = ""
    {.cast(gcsafe).}:
      try:
        failure = spawnSimulator(arg.simDir, arg.version, arg.port, arg.mainClass)
      except CatchableError as e:
        failure = e.msg
    arg.finish(failure)

  QtObject:
    type KeycardTestController* = ref object of QObject
      simProcess: Process  # the spawned jcardsim simulator server (if started from the app)
      threadpool: ThreadPool

    ## Forward declaration
    proc delete*(self: KeycardTestController)

    proc newKeycardTestController*(threadpool: ThreadPool): KeycardTestController =
      new(result, delete)
      result.QObject.setup
      result.threadpool = threadpool

    proc delete*(self: KeycardTestController) =
      stopProcess(takeStartedSimProcess())
      stopProcess(self.simProcess)
      self.simProcess = nil
      self.QObject.delete

    proc simulatorStartFinished*(self: KeycardTestController, error: string) {.signal.}

    proc onStartSimulatorDone(self: KeycardTestController, failure: string) {.slot.} =
      let pending = takeStartedSimProcess()
      if failure.len > 0:
        stopProcess(pending)
        self.simProcess = nil
        error "keycard simulator start failed", err = failure
      else:
        self.simProcess = pending
      self.simulatorStartFinished(failure)

    proc startSimulator*(self: KeycardTestController, version: string): string {.slot.} =
      var safeVersion = ""
      for c in version:
        if c in {'0'..'9', '.'}: safeVersion.add(c)
      if safeVersion.len == 0:
        safeVersion = KEYCARD_SIMULATOR_DEFAULT_VERSION

      let simDir = resolveSimDir()
      if not dirExists(simDir):
        error "keycard simulator directory not found", dir = simDir
        return "keycard simulator directory not found; set STATUS_KEYCARD_SIM_DIR"

      let buildErr = ensureSimulatorBuilt(simDir)
      if buildErr.len > 0:
        error "keycard simulator build failed", err = buildErr, dir = simDir
        return buildErr

      let mainClass = readMainClass(simDir, safeVersion)
      if mainClass.len == 0:
        error "keycard simulator mainClass missing", version = safeVersion, dir = simDir
        return "missing mainClass for applet version " & safeVersion

      var port = ""
      for c in getEnv("STATUS_KEYCARD_SIM_ENDPOINT", KEYCARD_SIMULATOR_DEFAULT_SIMULATOR_ADDRESS).rsplit(":", 1)[^1]:
        if c in {'0'..'9'}: port.add(c)
      if port.len == 0:
        port = "9025"

      stopProcess(self.simProcess)
      self.simProcess = nil
      discard callRPC("Stop")
      discard keycard_go.keycardTestRemoveCard()
      discard keycard_go.keycardTestUnplugReader()

      self.threadpool.start(StartSimulatorArg(
        tptr: startSimulatorTask,
        vptr: cast[uint](self.vptr),
        slot: "onStartSimulatorDone",
        simDir: simDir,
        version: safeVersion,
        port: port,
        mainClass: mainClass,
      ))
      return ""

    proc createCard*(self: KeycardTestController, cardId: string) {.slot.} =
      info "creating a new keycard with id: ", cardId
      discard keycard_go.keycardTestCreateCard(cardId)

    proc cardCreationFinished*(self: KeycardTestController, error: string) {.signal.}

    proc onLoadCardDone(self: KeycardTestController, response: string) {.slot.} =
      info "load card task done with response: ", response
      defer:
        ignoreKeycardLibSignals = false
      discard callRPC("Stop") # fully resets the SessionManager, returning the lib to its pre-call idle state
      discard keycard_go.keycardTestRemoveCard()
      discard keycard_go.keycardTestUnplugReader()
      var failure = ""
      try:
        let obj = response.parseJson
        let err = obj{"error"}.getStr
        if err.len > 0:
          failure = err
          error "createKeycardWithSeed: task error", err = err
        else:
          let rpcObj = obj{"response"}.getStr.parseJson
          if rpcObj.hasKey("error") and rpcObj["error"].kind != JNull:
            failure = rpcObj["error"]{"message"}.getStr($rpcObj["error"])
            error "createKeycardWithSeed: Load error", err = $rpcObj["error"]
          else:
            info "createKeycardWithSeed: card provisioned"
      except CatchableError as e:
        failure = e.msg
        warn "createKeycardWithSeed: bad Load response", err = e.msg
      self.cardCreationFinished(failure)

    proc clearLocalPairings*(self: KeycardTestController) {.slot.} =
      try:
        writeFile(status_const.KEYCARDPAIRINGDATAFILE, "{}")
        info "cleared all keycard pairings", file = status_const.KEYCARDPAIRINGDATAFILE
      except CatchableError as e:
        error "failed to clear keycard pairings", err = e.msg

    proc createKeycardWithSeed*(self: KeycardTestController, cardId: string, mnemonic: string, pin: string, puk: string,
      metadataName: string, metadataPaths: string, pairingPassword: string = "") {.slot.} =
      ignoreKeycardLibSignals = true

      var paths: seq[string]
      for p in metadataPaths.split({',', ' ', '\n', '\t'}):
        let t = p.strip()
        if t.len > 0:
          paths.add(t)

      discard keycard_go.keycardTestCreateCard(cardId)
      discard keycard_go.keycardTestPlugReader()
      discard keycard_go.keycardTestInsertCard(cardId)

      let params = %*{
        "pin": pin,
        "puk": puk,
        "pairingPassword": pairingPassword,
        "mnemonic": mnemonic,
        "metadataName": metadataName,
        "metadataPaths": paths,
        "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
        "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
        "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
      }
      info "starting load card task", params=params.pretty()
      self.threadpool.start(LoadCardArg(
        tptr: loadCardTask,
        vptr: cast[uint](self.vptr),
        slot: "onLoadCardDone",
        params: params,
      ))

    proc insertCard*(self: KeycardTestController, cardId: string) {.slot.} =
      info "inserting card with id: ", cardId
      discard keycard_go.keycardTestInsertCard(cardId)

    proc removeCard*(self: KeycardTestController) {.slot.} =
      info "removing card"
      discard keycard_go.keycardTestRemoveCard()

    proc plugReader*(self: KeycardTestController) {.slot.} =
      info "plugging reader"
      discard keycard_go.keycardTestPlugReader()

    proc unplugReader*(self: KeycardTestController) {.slot.} =
      info "unplugging reader"
      discard keycard_go.keycardTestUnplugReader()
