import nimqml, sequtils, strutils

import ./io_interface, ./model, ./rpc_providers_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      flatNetworks: Model
      rpcProvidersModel: RpcProvidersModel
      areTestNetworksEnabled: bool
      enabledChainIds: string

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.delegate = delegate
    result.flatNetworks = newModel(delegate.getNetworksDataSource())
    result.rpcProvidersModel = newRpcProvidersModel(delegate.getNetworksDataSource())
    result.enabledChainIds = ""
    result.setup()

  proc areTestNetworksEnabledChanged*(self: View) {.signal.}

  proc getAreTestNetworksEnabled(self: View): QVariant {.slot.} =
    return newQVariant(self.areTestNetworksEnabled)

  QtProperty[QVariant] areTestNetworksEnabled:
    read = getAreTestNetworksEnabled
    notify = areTestNetworksEnabledChanged

  proc setAreTestNetworksEnabled*(self: View, areTestNetworksEnabled: bool) =
    self.areTestNetworksEnabled = areTestNetworksEnabled
    self.areTestNetworksEnabledChanged()

  proc toggleTestNetworksEnabled*(self: View) {.slot.} =
    self.delegate.toggleTestNetworksEnabled()

  proc flatNetworksChanged*(self: View) {.signal.}
  proc getFlatNetworks(self: View): QAbstractListModel {.slot.} =
    return self.flatNetworks
  QtProperty[QAbstractListModel] flatNetworks:
    read = getFlatNetworks
    notify = flatNetworksChanged

  proc rpcProvidersChanged*(self: View) {.signal.}
  proc getRpcProviders(self: View): QAbstractListModel {.slot.} =
    return self.rpcProvidersModel
  QtProperty[QAbstractListModel] rpcProviders:
    read = getRpcProviders
    notify = rpcProvidersChanged

  proc enabledChainIdsChanged*(self: View) {.signal.}
  proc getEnabledChainIds(self: View): QVariant {.slot.} =
    return newQVariant(self.enabledChainIds)
  QtProperty[QVariant] enabledChainIds:
    read = getEnabledChainIds
    notify = enabledChainIdsChanged

  proc refreshModel*(self: View) =
    self.flatNetworks.refreshModel()
    self.rpcProvidersModel.refreshModel()
    self.enabledChainIds = self.flatNetworks.getEnabledChainIds(self.areTestNetworksEnabled)
    self.flatNetworksChanged()
    self.rpcProvidersChanged()
    self.enabledChainIdsChanged()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  # Used for balances/collectibles/activity filters
  proc toggleNetwork*(self: View, chainId: int) {.slot.} =
    let (chainIds, enable) = self.flatNetworks.networksToChangeStateOnUserActionFor(chainId, self.areTestNetworksEnabled)
    self.delegate.setNetworksState(chainIds, enable)

  # Used for balances/collectibles/activity filters
  proc enableNetwork*(self: View, chainId: int) {.slot.} =
    self.delegate.setNetworksState(@[chainId], enable = true)

  proc getBlockExplorerTxURL*(self: View, chainId: int): string {.slot.} =
    return self.flatNetworks.getBlockExplorerTxURL(chainId)

  # Used for enabling/disabling network across the whole app
  proc setNetworkActive*(self: View, chainId: int, active: bool) {.slot.} =
    self.delegate.setNetworkActive(chainId, active)

  proc updateNetworkEndPointValues*(self: View, chainId: int, newMainRpcInput: string, newFailoverRpcUrl: string) {.slot.} =
    self.delegate.updateNetworkEndPointValues(chainId, newMainRpcInput, newFailoverRpcUrl)

  proc fetchChainIdForUrl*(self: View, url: string, isMainUrl: bool) {.slot.} =
    self.delegate.fetchChainIdForUrl(url, isMainUrl)

  proc chainIdFetchedForUrl*(self: View, url: string, chainId: int, success: bool, isMainUrl: bool) {.signal.}

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

