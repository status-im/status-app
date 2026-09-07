import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import nimqml, tables

import app_service/service/market/service as market_service

import ./io_interface

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    Name
    Symbol
    Image
    CurrentPrice
    MarketCap
    TotalVolume
    PriceChangePercentage24h

type
  # The service mutates its MarketItem refs in place, so the model keeps its own
  # value copies: that is what a diff against the previous state runs on.
  LeaderboardRow = object
    key: string
    name: string
    symbol: string
    image: string
    currentPrice: float64
    marketCap: float64
    totalVolume: float64
    priceChangePercentage24h: float64

proc toRows(items: seq[MarketItem]): seq[LeaderboardRow] =
  result = newSeqOfCap[LeaderboardRow](items.len)
  for item in items:
    result.add(LeaderboardRow(
      key: item.key,
      name: item.name,
      symbol: item.symbol,
      image: item.image,
      currentPrice: item.currentPrice,
      marketCap: item.marketCap,
      totalVolume: item.totalVolume,
      priceChangePercentage24h: item.priceChangePercentage24h,
    ))

proc syncKey(it: LeaderboardRow): string = it.key
proc syncRoles(o, n: LeaderboardRow): seq[int] =
  result = @[]
  if o.name != n.name: result.add(ModelRole.Name.int)
  if o.symbol != n.symbol: result.add(ModelRole.Symbol.int)
  if o.image != n.image: result.add(ModelRole.Image.int)
  if o.currentPrice != n.currentPrice: result.add(ModelRole.CurrentPrice.int)
  if o.marketCap != n.marketCap: result.add(ModelRole.MarketCap.int)
  if o.totalVolume != n.totalVolume: result.add(ModelRole.TotalVolume.int)
  if o.priceChangePercentage24h != n.priceChangePercentage24h:
    result.add(ModelRole.PriceChangePercentage24h.int)

QtObject:
  type MarketLeaderboardModel* = ref object of QAbstractListModel
    delegate: io_interface.MarketLeaderboardDataSource
    items: seq[LeaderboardRow]

  proc setup(self: MarketLeaderboardModel)
  proc delete(self: MarketLeaderboardModel)
  proc newMarketLeaderboardModel*(
    delegate: io_interface.MarketLeaderboardDataSource,
    ): MarketLeaderboardModel =
    new(result, delete)
    result.setup
    result.delegate = delegate

  method rowCount(self: MarketLeaderboardModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: MarketLeaderboardModel): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.Name.int:"name",
      ModelRole.Symbol.int:"symbol",
      ModelRole.Image.int:"image",
      ModelRole.CurrentPrice.int:"currentPrice",
      ModelRole.MarketCap.int:"marketCap",
      ModelRole.TotalVolume.int:"totalVolume",
      ModelRole.PriceChangePercentage24h.int:"priceChangePercentage24h",
    }.toTable

  method data(self: MarketLeaderboardModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Key:
        result = newQVariant(item.key)
      of ModelRole.Name:
        result = newQVariant(item.name)
      of ModelRole.Symbol:
        result = newQVariant(item.symbol)
      of ModelRole.Image:
        result = newQVariant(item.image)
      of ModelRole.CurrentPrice:
        result = newQVariant(item.currentPrice)
      of ModelRole.MarketCap:
        result = newQVariant(item.marketCap)
      of ModelRole.TotalVolume:
        result = newQVariant(item.totalVolume)
      of ModelRole.PriceChangePercentage24h:
        result = newQVariant(item.priceChangePercentage24h)

  # Both entry points read the service's current page and diff it against the
  # rows on display: granular insert/remove for a page change, dataChanged with
  # the touched roles for a price tick, nothing for an unchanged page.
  proc modelsUpdated*(self: MarketLeaderboardModel) =
    self.modelSync(self.items, toRows(self.delegate.getMarketLeaderboardList()))

  proc pageUpdated*(self: MarketLeaderboardModel, updates: seq[LeaderboardTokenUpdated]) =
    self.modelsUpdated()

  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: MarketLeaderboardModel): seq[string] =
      for it in self.items: result.add(it.key)

  proc setup(self: MarketLeaderboardModel) =
    self.QAbstractListModel.setup

  proc delete(self: MarketLeaderboardModel) =
    self.QAbstractListModel.delete
