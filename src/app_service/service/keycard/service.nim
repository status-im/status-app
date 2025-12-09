import nimqml, chronicles, os
import app/global/feature_flags
import constants
import app/core/tasks/[qt, threadpool]
import app/core/eventemitter

featureGuard KEYCARD_ENABLED:
  import json, random, strutils
  import app/global/global_singleton
  import ../../../constants as status_const

  import keycard_go
  

type KCSFlowType* {.pure.} = enum
  NoFlow = -1 # this type is added only for the desktop app purpose
  GetAppInfo = 0 # enumeration of these flows should follow enumeration in the `status-keycard-go`
  RecoverAccount
  LoadAccount
  Login
  ExportPublic
  Sign
  ChangePIN
  ChangePUK
  ChangePairing
  UnpairThis
  UnpairOthers
  DeleteAccountAndUnpair
  StoreMetadata
  GetMetadata

const EmptyTxHash = "0000000000000000000000000000000000000000000000000000000000000000"
const DefaultBIP44Path = "m/0"
const DefaultEIP1581Path = "m/43'/60'/1581'"

const PINLengthForStatusApp* = 6
const PUKLengthForStatusApp* = 12
const CardNameLength* = 20

const SupportedMnemonicLength12* = 12
const SupportedMnemonicLength18* = 18
const SupportedMnemonicLength24* = 24

const MnemonicLengthForStatusApp = SupportedMnemonicLength12
const ReRunCurrentFlowInterval = 3 * 1000 # 3 seconds
const CheckKeycardAvailabilityInterval = 1000 # 1 seconds

const SIGNAL_KEYCARD_RESPONSE* = "keycardResponse"

type TimerReason {.pure.} = enum
  ReRunCurrentFlowLater = "ReRunCurrentFlowLater"
  WaitForKeycardAvailability = "WaitForKeycardAvailability"

logScope:
  topics = "keycard-service"

include ../../common/json_utils
include ../../common/mnemonics
include internal
include ../../common/async_tasks

type
  KeycardLibArgs* = ref object of Args
    flowType*: string
    flowEvent*: KeycardEvent

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    closingApp: bool
    currentFlow: KCSFlowType
    lastReceivedKeycardData: tuple[flowType: string, flowEvent: KeycardEvent]
    setPayloadForCurrentFlow: JsonNode
    doLogging: bool
    busy: bool
    waitingFlows: seq[tuple[flow: KCSFlowType, payload: JsonNode]]
    registeredCallback: proc ()

  ## Forward declaration
  proc startFlow(self: Service, payload: JsonNode)
  proc runTimer(self: Service, timeoutInMilliseconds: int, reason: string)

  proc isBusy*(self: Service): bool {.featureGuard(KEYCARD_ENABLED).}  =
    return self.busy

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service {.featureGuard(KEYCARD_ENABLED).}  =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.closingApp = false
    result.currentFlow = KCSFlowType.NoFlow
    result.doLogging = false
    if not defined(production):
      result.doLogging = true

  proc init*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    if self.doLogging:
      debug "init keycard using ", pairingsJson=status_const.KEYCARDPAIRINGDATAFILE
    # Do not remove the sleep 700
    # This sleep prevents a crash on intel MacOS
    # with errors like bad flushGen 12 in prepareForSweep; sweepgen 0
    if status_const.IS_MACOS and status_const.IS_INTEL:
      sleep 700
    let initResp = keycard_go.keycardInitFlow(status_const.KEYCARDPAIRINGDATAFILE)
    if self.doLogging:
      debug "initialization response: ", initResp

  proc processSignal(self: Service, signal: string) {.featureGuard(KEYCARD_ENABLED).} =
    var jsonSignal: JsonNode
    try:
      jsonSignal = signal.parseJson
    except:
      error "Invalid signal received", data = signal
      return

    if self.doLogging:
      debug "keycard_signal", response=signal

    var typeObj, eventObj: JsonNode
    if(not jsonSignal.getProp(ResponseKeyType, typeObj) or
      not jsonSignal.getProp(ResponseKeyEvent, eventObj)):
      return

    let flowType = typeObj.getStr
    let flowEvent = toKeycardEvent(eventObj)
    self.lastReceivedKeycardData = (flowType: flowType, flowEvent: flowEvent)
    self.events.emit(SIGNAL_KEYCARD_RESPONSE, KeycardLibArgs(flowType: flowType, flowEvent: flowEvent))

  proc receiveKeycardSignal*(self: Service, signal: string) {.slot, featureGuard(KEYCARD_ENABLED).} =
    self.busy = false
    self.processSignal(signal)
    if self.waitingFlows.len > 0:
      let (flow, payload) = self.waitingFlows[0]
      self.waitingFlows.delete(0)
      self.currentFlow = flow
      self.startFlow(payload)

  proc getLastReceivedKeycardData*(self: Service): tuple[flowType: string, flowEvent: KeycardEvent] {.featureGuard(KEYCARD_ENABLED).}  =
    return self.lastReceivedKeycardData

  proc cleanReceivedKeycardData*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    self.lastReceivedKeycardData = ("", KeycardEvent())

  proc buildSeedPhrasesFromIndexes*(self: Service, seedPhraseIndexes: seq[int]): seq[string] {.featureGuard(KEYCARD_ENABLED).}  =
    var seedPhrase: seq[string]
    for ind in seedPhraseIndexes:
      seedPhrase.add(englishWords[ind])
    return seedPhrase

  proc updateLocalPayloadForCurrentFlow(self: Service, obj: JsonNode, cleanBefore = false) {.featureGuard(KEYCARD_ENABLED).}  =
    # CRITICAL FIX: Check if obj is the same reference as setPayloadForCurrentFlow
    # This happens when onTimeout calls startFlow(self.setPayloadForCurrentFlow)
    # If we iterate and modify the same object, the iterator gets corrupted!
    if cast[pointer](obj) == cast[pointer](self.setPayloadForCurrentFlow):
      return
    
    if cleanBefore:
      self.setPayloadForCurrentFlow = %* {}
    
    for k, v in obj:
      self.setPayloadForCurrentFlow[k] = v

  proc getCurrentFlow*(self: Service): KCSFlowType {.featureGuard(KEYCARD_ENABLED).}  =
    return self.currentFlow

  proc startFlow(self: Service, payload: JsonNode) {.featureGuard(KEYCARD_ENABLED).} =
    if self.busy:
      self.waitingFlows.add((flow: self.currentFlow, payload: payload))
      return
    self.busy = true
    self.updateLocalPayloadForCurrentFlow(payload, cleanBefore = true)
    let response = keycard_go.keycardStartFlow(self.currentFlow.int, $payload)
    if self.doLogging:
      debug "keycardStartFlow", kcServiceCurrFlow=($self.currentFlow), payload=payload, response=response

  proc resumeFlow(self: Service, payload: JsonNode) {.featureGuard(KEYCARD_ENABLED).} =
    self.busy = true
    self.updateLocalPayloadForCurrentFlow(payload)
    let response = keycard_go.keycardResumeFlow($payload)
    if self.doLogging:
      debug "keycardResumeFlow", kcServiceCurrFlow=($self.currentFlow), payload=payload, response=response

  proc cancelCurrentFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    # Do not remove the sleep 700
    # This sleep prevents a crash on intel MacOS
    # with errors like bad flushGen 12 in prepareForSweep; sweepgen 0
    if status_const.IS_MACOS and status_const.IS_INTEL:
      sleep 700
    let response = keycard_go.keycardCancelFlow()
    # sleep 200 is needed for cancel flow
    sleep 200
    self.currentFlow = KCSFlowType.NoFlow
    self.busy = false
    if self.doLogging:
      debug "keycardCancelFlow", kcServiceCurrFlow=($self.currentFlow), response=response

  ##########################################################
  ## Used in test env only, for testing keycard flows
  proc registerMockedKeycard*(self: Service, cardIndex: int, readerState: int, keycardState: int,
  mockedKeycard: string, mockedKeycardHelper: string) {.featureGuard(KEYCARD_ENABLED).} =
    if not singletonInstance.localAppSettings.displayMockedKeycardWindow():
      error "registerMockedKeycard can be used only in test env"
      return
    let response = keycard_go.mockedLibRegisterKeycard(cardIndex, readerState, keycardState, mockedKeycard, mockedKeycardHelper)
    if self.doLogging:
      debug "mockedLibRegisterKeycard", kcServiceCurrFlow=($self.currentFlow), cardIndex=cardIndex, readerState=readerState, keycardState=keycardState, mockedKeycard=mockedKeycard, mockedKeycardHelper=mockedKeycardHelper, response=response

  proc pluginMockedReaderAction*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    if not singletonInstance.localAppSettings.displayMockedKeycardWindow():
      error "pluginMockedReaderAction can be used only in test env"
      return
    let response = keycard_go.mockedLibReaderPluggedIn()
    if self.doLogging:
      debug "mockedLibReaderPluggedIn", kcServiceCurrFlow=($self.currentFlow), response=response

  proc unplugMockedReaderAction*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    if not singletonInstance.localAppSettings.displayMockedKeycardWindow():
      error "unplugMockedReaderAction can be used only in test env"
      return
    let response = keycard_go.mockedLibReaderUnplugged()
    if self.doLogging:
      debug "mockedLibReaderUnplugged", kcServiceCurrFlow=($self.currentFlow), response=response

  proc insertMockedKeycardAction*(self: Service, cardIndex: int) {.featureGuard(KEYCARD_ENABLED).} =
    if not singletonInstance.localAppSettings.displayMockedKeycardWindow():
      error "insertMockedKeycardAction can be used only in test env"
      return
    let response = keycard_go.mockedLibKeycardInserted(cardIndex)
    if self.doLogging:
      debug "mockedLibKeycardInserted", kcServiceCurrFlow=($self.currentFlow), cardIndex=cardIndex, response=response

  proc removeMockedKeycardAction*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    if not singletonInstance.localAppSettings.displayMockedKeycardWindow():
      error "removeMockedKeycardAction can be used only in test env"
      return
    let response = keycard_go.mockedLibKeycardRemoved()
    if self.doLogging:
      debug "mockedLibKeycardRemoved", kcServiceCurrFlow=($self.currentFlow), response=response
  ##########################################################

  proc generateRandomPUK*(self: Service): string {.featureGuard(KEYCARD_ENABLED).}  =
    randomize()
    for i in 0 ..< PUKLengthForStatusApp:
      result = result & $rand(0 .. 9)

  proc onTimeout(self: Service, response: string) {.slot, featureGuard(KEYCARD_ENABLED).} =
    if response == $TimerReason.ReRunCurrentFlowLater:
      #TODO: Find another way to handle this. The vptr should be invalid by now..
      if(self.closingApp or self.currentFlow == KCSFlowType.NoFlow):
        return
      if self.doLogging:
        debug "onTimeout, about to start flow: ", kcServiceCurrFlow=($self.currentFlow)
      self.startFlow(self.setPayloadForCurrentFlow)
    elif response == $TimerReason.WaitForKeycardAvailability:
      if self.busy:
        self.runTimer(CheckKeycardAvailabilityInterval, $TimerReason.WaitForKeycardAvailability)
        return
      if self.registeredCallback != nil:
        self.registeredCallback()
        self.registeredCallback = nil
    else:
      error "unknown timer reason", reason = response

  proc runTimer(self: Service, timeoutInMilliseconds: int, reason: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if(self.closingApp or self.currentFlow == KCSFlowType.NoFlow):
      return

    let arg = TimerTaskArg(
      tptr: timerTask,
      vptr: cast[uint](self.vptr),
      slot: "onTimeout",
      timeoutInMilliseconds: timeoutInMilliseconds,
      reason: reason
    )
    self.threadpool.start(arg)

  proc startLoadAccountFlow*(self: Service, seedPhraseLength: int, seedPhrase: string, pin: string, puk: string,
    factoryReset: bool) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    if seedPhrase.len > 0 and seedPhraseLength > 0:
      payload[RequestParamMnemonic] = %* seedPhrase
      payload[RequestParamMnemonicLen] = %* seedPhraseLength
      payload[RequestParamNewPUK] = %* self.generateRandomPUK()
    if pin.len > 0:
      payload[RequestParamPIN] = %* pin
      payload[RequestParamNewPIN] = %* pin
      payload[RequestParamNewPUK] = %* self.generateRandomPUK()
    if puk.len > 0:
      payload[RequestParamNewPUK] = %* puk
    if factoryReset:
      payload[RequestParamFactoryReset] = %* factoryReset
    self.currentFlow = KCSFlowType.LoadAccount
    self.startFlow(payload)

  proc startLoginFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    let payload = %* { }
    self.currentFlow = KCSFlowType.Login
    self.startFlow(payload)

  proc startLoginFlowAutomatically*(self: Service, pin: string) {.featureGuard(KEYCARD_ENABLED).}  =
    let payload = %* {
      RequestParamPIN: pin
    }
    self.currentFlow = KCSFlowType.Login
    self.startFlow(payload)

  proc startRecoverAccountFlow*(self: Service, seedPhraseLength: int, seedPhrase: string, puk: string, factoryReset: bool) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    if seedPhrase.len > 0 and seedPhraseLength > 0:
      payload[RequestParamMnemonic] = %* seedPhrase
      payload[RequestParamMnemonicLen] = %* seedPhraseLength
      payload[RequestParamNewPUK] = %* self.generateRandomPUK()
    if puk.len > 0:
      payload[RequestParamNewPUK] = %* puk
    if factoryReset:
      payload[RequestParamFactoryReset] = %* factoryReset
    self.currentFlow = KCSFlowType.RecoverAccount
    self.startFlow(payload)

  proc startGetAppInfoFlow*(self: Service, factoryReset: bool) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    if factoryReset:
      payload[RequestParamFactoryReset] = %* factoryReset
    self.currentFlow = KCSFlowType.GetAppInfo
    self.startFlow(payload)

  proc startGetMetadataFlow*(self: Service, resolveAddress: bool, exportMasterAddr = false, pin = "") {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    if resolveAddress:
      payload[RequestParamResolveAddr] = %* resolveAddress
    if exportMasterAddr:
      payload[RequestParamExportMasterAddress] = %* exportMasterAddr
    if pin.len > 0:
      payload[RequestParamPIN] = %* pin
    self.currentFlow = KCSFlowType.GetMetadata
    self.startFlow(payload)

  proc startChangePinFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    self.currentFlow = KCSFlowType.ChangePIN
    self.startFlow(payload)

  proc startChangePukFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    self.currentFlow = KCSFlowType.ChangePUK
    self.startFlow(payload)

  proc startChangePairingFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    self.currentFlow = KCSFlowType.ChangePairing
    self.startFlow(payload)

  proc startExportPublicFlow*(self: Service, path: string, exportMasterAddr = false, exportPrivateAddr = false, pin = "") {.featureGuard(KEYCARD_ENABLED).}  =
    ## Exports addresses for passed `path`. Result of this flow sets instance of `GeneratedWalletAccount` under
    ## `generatedWalletAccount` property in `KeycardEvent`.
    if exportPrivateAddr and not path.startsWith(DefaultEIP1581Path):
      error "in order to export private address path must not be outside of eip1581 tree"
      return

    var payload = %* {
      RequestParamBIP44Path: DefaultBIP44Path,
      RequestParamExportMasterAddress: exportMasterAddr,
      RequestParamExportPrivate: exportPrivateAddr
    }
    if path.len > 0:
      payload[RequestParamBIP44Path] = %* path
    if pin.len > 0:
      payload[RequestParamPIN] = %* pin
    self.currentFlow = KCSFlowType.ExportPublic
    self.startFlow(payload)

  proc startExportPublicFlow*(self: Service, paths: seq[string], exportMasterAddr = false, exportPrivateAddr = false, pin = "") {.featureGuard(KEYCARD_ENABLED).}  =
    ## Exports addresses for passed `path`. Result of this flow sets array of `GeneratedWalletAccount` under
    ## `generatedWalletAccounts` property in `KeycardEvent`. The order of keys set in `generatedWalletAccounts` array
    ## mathch the order of `paths` sent to this flow.
    if exportPrivateAddr:
      for p in paths:
        if not p.startsWith(DefaultEIP1581Path):
          error "one of paths in the list refers to a private address path which is not in eip1581 tree"
          return

    var payload = %* {
      RequestParamBIP44Path: DefaultBIP44Path,
      RequestParamExportMasterAddress: exportMasterAddr,
      RequestParamExportPrivate: exportPrivateAddr
    }
    if paths.len > 0:
      payload[RequestParamBIP44Path] = %* paths
    if pin.len > 0:
      payload[RequestParamPIN] = %* pin
    self.currentFlow = KCSFlowType.ExportPublic
    self.startFlow(payload)

  proc startStoreMetadataFlow*(self: Service, cardName: string, pin: string, walletPaths: seq[string]) {.featureGuard(KEYCARD_ENABLED).}  =
    var name = cardName
    if cardName.len > CardNameLength:
      name = cardName[0 .. CardNameLength - 1]
    let payload = %* {
      RequestParamPIN: pin,
      RequestParamCardName: name,
      RequestParamWalletPaths: walletPaths
    }
    self.currentFlow = KCSFlowType.StoreMetadata
    self.startFlow(payload)

  proc startSignFlow*(self: Service, bip44Path: string, txHash: string, pin: string = "") {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* {
      RequestParamTXHash: EmptyTxHash,
      RequestParamBIP44Path: DefaultBIP44Path
    }
    if txHash.len > 0:
      payload[RequestParamTXHash] = %* txHash
    if bip44Path.len > 0:
      payload[RequestParamBIP44Path] = %* bip44Path
    if pin.len > 0:
      payload[RequestParamPIN] = %* pin
    self.currentFlow = KCSFlowType.Sign
    self.startFlow(payload)

  proc storePin*(self: Service, pin: string, puk: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if pin.len == 0:
      error "empty pin provided"
      return
    var payload = %* {
      RequestParamOverwrite: true,
      RequestParamMnemonicLen: MnemonicLengthForStatusApp,
      RequestParamPIN: pin,
      RequestParamNewPIN: pin
    }
    if puk.len > 0:
      payload[RequestParamNewPUK] = %* puk
    self.resumeFlow(payload)

  proc enterPin*(self: Service, pin: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if pin.len == 0:
      error "empty pin provided"
      return
    var payload = %* {
      RequestParamPIN: pin
    }
    self.resumeFlow(payload)

  proc storePuk*(self: Service, puk: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if puk.len == 0:
      error "empty puk provided"
      return
    var payload = %* {
      RequestParamOverwrite: true,
      RequestParamPUK: puk,
      RequestParamNewPUK: puk
    }
    self.resumeFlow(payload)

  proc enterPuk*(self: Service, puk: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if puk.len == 0:
      error "empty puk provided"
      return
    var payload = %* {
      RequestParamPUK: puk
    }
    self.resumeFlow(payload)

  proc storePairingCode*(self: Service, pairingCode: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if pairingCode.len == 0:
      error "empty pairing code provided"
      return
    var payload = %* {
      RequestParamOverwrite: true,
      RequestParamPairingPass: pairingCode,
      RequestParamNewPairingPass: pairingCode
    }
    self.resumeFlow(payload)

  proc storeSeedPhrase*(self: Service, seedPhraseLength: int, seedPhrase: string) {.featureGuard(KEYCARD_ENABLED).}  =
    if seedPhrase.len == 0:
      error "empty seed phrase provided"
      return
    var payload = %* {
      RequestParamOverwrite: true,
      RequestParamMnemonicLen: seedPhraseLength,
      RequestParamNewPUK: self.generateRandomPUK(),
      RequestParamMnemonic: seedPhrase
    }
    self.resumeFlow(payload)

  proc resumeCurrentFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    var payload = %* { }
    self.resumeFlow(payload)

  proc reRunCurrentFlow*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    let tmpFlow = self.currentFlow
    self.cancelCurrentFlow()
    self.currentFlow = tmpFlow
    self.startFlow(self.setPayloadForCurrentFlow)

  proc reRunCurrentFlowLater*(self: Service) {.featureGuard(KEYCARD_ENABLED).}  =
    let tmpFlow = self.currentFlow
    self.cancelCurrentFlow()
    self.currentFlow = tmpFlow
    self.runTimer(ReRunCurrentFlowInterval, $TimerReason.ReRunCurrentFlowLater)

  proc registerForKeycardAvailability*(self: Service, p: proc()) {.featureGuard(KEYCARD_ENABLED).}  =
    if not self.busy:
      echo "registerForKeycardAvailability can be called only when keycard is busy"
      return
    self.registeredCallback = p
    self.runTimer(CheckKeycardAvailabilityInterval, $TimerReason.WaitForKeycardAvailability)

  proc resetAPI*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
    keycard_go.ResetAPI()

  proc delete*(self: Service) =
    self.closingApp = true
    self.QObject.delete

