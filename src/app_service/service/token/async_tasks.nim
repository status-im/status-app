import times, std/strformat, json

#################################################
# Async task response envelopes
#################################################

type
  BuildGroupsForChainResponse* = object
    chainId*: int
    tokens*: seq[TokenDtoSafe]
    error*: string

  FetchAllTokenGroupsResponse* = object
    tokens*: seq[TokenDtoSafe]
    error*: string

  RefreshTokensResponse* = object
    requestId*: int
    tokensOfInterest*: seq[TokenDtoSafe]
    tokenPreferences*: JsonNode
    allTokens*: seq[TokenDtoSafe]
    error*: string

  FetchAllTokenListsResponse* = object
    allTokenLists*: seq[TokenListDto]
    error*: string

  TokensMarketValuesSlotResponse* = object
    tokenMarketValues*: JsonNode
    error*: string

  TokensDetailsSlotResponse* = object
    tokensDetails*: JsonNode
    error*: string

  TokensPricesSlotResponse* = object
    tokensPrices*: JsonNode
    error*: string

#################################################
# Async refresh tokens (blocking RPCs on threadpool)
#################################################

type
  AsyncRefreshTokensTaskArg = ref object of QObjectTaskArg
    requestId: int
    # When false, the full token catalogue (~3MB) is NOT fetched and "allTokens" stays
    # empty, so the main-thread slot keeps the existing cache and skips the heavy decode.
    # Only init / token-lists-updated set this to true.
    fetchAllTokens: bool

proc asyncRefreshTokensTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncRefreshTokensTaskArg](argEncoded)
  var output = %*{
    "requestId": arg.requestId,
    "tokensOfInterest": newJArray(),
    "tokenPreferences": newJArray(),
    "allTokens": newJArray(),
    "error": ""
  }
  try:
    var tokensOfInterestResponse: JsonNode
    var err = status_go_tokens.getTokensOfInterestForActiveNetworksMode(tokensOfInterestResponse)
    if err.len > 0:
      raise newException(CatchableError, "getTokensOfInterestForActiveNetworksMode failed: " & err)
    output["tokensOfInterest"] = if tokensOfInterestResponse.isNil: newJArray() else: tokensOfInterestResponse

    let prefsResponse = backend.getTokenPreferences()
    if not prefsResponse.error.isNil:
      raise newException(CatchableError, "getTokenPreferences failed: " & prefsResponse.error.message)
    output["tokenPreferences"] = if prefsResponse.result.isNil: newJNull() else: prefsResponse.result
  except Exception as e:
    output["error"] = %* fmt"Error refreshing tokens: {e.msg}"

  # fetch all tokens for the group-key index only when the catalogue may have changed.
  # Skipping this on routine refreshes avoids shipping+decoding ~3MB on the main thread.
  if arg.fetchAllTokens:
    try:
      var allTokensResponse: JsonNode
      let allTokensErr = status_go_tokens.getAllTokens(allTokensResponse)
      if allTokensErr.len > 0:
        warn "asyncRefreshTokensTask: getAllTokens failed", err = allTokensErr
      else:
        output["allTokens"] = if allTokensResponse.isNil: newJArray() else: allTokensResponse
    except Exception as e:
      warn "asyncRefreshTokensTask: getAllTokens exception", err = e.msg

  arg.finish(output)

type
  AsyncFetchAllTokenListsTaskArg = ref object of QObjectTaskArg
    discard

proc asyncFetchAllTokenListsTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncFetchAllTokenListsTaskArg](argEncoded)
  var output = %*{
    "allTokenLists": newJArray(),
    "error": ""
  }
  try:
    var allTokenListsResponse: JsonNode
    var err = status_go_tokens.getAllTokenLists(allTokenListsResponse)
    if err.len > 0:
      raise newException(CatchableError, "getAllTokenLists failed: " & err)
    output["allTokenLists"] = if allTokenListsResponse.isNil: newJArray() else: allTokenListsResponse
  except Exception as e:
    output["error"] = %* fmt"Error fetching all token lists: {e.msg}"
  arg.finish(output)

type
  AsyncFetchAllTokenGroupsTaskArg = ref object of QObjectTaskArg
    discard

proc asyncFetchAllTokenGroupsTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncFetchAllTokenGroupsTaskArg](argEncoded)
  var output = %*{
    "tokens": newJArray(),
    "error": ""
  }
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokensForActiveNetworksMode(response)
    if err.len > 0:
      raise newException(CatchableError, "getTokensForActiveNetworksMode failed: " & err)
    output["tokens"] = if response.isNil: newJArray() else: response
  except Exception as e:
    output["error"] = %* fmt"Error fetching all token groups: {e.msg}"
  arg.finish(output)

type
  AsyncBuildGroupsForChainTaskArg = ref object of QObjectTaskArg
    chainId: int

proc asyncBuildGroupsForChainTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncBuildGroupsForChainTaskArg](argEncoded)
  var output = %*{
    "chainId": arg.chainId,
    "tokens": newJArray(),
    "error": ""
  }
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokensByChain(response, arg.chainId)
    if err.len > 0:
      raise newException(CatchableError, "getTokensByChain failed: " & err)
    output["tokens"] = if response.isNil: newJArray() else: response
  except Exception as e:
    output["error"] = %* fmt"Error building groups for chain {arg.chainId}: {e.msg}"
  arg.finish(output)

#################################################
# Async load transactions
#################################################

const DAYS_IN_WEEK = 7
const HOURS_IN_DAY = 24

type
  FetchTokensMarketValuesTaskArg = ref object of QObjectTaskArg
    tokensKeys: seq[string]
    currency: string

proc fetchTokensMarketValuesTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchTokensMarketValuesTaskArg](argEncoded)
  var output = %*{
    "tokenMarketValues": newJNull(),
    "error": ""
  }
  try:
    let response = backend.fetchMarketValues(arg.tokensKeys, arg.currency)
    output["tokenMarketValues"] = %*response
  except Exception as e:
    output["error"] = %* fmt"Error fetching market values: {e.msg}"
  arg.finish(output)


type
  FetchTokensDetailsTaskArg = ref object of QObjectTaskArg
    tokensKeys: seq[string]

proc fetchTokensDetailsTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchTokensDetailsTaskArg](argEncoded)
  var output = %*{
    "tokensDetails": newJNull(),
    "error": ""
  }
  try:
    let response = backend.fetchTokenDetails(arg.tokensKeys)
    output["tokensDetails"] = %*response
  except Exception as e:
    output["error"] = %* fmt"Error fetching token details: {e.msg}"
  arg.finish(output)

type
  FetchTokensPricesTaskArg = ref object of QObjectTaskArg
    tokensKeys: seq[string]
    currencies: seq[string]

proc fetchTokensPricesTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchTokensPricesTaskArg](argEncoded)
  var output = %*{
    "tokensPrices": newJNull(),
    "error": ""
  }
  try:
    let response = backend.fetchPrices(arg.tokensKeys, arg.currencies)
    output["tokensPrices"] = %*response
  except Exception as e:
    output["error"] = %* fmt"Error fetching prices: {e.msg}"
  arg.finish(output)

type
  GetTokenHistoricalDataTaskArg = ref object of QObjectTaskArg
    tokenKey: string
    currency: string
    range: int

proc daysInCurrentMonthCycle(): int =
  let today = now()

  # Subtract 1 month to get the "same day" in the previous month
  # Nim handles the year rollover and month lengths automatically
  let sameDayLastMonth = today - months(1)

  # Calculate the duration between the two points in time
  let diff = today - sameDayLastMonth

  # Return the total number of full days as an integer
  return diff.inDays.int

proc getTokenHistoricalDataTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetTokenHistoricalDataTaskArg](argEncoded)
  var
    response = %*{}
    output = %*{
      "tokenKey": arg.tokenKey,
      "range": arg.range,
      "error": ""
    }
  try:
    let td = now()
    case arg.range:
      of WEEKLY_TIME_RANGE:
        response = backend.getHourlyMarketValues(arg.tokenKey, arg.currency, DAYS_IN_WEEK*HOURS_IN_DAY, 1).result
      of MONTHLY_TIME_RANGE:
        response = backend.getDailyMarketValues(arg.tokenKey, arg.currency, daysInCurrentMonthCycle(), false, 1).result
      of HALF_YEARLY_TIME_RANGE:
        response = backend.getDailyMarketValues(arg.tokenKey, arg.currency, int(getDaysInYear(td.year)/2), false, 1).result
      of YEARLY_TIME_RANGE:
        response = backend.getDailyMarketValues(arg.tokenKey, arg.currency, getDaysInYear(td.year), false, 1).result
      of ALL_TIME_RANGE:
        response = backend.getDailyMarketValues(arg.tokenKey, arg.currency, 1, true, 12).result
      else:
        output["error"] = %* "Range not defined"

    output["historicalData"] = response

  except Exception as e:
    output["error"] = %* "Historical market value not found"
  arg.finish(output)

type
  PrefetchParaswapSupportTaskArg = ref object of QObjectTaskArg
    chainId: int

proc prefetchParaswapSupportTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[PrefetchParaswapSupportTaskArg](argEncoded)
  if arg.chainId <= 0:
    arg.finish(%*{"chainId": 0, "error": "invalid chainId"})
    return
  try:
    var response: JsonNode
    var err = status_go_tokens.isChainSupportedForSwapViaParaswap(response, arg.chainId)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JBool:
      raise newException(CatchableError, "unexpected response")
    arg.finish(%*{
      "chainId": arg.chainId,
      "supported": response.getBool(),
      "error": "",
    })
  except Exception as e:
    error "prefetch paraswap chain support failed", chainId = arg.chainId, err = e.msg
    arg.finish(%*{
      "chainId": arg.chainId,
      "error": e.msg,
    })
