import nimqml, strutils, json

import ./io_interface
import app/modules/shared/wallet_utils
import app_service/service/currency/dto
import app_service/service/token/items/market_values
import app/modules/shared_models/currency_amount

QtObject:
  type MarketDetailsItem* = ref object of QObject
    tokenKey*: string
    currencyFormat: CurrencyFormatDto
    tokenPrice: float64
    tokenMarketValues: TokenMarketValuesItem

    # according to the PR: https://github.com/status-im/status-desktop/pull/18985 in order to avoid craches we need
    # to maintain these items locally instead of returning temporary CurrencyAmount items
    currencyPriceItem: CurrencyAmount
    marketCapItem: CurrencyAmount
    highDayItem: CurrencyAmount
    lowDayItem: CurrencyAmount

  proc setup*(self: MarketDetailsItem)
  proc delete*(self: MarketDetailsItem)

  proc newMarketDetailsItem*(tokenKey: string, tokenPrice: float64, tokenMarketValues: TokenMarketValuesItem,
    currencyFormat: CurrencyFormatDto): MarketDetailsItem =
    new(result, delete)
    result.setup()
    result.tokenKey = tokenKey
    result.tokenPrice = tokenPrice
    result.tokenMarketValues = tokenMarketValues
    result.currencyFormat = currencyFormat

    result.currencyPriceItem = currencyAmountToItem(tokenPrice, result.currencyFormat)
    result.marketCapItem = currencyAmountToItem(tokenMarketValues.marketCap, result.currencyFormat)
    result.highDayItem = currencyAmountToItem(tokenMarketValues.highDay, result.currencyFormat)
    result.lowDayItem = currencyAmountToItem(tokenMarketValues.lowDay, result.currencyFormat)

  proc currencyPriceChanged*(self: MarketDetailsItem) {.signal.}
  proc currencyPrice*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.currencyPriceItem)
  QtProperty[QVariant] currencyPrice:
    read = currencyPrice
    notify = currencyPriceChanged

  proc marketCapChanged*(self: MarketDetailsItem) {.signal.}
  proc marketCap*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.marketCapItem)
  QtProperty[QVariant] marketCap:
    read = marketCap
    notify = marketCapChanged

  proc highDayChanged*(self: MarketDetailsItem) {.signal.}
  proc highDay*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.highDayItem)
  QtProperty[QVariant] highDay:
    read = highDay
    notify = highDayChanged

  proc lowDayChanged*(self: MarketDetailsItem) {.signal.}
  proc lowDay*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.lowDayItem)
  QtProperty[QVariant] lowDay:
    read = lowDay
    notify = lowDayChanged

  proc changePctHourChanged*(self: MarketDetailsItem) {.signal.}
  proc changePctHour*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.tokenMarketValues.changePctHour)
  QtProperty[QVariant] changePctHour:
    read = changePctHour
    notify = changePctHourChanged

  proc changePctDayChanged*(self: MarketDetailsItem) {.signal.}
  proc changePctDay*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.tokenMarketValues.changePctDay)
  QtProperty[QVariant] changePctDay:
    read = changePctDay
    notify = changePctDayChanged

  proc changePct24hourChanged*(self: MarketDetailsItem) {.signal.}
  proc changePct24hour*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.tokenMarketValues.changePct24hour)
  QtProperty[QVariant] changePct24hour:
    read = changePct24hour
    notify = changePct24hourChanged

  proc change24hourChanged*(self: MarketDetailsItem) {.signal.}
  proc change24hour*(self: MarketDetailsItem): QVariant {.slot.} =
    return newQVariant(self.tokenMarketValues.change24hour)
  QtProperty[QVariant] change24hour:
    read = change24hour
    notify = change24hourChanged

  proc updateCurrencyFormat*(self: MarketDetailsItem, currencyFormat: CurrencyFormatDto) =
    self.currencyFormat = currencyFormat
    self.currencyPriceItem = currencyAmountToItem(self.tokenPrice, self.currencyFormat)
    self.marketCapItem = currencyAmountToItem(self.tokenMarketValues.marketCap, self.currencyFormat)
    self.highDayItem = currencyAmountToItem(self.tokenMarketValues.highDay, self.currencyFormat)
    self.lowDayItem = currencyAmountToItem(self.tokenMarketValues.lowDay, self.currencyFormat)
    self.currencyPriceChanged()
    self.marketCapChanged()
    self.highDayChanged()
    self.lowDayChanged()

  proc updateTokenPrice*(self: MarketDetailsItem, tokenPrice: float64) =
    self.tokenPrice = tokenPrice
    self.currencyPriceItem = currencyAmountToItem(self.tokenPrice, self.currencyFormat)
    self.currencyPriceChanged()

  proc updateTokenMarketValues*(self: MarketDetailsItem, tokenMarketValues: TokenMarketValuesItem) =
    self.tokenMarketValues = tokenMarketValues
    self.marketCapItem = currencyAmountToItem(self.tokenMarketValues.marketCap, self.currencyFormat)
    self.highDayItem = currencyAmountToItem(self.tokenMarketValues.highDay, self.currencyFormat)
    self.lowDayItem = currencyAmountToItem(self.tokenMarketValues.lowDay, self.currencyFormat)
    self.marketCapChanged()
    self.highDayChanged()
    self.lowDayChanged()
    self.changePctHourChanged()
    self.changePctDayChanged()
    self.changePct24hourChanged()
    self.change24hourChanged()

  proc updateRepresentativeToken*(self: MarketDetailsItem, tokenKey: string, tokenPrice: float64,
      tokenMarketValues: TokenMarketValuesItem) =
    ## The group's representative token (the first priced token in the group) changed
    ## for a surviving group key: repoint tokenKey and refresh every derived figure so
    ## the market-values signal path (which re-fetches by self.tokenKey) reads the new
    ## token rather than the stale one. Currency format is untouched (its own updater).
    self.tokenKey = tokenKey
    self.tokenPrice = tokenPrice
    self.tokenMarketValues = tokenMarketValues
    self.currencyPriceItem = currencyAmountToItem(self.tokenPrice, self.currencyFormat)
    self.marketCapItem = currencyAmountToItem(self.tokenMarketValues.marketCap, self.currencyFormat)
    self.highDayItem = currencyAmountToItem(self.tokenMarketValues.highDay, self.currencyFormat)
    self.lowDayItem = currencyAmountToItem(self.tokenMarketValues.lowDay, self.currencyFormat)
    self.currencyPriceChanged()
    self.marketCapChanged()
    self.highDayChanged()
    self.lowDayChanged()
    self.changePctHourChanged()
    self.changePctDayChanged()
    self.changePct24hourChanged()
    self.change24hourChanged()

  proc setup*(self: MarketDetailsItem) =
    self.QObject.setup

  proc delete*(self: MarketDetailsItem) =
    self.QObject.delete