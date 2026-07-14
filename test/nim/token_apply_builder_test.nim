## Unit tests for the pure worker-side token-apply builder.
##
## This is the off-GUI-thread core that will feed the typed-completion
## handoff: given the raw RPC response JSON (tokens-of-interest, all-tokens,
## token-preferences, token-lists), it produces the COMPLETE finished structures
## the GUI slot currently builds inline in applyRefreshTokensData /
## applyAllTokenListsData — token items, groups-of-interest, the preferences
## rows, and the all-tokens-by-group index — so the slot reduces to a swap+emit.
## Pure: no Service, no threadpool, no backend. Byte-identical to the current
## GUI-thread build (same inputs -> same structures).

import unittest, json, tables, sequtils, algorithm

import app_service/service/token/token_apply_builder
import app_service/service/token/items/token
import app_service/service/token/items/token_group
import app_service/service/token/items/token_list

# --- fixtures: real payload shapes (field names match the DTO serializedFieldName) ---
# Two tokens share a crossChainId (one group); a third has an empty crossChainId
# (its own key becomes its group key).
const tokenA = """{"chainId":1,"address":"0xAAAA000000000000000000000000000000000001",
  "name":"Alpha","symbol":"ALP","decimals":18,"logoUri":"logoA","custom":false,
  "crossChainId":"grp-eth","communityData":{"id":"","name":"","color":"","image":""}}"""
const tokenB = """{"chainId":10,"address":"0xBBBB000000000000000000000000000000000002",
  "name":"Alpha","symbol":"ALP","decimals":18,"logoUri":"logoB","custom":false,
  "crossChainId":"grp-eth","communityData":{"id":"","name":"","color":"","image":""}}"""
const tokenC = """{"chainId":1,"address":"0xCCCC000000000000000000000000000000000003",
  "name":"Gamma","symbol":"GAM","decimals":6,"logoUri":"logoC","custom":true,
  "crossChainId":"","communityData":{"id":"comm-1","name":"Comm","color":"#fff","image":"img"}}"""

proc arr(items: varargs[string]): JsonNode =
  result = newJArray()
  for it in items:
    result.add parseJson(it)

const prefsJson = """[{"key":"grp-eth","position":0,"groupPosition":2,"visible":true,"communityId":""},
  {"key":"other","position":1,"groupPosition":0,"visible":false,"communityId":"comm-1"}]"""

proc symbolsOf(items: seq[TokenItem]): seq[string] =
  items.mapIt(it.symbol).sorted()

suite "token apply builder — refresh tokens":

  test "builds by-key table, groups-of-interest, and all-tokens index":
    let res = buildRefreshTokensApply(arr(tokenA, tokenB, tokenC), arr(tokenA, tokenC),
                                      parseJson(prefsJson))
    # tokens-of-interest: 3 distinct keys
    check res.tokensOfInterestCount == 3
    check res.tokensOfInterestByKey.len == 3
    check symbolsOf(toSeq(res.tokensOfInterestByKey.values)) == @["ALP", "ALP", "GAM"]
    # groups: A+B collapse into "grp-eth"; C forms its own group
    check res.groupsOfInterestByKey.len == 2
    check res.groupsOfInterest.len == 2
    check res.groupsOfInterestByKey.hasKey("grp-eth")
    check res.groupsOfInterestByKey["grp-eth"].tokens.len == 2
    let cGroupKey = toSeq(res.groupsOfInterestByKey.keys).filterIt(it != "grp-eth")[0]
    check res.groupsOfInterestByKey[cGroupKey].tokens.len == 1
    check res.groupsOfInterestByKey[cGroupKey].tokens[0].symbol == "GAM"
    # all-tokens index: grouped by group key, count reflects the all-tokens input
    check res.allTokensCount == 2
    check res.allTokensByGroupKey.len == 2
    check res.allTokensByGroupKey["grp-eth"].len == 1
    check res.allTokensByGroupKey["grp-eth"][0].symbol == "ALP"

  test "preferences are parsed to rows and the raw array is preserved":
    let res = buildRefreshTokensApply(arr(tokenA), arr(tokenA), parseJson(prefsJson))
    check res.tokenPreferences.len == 2
    let byKey = res.tokenPreferences.mapIt((it.key, it)).toTable
    check byKey["grp-eth"].groupPosition == 2
    check byKey["grp-eth"].visible
    check byKey["other"].visible == false
    check byKey["other"].communityId == "comm-1"
    # tokenPreferencesJson is the backend array verbatim (round-trips to the same node)
    check parseJson(res.tokenPreferencesJson) == parseJson(prefsJson)

  test "empty / missing preferences yield an empty rows list and [] json":
    let res = buildRefreshTokensApply(arr(tokenA), arr(tokenA), newJArray())
    check res.tokenPreferences.len == 0
    check res.tokenPreferencesJson == "[]"

  test "empty refresh builds empty structures (slot then keeps prior via swap-not-clear)":
    let res = buildRefreshTokensApply(newJArray(), newJArray(), newJArray())
    check res.tokensOfInterestCount == 0
    check res.allTokensCount == 0
    check res.tokensOfInterestByKey.len == 0
    check res.groupsOfInterestByKey.len == 0
    check res.allTokensByGroupKey.len == 0

  test "deterministic: same input builds structurally identical output":
    let a = buildRefreshTokensApply(arr(tokenA, tokenB, tokenC), arr(tokenA), parseJson(prefsJson))
    let b = buildRefreshTokensApply(arr(tokenA, tokenB, tokenC), arr(tokenA), parseJson(prefsJson))
    check toSeq(a.tokensOfInterestByKey.keys).sorted == toSeq(b.tokensOfInterestByKey.keys).sorted
    check toSeq(a.groupsOfInterestByKey.keys).sorted == toSeq(b.groupsOfInterestByKey.keys).sorted

  test "groups-of-interest is ordered deterministically by group key":
    let res = buildRefreshTokensApply(arr(tokenA, tokenB, tokenC), arr(tokenA), parseJson(prefsJson))
    let orderKeys = res.groupsOfInterest.mapIt(it.key)
    # the exposed group seq is sorted by key (not Table hash order)...
    check orderKeys == orderKeys.sorted
    # ...and its order is exactly the by-key set (the getId diffs on) in sorted
    # order, so a structural change only inserts/removes and never reshuffles survivors.
    check orderKeys == toSeq(res.groupsOfInterestByKey.keys).sorted

suite "token apply builder — all token lists":

  test "builds token-list items with version, source and nested tokens":
    let listJson = """[{"id":"list1","name":"List One","timestamp":"1700000000",
      "fetchedTimestamp":"1700000001","source":"uniswap","version":{"major":1,"minor":2,"patch":3},
      "logoUri":"L","tokens":[""" & tokenA & "," & tokenC & """]}]"""
    let res = buildAllTokenListsApply(parseJson(listJson))
    check res.allTokenLists.len == 1
    let item = res.allTokenLists[0]
    check item.id == "list1"
    check item.name == "List One"
    check item.source == "uniswap"
    check item.version == "1.2.3"
    check item.tokens.len == 2
    check symbolsOf(item.tokens) == @["ALP", "GAM"]

  test "empty token-lists input yields no items":
    let res = buildAllTokenListsApply(newJArray())
    check res.allTokenLists.len == 0

# The worker calls assemble*Result, then finishTyped(result). These must ALWAYS
# return a non-nil result carrying the generation stamp — even on an RPC error or
# a build exception — so the GUI slot always runs and the generation
# coordinator never wedges (deadlock-safety).
const badToken = """{"chainId":0,"address":"","name":"Bad","symbol":"BAD","decimals":0,
  "custom":false,"crossChainId":"","communityData":{"id":"","name":"","color":"","image":""}}"""

suite "token apply builder — worker result assembly (deadlock-safe)":

  test "refresh: success carries generation and the built structures":
    let res = assembleRefreshResult(arr(tokenA, tokenB), arr(tokenA), parseJson(prefsJson),
                                    generation = 7, rpcError = "")
    check res != nil
    check res.generation == 7
    check res.error == ""
    check res.tokensOfInterestCount == 2

  test "refresh: an RPC error is passed through, no build, still stamped":
    let res = assembleRefreshResult(newJArray(), newJArray(), newJArray(),
                                    generation = 3, rpcError = "getTokens failed")
    check res != nil
    check res.generation == 3
    check res.error == "getTokens failed"
    check res.tokensOfInterestCount == 0

  test "refresh: a build exception becomes an error, never raises, still stamped":
    # A malformed token dto makes createTokenItem raise (ValueError) inside the build.
    # assemble* catches `Exception` (not `CatchableError`) so that a Defect — e.g.
    # OutOfMemDefect building the multi-MB model on a memory-pressured wake — is also
    # turned into a stamped, non-nil result rather than escaping and wedging the
    # in-flight gate. A real Defect has no clean injection seam in
    # this build path, so the Defect case is covered by the `except Exception` choice
    # plus the worker's structural try/finally (async_tasks.nim); this test exercises
    # the catch/stamp/non-nil contract via the reachable CatchableError path.
    let res = assembleRefreshResult(arr(badToken), arr(badToken), newJArray(),
                                    generation = 9, rpcError = "")
    check res != nil
    check res.generation == 9
    check res.error.len > 0
    check res.tokensOfInterestCount == 0

  test "token lists: success carries generation and items":
    let listJson = """[{"id":"l","name":"L","timestamp":"1","fetchedTimestamp":"1","source":"s",
      "version":{"major":1,"minor":0,"patch":0},"logoUri":"","tokens":[]}]"""
    let res = assembleAllTokenListsResult(parseJson(listJson), generation = 4, rpcError = "")
    check res != nil
    check res.generation == 4
    check res.error == ""
    check res.allTokenLists.len == 1

  test "token lists: an RPC error is passed through, no build, still stamped":
    let res = assembleAllTokenListsResult(newJArray(), generation = 2, rpcError = "boom")
    check res != nil
    check res.generation == 2
    check res.error == "boom"
    check res.allTokenLists.len == 0

suite "token apply builder — token groups (by-chain / all-groups)":

  test "builds name-sorted groups, collapsing a shared crossChainId":
    # C ("Gamma") then the A/B group ("Alpha") -> sorted by name = Alpha, Gamma.
    let groups = buildTokenGroupsApply(arr(tokenC, tokenA, tokenB))
    check groups.len == 2
    check groups.mapIt(it.name) == @["Alpha", "Gamma"]
    let alpha = groups.filterIt(it.name == "Alpha")[0]
    check alpha.key == "grp-eth"
    check alpha.tokens.len == 2   # A + B collapsed
    check groups.filterIt(it.name == "Gamma")[0].tokens.len == 1

  test "empty tokens node yields no groups":
    check buildTokenGroupsApply(newJArray()).len == 0

  test "assemble: success carries the built groups, no error":
    let res = assembleTokenGroupsResult(arr(tokenA, tokenB, tokenC), rpcError = "")
    check res != nil
    check res.error == ""
    check res.groups.len == 2

  test "assemble: an RPC error is passed through, no build":
    let res = assembleTokenGroupsResult(newJArray(), rpcError = "getTokensByChain failed")
    check res != nil
    check res.error == "getTokensByChain failed"
    check res.groups.len == 0

  test "assemble: a build exception becomes an error, never raises":
    let res = assembleTokenGroupsResult(arr(badToken), rpcError = "")
    check res != nil
    check res.error.len > 0
    check res.groups.len == 0
