import nimqml, std/strformat, json

include app_service/common/json_utils

QtObject:
  type CurrencyAmount* = ref object of QObject
    amount: float64
    tokenKey: string
    symbol: string
    displayDecimals: int
    stripTrailingZeroes: bool

  proc setup(self: CurrencyAmount)
  proc delete*(self: CurrencyAmount)
  proc newCurrencyAmount*(
    amount: float64,
    tokenKey: string,
    symbol: string,
    displayDecimals: int,
    stripTrailingZeroes: bool,
  ): CurrencyAmount =
    new(result, delete)
    result.setup
    result.amount = amount
    result.tokenKey = tokenKey
    result.symbol = symbol
    result.displayDecimals = displayDecimals
    result.stripTrailingZeroes = stripTrailingZeroes

  proc newCurrencyAmount*: CurrencyAmount =
    result = newCurrencyAmount(0.0, "", "", 0, true)

  proc set*(self: var CurrencyAmount, other: CurrencyAmount) =
    self.amount = other.amount
    self.tokenKey = other.tokenKey
    self.symbol = other.symbol
    self.displayDecimals = other.displayDecimals
    self.stripTrailingZeroes = other.stripTrailingZeroes

  proc `==`*(self: CurrencyAmount, other: CurrencyAmount): bool =
    if self.isNil or other.isNil: return false

    return self.amount == other.amount and
      self.tokenKey == other.tokenKey and
      self.symbol == other.symbol and
      self.displayDecimals == other.displayDecimals and
      self.stripTrailingZeroes == other.stripTrailingZeroes

  proc `$`*(self: CurrencyAmount): string =
    result = fmt"""CurrencyAmount(
      amount: {self.amount},
      tokenKey: {self.tokenKey},
      symbol: {self.symbol},
      displayDecimals: {self.displayDecimals},
      stripTrailingZeroes: {self.stripTrailingZeroes}
      )"""

  proc getAmount*(self: CurrencyAmount): float {.slot.} =
    return self.amount
  QtProperty[float] amount:
    read = getAmount


  proc getTokenKey*(self: CurrencyAmount): string {.slot.} =
    return self.tokenKey
  QtProperty[string] tokenKey:
    read = getTokenKey

  proc getSymbol*(self: CurrencyAmount): string {.slot.} =
    return self.symbol
  QtProperty[string] symbol:
    read = getSymbol

  proc getDisplayDecimals*(self: CurrencyAmount): int {.slot.} =
    return self.displayDecimals
  QtProperty[int] displayDecimals:
    read = getDisplayDecimals

  proc isStripTrailingZeroesActive*(self: CurrencyAmount): bool {.slot.} =
    return self.stripTrailingZeroes
  QtProperty[bool] stripTrailingZeroes:
    read = isStripTrailingZeroesActive

  # Needed to expose object to QML, see issue #8913
  proc toJsonNode*(self: CurrencyAmount): JsonNode =
    result = %* {
      "amount": self.amount,
      "tokenKey": self.tokenKey,
      "symbol": self.symbol,
      "displayDecimals": self.displayDecimals,
      "stripTrailingZeroes": self.stripTrailingZeroes
    }

  # Needed by profile showcase
  proc toCurrencyAmount*(jsonObj: JsonNode): CurrencyAmount =
    new(result, delete)
    result.setup
    discard jsonObj.getProp("amount", result.amount)
    discard jsonObj.getProp("tokenKey", result.tokenKey)
    discard jsonObj.getProp("symbol", result.symbol)
    discard jsonObj.getProp("displayDecimals", result.displayDecimals)
    discard jsonObj.getProp("stripTrailingZeroes", result.stripTrailingZeroes)

  proc setup(self: CurrencyAmount) =
    self.QObject.setup

  proc delete*(self: CurrencyAmount) =
    self.QObject.delete

