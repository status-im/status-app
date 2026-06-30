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
    KEYCARD_SIMULATOR_DEFAULT_SIMULATOR_DIR = "vendor/status-keycard-qt/test/keycard-simulator"

  var ignoreKeycardLibSignals = false # used to avoid triggering of any keycard actions while setting up the test keycard

  proc shouldIgnoreKeycardLibSignals*(): bool =
    return ignoreKeycardLibSignals

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

    proc startSimulator*(self: KeycardTestController, version: string) {.slot.} =
      if not self.simProcess.isNil and self.simProcess.running:
        info "keycard simulator already running"
        return
      var safeVersion = ""
      for c in version:
        if c in {'0'..'9', '.'}: safeVersion.add(c)
      if safeVersion.len == 0:
        safeVersion = KEYCARD_SIMULATOR_DEFAULT_VERSION
      let simDir = getEnv("STATUS_KEYCARD_SIM_DIR", KEYCARD_SIMULATOR_DEFAULT_SIMULATOR_DIR)
      let port = getEnv("STATUS_KEYCARD_SIM_ENDPOINT", KEYCARD_SIMULATOR_DEFAULT_SIMULATOR_ADDRESS).rsplit(":", 1)[^1]
      try:
        self.simProcess = startProcess("/bin/bash",
          args = @["-c", "cd '" & simDir & "' && ./build.sh && exec ./run.sh " & port & " " & safeVersion],
          options = {poParentStreams})
        info "starting keycard simulator", dir = simDir, port = port, version = safeVersion
      except CatchableError as e:
        error "failed to start keycard simulator", err = e.msg

    proc createCard*(self: KeycardTestController, cardId: string) {.slot.} =
      info "creating a new keycard with id: ", cardId
      discard keycard_go.keycardTestCreateCard(cardId)

    proc onLoadCardDone(self: KeycardTestController, response: string) {.slot.} =
      info "load card task done with response: ", response
      defer:
        ignoreKeycardLibSignals = false
      discard callRPC("Stop") # fully resets the SessionManager, returning the lib to its pre-call idle state
      discard keycard_go.keycardTestRemoveCard()
      discard keycard_go.keycardTestUnplugReader()
      try:
        let obj = response.parseJson
        let err = obj{"error"}.getStr
        if err.len > 0:
          error "createKeycardWithSeed: task error", err = err
          return
        let rpcObj = obj{"response"}.getStr.parseJson
        if rpcObj.hasKey("error") and rpcObj["error"].kind != JNull:
          error "createKeycardWithSeed: Load error", err = $rpcObj["error"]
        else:
          info "createKeycardWithSeed: card provisioned"
      except CatchableError as e:
        warn "createKeycardWithSeed: bad Load response", err = e.msg

    proc createKeycardWithSeed*(self: KeycardTestController, cardId: string, mnemonic: string, pin: string, puk: string,
      metadataName: string, metadataPaths: string) {.slot.} =
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
        "pairingPassword": "",
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
