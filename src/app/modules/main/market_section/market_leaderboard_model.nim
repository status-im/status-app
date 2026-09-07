import app/modules/shared_models/model_utils
import nimqml, tables, options

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
  # Items are refs the service mutates in place, so values are copied, not items
  SnapshotRow = object
    key: string
    name: string
    symbol: string
    image: string
    currentPrice: float64
    marketCap: float64
    totalVolume: float64
    priceChangePercentage24h: float64

proc toSnapshot(items: seq[MarketItem]): seq[SnapshotRow] =
  result = newSeqOfCap[SnapshotRow](items.len)
  for item in items:
    result.add(SnapshotRow(
      key: item.key,
      name: item.name,
      symbol: item.symbol,
      image: item.image,
      currentPrice: item.currentPrice,
      marketCap: item.marketCap,
      totalVolume: item.totalVolume,
      priceChangePercentage24h: item.priceChangePercentage24h,
    ))

proc changedRolesFor(item: MarketItem, prev: SnapshotRow): seq[int] =
  if item.name != prev.name: result.add(ModelRole.Name.int)
  if item.symbol != prev.symbol: result.add(ModelRole.Symbol.int)
  if item.image != prev.image: result.add(ModelRole.Image.int)
  if item.currentPrice != prev.currentPrice: result.add(ModelRole.CurrentPrice.int)
  if item.marketCap != prev.marketCap: result.add(ModelRole.MarketCap.int)
  if item.totalVolume != prev.totalVolume: result.add(ModelRole.TotalVolume.int)
  if item.priceChangePercentage24h != prev.priceChangePercentage24h:
    result.add(ModelRole.PriceChangePercentage24h.int)

QtObject:
  type MarketLeaderboardModel* = ref object of QAbstractListModel
    delegate: io_interface.MarketLeaderboardDataSource
    snapshot: seq[SnapshotRow]

  proc setup(self: MarketLeaderboardModel)
  proc delete(self: MarketLeaderboardModel)
  proc newMarketLeaderboardModel*(
    delegate: io_interface.MarketLeaderboardDataSource,
    ): MarketLeaderboardModel =
    new(result, delete)
    result.setup
    result.delegate = delegate

  method rowCount(self: MarketLeaderboardModel, index: QModelIndex = nil): int =
    return self.delegate.getMarketLeaderboardList().len

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

  proc getRoleFromName(self: MarketLeaderboardModel, roleName: string): Option[int] =
    for roleInt, name in self.roleNames():
      if name == roleName:
        return some(roleInt)
    return none(int)

  method data(self: MarketLeaderboardModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    # the only way to read items from service is by this single method getMarketLeaderboardList

    let item = self.delegate.getMarketLeaderboardList()[index.row]

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

  proc sameRowsAsSnapshot(self: MarketLeaderboardModel, items: seq[MarketItem]): bool =
    if items.len != self.snapshot.len:
      return false
    for i in 0 ..< items.len:
      if items[i].key != self.snapshot[i].key:
        return false
    return true

  proc modelsUpdated*(self: MarketLeaderboardModel) =
    let items = self.delegate.getMarketLeaderboardList()

    # A reset drops every delegate in the views, so report roles where possible
    if not self.sameRowsAsSnapshot(items):
      self.beginResetModel()
      self.snapshot = toSnapshot(items)
      self.endResetModel()
      return

    for i in 0 ..< items.len:
      let changedRoles = changedRolesFor(items[i], self.snapshot[i])
      if changedRoles.len > 0:
        notifyRangeRolesChanged(i, i, changedRoles)

    self.snapshot = toSnapshot(items)

  proc pageUpdated*(self: MarketLeaderboardModel, updates: seq[LeaderboardTokenUpdated]) =
    for update in updates:
      var changedRoles: seq[int] = @[]
      for field in update.changedFields:
        let roleOpt = self.getRoleFromName(field)
        if roleOpt.isSome:
          changedRoles.add(roleOpt.get())

      if changedRoles.len > 0:
        notifyRangeRolesChanged(update.index, update.index, changedRoles)

    self.snapshot = toSnapshot(self.delegate.getMarketLeaderboardList())

  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: MarketLeaderboardModel): seq[string] =
      for it in self.delegate.getMarketLeaderboardList(): result.add(it.key)

  proc setup(self: MarketLeaderboardModel) =
    self.QAbstractListModel.setup

  proc delete(self: MarketLeaderboardModel) =
    self.QAbstractListModel.delete
