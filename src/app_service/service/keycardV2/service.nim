import nimqml, tables, json, os, chronicles, strutils, random, json_serialization
import app/global/feature_flags
import app/global/global_singleton
import app/core/eventemitter
import app/core/tasks/[qt, threadpool]
import backend/response_type
import ./dto, rpc

featureGuard KEYCARD_ENABLED:
  import keycard_go
  import constants as status_const

export dto

logScope:
  topics = "keycardV2-service"

const SupportedMnemonicLength12* = 12
const PUKLengthForStatusApp* = 12

const KeycardLibCallsInterval = 500 # 0.5 seconds

const SIGNAL_KEYCARD_STATE_UPDATED* = "keycardStateUpdated"
const SIGNAL_KEYCARD_SET_PIN_FAILURE* = "keycardSetPinFailure"
const SIGNAL_KEYCARD_AUTHORIZE_FINISHED* = "keycardAuthorizeFinished"
const SIGNAL_KEYCARD_LOAD_MNEMONIC_FAILURE* = "keycardLoadMnemonicFailure"
const SIGNAL_KEYCARD_LOAD_MNEMONIC_SUCCESS* = "keycardLoadMnemonicSuccess"
const SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_FAILURE* = "keycardExportRestoreKeysFailure"
const SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_SUCCESS* = "keycardExportRestoreKeysSuccess"
const SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_FAILURE* = "keycardExportLoginKeysFailure"
const SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_SUCCESS* = "keycardExportLoginKeysSuccess"

type KeycardAction {.pure.} = enum
  Start = "Start"
  Stop = "Stop"
  GenerateMnemonic = "GenerateMnemonic"
  LoadMnemonic = "LoadMnemonic"
  Authorize = "Authorize"
  Initialize = "Initialize"
  ExportRecoverKeys = "ExportRecoverKeys"
  ExportLoginKeys = "ExportLoginKeys"
  FactoryReset = "FactoryReset"
  GetMetadata = "GetMetadata"
  StoreMetadata = "StoreMetadata"

type
  KeycardEventArg* = ref object of Args
    keycardEvent*: KeycardEventDto

  KeycardErrorArg* = ref object of Args
    error*: string

  KeycardAuthorizeEvent* = ref object of Args
    error*: string
    authorized*: bool

  KeycardKeyUIDArg* = ref object of Args
    keyUID*: string

  KeycardExportedKeysArg* = ref object of Args
    exportedKeys*: KeycardExportedKeysDto

include utils
include app_service/common/async_tasks
include async_tasks

type
  KeycardRequest = ref object
    action*: KeycardAction
    params*: JsonNode
    callback: proc (responseObj: JsonNode, err: string)

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    currentRequest: KeycardRequest
    requestCounter: int
    requestMap: Table[int, KeycardRequest]

  ## Forward declaration
  proc initializeRPC(self: Service)
  proc asyncStart*(self: Service, storageDir: string)
  proc onAsyncResponse(self: Service, response: string) {.slot.}

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool

  include queued_async_calls

  proc init*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    debug "KeycardServiceV2 init"
    # Do not remove the sleep 700, this sleep prevents a crash on intel MacOS
    # with errors like bad flushGen 12 in prepareForSweep; sweepgen 0
    # More details: https://github.com/status-im/status-app/pull/15194
    if status_const.IS_MACOS and status_const.IS_INTEL:
      sleep 700
    self.initializeRPC()
    self.asyncStart(status_const.KEYCARDPAIRINGDATAFILE)
    discard

  proc initializeRPC(self: Service) {.slot, featureGuard(KEYCARD_ENABLED).} =
    var response = keycard_go.keycardInitializeRPC()

  proc receiveKeycardSignalV2(self: Service, signal: string) {.slot, featureGuard(KEYCARD_ENABLED).} =
    try:
      # Since only one service can register to signals, we pass the signal to the old service too
      var jsonSignal = signal.parseJson
      if jsonSignal["type"].getStr == "status-changed":
        let keycardEvent = jsonSignal["event"].toKeycardEventDto()

        self.events.emit(SIGNAL_KEYCARD_STATE_UPDATED, KeycardEventArg(keycardEvent: keycardEvent))
    except Exception as e:
      error "error receiving a keycard signal", err=e.msg, data = signal

  proc asyncStart(self: Service, storageDir: string) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{
      "storageFilePath": storageDir,
      "logEnabled": KEYCARD_LOGS_ENABLED,
      "logFilePath": KEYCARD_LOG_FILE_PATH,
    }
    self.asyncCallRPC(KeycardAction.Start, params, proc (responseObj: JsonNode, err: string) {.featureGuard(KEYCARD_ENABLED).} =
      if err.len > 0:
        error "error starting keycard", err=err
        return
      debug "keycard started"
    )

  proc asyncStop*(self: Service)  {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{}
    self.asyncCallRPC(KeycardAction.Stop, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error stopping keycard", err=err
        return
      debug "keycard stopped"
    )

  proc stop*(self: Service)  {.featureGuard(KEYCARD_ENABLED).} =
    try:
      let response = callRPC($KeycardAction.Stop)
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
          let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
          raise newException(RpcException, error.message)
    except Exception as e:
      error "error stop", err=e.msg

  proc generateMnemonic*(self: Service, length: int): string {.featureGuard(KEYCARD_ENABLED).} =
    try:
      let response = callRPC($KeycardAction.GenerateMnemonic, %*{"length": length})
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
          let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
          raise newException(RpcException, error.message)

      let indexes = rpcResponseObj["result"]["indexes"]
      let words = buildSeedPhrasesFromIndexes(indexes)
      let mnemonic = words.join(" ")
      return mnemonic
    except Exception as e:
      error "error generating mnemonic", err=e.msg

  proc getMetadata*(self: Service): CardMetadataDto {.featureGuard(KEYCARD_ENABLED).} =
    try:
      let response = callRPC($KeycardAction.GetMetadata)
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
        raise newException(RpcException, error.message)
      return rpcResponseObj["result"].toCardMetadataDto()
    except Exception as e:
      error "error getting metadata", err=e.msg

  proc asyncLoadMnemonic*(self: Service, mnemonic: string) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{"mnemonic": mnemonic}
    self.asyncCallRPC(KeycardAction.LoadMnemonic, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error loading mnemonic", err=err
        self.events.emit(SIGNAL_KEYCARD_LOAD_MNEMONIC_FAILURE, KeycardErrorArg(error: err))
        return
      let keyUID = responseObj["result"]["keyUID"].getStr
      self.events.emit(SIGNAL_KEYCARD_LOAD_MNEMONIC_SUCCESS, KeycardKeyUIDArg(keyUID: keyUID))
    )

  proc asyncAuthorize*(self: Service, pin: string) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{"pin": pin}
    self.asyncCallRPC(KeycardAction.Authorize, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error authorizing", err=err
        let event = KeycardAuthorizeEvent(error: err, authorized: false)
        self.events.emit(SIGNAL_KEYCARD_AUTHORIZE_FINISHED, event)
        return
      let resultObj = responseObj{"result"}
      let event = KeycardAuthorizeEvent(
        error: "",
        authorized: resultObj{"authorized"}.getBool(),
      )
      self.events.emit(SIGNAL_KEYCARD_AUTHORIZE_FINISHED, event)
    )

  proc asyncInitialize*(self: Service, pin: string, puk: string) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{"pin": pin, "puk": puk}
    self.asyncCallRPC(KeycardAction.Initialize, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error initializing keycard", err=err
        self.events.emit(SIGNAL_KEYCARD_SET_PIN_FAILURE, KeycardErrorArg(error: err))
        return
      debug "keycard initialized"
    )

  proc asyncExportRecoverKeys*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{}
    self.asyncCallRPC(KeycardAction.ExportRecoverKeys, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error exporting recover keys", err=err
        self.events.emit(SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_FAILURE, KeycardErrorArg(error: err))
        return
      let keys = responseObj["result"]["keys"].toKeycardExportedKeysDto()
      self.events.emit(SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_SUCCESS, KeycardExportedKeysArg(exportedKeys: keys))
    )

  proc asyncExportLoginKeys*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{}
    self.asyncCallRPC(KeycardAction.ExportLoginKeys, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error exporting login keys", err=err
        self.events.emit(SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_FAILURE, KeycardErrorArg(error: err))
        return
      let keys = responseObj["result"]["keys"].toKeycardExportedKeysDto()
      self.events.emit(SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_SUCCESS, KeycardExportedKeysArg(exportedKeys: keys))
    )

  proc asyncFactoryReset*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{}
    self.asyncCallRPC(KeycardAction.FactoryReset, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error factory reset", err=err
        return
      debug "factory reset"
    )

  proc asyncStoreMetadata*(self: Service, name: string, paths: seq[string]) {.featureGuard(KEYCARD_ENABLED).} =
    let params = %*{"name": name, "paths": paths}
    self.asyncCallRPC(KeycardAction.StoreMetadata, params, proc (responseObj: JsonNode, err: string) =
      if err.len > 0:
        error "error storing metadata", err=err
        return
      debug "metadata stored"
    )

  proc storeMetadata*(self: Service, name: string, paths: seq[string]) {.featureGuard(KEYCARD_ENABLED).} =
    try:
      let response = callRPC($KeycardAction.StoreMetadata, %*{"name": name, "paths": paths})
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
          let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
          raise newException(RpcException, error.message)
    except Exception as e:
      error "error storing metadata", err=e.msg

  proc startDetection*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    self.asyncStart(status_const.KEYCARDPAIRINGDATAFILE)

  proc delete*(self: Service) =
    self.QObject.delete

