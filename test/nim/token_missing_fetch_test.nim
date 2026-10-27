## Unit tests for the decode-and-release step of the async missing-tokens batch.
##
## This is the slot-side half of the batched fetch: the worker's envelope comes
## back as a string, and whatever the outcome the batch's keys must leave the
## in-flight set — a key stuck in flight can never re-enqueue, so the token
## wedges (stops resolving) for the rest of the session. No Qt/backend.

import unittest, sets, strutils, tables

import app_service/common/utils as common_utils
import app_service/service/token/dto/token as token_dto
import app_service/service/token/items/token_group
import app_service/service/token/token_missing_fetch
import app_service/service/token/token_pending_fetch

suite "missing-tokens batch — decoded envelope":
  test "a clean envelope yields its keys and releases them from the in-flight set":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                 # 1-0xaaa is now in flight
    let response = """{"requestedKeys":["1-0xaaa"],"tokens":[],"error":""}"""
    let (env, decodeError) = decodeAndCompleteBatch(p, response)
    check decodeError.len == 0
    check env.requestedKeys == @["1-0xaaa"]
    check env.error.len == 0
    check p.enqueue("1-0xaaa") == true    # released -> a fresh miss may re-enqueue

  test "a backend-error envelope still releases the batch's keys":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()
    let response = """{"requestedKeys":["1-0xaaa"],"tokens":[],"error":"boom"}"""
    let (env, decodeError) = decodeAndCompleteBatch(p, response)
    check decodeError.len == 0
    check env.error == "boom"
    check p.enqueue("1-0xaaa") == true    # transient failure -> retry allowed

suite "missing-tokens batch — undecodable envelope":
  test "a raised decode still releases the in-flight keys instead of wedging them":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                 # 1-0xaaa is now in flight
    let (env, decodeError) = decodeAndCompleteBatch(p, "not json at all")
    check decodeError.len > 0
    # The batch's keys are unknown when the envelope itself is undecodable, so
    # everything in flight must be released — otherwise these keys stay "in
    # flight" forever and can never be fetched again this session. The released
    # keys stand in for the batch's, so the caller can retry them.
    check env.requestedKeys == @["1-0xaaa"]
    check p.enqueue("1-0xaaa") == true

  test "an empty response (drained handoff) releases the in-flight keys too":
    var p = initPendingTokenFetch()
    discard p.enqueue("10-0xbbb")
    discard p.takeBatch()
    let (_, decodeError) = decodeAndCompleteBatch(p, "")
    check decodeError.len > 0
    check p.enqueue("10-0xbbb") == true

suite "missing-tokens batch — notification":
  test "found tokens refresh the token list":
    check batchNotice(foundCount = 1, settledMissingCount = 0) == MissingFetchNotice.TokensListUpdated
    check batchNotice(foundCount = 1, settledMissingCount = 2) == MissingFetchNotice.TokensListUpdated

  test "a batch that only settles keys as missing sends the narrow notice":
    check batchNotice(foundCount = 0, settledMissingCount = 2) == MissingFetchNotice.KeysSettled

  test "a batch that settles nothing notifies nobody":
    check batchNotice(foundCount = 0, settledMissingCount = 0) == MissingFetchNotice.None

proc dto(chainId: int, address: string, crossChainId = "grp"): TokenDto =
  TokenDto(chainId: chainId, address: address, crossChainId: crossChainId, name: "Tok", symbol: "TOK", decimals: 18)

proc envelope(requestedKeys: seq[string], tokens: seq[TokenDto]): FetchMissingTokensResponse =
  FetchMissingTokensResponse(requestedKeys: requestedKeys, tokens: tokens)

proc raisingOn(address: string): TokenItemFactory =
  return proc(d: TokenDto): TokenItem =
    if d.address == address:
      raise newException(ValueError, "injected")
    createTokenItem(d)

type Caches = object
  tokensByKey: Table[string, TokenItem]
  groupsByKey: Table[string, TokenGroupItem]
  knownMissingKeys: HashSet[string]

proc cachesWithExistingGroup(): Caches =
  let existing = createTokenItem(dto(10, "0xccc"))
  result.groupsByKey["grp"] = TokenGroupItem(key: "grp", tokens: @[existing])
  result.tokensByKey[existing.key] = existing

proc apply(c: var Caches, fetch: var PendingTokenFetch, env: FetchMissingTokensResponse,
    makeToken: TokenItemFactory = nil): MissingFetchNotice =
  if makeToken.isNil:
    return applyMissingTokensBatch(fetch, env, c.tokensByKey, c.groupsByKey, c.knownMissingKeys)
  return applyMissingTokensBatch(fetch, env, c.tokensByKey, c.groupsByKey, c.knownMissingKeys, makeToken)

proc isSettled(c: Caches): proc(key: string): bool =
  return proc(key: string): bool = isMissingKeySettled(key, c.tokensByKey, c.knownMissingKeys)

let keyA = createTokenKey(1, "0xaaa")
let keyB = createTokenKey(1, "0xbbb")
let keyMissing = createTokenKey(1, "0xddd")

suite "missing-tokens batch — caching the result":
  test "found tokens are cached under the requested key and grouped; the rest settle as missing":
    var c = cachesWithExistingGroup()
    var p = initPendingTokenFetch()
    let checksummedA = createTokenKey(1, "0xaaa").replace("aaa", "AAA")
    let notice = c.apply(p, envelope(@[checksummedA, keyMissing], @[dto(1, "0xAAA")]))
    check notice == MissingFetchNotice.TokensListUpdated
    check c.tokensByKey.hasKey(checksummedA)
    check c.groupsByKey["grp"].tokens.len == 2
    check keyMissing in c.knownMissingKeys
    check checksummedA notin c.knownMissingKeys

  test "a batch where nothing was found only settles the keys":
    var c = Caches()
    var p = initPendingTokenFetch()
    check c.apply(p, envelope(@[keyMissing], @[])) == MissingFetchNotice.KeysSettled
    check keyMissing in c.knownMissingKeys
    check c.tokensByKey.len == 0

  test "an exception while processing leaves every cache unchanged":
    var c = cachesWithExistingGroup()
    var p = initPendingTokenFetch()
    let env = envelope(@[keyA, keyB, keyMissing], @[dto(1, "0xaaa"), dto(1, "0xbbb")])
    expect ValueError:
      discard c.apply(p, env, raisingOn("0xbbb"))
    check not c.tokensByKey.hasKey(keyA)
    check c.tokensByKey.len == 1
    check c.groupsByKey.len == 1
    check c.groupsByKey["grp"].tokens.len == 1
    check c.knownMissingKeys.len == 0

  test "the keys of a batch that raised are retried, not skipped as settled":
    var c = cachesWithExistingGroup()
    var p = initPendingTokenFetch()
    discard p.enqueue(keyA)
    discard p.enqueue(keyB)
    let batch = p.takeBatch()
    p.completeBatch(batch)
    expect ValueError:
      discard c.apply(p, envelope(@[keyA, keyB], @[dto(1, "0xaaa"), dto(1, "0xbbb")]), raisingOn("0xbbb"))
    let (retryTiers, gaveUp, notice) = failMissingTokensBatch(p, batch, c.knownMissingKeys)
    check retryTiers == @[0]
    check gaveUp.len == 0
    check notice == MissingFetchNotice.None
    check p.releaseRetries(0, c.isSettled) == true
    check p.takeBatch().toHashSet == [keyA, keyB].toHashSet

  test "a persistently raising batch gives up after the first try and every retry":
    var c = Caches()
    var p = initPendingTokenFetch()
    discard p.enqueue(keyA)
    var attempts = 0
    var lastNotice = MissingFetchNotice.None
    var gaveUpKeys: seq[string]
    while true:
      let batch = p.takeBatch()
      if batch.len == 0:
        break
      p.completeBatch(batch)
      inc attempts
      expect ValueError:
        discard c.apply(p, envelope(batch, @[dto(1, "0xaaa")]), raisingOn("0xaaa"))
      let (retryTiers, gaveUp, notice) = failMissingTokensBatch(p, batch, c.knownMissingKeys)
      lastNotice = notice
      gaveUpKeys = gaveUp
      for tier in retryTiers:
        discard p.releaseRetries(tier, c.isSettled)
    check attempts == 1 + MissingTokenFetchRetryDelaysMs.len
    check gaveUpKeys == @[keyA]
    check lastNotice == MissingFetchNotice.KeysSettled
    check keyA in c.knownMissingKeys
    check not c.tokensByKey.hasKey(keyA)
    check p.enqueue(keyA) == true

suite "token group copy":
  test "a copy carries every field and owns its tokens seq":
    let token = createTokenItem(dto(1, "0xaaa"))
    let original = TokenGroupItem(key: "grp", name: "Tok", symbol: "TOK", decimals: 18,
      logoUri: "logo", tokens: @[token])
    for name, value in original[].fieldPairs:
      check value != default(typeof(value))   # a new field must be set above
    let copy = original.copyGroup()
    check copy != original
    check copy[] == original[]
    copy.tokens.add(createTokenItem(dto(1, "0xbbb")))
    check original.tokens.len == 1
