## Unit tests for the pure token-lookup cache helpers.
## These cover the negative-cache decision that gates the blocking backend RPC and
## the swap-not-clear guard used when a token refresh is applied. No Qt/backend
## required — the helpers operate on plain tables/sets and TokenItems.

import unittest, tables, sets

import app_service/service/token/token_lookup_cache
import app_service/service/token/items/token
import app_service/service/token/dto/token as token_dto

proc testToken(chainId: int, address: string): TokenItem =
  var dto: token_dto.TokenDto
  dto.chainId = chainId
  dto.address = address
  dto.name = "Test"
  dto.symbol = "TST"
  dto.decimals = 18
  return createTokenItem(dto)

suite "token negative-cache lookup classification":
  test "unknown key needs a fetch; once marked missing the next lookup skips the RPC":
    let key = "1-0xdead"
    var byKey = initTable[string, TokenItem]()
    var missing = initHashSet[string]()

    # First lookup: nothing is known about the key -> a backend fetch is required.
    check classifyTokenLookup(byKey, missing, key) == TokenLookupOutcome.NeedsFetch

    # The backend returned nothing, so the caller records the miss.
    missing.incl(key)

    # Second lookup of the same key must NOT ask for another fetch.
    check classifyTokenLookup(byKey, missing, key) == TokenLookupOutcome.KnownMissing

  test "a cached key is a hit and never fetched, even if also marked missing":
    let key = "1-0xbeef"
    var byKey = {key: testToken(1, "0xbeef")}.toTable
    var missing = initHashSet[string]()

    check classifyTokenLookup(byKey, missing, key) == TokenLookupOutcome.Hit

    # A stale/defensive missing marker must never shadow real data.
    missing.incl(key)
    check classifyTokenLookup(byKey, missing, key) == TokenLookupOutcome.Hit

suite "token refresh swap-not-clear guard":
  test "a refresh carrying tokens replaces the cache":
    check shouldReplaceTokensCache(newTokenCount = 5, priorCacheCount = 3)

  test "an empty/failed refresh preserves an existing cache":
    check not shouldReplaceTokensCache(newTokenCount = 0, priorCacheCount = 3)

  test "an empty refresh still applies when the cache is empty (first fill)":
    check shouldReplaceTokensCache(newTokenCount = 0, priorCacheCount = 0)

  test "the replacement table is fully built before it is swapped in":
    # The refresh must build the new lookup table aside and hand it back complete,
    # so assigning it is an atomic swap with no observable empty-cache window.
    let tokens = @[testToken(1, "0xaaa"), testToken(1, "0xbbb"), testToken(10, "0xaaa")]
    let byKey = buildTokensByKey(tokens)

    check byKey.len == 3
    for token in tokens:
      check byKey.hasKey(token.key)
      check byKey[token.key].key == token.key

  test "building from no tokens yields an empty table":
    check buildTokensByKey(newSeq[TokenItem]()).len == 0
