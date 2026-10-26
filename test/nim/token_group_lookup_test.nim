## Unit tests for the bounded on-demand token-group lookup cache that replaced
## the full all-tokens group-key index. The backend fetch is injected, so no
## Qt/backend is needed.

import unittest, sequtils

import app_service/service/token/token_group_lookup
import app_service/service/token/items/token
import app_service/service/token/dto/token as token_dto

proc testToken(chainId: int, address: string, crossChainId = ""): TokenItem =
  var dto: token_dto.TokenDto
  dto.chainId = chainId
  dto.address = address
  dto.crossChainId = crossChainId
  dto.symbol = "TST"
  dto.decimals = 18
  return createTokenItem(dto)

type FakeBackend = ref object
  tokens: seq[TokenItem]
  fail: bool
  calls: seq[string]

proc fetcher(backend: FakeBackend): GroupTokensFetch =
  return proc(groupKey: string): GroupTokensFetchResult =
    backend.calls.add(groupKey)
    if backend.fail:
      return GroupTokensFetchResult(ok: false)
    return GroupTokensFetchResult(ok: true, tokens: backend.tokens.filterIt(it.groupKey == groupKey))

proc keys(tokens: seq[TokenItem]): seq[string] = tokens.mapIt(it.key)

suite "on-demand token group lookup":
  setup:
    let usdcEth = testToken(1, "0x01", "usd-coin")
    let usdcOpt = testToken(10, "0x02", "usd-coin")
    let plain = testToken(1, "0x03")
    let backend = FakeBackend(tokens: @[usdcEth, plain, usdcOpt])
    var cache = initGroupTokensCache()

  test "a miss fetches the group once; the repeat lookup is served from the cache":
    check cache.lookup("usd-coin", backend.fetcher).keys == @[usdcEth.key, usdcOpt.key]
    check cache.lookup("usd-coin", backend.fetcher).keys == @[usdcEth.key, usdcOpt.key]
    check backend.calls == @["usd-coin"]

  test "a token key without a cross-chain id is its own group":
    check cache.lookup(plain.key, backend.fetcher).keys == @[plain.key]

  test "an unknown group is cached as missing":
    check cache.lookup("unknown", backend.fetcher).len == 0
    check cache.lookup("unknown", backend.fetcher).len == 0
    check backend.calls == @["unknown"]

  test "a failed fetch is not cached":
    backend.fail = true
    check cache.lookup("usd-coin", backend.fetcher).len == 0
    backend.fail = false
    check cache.lookup("usd-coin", backend.fetcher).keys == @[usdcEth.key, usdcOpt.key]
    check backend.calls == @["usd-coin", "usd-coin"]

  test "tokens of other groups in the response are dropped":
    let leaky = proc(groupKey: string): GroupTokensFetchResult =
      GroupTokensFetchResult(ok: true, tokens: @[usdcEth, plain])
    check cache.lookup("usd-coin", leaky).keys == @[usdcEth.key]

  test "clear forgets hits and misses":
    discard cache.lookup("usd-coin", backend.fetcher)
    discard cache.lookup("unknown", backend.fetcher)
    cache.clear()
    check cache.len == 0
    discard cache.lookup("usd-coin", backend.fetcher)
    discard cache.lookup("unknown", backend.fetcher)
    check backend.calls == @["usd-coin", "unknown", "usd-coin", "unknown"]

  test "the default capacity is 256 groups":
    for i in 0 ..< 300:
      discard cache.lookup("group-" & $i, backend.fetcher)
    check cache.len == 256

  test "past capacity the oldest group is evicted":
    var small = initGroupTokensCache(capacity = 2)
    discard small.lookup("a", backend.fetcher)
    discard small.lookup("b", backend.fetcher)
    discard small.lookup("a", backend.fetcher)
    discard small.lookup("c", backend.fetcher)
    check small.len == 2
    discard small.lookup("b", backend.fetcher)
    discard small.lookup("c", backend.fetcher)
    check backend.calls == @["a", "b", "c"]
    discard small.lookup("a", backend.fetcher)
    check backend.calls == @["a", "b", "c", "a"]
