import unittest, json, tables

import app_service/service/token/token_market_values_apply
import app_service/service/token/items/market_values

proc pricesResponse(currency: string, price: float): TokensPricesSlotResponse =
  TokensPricesSlotResponse(
    currency: currency,
    tokensPrices: %*{"result": {"eth": {currency: price}}})

proc marketValuesResponse(currency: string, marketCap: float): TokensMarketValuesSlotResponse =
  TokensMarketValuesSlotResponse(
    currency: currency,
    tokenMarketValues: %*{"result": {"eth": {"MKTCAP": marketCap}}})

suite "applyPricesResponse":
  test "prices for the current currency fill the cache":
    var prices = initTable[string, float64]()
    var hasCache = false
    check applyPricesResponse(prices, hasCache, pricesResponse("eur", 2.0), "eur")
    check hasCache
    check prices["eth"] == 2.0

  test "currency match is case-insensitive":
    var prices = initTable[string, float64]()
    var hasCache = false
    check applyPricesResponse(prices, hasCache, pricesResponse("USD", 3.0), "usd")
    check prices["eth"] == 3.0

  test "prices fetched for the previous currency are dropped":
    var prices = initTable[string, float64]()
    var hasCache = false
    check not applyPricesResponse(prices, hasCache, pricesResponse("usd", 1.0), "eur")
    check not hasCache
    check prices.len == 0

  test "an error for the current currency raises":
    var prices = initTable[string, float64]()
    var hasCache = false
    expect ValueError:
      discard applyPricesResponse(prices, hasCache,
        TokensPricesSlotResponse(currency: "eur", error: "boom"), "eur")

suite "applyMarketValuesResponse":
  test "market values for the current currency fill the cache":
    var values = initTable[string, TokenMarketValuesItem]()
    var hasCache = false
    check applyMarketValuesResponse(values, hasCache, marketValuesResponse("eur", 5.0), "eur")
    check hasCache
    check values["eth"].marketCap == 5.0

  test "market values fetched for the previous currency are dropped":
    var values = initTable[string, TokenMarketValuesItem]()
    var hasCache = false
    check not applyMarketValuesResponse(values, hasCache, marketValuesResponse("usd", 5.0), "eur")
    check not hasCache
    check values.len == 0
