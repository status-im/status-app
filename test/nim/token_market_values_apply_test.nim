import unittest, json, tables, sets

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

suite "pricedKeysInResponse":
  # the on-demand fetch answers for the keys it asked; a key the provider doesn't
  # list comes back absent or at zero and must count as unpriced (it gets backed off)
  proc byKeyResponse(currency: string, prices: JsonNode, requested: seq[string]): TokensPricesSlotResponse =
    TokensPricesSlotResponse(currency: currency, requestedKeys: requested, tokensPrices: %*{"result": prices})

  test "requested keys with a positive price for the currency are priced":
    let env = byKeyResponse("usd", %*{"4663-0x1inch": {"usd": 0.31}, "10-0x1inch": {"usd": 0}}, @["4663-0x1inch", "10-0x1inch"])
    check pricedKeysInResponse(env, "usd") == ["4663-0x1inch"].toHashSet

  test "a key the provider left out is unpriced":
    let env = byKeyResponse("usd", %*{"4663-0x1inch": {"usd": 0.31}}, @["4663-0x1inch", "10-0xdust"])
    check pricedKeysInResponse(env, "usd") == ["4663-0x1inch"].toHashSet

  test "the currency comparison ignores case and other currencies":
    let env = byKeyResponse("usd", %*{"4663-0x1inch": {"USD": 0.31}, "10-0x1inch": {"eur": 0.3}}, @["4663-0x1inch", "10-0x1inch"])
    check pricedKeysInResponse(env, "usd") == ["4663-0x1inch"].toHashSet

  test "a missing result yields no priced keys":
    let env = TokensPricesSlotResponse(currency: "usd", requestedKeys: @["4663-0x1inch"], tokensPrices: newJNull())
    check pricedKeysInResponse(env, "usd").len == 0
