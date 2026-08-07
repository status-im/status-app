import nimqml

when defined(useSimulatedKeycard):
  import std/[os, osproc, strutils, json]
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

  # Windows: free leftover keycardqt on port; refuse if held by something else (like run.sh).
  proc freeSimulatorPort(port: string): string =
    when defined(windows):
      try:
        proc listeningPids(): seq[string] =
          let (netOut, _) = execCmdEx("netstat -ano -p TCP")
          for line in netOut.splitLines():
            let parts = line.splitWhitespace()
            if parts.len >= 5 and parts[0] == "TCP" and parts[^2] == "LISTENING" and
                parts[1].endsWith(":" & port):
              let pid = parts[^1]
              if pid.len > 0 and pid != "0" and pid notin result:
                result.add(pid)

        let pids = listeningPids()
        for pid in pids:
          let (cmdOut, _) = execCmdEx(
            "powershell -NoProfile -Command \"(Get-CimInstance Win32_Process -Filter 'ProcessId=" &
            pid & "').CommandLine\"")
          let cmd = cmdOut.strip()
          if "keycardqt" in cmd.toLowerAscii():
            info "Port held by previous simulator — stopping it", port = port, pid = pid
            discard execCmdEx("taskkill /PID " & pid & " /F")
          else:
            return "port " & port & " is in use by a non-simulator process (pid " & pid & ")"
        for _ in 0 ..< 20:
          if listeningPids().len == 0:
            break
          sleep(200)
        return ""
      except CatchableError as e:
        return "failed to check simulator port: " & e.msg
    else:
      return ""

  type
    LoadCardArg = ref object of QObjectTaskArg
      params: JsonNode

  proc loadCardTask(argEncoded: string) {.gcsafe, nimcall.} =
    let arg = decode[LoadCardArg](argEncoded)
    var output = %*{"response": "", "error": ""}
    try:
      output["response"] = %* callRPC("Load", arg.params)
    except Exception as e:
      output["error"] = %* e.msg
    arg.finish(output)

  QtObject:
    type KeycardTestController* = ref object of QObject
      simProcess: Process  # the spawned jcardsim simulator server (if started from the app)
      threadpool: ThreadPool

    ## Forward declaration
    proc delete*(self: KeycardTestController)

    proc newKeycardTestController*(): KeycardTestController =
      new(result, delete)
      result.QObject.setup
      result.threadpool = newThreadPool()

    proc delete*(self: KeycardTestController) =
      if not self.simProcess.isNil and self.simProcess.running:
        self.simProcess.terminate()
        self.simProcess.close()
      if not self.threadpool.isNil:
        self.threadpool.teardown()
      self.QObject.delete

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

      if not self.simProcess.isNil and self.simProcess.running:
        self.simProcess.terminate()
        self.simProcess.close()
      self.simProcess = nil
      discard callRPC("Stop")
      discard keycard_go.keycardTestRemoveCard()
      discard keycard_go.keycardTestUnplugReader()

      try:
        when defined(windows):
          # Mirror run.sh: version/mainClass already validated above; free port then launch JVM.
          let javaExe = findExe("java")
          if javaExe.len == 0:
            error "java not found for keycard simulator"
            return "java not found in PATH; install a JRE >= 11"
          let portErr = freeSimulatorPort(port)
          if portErr.len > 0:
            error "keycard simulator port unavailable", err = portErr, port = port
            return portErr
          let classpath = buildClasspath(simDir, safeVersion)
          self.simProcess = startProcess(
            javaExe,
            workingDir = simDir,
            args = @["-noverify", "-cp", classpath, mainClass, port],
            options = {poParentStreams},
          )
        else:
          # run.sh validates version props and frees a leftover simulator on the port.
          self.simProcess = startProcess(
            "/bin/bash",
            workingDir = simDir,
            args = @["./run.sh", port, safeVersion],
            options = {poParentStreams},
          )
        info "starting keycard simulator", dir = simDir, port = port, version = safeVersion
        return ""
      except CatchableError as e:
        error "failed to start keycard simulator", err = e.msg
        return "failed to start keycard simulator: " & e.msg

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
