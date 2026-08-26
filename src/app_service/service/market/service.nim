import nimqml, strutils, tables, chronicles

import app/core/eventemitter
import app/core/signals/types
import backend/backend as backend

import app_service/service/settings/service as settings_service
import json_serialization

import service_items

export service_items

logScope:
  topics = "market-service"

# Signals which may be emitted by this service:
const
  SIGNAL_MARKET_LEADERBOARD_PAGE_LOADED* = "marketLeaderboardPageLoaded"
  SIGNAL_MARKET_LEADERBOARD_TOKEN_UPDATED* = "marketLeaderboardTokenUpdated"

# Signals coming from statusgo
  EventFetchLeaderboardPageDone = "wallet-fetch-leaderboard-page-done"
  EventLeaderboardPageDataUpdated = "wallet-leaderboard-page-data-updated"
  EventLeaderboardPagePricesUpdated = "wallet-leaderboard-page-prices-updated"

type LeaderboardTokenUpdated* = ref object of Args
  index*: int
  changedFields*: seq[string]

type
  LeaderboardTokensBatchUpdated* = ref object of Args
    updates*: seq[LeaderboardTokenUpdated]

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    settingsService: settings_service.Service
    marketLeaderboardTokens: seq[MarketItem]
    leaderboardPageLoading: bool
    totalLeaderboardCount: int
    currentPage: int
    currentCurrency: string

  # forward declaration
  proc handleLeaderboardPageLoaded(self: Service, data: WalletSignal)
  proc handlePageDataUpdated(self: Service, data: WalletSignal)
  proc handlePricesUpdated(self: Service, data: WalletSignal)

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    settingsService: settings_service.Service
  ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.settingsService = settingsService
    result.leaderboardPageLoading = false
    result.totalLeaderboardCount = 0
    result.currentPage = -1
    result.currentCurrency = ""
    result.marketLeaderboardTokens = @[]

  proc init*(self: Service) =
    self.events.on(SignalType.Wallet.event) do(e:Args):
      var data = WalletSignal(e)
      case data.eventType:
        of EventFetchLeaderboardPageDone:
          self.handleLeaderboardPageLoaded(data)
        of EventLeaderboardPageDataUpdated:
          self.handlePageDataUpdated(data)
        of EventLeaderboardPagePricesUpdated:
          self.handlePricesUpdated(data)

  proc updateBelongsToPage(self: Service, currency: string): bool =
    ## An update belongs to the displayed page when it carries the currency
    ## that page is in. That is normally the selected currency, but the backend
    ## serves a fallback one when the market data provider cannot price the
    ## selection, and the updates then arrive in the fallback too.
    return currency.cmpIgnoreCase(self.currentCurrency) == 0 or
        currency.cmpIgnoreCase(self.settingsService.getCurrency()) == 0

  proc handleLeaderboardPageLoaded(self: Service, data: WalletSignal) =
    try:
      let leaderboardData = Json.decode($data.message, LeaderboardPage, allowUnknownFields = true)
      if self.currentPage == leaderboardData.page:
        self.leaderboardPageLoading = false
        self.totalLeaderboardCount = leaderboardData.totalCount
        self.marketLeaderboardTokens = leaderboardData.data
        self.currentCurrency = leaderboardData.currency
        self.events.emit(SIGNAL_MARKET_LEADERBOARD_PAGE_LOADED, Args())
    except:
      error "Error parsing page loaded leaderboard data"

  proc handlePageDataUpdated(self: Service, data: WalletSignal) =
    try:
      let leaderboardData = Json.decode($data.message, LeaderboardPage, allowUnknownFields = true)
      if self.currentPage == leaderboardData.page and
          self.updateBelongsToPage(leaderboardData.currency):
        self.currentCurrency = leaderboardData.currency

        var updates: seq[LeaderboardTokenUpdated] = @[]

        for i in 0..<leaderboardData.data.len:
          let result = leaderboardData.data[i].diff(self.marketLeaderboardTokens[i])
          if not result.isEqual:
            updates.add(LeaderboardTokenUpdated(index: i, changedFields: result.changedFields))

        if updates.len > 0:
          self.events.emit(SIGNAL_MARKET_LEADERBOARD_TOKEN_UPDATED,
              LeaderboardTokensBatchUpdated(updates: updates))
    except:
      error "Error parsing leaderboard page update data"


  proc handlePricesUpdated(self: Service, data: WalletSignal) =
    try:
      let leaderboardPricesUpdate = Json.decode($data.message, LeaderboardPagePrices, allowUnknownFields = true)
      if self.currentPage == leaderboardPricesUpdate.page and
          self.updateBelongsToPage(leaderboardPricesUpdate.currency):

        # Create a temporary Table for fast lookups: key => (index, MarketItem)
        var tokenMap = initTable[string, int]()
        for i, token in self.marketLeaderboardTokens:
          tokenMap[token.key] = i

        var updates: seq[LeaderboardTokenUpdated] = @[]

        for newToken in leaderboardPricesUpdate.data:
          if newToken.id in tokenMap:
            let index = tokenMap[newToken.id]
            var tokenToBeUpdated = self.marketLeaderboardTokens[index]
            let result = newToken.pricesDiff(tokenToBeUpdated)
            if not result.isEqual:
              # Update the sequence at the correct index
              self.marketLeaderboardTokens[index] = tokenToBeUpdated
              updates.add(LeaderboardTokenUpdated(index: index, changedFields: result.changedFields))

        if updates.len > 0:
          self.events.emit(SIGNAL_MARKET_LEADERBOARD_TOKEN_UPDATED,
              LeaderboardTokensBatchUpdated(updates: updates))
    except:
      error "Error parsing leaderboard prices update data"

  proc getMarketLeaderboardList*(self: Service): var seq[MarketItem] =
    return self.marketLeaderboardTokens

  proc getMarketLeaderboardLoading*(self: Service): bool =
    return self.leaderboardPageLoading

  proc getTotalMarketLeaderboardModelCount*(self: Service): int =
    return self.totalLeaderboardCount

  proc getCurrentPage*(self: Service): int =
    return self.currentPage

  # backend calls
  proc fetchMarketTokenPage*(self: Service, page: int, pageSize: int = 100, sortOrder: int = 0) =
    try:
      self.currentPage = page
      self.leaderboardPageLoading =  true
      var currentCurrency = self.settingsService.getCurrency()
      discard backend.fetchMarketTokenPageAsync(page, pageSize, sortOrder, currentCurrency)
    except Exception as e:
      error "error when calling fetchMarketTokenPage ", msg = e.msg

  proc unsubscribeFromLeaderboard*(self: Service) =
    try:
      discard backend.unsubscribeFromLeaderboard()
    except Exception as e:
      error "error when calling unsubscribeFromLeaderboard ", msg = e.msg

  proc delete*(self: Service) =
    self.QObject.delete

