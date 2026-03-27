import times, std/strformat

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
    "tokenMarketValues": "",
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
    "tokensDetails": "",
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
    "tokensPrices": "",
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
