import nimqml, tables, strutils, sequtils, sugar

import ./io_interface

from app_service/service/network/service import EXPLORER_TX_PATH
import app_service/service/network/network_item

type
  ModelRole* {.pure.} = enum
    ChainId = UserRole + 1,
    Layer
    ChainName
    BlockExplorerURL
    NativeCurrencyName
    NativeCurrencySymbol
    NativeCurrencyDecimals
    IsTest
    IsEnabled
    IconUrl
    ChainColor
    ShortName
    IsActive
    IsDeactivatable
    CommunitiesSupported

QtObject:
  type
    Model* = ref object of QAbstractListModel
      delegate: io_interface.NetworksDataSource

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(delegate: io_interface.NetworksDataSource): Model =
    new(result, delete)
    result.setup
    result.delegate = delegate

  method rowCount*(self: Model, index: QModelIndex = nil): int =
    return self.delegate.getFlatNetworksList().len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.ChainId.int:"chainId",
      ModelRole.NativeCurrencyDecimals.int:"nativeCurrencyDecimals",
      ModelRole.Layer.int:"layer",
      ModelRole.ChainName.int:"chainName",
      ModelRole.BlockExplorerURL.int:"blockExplorerURL",
      ModelRole.NativeCurrencyName.int:"nativeCurrencyName",
      ModelRole.NativeCurrencySymbol.int:"nativeCurrencySymbol",
      ModelRole.IsTest.int:"isTest",
      ModelRole.IsEnabled.int:"isEnabled",
      ModelRole.IconUrl.int:"iconUrl",
      ModelRole.ShortName.int: "shortName",
      ModelRole.ChainColor.int: "chainColor",
      ModelRole.IsActive.int: "isActive",
      ModelRole.IsDeactivatable.int: "isDeactivatable",
      ModelRole.CommunitiesSupported.int: "communitiesSupported"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.rowCount()):
      return

    let item = self.delegate.getFlatNetworksList()[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.ChainId:
      result = newQVariant(item.chainId)
    of ModelRole.NativeCurrencyDecimals:
      result = newQVariant(item.nativeCurrencyDecimals)
    of ModelRole.Layer:
      result = newQVariant(item.layer)
    of ModelRole.ChainName:
      result = newQVariant(item.chainName)
    of ModelRole.BlockExplorerURL:
      result = newQVariant(item.blockExplorerURL)
    of ModelRole.NativeCurrencyName:
      result = newQVariant(item.nativeCurrencyName)
    of ModelRole.NativeCurrencySymbol:
      result = newQVariant(item.nativeCurrencySymbol)
    of ModelRole.IsTest:
      result = newQVariant(item.isTest)
    of ModelRole.IsEnabled:
      result = newQVariant(item.isEnabled)
    of ModelRole.IconUrl:
      result = newQVariant(item.iconURL)
    of ModelRole.ShortName:
      result = newQVariant(item.shortName)
    of ModelRole.ChainColor:
      result = newQVariant(item.chainColor)
    of ModelRole.IsActive:
      result = newQVariant(item.isActive)
    of ModelRole.IsDeactivatable:
      result = newQVariant(item.isDeactivatable)
    of ModelRole.CommunitiesSupported:
      result = newQVariant(item.communitiesSupported)

  proc refreshModel*(self: Model) =
    self.beginResetModel()
    self.endResetModel()

  proc getBlockExplorerTxURL*(self: Model, chainId: int): string =
    for item in self.delegate.getFlatNetworksList():
      if(item.chainId == chainId):
        return item.blockExplorerURL & EXPLORER_TX_PATH
    return ""

  # Returns currently active networks (i.e. isActive is true and isTest matches the given testnet mode)
  proc getFilteredNetworks(self: Model, areTestNetworksEnabled: bool): seq[NetworkItem] =
    return self.delegate.getFlatNetworksList().filter(n => n.isTest == areTestNetworksEnabled and n.isActive)

  proc getEnabledNetworks(self: Model, areTestNetworksEnabled: bool): seq[NetworkItem] =
    return self.getFilteredNetworks(areTestNetworksEnabled).filter(n => n.isEnabled)

  proc getEnabledChainIds*(self: Model, areTestNetworksEnabled: bool): string =
    return self.getEnabledNetworks(areTestNetworksEnabled).map(n => n.chainId).join(":")

  proc getNetworkByChainId*(self: Model, chainId: int): NetworkItem =
    for network in self.delegate.getFlatNetworksList():
      if chainId == network.chainId:
        return network
    return nil

  # Returns the chains that need to be enabled or disabled (the second return value)
  #   to satisty the transitions: all enabled to only chainId enabled and
  #   only chainId enabled to all enabled
  proc networksToChangeStateOnUserActionFor*(self: Model, chainId: int, areTestNetworksEnabled: bool): (seq[int], bool) =
    let filteredNetworks = self.getFilteredNetworks(areTestNetworksEnabled)
    let allEnabled = filteredNetworks.all(n => n.isEnabled)
    var chainIds: seq[int] = @[]
    var enable = false

    if allEnabled:
      # disable all but chainId
      for item in filteredNetworks:
        if item.chainId != chainId:
          chainIds.add(item.chainId)
    else:
      let network = self.getNetworkByChainId(chainId)
      if network != nil:
        if network.isEnabled:
          # Iterate to check for the only chainId enabled case ...
          for item in filteredNetworks:
            if item.isEnabled and item.chainId != chainId:
              # ... as soon as we find another enabled chain mark this by adding it to the list
              chainIds.add(chainId)
              break

          # ... if no other chains are enabled, then it's a transition from only chainId enabled to all enabled
          if chainIds.len == 0:
            for item in filteredNetworks:
              if item.chainId != chainId:
                chainIds.add(item.chainId)
            enable = true
        else:
          # enable chainId
          chainIds.add(chainId)
          enable = true
    return (chainIds, enable)

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

