import app/modules/shared_models/model_utils
import nimqml, tables, strutils, std/strformat, sequtils, sugar, json, stint

import app_service/service/network/types
import app/modules/shared_models/currency_amount
import ./network_route_item, ./suggested_route_item

type
  ModelRole* {.pure.} = enum
    ChainId = UserRole + 1,
    IsRouteEnabled
    IsRoutePreferred
    HasGas
    TokenBalance
    AmountIn
    AmountOut
    ToNetworks

QtObject:
  type NetworkRouteModel* = ref object of QAbstractListModel
    items*: seq[NetworkRouteItem]

  proc delete(self: NetworkRouteModel)
  proc setup(self: NetworkRouteModel)
  proc newNetworkRouteModel*(): NetworkRouteModel =
    new(result, delete)
    result.setup

  proc `$`*(self: NetworkRouteModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: NetworkRouteModel) {.signal.}

  proc getCount(self: NetworkRouteModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount*(self: NetworkRouteModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: NetworkRouteModel): Table[int, string] =
    {
      ModelRole.ChainId.int:"chainId",
      ModelRole.IsRouteEnabled.int:"isRouteEnabled",
      ModelRole.IsRoutePreferred.int:"isRoutePreferred",
      ModelRole.HasGas.int:"hasGas",
      ModelRole.TokenBalance.int:"tokenBalance",
      ModelRole.AmountIn.int:"amountIn",
      ModelRole.AmountOut.int:"amountOut",
      ModelRole.ToNetworks.int:"toNetworks"
    }.toTable

  method data(self: NetworkRouteModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.ChainId:
      result = newQVariant(item.getChainId())
    of ModelRole.IsRouteEnabled:
      result = newQVariant(item.isRouteEnabled())
    of ModelRole.IsRoutePreferred:
      result = newQVariant(item.isRoutePreferred())
    of ModelRole.HasGas:
      result = newQVariant(item.hasGas())
    of ModelRole.TokenBalance:
      result = newQVariant(item.getTokenBalance())
    of ModelRole.AmountIn:
      result = newQVariant(item.amountIn())
    of ModelRole.AmountOut:
      result = newQVariant(item.amountOut())
    of ModelRole.ToNetworks:
      result = newQVariant(item.toNetworks())

  proc setItems*(self: NetworkRouteModel, items: seq[NetworkRouteItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getAllNetworksChainIds*(self: NetworkRouteModel): seq[int] =
    return self.items.map(x => x.getChainId())

  proc findIndexByChainId(self: NetworkRouteModel, chainId: int): int =
    for i in 0 ..< self.items.len:
      if self.items[i].getChainId() == chainId:
        return i
    return -1

  proc reset*(self: NetworkRouteModel) =
    for ind in 0 ..< self.items.len:
      let amountIn = ""
      let amountOut = ""
      let toNetworks = ""
      let hasGas = true
      let isRouteEnabled = true
      let isRoutePreferred = true
      updateRolesAndNotify:
        updateRole(amountIn)
        updateRole(amountOut)
        updateRole(toNetworks)
        updateRole(hasGas)
        updateRole(isRouteEnabled)
        updateRole(isRoutePreferred)

  proc updateTokenBalanceForSymbol*(self: NetworkRouteModel, chainId: int, tokenBalance: CurrencyAmount) =
    updateItemRolesAndNotify self.findIndexByChainId(chainId):
      updateRole(tokenBalance)

  proc updateFromNetworks*(self: NetworkRouteModel, path: SuggestedRouteItem, hasGas: bool) =
    for ind in 0 ..< self.items.len:
      if path.getfromNetwork() == self.items[ind].getChainId():
        let amountIn = path.getAmountIn()
        let toNetworks = if self.items[ind].toNetworks().len == 0:
          $path.getToNetwork()
        else:
          self.items[ind].toNetworks() & ":" & $path.getToNetwork()
        updateRolesAndNotify:
          updateRole(amountIn)
          updateRole(toNetworks)
          updateRole(hasGas)

  proc updateToNetworks*(self: NetworkRouteModel, path: SuggestedRouteItem) =
    for ind in 0 ..< self.items.len:
      if path.getToNetwork() == self.items[ind].getChainId():
        let targetAmountOut = if self.items[ind].amountOut().len != 0:
          $(stint.u256(self.items[ind].amountOut()) + stint.u256(path.getAmountOut()))
        else:
          path.getAmountOut()
        updateRolesAndNotify:
          updateRoleWithValue(amountOut, targetAmountOut)

  proc resetPathData*(self: NetworkRouteModel) =
    for ind in 0 ..< self.items.len:
      let amountIn = ""
      let amountOut = ""
      let toNetworks = ""
      let hasGas = true
      updateRolesAndNotify:
        updateRole(amountIn)
        updateRole(amountOut)
        updateRole(toNetworks)
        updateRole(hasGas)

  proc getSelectedChain*(self: NetworkRouteModel): int =
    for item in self.items:
      if item.isRouteEnabled():
        return item.getChainId()
    return 0

  proc updateRoutePreferredChains*(self: NetworkRouteModel, chainIds: string) =
    try:
      for ind in 0 ..< self.items.len:
        var isRoutePreferred = false
        if chainIds.len == 0:
          isRoutePreferred = self.items[ind].getLayer() == NETWORK_LAYER_1
        else:
          for chainID in chainIds.split(':'):
            if $self.items[ind].getChainId() == chainID:
              isRoutePreferred = true

        let isRouteEnabled = isRoutePreferred
        updateRolesAndNotify:
          updateRole(isRoutePreferred)
          updateRole(isRouteEnabled)
    except:
      discard

  proc disableRouteUnpreferredChains*(self: NetworkRouteModel) =
    for ind in 0 ..< self.items.len:
      if not self.items[ind].isRoutePreferred():
        updateRolesAndNotify:
          updateRoleWithValue(isRouteEnabled, false)

  proc enableRouteUnpreferredChains*(self: NetworkRouteModel) =
    for ind in 0 ..< self.items.len:
      if not self.items[ind].isRoutePreferred():
        updateRolesAndNotify:
          updateRoleWithValue(isRouteEnabled, true)


  proc setRouteEnabledChain*(self: NetworkRouteModel, chainId: int) {.slot.} =
    for ind in 0 ..< self.items.len:
      let isRouteEnabled = self.items[ind].getChainId() == chainId
      updateRolesAndNotify:
        updateRole(isRouteEnabled)

  proc delete(self: NetworkRouteModel) =
    self.QAbstractListModel.delete

  proc setup(self: NetworkRouteModel) =
    self.QAbstractListModel.setup
