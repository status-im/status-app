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

const SignalKeycardStatusChanged* = "status-changed"
const SignalKeycardChannelStateChanged* = "channel-state-changed"

const SupportedMnemonicLength12* = 12
const PUKLengthForStatusApp* = 12

const KeycardLibCallsInterval = 500 # 0.5 seconds

const SIGNAL_KEYCARD_STATE_UPDATED* = "keycardStateUpdated"
const SIGNAL_KEYCARD_CHANNEL_STATE_UPDATED* = "keycardChannelStateUpdated"
const SIGNAL_KEYCARD_SET_PIN_FAILURE* = "keycardSetPinFailure"
const SIGNAL_KEYCARD_AUTHORIZE_FINISHED* = "keycardAuthorizeFinished"
const SIGNAL_KEYCARD_LOAD_MNEMONIC_FAILURE* = "keycardLoadMnemonicFailure"
const SIGNAL_KEYCARD_LOAD_MNEMONIC_SUCCESS* = "keycardLoadMnemonicSuccess"
const SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_FAILURE* = "keycardExportRestoreKeysFailure"
const SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_SUCCESS* = "keycardExportRestoreKeysSuccess"
const SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_FAILURE* = "keycardExportLoginKeysFailure"
const SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_SUCCESS* = "keycardExportLoginKeysSuccess"

## Signals for keycard composite actions
const SIGNAL_KEYCARD_LOGIN_FINISHED* = "keycardLoginFinished"
const SIGNAL_KEYCARD_RECOVER_FINISHED* = "keycardRecoverFinished"
const SIGNAL_KEYCARD_LOAD_FINISHED* = "keycardLoadFinished"
const SIGNAL_KEYCARD_EXPORT_PUBLIC_KEYS_FINISHED* = "keycardExportPublicKeysFinished"
const SIGNAL_KEYCARD_EXPORT_EXTENDED_PUBLIC_KEYS_FINISHED* = "keycardExportExtendedPublicKeysFinished"
const SIGNAL_KEYCARD_CHANGE_PIN_FINISHED* = "keycardChangePinFinished"
const SIGNAL_KEYCARD_CHANGE_PUK_FINISHED* = "keycardChangePukFinished"
const SIGNAL_KEYCARD_UNBLOCK_FINISHED* = "keycardUnblockFinished"
const SIGNAL_KEYCARD_GET_KEYCARD_METADATA_FINISHED* = "keycardGetKeycardMetadataFinished"
const SIGNAL_KEYCARD_STORE_KEYCARD_METADATA_FINISHED* = "keycardStoreKeycardMetadataFinished"
const SIGNAL_KEYCARD_SIGN_FINISHED* = "keycardSignFinished"
const SIGNAL_KEYCARD_FACTORY_RESET_KEYCARD_FINISHED* = "keycardFactoryResetKeycardFinished"

type KeycardAction {.pure.} = enum
  # single step actions
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
  CancelCurrentOperation = "CancelCurrentOperation"
  # composite actions
  ExportPublicKey = "ExportPublicKey"
  ExportExtendedPublicKey = "ExportExtendedPublicKey"
  Login = "Login"
  Recover = "Recover"
  ChangeKeycardPIN = "ChangeKeycardPIN"
  ChangeKeycardPUK = "ChangeKeycardPUK"
  UnblockUsingPUK = "UnblockUsingPUK"
  GetKeycardMetadata = "GetKeycardMetadata"
  StoreKeycardMetadata = "StoreKeycardMetadata"
  Sign = "Sign"
  FactoryResetKeycard = "FactoryResetKeycard"
  Load = "Load"

type
  KeycardEventArg* = ref object of Args
    keycardEvent*: KeycardEventDto

  KeycardErrorArg* = ref object of Args
    error*: string

  KeycardAuthorizeEvent* = ref object of KeycardErrorArg
    authorized*: bool

  KeycardKeyUIDArg* = ref object of Args
    keyUID*: string

  KeycardExportedKeysArg* = ref object of KeycardErrorArg
    exportedKeys*: KeycardExportedKeysDto

  KeycardChannelStateArg* = ref object of Args
    state*: string

  KeycardLoginArgs* = ref object of KeycardErrorArg
    exportedKeys*: KeycardExportedKeysDto

  KeycardExportedPublicKeysArgs* = ref object of KeycardErrorArg
    exportedPublicKeys*: KeycardExportedPublicKeysDto

  KeycardExportedExtendedPublicKeyArgs* = ref object of KeycardErrorArg
    exportResult*: KeycardExportExtendedPublicKeyResultDto

  KeycardGetKeycardMetadataArgs* = ref object of KeycardErrorArg
    metadata*: CardMetadataDto

  KeycardSignArgs* = ref object of KeycardErrorArg
    signature*: KeycardSignatureDto

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
  proc onAsyncResponse(self: Service, response: string) {.slot.}
  proc delete*(self: Service)

  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool

  proc receiveKeycardSignalV2(self: Service, signal: string) {.slot, featureGuard(KEYCARD_ENABLED).} =
    try:
      # Since only one service can register to signals, we pass the signal to the old service too
      var jsonSignal = signal.parseJson
      let signalType = jsonSignal["type"].getStr

      if signalType == SignalKeycardStatusChanged:
        let keycardEvent = jsonSignal["event"].toKeycardEventDto()
        self.events.emit(SIGNAL_KEYCARD_STATE_UPDATED, KeycardEventArg(keycardEvent: keycardEvent))
      elif signalType == SignalKeycardChannelStateChanged:
        let state = jsonSignal["event"]["state"].getStr
        debug "keycardV2 service: emitting channel state update", state=state, signal=SIGNAL_KEYCARD_CHANNEL_STATE_UPDATED
        self.events.emit(SIGNAL_KEYCARD_CHANNEL_STATE_UPDATED, KeycardChannelStateArg(state: state))
    except Exception as e:
      error "error receiving a keycard signal", err=e.msg, data = signal

  include queued_async_calls
  include service_main
  include service_composite_methods

  proc delete*(self: Service) =
    self.QObject.delete

