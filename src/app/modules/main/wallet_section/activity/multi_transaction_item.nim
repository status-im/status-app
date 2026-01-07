import std/strformat

import ./backend/transactions

const MultiTransactionMissingID* = 0

type
  MultiTransactionItem* = object
    id: int
    timestamp: int
    fromAddress: string
    toAddress: string
    fromAsset: string
    toAsset: string
    fromAmount: string
    multiTxType: MultiTransactionType

proc initMultiTransactionItem*(
  id: int,
  timestamp: int,
  fromAddress: string,
  toAddress: string,
  fromAsset: string,
  toAsset: string,
  fromAmount: string,
  multiTxType: MultiTransactionType,
): MultiTransactionItem =
  result.id = id
  result.timestamp = timestamp
  result.fromAddress = fromAddress
  result.toAddress = toAddress
  result.fromAsset = fromAsset
  result.toAsset = toAsset
  result.fromAmount = fromAmount
  result.multiTxType = multiTxType

proc `$`*(self: MultiTransactionItem): string =
  result = fmt"""MultiTransactionItem(
    id: {self.id},
    timestamp: {self.timestamp},
    fromAddress: {self.fromAddress},
    toAddress: {self.toAddress},
    fromAsset: {self.fromAsset},
    toAsset: {self.toAsset},
    fromAmount: {self.fromAmount},
    multiTxType: {self.multiTxType},
    ]"""

proc getId*(self: MultiTransactionItem): int =
  return self.id

proc getTimestamp*(self: MultiTransactionItem): int =
  return self.timestamp

proc getFromAddress*(self: MultiTransactionItem): string =
  return self.fromAddress

proc getToAddress*(self: MultiTransactionItem): string =
  return self.toAddress

proc getFromAsset*(self: MultiTransactionItem): string =
  return self.fromAsset

proc getToAsset*(self: MultiTransactionItem): string =
  return self.toAsset

proc getFromAmount*(self: MultiTransactionItem): string =
  return self.fromAmount

proc getMultiTxType*(self: MultiTransactionItem): MultiTransactionType =
  return self.multiTxType