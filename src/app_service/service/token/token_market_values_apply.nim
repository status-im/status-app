import json, tables, strutils
import json_serialization

import dto/market_data
import items/market_values

type
  TokensMarketValuesSlotResponse* = object
    tokenMarketValues*: JsonNode
    currency*: string
    error*: string

  TokensPricesSlotResponse* = object
    tokensPrices*: JsonNode
    currency*: string
    error*: string

proc resultOf(node: JsonNode): JsonNode =
  if node.isNil or node.kind != JObject:
    return nil
  result = node{"result"}
  if not result.isNil and result.kind == JNull:
    result = nil

# Applies prices fetched for `currency`; returns false for a response fetched for another currency.
proc applyPricesResponse*(prices: var Table[string, float64], hasCache: var bool,
    env: TokensPricesSlotResponse, currency: string): bool =
  if cmpIgnoreCase(env.currency, currency) != 0:
    return false
  if not env.error.isEmptyOrWhitespace:
    raise newException(ValueError, "Error getting tokens prices: " & env.error)
  result = true
  let tokens = resultOf(env.tokensPrices)
  if tokens.isNil:
    return
  for (tokenKey, byCurrency) in tokens.pairs:
    for (priceCurrency, price) in byCurrency.pairs:
      if cmpIgnoreCase(priceCurrency, currency) == 0:
        prices[tokenKey] = price.getFloat
  hasCache = true

# Applies market values fetched for `currency`; returns false for a response fetched for another currency.
proc applyMarketValuesResponse*(values: var Table[string, TokenMarketValuesItem], hasCache: var bool,
    env: TokensMarketValuesSlotResponse, currency: string): bool =
  if cmpIgnoreCase(env.currency, currency) != 0:
    return false
  if not env.error.isEmptyOrWhitespace:
    raise newException(ValueError, "Error getting tokens market values: " & env.error)
  result = true
  let tokens = resultOf(env.tokenMarketValues)
  if tokens.isNil:
    return
  for (tokenKey, obj) in tokens.pairs:
    let dto = Json.decode($obj, TokenMarketValuesDto, allowUnknownFields = true)
    values[tokenKey] = TokenMarketValuesItem(
      marketCap: dto.marketCap,
      highDay: dto.highDay,
      lowDay: dto.lowDay,
      changePctHour: dto.changePctHour,
      changePctDay: dto.changePctDay,
      changePct24hour: dto.changePct24hour,
      change24hour: dto.change24hour)
  hasCache = true
