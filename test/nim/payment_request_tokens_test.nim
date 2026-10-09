import unittest

import app_service/service/message/payment_request_tokens
import app_service/service/message/dto/payment_request
import app_service/service/token/items/token
import app_service/service/token/dto/token as token_dto

proc testToken(chainId: int, address: string, symbol: string): TokenItem =
  var dto: token_dto.TokenDto
  dto.chainId = chainId
  dto.address = address
  dto.name = symbol
  dto.symbol = symbol
  dto.decimals = 18
  dto.logoUri = "logo-" & symbol
  return createTokenItem(dto)

proc legacyRequest(symbol: string, chainId: int): PaymentRequest =
  PaymentRequest(receiver: "0x1", amount: "1", symbol: symbol, chainId: chainId)

suite "legacy payment request token resolution":
  test "each (chainId, symbol) is looked up once per batch, case insensitive":
    var calls: seq[(string, int)]
    let lookup = proc(symbol: string, chainId: int): TokenItem =
      calls.add((symbol, chainId))
      testToken(chainId, "0xusdc", "USDC")

    var cache: PaymentRequestTokenCache
    var first = @[legacyRequest("USDC", 1), legacyRequest("usdc", 1)]
    var second = @[legacyRequest("Usdc", 1), legacyRequest("USDC", 10)]
    check resolvePaymentRequestTokens(first, cache, lookup).len == 0
    check resolvePaymentRequestTokens(second, cache, lookup).len == 0

    check calls == @[("USDC", 1), ("USDC", 10)]
    for request in first & second:
      check request.symbol == "USDC"
      check request.logoUri == "logo-USDC"
      check request.tokenKey.len > 0

  test "a missing token is cached as nil and reported unresolved":
    var calls = 0
    let lookup = proc(symbol: string, chainId: int): TokenItem =
      inc calls
      nil

    var cache: PaymentRequestTokenCache
    var requests = @[legacyRequest("NOPE", 1), legacyRequest("nope", 1)]
    check resolvePaymentRequestTokens(requests, cache, lookup) == @["NOPE", "nope"]
    check calls == 1
    check requests[0].tokenKey.len == 0
    check requests[0].logoUri.len == 0

  test "requests with tokenKey and logoUri or without symbol skip the lookup":
    var calls = 0
    let lookup = proc(symbol: string, chainId: int): TokenItem =
      inc calls
      nil

    var cache: PaymentRequestTokenCache
    var requests = @[
      newPaymentRequest("0x1", "1", "1-0xabc", "ABC", "logo"),
      legacyRequest("", 1),
    ]
    check resolvePaymentRequestTokens(requests, cache, lookup).len == 0
    check calls == 0
    check requests[0].tokenKey == "1-0xabc"
