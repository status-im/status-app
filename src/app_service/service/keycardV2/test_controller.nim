import nimqml

when defined(useSimulatedKeycard):
  import std/[os, osproc, strutils, json, locks, net]
  import chronicles
  import keycard_go
  import constants as status_const
  import rpc
  import app/core/tasks/[qt, threadpool]
  import app/global/app_lifecycle

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
        defer:
          p.close()
        while p.running:
          if isShuttingDown():
            p.terminate()
            discard p.waitForExit(5_000)
            return "keycard simulator build cancelled"
          sleep(100)
        let code = p.waitForExit()
        if code != 0 or not dirExists(simDir / "out"):
          return "keycard simulator build.sh failed"
        return ""
      except CatchableError as e:
        return "failed to run build.sh: " & e.msg

  const
    COMMAND_TIMEOUT_MSEC = 10_000
    SIMULATOR_START_TIMEOUT_MSEC = 110_000
    SIMULATOR_POLL_INTERVAL_MSEC = 100

  func simulatorProcessOpts(): set[ProcessOption] =
    when defined(windows):
      {poUsePath, poParentStreams, poDaemon}
    else:
      {poUsePath, poParentStreams}

  proc stopProcess(p: Process) =
    if not p.isNil:
      if p.running:
        p.terminate()
      p.close()

  var simulatorProcessLock: Lock
  var simulatorProcess: Process
  simulatorProcessLock.initLock()

  proc setSimulatorProcess(p: Process) =
    {.cast(gcsafe).}:
      acquire(simulatorProcessLock)
      simulatorProcess = p
      release(simulatorProcessLock)

  proc takeSimulatorProcess(): Process =
    {.cast(gcsafe).}:
      acquire(simulatorProcessLock)
      result = simulatorProcess
      simulatorProcess = nil
      release(simulatorProcessLock)

  proc simulatorPing(port: string): bool =
    let socket = newSocket()
    defer:
      socket.close()
    try:
      socket.connect("127.0.0.1", Port(parseInt(port)), timeout = 500)
      socket.send("PING\n")
      result = socket.recvLine(timeout = 500).startsWith("OK")
    except CatchableError:
      result = false

  when defined(windows):
    const hiddenCommandOpts = {poUsePath, poStdErrToStdOut, poDaemon}

    proc commandOutput(cmd: string; args: seq[string]): string =
      execProcess(cmd, args = args, options = hiddenCommandOpts)

    proc runHidden(cmd: string; args: seq[string]): int =
      let p = startProcess(cmd, args = args,
        options = {poUsePath, poParentStreams, poDaemon})
      defer:
        p.close()
      p.waitForExit(COMMAND_TIMEOUT_MSEC)

    proc addrListensOnPort(addrPort, port: string): bool =
      let colon = addrPort.rfind(':')
      if colon < 0:
        return false
      addrPort.substr(colon + 1) == port

    proc windowsListeningPids(port: string): seq[string] =
      let netOut = commandOutput("netstat", @["-ano", "-p", "TCP"])
      for line in netOut.splitLines():
        let parts = line.splitWhitespace()
        if parts.len >= 5 and parts[0] == "TCP" and parts[^2] == "LISTENING" and
            addrListensOnPort(parts[1], port):
          let pid = parts[^1]
          if pid.len > 0 and pid != "0" and pid notin result:
            result.add(pid)

    proc windowsImageName(pid: string): string =
      let outp = commandOutput("tasklist", @["/FI", "PID eq " & pid, "/FO", "CSV", "/NH"])
      let line = outp.strip()
      if line.startsWith("\""):
        let endq = line.find('"', 1)
        if endq > 1:
          return line[1 ..< endq]
      let comma = line.find(',')
      if comma > 0:
        return line[0 ..< comma]
      return line

    proc freeSimulatorPort(port: string): string =
      try:
        for pid in windowsListeningPids(port):
          if windowsImageName(pid).toLowerAscii() != "java.exe" or not simulatorPing(port):
            return "port " & port & " is in use by a non-simulator process (pid " & pid & ")"
          info "Port held by previous simulator — stopping it", port = port, pid = pid
          discard runHidden("taskkill", @["/PID", pid, "/F"])
        for _ in 0 ..< 20:
          if windowsListeningPids(port).len == 0:
            return ""
          sleep(200)
        return "port " & port & " was not released"
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

  proc spawnSimulator(version, port: string): string =
    if isShuttingDown():
      return "keycard simulator start cancelled"

    let simDir = resolveSimDir()
    if not dirExists(simDir):
      return "keycard simulator directory not found; set STATUS_KEYCARD_SIM_DIR"

    let buildErr = ensureSimulatorBuilt(simDir)
    if buildErr.len > 0:
      return buildErr

    let mainClass = readMainClass(simDir, version)
    if mainClass.len == 0:
      return "missing mainClass for applet version " & version

    when defined(windows):
      let portErr = freeSimulatorPort(port)
      if portErr.len > 0:
        error "keycard simulator port unavailable", err = portErr, port = port
        return portErr
    var p: Process
    try:
      info "starting keycard simulator", dir = simDir, port = port, version = version
      when defined(windows):
        let javaExe = findJavaExe()
        if javaExe.len == 0:
          error "java not found for keycard simulator"
          return "java not found in PATH or JAVA_HOME; install a JRE >= 11"
        let classpath = buildClasspath(simDir, version)
        p = startProcess(
          javaExe,
          workingDir = simDir,
          args = @["-noverify", "-cp", classpath, mainClass, port],
          options = simulatorProcessOpts(),
        )
      else:
        p = startProcess(
          "/bin/bash",
          workingDir = simDir,
          args = @["./run.sh", port, version],
          options = simulatorProcessOpts(),
        )
      setSimulatorProcess(p)

      for _ in 0 ..< SIMULATOR_START_TIMEOUT_MSEC div SIMULATOR_POLL_INTERVAL_MSEC:
        if isShuttingDown():
          return "keycard simulator start cancelled"
        if not p.running:
          return "keycard simulator exited before becoming ready"
        if simulatorPing(port):
          info "keycard simulator started", dir = simDir, port = port, version = version
          return ""
        sleep(SIMULATOR_POLL_INTERVAL_MSEC)
      return "keycard simulator did not become ready"
    except CatchableError as e:
      error "failed to start keycard simulator", err = e.msg
      return "failed to start keycard simulator: " & e.msg

  type
    LoadCardArg = ref object of QObjectTaskArg
      params: JsonNode

    StartSimulatorArg = ref object of QObjectTaskArg
      version: string
      port: string

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
        failure = spawnSimulator(arg.version, arg.port)
      except CatchableError as e:
        failure = e.msg
    arg.finish(failure)

  QtObject:
    type KeycardTestController* = ref object of QObject
      simulatorStarting: bool
      threadpool: ThreadPool

    ## Forward declaration
    proc delete*(self: KeycardTestController)

    proc newKeycardTestController*(threadpool: ThreadPool): KeycardTestController =
      new(result, delete)
      result.QObject.setup
      result.threadpool = threadpool

    proc delete*(self: KeycardTestController) =
      stopProcess(takeSimulatorProcess())
      self.QObject.delete

    proc simulatorStartFinished*(self: KeycardTestController, error: string) {.signal.}

    proc onStartSimulatorDone(self: KeycardTestController, failure: string) {.slot.} =
      self.simulatorStarting = false
      if failure.len > 0:
        stopProcess(takeSimulatorProcess())
        error "keycard simulator start failed", err = failure
      self.simulatorStartFinished(failure)

    proc startSimulator*(self: KeycardTestController, version: string): string {.slot.} =
      if self.simulatorStarting:
        return "keycard simulator is already starting"

      var safeVersion = ""
      for c in version:
        if c in {'0'..'9', '.'}: safeVersion.add(c)
      if safeVersion.len == 0:
        safeVersion = KEYCARD_SIMULATOR_DEFAULT_VERSION

      var port = ""
      for c in getEnv("STATUS_KEYCARD_SIM_ENDPOINT", KEYCARD_SIMULATOR_DEFAULT_SIMULATOR_ADDRESS).rsplit(":", 1)[^1]:
        if c in {'0'..'9'}: port.add(c)
      if port.len == 0:
        port = "9025"

      stopProcess(takeSimulatorProcess())
      discard callRPC("Stop")
      discard keycard_go.keycardTestRemoveCard()
      discard keycard_go.keycardTestUnplugReader()

      self.simulatorStarting = true
      self.threadpool.start(StartSimulatorArg(
        tptr: startSimulatorTask,
        vptr: cast[uint](self.vptr),
        slot: "onStartSimulatorDone",
        version: safeVersion,
        port: port,
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
