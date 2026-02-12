import nimqml, chronicles, times, json, uuids
import strutils

import backend/wallet_connect as status_go
import backend/wallet

import app_service/service/settings/service as settings_service
import app_service/common/wallet_constants
from app_service/service/transaction/dto import PendingTransactionTypeDto
import app_service/service/transaction/service as tr
import app_service/service/keycard/service as keycard_service

import app/global/global_singleton

import app/core/eventemitter
import app/core/signals/types
import app/core/[main]
import app/core/tasks/[qt, threadpool]

import app/modules/shared_modules/keycard_popup/io_interface as keycard_shared_module

include app_service/common/json_utils
include app/core/tasks/common
include async_tasks

logScope:
  topics = "wallet-connect-service"

# include async_tasks

const UNIQUE_WALLET_CONNECT_MODULE_IDENTIFIER* = "WalletSection-WCModule"
const SIGNAL_ESTIMATED_TIME_RESPONSE* = "estimatedTimeResponse"
const SIGNAL_SUGGESTED_FEES_RESPONSE* = "suggestedFeesResponse"
const SIGNAL_ESTIMATED_GAS_RESPONSE* = "estimatedGasResponse"

type
  AuthenticationResponseFn* = proc(keyUid: string, password: string, pin: string)
  SignResponseFn* = proc(keyUid: string, signature: string)

type
  EstimatedTimeArgs* = ref object of Args
    topic*: string
    chainId*: int
    estimatedTime*: int
  
  SuggestedFeesArgs* = ref object of Args
    topic*: string
    chainId*: int
    suggestedFees*: JsonNode

  EstimatedGasArgs* = ref object of Args
    topic*: string
    chainId*: int
    estimatedGas*: string

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    settingsService: settings_service.Service
    transactions: tr.Service
    keycardService: keycard_service.Service

    connectionKeycardResponse: UUID
    authenticationCallback: AuthenticationResponseFn
    signCallback: SignResponseFn

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    settingsService: settings_service.Service,
    transactions: tr.Service,
    keycardService: keycard_service.Service,
  ): Service =
    new(result, delete)
    result.QObject.setup

    result.events = events
    result.threadpool = threadpool
    result.settingsService = settings_service
    result.transactions = transactions
    result.keycardService = keycardService

  proc init*(self: Service) =
    self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_USER_AUTHENTICATED) do(e: Args):
      let args = SharedKeycarModuleArgs(e)
      if args.uniqueIdentifier != UNIQUE_WALLET_CONNECT_MODULE_IDENTIFIER:
        return
      if self.authenticationCallback == nil:
        error "unexpected user authenticated event; no callback set"
        return
      defer:
        self.authenticationCallback = nil
      self.authenticationCallback(args.keyUid, args.password, args.pin)

  # Will fail if another authentication is in progress
  proc authenticateUser*(self: Service, keyUid: string, callback: AuthenticationResponseFn): bool =
    if self.authenticationCallback != nil:
      return false
    self.authenticationCallback = callback
    let data = SharedKeycarModuleAuthenticationArgs(
      uniqueIdentifier: UNIQUE_WALLET_CONNECT_MODULE_IDENTIFIER,
      keyUid: keyUid)
    self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_AUTHENTICATE_USER, data)
    return true

  proc hashMessageEIP191*(self: Service, message: string): string =
    let hashRes = hashMessageEIP191("0x" & toHex(message))
    if not hashRes.error.isNil:
      error "hashMessageEIP191 failed: ", msg=hashRes.error.message
      return ""
    return hashRes.result.getStr()

  proc signMessage*(self: Service, address: string, hashedPassword: string, hashedMessage: string): tuple[res: string, err: string] =
    return self.transactions.signMessage(address, hashedPassword, hashedMessage)

  proc buildTransaction*(self: Service, chainId: int, txJson: string): tuple[txToSign: string, txData: JsonNode] =
    var buildTxResponse: JsonNode
    var err = wallet.buildTransaction(buildTxResponse, chainId, txJson)
    if err.len > 0:
      error "status-go - wallet_buildTransaction failed", err=err
      return
    if buildTxResponse.isNil or buildTxResponse.kind != JsonNodeKind.JObject or
      not buildTxResponse.hasKey("txArgs") or not buildTxResponse.hasKey("messageToSign"):
        error "unexpected wallet_buildTransaction response"
        return
    result.txToSign = buildTxResponse["messageToSign"].getStr
    if result.txToSign.len != wallet_constants.TX_HASH_LEN_WITH_PREFIX:
      error "unexpected tx hash length"
      return
    result.txData = buildTxResponse["txArgs"]

  proc buildRawTransaction*(self: Service, chainId: int, txData: string, signature: string): string =
    var txResponse: JsonNode
    var err = wallet.buildRawTransaction(txResponse, chainId, txData, signature)
    if err.len > 0:
      error "status-go - wallet_buildRawTransaction failed", err=err
      return
    if txResponse.isNil or txResponse.kind != JsonNodeKind.JObject or not txResponse.hasKey("rawTx"):
      error "unexpected wallet_buildRawTransaction response"
      return
    return txResponse["rawTx"].getStr

  proc sendTransactionWithSignature*(self: Service, chainId: int, txData: string, signature: string): string =
    var txResponse: JsonNode
    let err = wallet.sendTransactionWithSignature(txResponse,
      chainId,
      $PendingTransactionTypeDto.WalletConnectTransfer,
      txData,
      singletonInstance.utils.removeHexPrefix(signature))
    if err.len > 0:
      error "status-go - sendTransactionWithSignature failed", err=err
      return ""
    if txResponse.isNil or txResponse.kind != JsonNodeKind.JString:
      error "unexpected sendTransactionWithSignature response"
      return ""
    return txResponse.getStr

  proc hashTypedData*(self: Service, data: string): string =
    var response: JsonNode
    let err = wallet.hashTypedData(response, data)
    if err.len > 0:
      error "status-go - hashTypedData failed", err=err
      return ""
    if response.isNil or response.kind != JsonNodeKind.JString:
      error "unexpected hashTypedData response"
      return ""
    return response.getStr

  proc hashTypedDataV4*(self: Service, data: string): string =
    var response: JsonNode
    let err = wallet.hashTypedDataV4(response, data)
    if err.len > 0:
      error "status-go - hashTypedDataV4 failed", err=err
      return ""
    if response.isNil or response.kind != JsonNodeKind.JString:
      error "unexpected hashTypedDataV4 response"
      return ""
    return response.getStr

  # empty maxFeePerGasHex will fetch the current chain's maxFeePerGas
  proc getEstimatedTime*(self: Service, topic: string, chainId: int, maxFeePerGasHex: string) =
    let request = AsyncGetEstimatedTimeArgs(
      tptr: asyncGetEstimatedTimeTask,
      vptr: cast[uint](self.vptr),
      slot: "estimatedTimeResponse",
      topic: topic,
      chainId: chainId,
      maxFeePerGasHex: maxFeePerGasHex
    )
    self.threadpool.start(request)

  proc estimatedTimeResponse*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      let args = EstimatedTimeArgs(
        topic: responseObj["topic"].getStr,
        chainId: responseObj["chainId"].getInt,
        estimatedTime: responseObj["estimatedTime"].getInt
      )
      self.events.emit(SIGNAL_ESTIMATED_TIME_RESPONSE, args)
    except Exception as e:
      error "failed to parse estimated time response", msg = e.msg

  proc requestSuggestedFees*(self: Service, topic: string, chainId: int) =
    let request = AsyncSuggestedFeesArgs(
      tptr: asyncSuggestedFeesTask,
      vptr: cast[uint](self.vptr),
      slot: "suggestedFeesResponse",
      topic: topic,
      chainId: chainId
    )
    self.threadpool.start(request)

  proc suggestedFeesResponse*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      let args = SuggestedFeesArgs(
        topic: responseObj["topic"].getStr,
        chainId: responseObj["chainId"].getInt,
        suggestedFees: responseObj["suggestedFees"]
      )
      self.events.emit(SIGNAL_SUGGESTED_FEES_RESPONSE, args)
    except Exception as e:
      error "failed to parse suggested fees response", msg = e.msg

  proc disconnectKeycardReponseSignal(self: Service) =
    self.events.disconnect(self.connectionKeycardResponse)

  proc connectKeycardReponseSignal(self: Service) =
    self.connectionKeycardResponse = self.events.onWithUUID(SIGNAL_KEYCARD_RESPONSE) do(e: Args):
      let args = KeycardLibArgs(e)
      self.disconnectKeycardReponseSignal()
      if self.signCallback == nil:
        error "unexpected user authenticated event; no callback set"
        return
      defer:
        self.signCallback = nil
      let currentFlow = self.keycardService.getCurrentFlow()
      if currentFlow != KCSFlowType.Sign:
        error "unexpected keycard flow type: ", currentFlow
        self.signCallback("", "")
        return
      let signature = "0x" &
        singletonInstance.utils.removeHexPrefix(args.flowEvent.txSignature.r) &
        singletonInstance.utils.removeHexPrefix(args.flowEvent.txSignature.s) &
        singletonInstance.utils.removeHexPrefix(args.flowEvent.txSignature.v)
      self.signCallback(args.flowEvent.keyUid, signature)

  proc cancelCurrentFlow*(self: Service) =
      self.keycardService.cancelCurrentFlow()

  proc runSigningOnKeycard*(self: Service, keyUid: string, path: string, hashedMessageToSign: string, pin: string, callback: SignResponseFn): bool =
    if pin.len == 0:
      return false
    if self.signCallback != nil:
      return false
    self.signCallback = callback
    self.cancelCurrentFlow()
    self.connectKeycardReponseSignal()
    self.keycardService.startSignFlow(path, hashedMessageToSign, pin)
    return true

  proc requestGasEstimate*(self: Service, topic: string, tx: JsonNode, chainId: int) =
    let request = AsyncEstimateGasArgs(
      tptr: asyncEstimateGasTask,
      vptr: cast[uint](self.vptr),
      slot: "estimatedGasResponse",
      topic: topic,
      chainId: chainId,
      txJson: $tx
    )
    self.threadpool.start(request)

  proc estimatedGasResponse*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      let args = EstimatedGasArgs(
        topic: responseObj["topic"].getStr,
        chainId: responseObj["chainId"].getInt,
        estimatedGas: responseObj["estimatedGas"].getStr
      )
      self.events.emit(SIGNAL_ESTIMATED_GAS_RESPONSE, args)
    except Exception as e:
      error "failed to parse estimated gas response", msg = e.msg 

  proc delete*(self: Service) =
    self.QObject.delete

