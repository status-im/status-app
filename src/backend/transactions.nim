import tables, json, json_serialization, std/strformat, chronicles

import ./core as core

include common

type
  TransactionsSignatures* = Table[string, tuple[r: string, s: string, v: string]]

# mirrors the MultiTransactionType from status-go, services/wallet/transfer/transaction.go
type
  MultiTransactionType* = enum
    MultiTransactionSend = 0,
    MultiTransactionSwap = 1,
    MultiTransactionBridge = 2,
    MultiTransactionApprove = 3

  MultiTransactionCommandDto* = ref object of RootObj
    fromAddress* {.serializedFieldName("fromAddress").}: string
    toAddress* {.serializedFieldName("toAddress").}: string
    fromAsset* {.serializedFieldName("fromAsset").}: string
    toAsset* {.serializedFieldName("toAsset").}: string
    fromAmount* {.serializedFieldName("fromAmount").}: string
    toAmount* {.serializedFieldName("toAmount").}: string
    multiTxType* {.serializedFieldName("type").}: MultiTransactionType

  MultiTransactionDto* = ref object of RootObj
    id* {.serializedFieldName("id").}: int
    timestamp* {.serializedFieldName("timestamp").}: int
    fromAddress* {.serializedFieldName("fromAddress").}: string
    toAddress* {.serializedFieldName("toAddress").}: string
    fromAsset* {.serializedFieldName("fromAsset").}: string
    toAsset* {.serializedFieldName("toAsset").}: string
    fromAmount* {.serializedFieldName("fromAmount").}: string
    toAmount* {.serializedFieldName("toAmount").}: string
    multiTxType* {.serializedFieldName("type").}: MultiTransactionType

# Mirrors the transfer events from status-go, services/wallet/transfer/commands.go
const EventFetchingRecentHistory*: string = "recent-history-fetching"
const EventRecentHistoryReady*: string = "recent-history-ready"
const EventFetchingHistoryError*: string = "fetching-history-error"
const EventNonArchivalNodeDetected*: string = "non-archival-node-detected"

# Mirrors the pending transfer event from status-go, status-go/services/wallet/transfer/transaction.go
const EventPendingTransactionUpdate*: string = "pending-transaction-update"

proc `$`*(self: MultiTransactionDto): string =
  return fmt"""MultiTransactionDto(
    id:{self.id},
    timestamp:{self.timestamp},
    fromAddress:{self.fromAddress},
    toAddress:{self.toAddress},
    fromAsset:{self.fromAsset},
    toAsset:{self.toAsset},
    fromAmount:{self.fromAmount},
    toAmount:{self.toAmount},
    multiTxType:{self.multiTxType}
  )"""

proc `%`*(self: MultiTransactionCommandDto): JsonNode {.inline.} =
  result = newJObject()
  result["fromAddress"] = %(self.fromAddress)
  result["toAddress"] = %(self.toAddress)
  result["fromAsset"] = %(self.fromAsset)
  result["toAsset"] = %(self.toAsset)
  result["fromAmount"] = %(self.fromAmount)
  result["toAmount"] = %(self.toAmount)
  result["type"] = %int(self.multiTxType)

proc buildTransactionsFromRoute*(resultOut: var JsonNode, uuid: string): string =
  try:
    let payload = %* [uuid]
    let response = core.callPrivateRPC("wallet_buildTransactionsFromRoute", payload)
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error building transactions", err = e.msg
    return e.msg

proc sendRouterTransactionsWithSignatures*(resultOut: var JsonNode, uuid: string, signatures: TransactionsSignatures): string =
  try:
    var jsonSignatures = %* {}
    for key, value in signatures:
      jsonSignatures[key] = %* { "r": value.r, "s": value.s, "v": value.v }

    var payload = %* [{
      "uuid": uuid,
      "signatures": jsonSignatures
    }]
    let response = core.callPrivateRPC("wallet_sendRouterTransactionsWithSignatures", payload)
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error sending transactions", err = e.msg
    return e.msg