import nimqml, chronicles, times, json, uuids
import strutils

import backend/wallet_connect as status_go
import backend/wallet

import app_service/service/settings/service as settings_service
import app_service/common/wallet_constants
from app_service/service/transaction/dto import PendingTransactionTypeDto
import app_service/service/transaction/service as tr

import app/core/eventemitter
import app/core/signals/types
import app/core/[main]
import app/core/tasks/[qt, threadpool]

include app_service/common/json_utils
include app/core/tasks/common
include async_tasks

logScope:
  topics = "wallet-connect-service"

# include async_tasks

const SIGNAL_ESTIMATED_TIME_RESPONSE* = "estimatedTimeResponse"
const SIGNAL_SUGGESTED_FEES_RESPONSE* = "suggestedFeesResponse"
const SIGNAL_ESTIMATED_GAS_RESPONSE* = "estimatedGasResponse"
const SIGNAL_WC_TX_WORK_DONE* = "wcTxWorkDone"

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

  WcTxWorkDoneArgs* = ref object of Args
    key*: string
    resultJson*: string

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    settingsService: settings_service.Service
    transactions: tr.Service

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    settingsService: settings_service.Service,
    transactions: tr.Service,
  ): Service =
    new(result, delete)
    result.QObject.setup

    result.events = events
    result.threadpool = threadpool
    result.settingsService = settings_service
    result.transactions = transactions

  proc init*(self: Service) =
    discard

  proc hashMessageEIP191*(self: Service, message: string): string =
    let hashRes = hashMessageEIP191("0x" & toHex(message))
    if not hashRes.error.isNil:
      error "hashMessageEIP191 failed: ", msg=hashRes.error.message
      return ""
    return hashRes.result.getStr()

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

  proc requestGasEstimate*(self: Service, topic: string, tx: JsonNode, chainId: int) =
    let request = AsyncEstimateGasArgs(
      tptr: asyncEstimateGasTask,
      vptr: cast[uint](self.vptr),
      slot: "estimatedGasResponse",
      topic: topic,
      chainId: chainId,
      txJson: tx
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

  # Runs the transaction RPC on the threadpool and emits SIGNAL_WC_TX_WORK_DONE.
  proc startTxWork*(self: Service, key: string, kind: string, chainId: int, txJson: string, signature: string) =
    let request = AsyncTxWorkArgs(
      tptr: asyncTxWorkTask,
      vptr: cast[uint](self.vptr),
      slot: "txWorkDone",
      key: key,
      kind: kind,
      chainId: chainId,
      txJson: txJson,
      signature: signature
    )
    self.threadpool.start(request)

  proc txWorkDone*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      self.events.emit(SIGNAL_WC_TX_WORK_DONE, WcTxWorkDoneArgs(key: responseObj["key"].getStr, resultJson: response))
    except Exception as e:
      error "failed to parse tx work response", msg = e.msg

  proc delete*(self: Service) =
    self.QObject.delete

