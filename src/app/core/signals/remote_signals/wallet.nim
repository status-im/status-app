import json, options, chronicles, tables

import base
import signal_type

import app_service/service/transaction/dtoV2
import app_service/service/transaction/router_transactions_dto

const
  EventPendingTransactionUpdate* = "pending-transaction-update"
  EventPendingTransactionStatusChanged* = "pending-transaction-status-changed"
  EventWatchOnlyAccountRetrieved* = "wallet-watch-only-account-retrieved"

type WalletSignal* = ref object of Signal
  content*: string
  eventType*: string
  blockNumber*: int
  accounts*: seq[string]
  # newTransactions*: ???
  erc20*: bool
  at*: int
  chainID*: int
  message*: string
  requestId*: Option[int]
  txHashes*: seq[string]
  uuid*: string
  bestRouteRaw*: string
  bestRoute*: seq[TransactionPathDtoV2]
  error*: string
  errorCode*: string
  updatedPrices*: Table[string, float64]
  routerTransactionsSendingDetails*: SendDetailsDto
  routerTransactionsForSigning*: RouterTransactionsForSigningDto
  routerSentTransactions*: RouterSentTransactionsDto
  transactionStatusChange*: TransactionStatusChange
  # Token balance fetch signal fields
  balanceFetchChainId*: int
  balanceFetchAccount*: string
  balanceChanged*: bool

proc fromEvent*(T: type WalletSignal, signalType: SignalType, jsonSignal: JsonNode): WalletSignal =
  result = WalletSignal()
  result.signalType = signalType
  let event = jsonSignal["event"]
  if event.kind == JNull:
    return
  if signalType == SignalType.Wallet:
    result.content = $jsonSignal
    result.eventType = event["type"].getStr
    result.blockNumber = event{"blockNumber"}.getInt
    result.erc20 = event{"erc20"}.getBool
    result.accounts = @[]
    if event["accounts"].kind != JNull:
      for account in event["accounts"]:
        result.accounts.add(account.getStr)
    result.at = event{"at"}.getInt
    result.chainID = event{"chainId"}.getInt
    result.message = event{"message"}.getStr
    const requestIdName = "requestId"
    if event.contains(requestIdName):
      result.requestId = some(event[requestIdName].getInt())

    ## handling tx status change
    if result.eventType == EventPendingTransactionStatusChanged:
      result.signalType = SignalType.WalletTransactionStatusChanged
      if result.message.len == 0:
        return
      var statusChangedPayload: JsonNode
      try:
        statusChangedPayload = result.message.parseJson
      except CatchableError:
        return
      result.transactionStatusChange = toTransactionStatusChange(statusChangedPayload)
    ## handling watch-only account retrieval
    if result.eventType == EventWatchOnlyAccountRetrieved:
      # Message is parsed in the service
      return
    return
  if signalType == SignalType.WalletSignTransactions:
    if event.kind != JArray:
      return
    for tx in event:
      result.txHashes.add(tx.getStr)
    return
  if signalType == SignalType.WalletRouterSignTransactions:
    if event.kind != JObject:
      return
    result.routerTransactionsForSigning = toRouterTransactionsForSigningDto(event)
    return
  if signalType == SignalType.WalletRouterTransactionsSent:
    if event.kind != JObject:
      return
    result.routerSentTransactions = toRouterSentTransactionsDto(event)
    return
  if signalType == SignalType.WalletRouterSendingTransactionsStarted:
    result.routerTransactionsSendingDetails = toSendDetailsDto(event)
    return
  if signalType == SignalType.WalletTransactionStatusChanged:
    return
  if signalType == SignalType.WalletSuggestedRoutes:
    try:
      if event.contains("Uuid"):
        result.uuid = event["Uuid"].getStr()
      if event.contains("Route"):
        let bestRouteJsonNode = event["Route"]
        result.bestRouteRaw = $bestRouteJsonNode
        result.bestRoute = bestRouteJsonNode.toTransactionPathsDtoV2()
      if event.contains("ErrorResponse"):
        let errorResponseJsonNode = event["ErrorResponse"]
        if errorResponseJsonNode.contains("details"):
          result.error = errorResponseJsonNode["details"].getStr
        if errorResponseJsonNode.contains("code"):
          result.errorCode = errorResponseJsonNode["code"].getStr
      result.updatedPrices = initTable[string, float64]()
      if event.contains("UpdatedPrices"):
        for tokenKey, price in event["UpdatedPrices"].pairs():
          result.updatedPrices[tokenKey] = price.getFloat
    except Exception as e:
      error "Error parsing best route: ", err=e.msg
    return
  if signalType == SignalType.WalletTokenBalancesFetchFinished:
    result.balanceFetchChainId = event{"chainId"}.getInt
    result.balanceFetchAccount = event{"account"}.getStr
    result.balanceChanged = event{"balanceChanged"}.getBool
    return
