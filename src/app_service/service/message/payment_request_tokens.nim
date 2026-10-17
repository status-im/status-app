## Resolves legacy payment requests (no tokenKey/logoUri) by symbol on their chain.
## The cache is meant to live for a single message batch only.

import tables, strutils

import app_service/service/token/items/token
import ./dto/payment_request

type
  TokenBySymbolLookup* = proc(symbol: string, chainId: int): TokenItem
  PaymentRequestTokenCache* = Table[(int, string), TokenItem]

proc isLegacyPaymentRequest*(paymentRequest: PaymentRequest): bool =
  return (paymentRequest.tokenKey.len == 0 or paymentRequest.logoUri.len == 0) and paymentRequest.symbol.len > 0

proc lookupCached*(cache: var PaymentRequestTokenCache, lookup: TokenBySymbolLookup,
    symbol: string, chainId: int): TokenItem =
  let cacheKey = (chainId, symbol.toLowerAscii)
  if cache.hasKey(cacheKey):
    return cache[cacheKey]
  result = lookup(symbol, chainId)
  cache[cacheKey] = result

## Fills tokenKey/symbol/logoUri of legacy payment requests; returns the symbols that didn't resolve.
proc resolvePaymentRequestTokens*(paymentRequests: var seq[PaymentRequest], cache: var PaymentRequestTokenCache,
    lookup: TokenBySymbolLookup): seq[string] =
  for paymentRequest in paymentRequests.mitems:
    if not paymentRequest.isLegacyPaymentRequest:
      continue
    let token = cache.lookupCached(lookup, paymentRequest.symbol, paymentRequest.chainId)
    if token.isNil:
      result.add(paymentRequest.symbol)
      continue
    paymentRequest.tokenKey = token.key
    paymentRequest.symbol = token.symbol
    paymentRequest.logoUri = token.logoUri
