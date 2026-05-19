import nimqml, chronicles, strutils, tables, json, stint

import ../../../backend/backend as backend

import ../../../app/core/eventemitter
import ../../../app/core/tasks/[qt, threadpool]
import ../../../app/core/signals/types

import ../settings/service as settings_service
import ../token/service as token_service
import ./dto

include  ../../common/json_utils
include async_tasks

export dto

# Signals which may be emitted by this service:
const SIGNAL_CURRENCY_FORMATS_UPDATED* = "currencyFormatsUpdated"

type
  CurrencyFormatsUpdatedArgs* = ref object of Args
    discard

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    tokenService: token_service.Service
    settingsService: settings_service.Service
    currencyFormatCache: Table[string, CurrencyFormatDto] # [key, CurrencyFormatDto] - key can be tokenKey or currency symbol

  # Forward declarations
  proc fetchAllCurrencyFormats(self: Service)
  proc loadCachedCurrencyFormats(self: Service)

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    tokenService: token_service.Service,
    settingsService: settings_service.Service,
  ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.tokenService = tokenService
    result.settingsService = settingsService

  proc init*(self: Service) =
    self.events.on(SignalType.Wallet.event) do(e:Args):
      var data = WalletSignal(e)
      case data.eventType:
        of "wallet-currency-tick-update-format":
          self.fetchAllCurrencyFormats()
          discard
    self.loadCachedCurrencyFormats()
    self.fetchAllCurrencyFormats()

  proc jsonToFormatsTable(node: JsonNode) : Table[string, CurrencyFormatDto] =
    result = initTable[string, CurrencyFormatDto]()

    for (key, formatObj) in node.pairs:
      result[key] = formatObj.toCurrencyFormatDto()

  proc onCachedCurrencyFormatsLoaded(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj.kind != JObject:
        return

      var formatsJson: JsonNode
      discard responseObj.getProp("formats", formatsJson)
      if formatsJson.isNil or formatsJson.kind == JNull:
        return

      let formatsPerKey = jsonToFormatsTable(formatsJson)
      # Don't overwrite entries possibly already populated by a fresher network fetch.
      for key, format in formatsPerKey:
        if not self.currencyFormatCache.hasKey(key):
          self.currencyFormatCache[key] = format
      self.events.emit(SIGNAL_CURRENCY_FORMATS_UPDATED, CurrencyFormatsUpdatedArgs())
    except Exception as e:
      let errDescription = e.msg
      error "error onCachedCurrencyFormatsLoaded: ", errDescription

  proc loadCachedCurrencyFormats(self: Service) =
    let arg = AsyncGetCachedCurrencyFormatsTaskArg(
      tptr: asyncGetCachedCurrencyFormatsTask,
      vptr: cast[uint](self.vptr),
      slot: "onCachedCurrencyFormatsLoaded",
    )
    self.threadpool.start(arg)

  proc onAllCurrencyFormatsFetched(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if (responseObj.kind == JObject):

        var formatsJson: JsonNode
        discard responseObj.getProp("formats", formatsJson)
        if formatsJson.isNil or formatsJson.kind == JNull:
          return

        let formatsPerKey = jsonToFormatsTable(formatsJson)
        for key, format in formatsPerKey:
          self.currencyFormatCache[key] = format
        self.events.emit(SIGNAL_CURRENCY_FORMATS_UPDATED, CurrencyFormatsUpdatedArgs())
    except Exception as e:
      let errDescription = e.msg
      error "error onAllCurrencyFormatsFetched: ", errDescription

  proc fetchAllCurrencyFormats(self: Service) =
    let arg = FetchAllCurrencyFormatsTaskArg(
      tptr: fetchAllCurrencyFormatsTaskArg,
      vptr: cast[uint](self.vptr),
      slot: "onAllCurrencyFormatsFetched",
    )
    self.threadpool.start(arg)

  # Returns the currency format for a given key. Key can be tokenGroupKey, tokenKey or currency symbol
  proc getCurrencyFormat*(self: Service, key: string): CurrencyFormatDto =
    if key.len == 0:
      return newCurrencyFormatDto()
    if not self.currencyFormatCache.hasKey(key):
      let groupedTokens = self.tokenService.getTokensByGroupKey(key)
      if groupedTokens.len > 0: # it means that the provided key is a token group key
        return newCurrencyFormatDto(groupedTokens[0].key, groupedTokens[0].symbol) # since all tokens in the same group have the same symbol and currency format
      let token = self.tokenService.getTokenByKey(key)
      if not token.isNil: # it means that the provided key is has a token key
        return newCurrencyFormatDto(token.key, token.symbol)
      return newCurrencyFormatDto(key, key) # it means that the provided key is a currency symbol
    return self.currencyFormatCache[key]

  proc toFloat(amountInt: UInt256): float64 =
    return float64(amountInt.truncate(uint64))

  proc u256ToFloat(decimals: int, amountInt: UInt256): float64 =
    if decimals == 0:
      return amountInt.toFloat()

    # Convert to float at the end to avoid losing precision
    let base = 10.to(UInt256)
    let p = base.pow(decimals)
    let i = amountInt.div(p)
    let r = amountInt.mod(p)

    return i.toFloat() + r.toFloat() / p.toFloat()

  proc getCurrencyValueForToken*(self: Service, tokenKey: string, amountInt: UInt256): float64 =
    let token = self.tokenService.getTokenByKey(tokenKey)
    var decimals: int = 0
    if not token.isNil:
      decimals = token.decimals
    return u256ToFloat(decimals, amountInt)

  proc delete*(self: Service) =
    self.QObject.delete

