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

QtObject:
  type MarketLeaderboardModel* = ref object of QAbstractListModel
    delegate: io_interface.MarketLeaderboardDataSource

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

  proc modelsUpdated*(self: MarketLeaderboardModel) =
    self.beginResetModel()
    self.endResetModel()

  proc pageUpdated*(self: MarketLeaderboardModel, updates: seq[LeaderboardTokenUpdated]) =
    for update in updates:
      let modelIndex = self.createIndex(update.index, 0, nil)
      defer: modelIndex.delete
      var changedRoles: seq[int] = @[]
      for field in update.changedFields:
        let roleOpt = self.getRoleFromName(field)
        if roleOpt.isSome:
          changedRoles.add(roleOpt.get())

      if changedRoles.len > 0:
        self.dataChanged(modelIndex, modelIndex, changedRoles)

  proc setup(self: MarketLeaderboardModel) =
    self.QAbstractListModel.setup

  proc delete(self: MarketLeaderboardModel) =
    self.QAbstractListModel.delete
