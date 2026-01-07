import json, chronicles
import std/strformat
include app_service/common/json_utils

type PaymentRequest* = object
    receiver*: string
    amount*: string
    tokenKey*: string
    symbol*: string
    logoUri*: string
    chainId*: int # kept for backward compatibility with the old payment requests


proc newPaymentRequest*(receiver: string, amount: string, tokenKey: string, symbol: string, logoUri: string): PaymentRequest =
  result = PaymentRequest(receiver: receiver, amount: amount, tokenKey: tokenKey, symbol: symbol, logoUri: logoUri)

proc toPaymentRequest*(jsonObj: JsonNode): PaymentRequest =
  result = PaymentRequest()
  discard jsonObj.getProp("receiver", result.receiver)
  discard jsonObj.getProp("amount", result.amount)
  discard jsonObj.getProp("tokenKey", result.tokenKey)
  discard jsonObj.getProp("symbol", result.symbol)
  discard jsonObj.getProp("logoUri", result.logoUri)
  discard jsonObj.getProp("chainId", result.chainId)

proc `%`*(self: PaymentRequest): JsonNode =
  return %*{
    "receiver": self.receiver,
    "amount": self.amount,
    "tokenKey": self.tokenKey,
    "symbol": self.symbol,
    "logoUri": self.logoUri
  }

proc `$`*(self: PaymentRequest): string =
  result = fmt"""PaymentRequest(
    receiver: {self.receiver},
    amount: {self.amount},
    tokenKey: {self.tokenKey},
    symbol: {self.symbol},
    logoUri: {self.logoUri},
    chainId: {self.chainId}
  )"""