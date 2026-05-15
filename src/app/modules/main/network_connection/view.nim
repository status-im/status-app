import nimqml, json

import ./io_interface
import ./network_connection_item
import ../../../../app_service/service/network_connection/service as network_connection_service

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      blockchainNetworkConnection: NetworkConnectionItem
      collectiblesNetworkConnection: NetworkConnectionItem
      marketValuesNetworkConnection: NetworkConnectionItem
      unsupportedCollectibleChainsJsonValue: string

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.delegate = delegate
    result.blockchainNetworkConnection = newNetworkConnectionItem()
    result.collectiblesNetworkConnection = newNetworkConnectionItem()
    result.marketValuesNetworkConnection = newNetworkConnectionItem()
    result.unsupportedCollectibleChainsJsonValue = "[]"
    result.setup()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc blockchainNetworkConnectionChanged*(self:View) {.signal.}
  proc getBlockchainNetworkConnection(self: View): QVariant {.slot.} =
    return newQVariant(self.blockchainNetworkConnection)
  QtProperty[QVariant] blockchainNetworkConnection:
    read = getBlockchainNetworkConnection
    notify = blockchainNetworkConnectionChanged

  proc collectiblesNetworkConnectionChanged*(self:View) {.signal.}
  proc getCollectiblesNetworkConnection(self: View): QVariant {.slot.} =
    return newQVariant(self.collectiblesNetworkConnection)
  QtProperty[QVariant] collectiblesNetworkConnection:
    read = getCollectiblesNetworkConnection
    notify = collectiblesNetworkConnectionChanged

  proc marketValuesNetworkConnectionChanged*(self:View) {.signal.}
  proc getMarketValuesNetworkConnection(self: View): QVariant {.slot.} =
    return newQVariant(self.marketValuesNetworkConnection)
  QtProperty[QVariant] marketValuesNetworkConnection:
    read = getMarketValuesNetworkConnection
    notify = marketValuesNetworkConnectionChanged

  proc refreshBlockchainValues*(self: View) {.slot.} =
    self.delegate.refreshBlockchainValues()

  proc refreshMarketValues*(self: View) {.slot.} =
    self.delegate.refreshMarketValues()

  proc refreshCollectiblesValues*(self: View) {.slot.} =
    self.delegate.refreshCollectiblesValues()

  proc unsupportedCollectibleChainsJsonChanged*(self: View) {.signal.}
  proc getUnsupportedCollectibleChainsJson(self: View): string {.slot.} =
    return self.unsupportedCollectibleChainsJsonValue
  QtProperty[string] unsupportedCollectibleChainsJson:
    read = getUnsupportedCollectibleChainsJson
    notify = unsupportedCollectibleChainsJsonChanged

  proc setUnsupportedCollectibleChains*(self: View, chains: seq[int]) =
    let encoded = $(%* chains)
    if self.unsupportedCollectibleChainsJsonValue == encoded:
      return
    self.unsupportedCollectibleChainsJsonValue = encoded
    self.unsupportedCollectibleChainsJsonChanged()

  proc networkConnectionStatusUpdate*(self: View, website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAt: float) {.signal.}

  proc updateNetworkConnectionStatus*(self: View, website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAt: int) =
    case website:
      of BLOCKCHAINS:
        self.blockchainNetworkConnection.updateValues(completelyDown, connectionState, chainIds, lastCheckedAt)
      of COLLECTIBLES:
        self.collectiblesNetworkConnection.updateValues(completelyDown, connectionState, chainIds, lastCheckedAt)
      of MARKET:
        self.marketValuesNetworkConnection.updateValues(completelyDown, connectionState, chainIds, lastCheckedAt)
    self.networkConnectionStatusUpdate(website, completelyDown, connectionState, chainIds, float(lastCheckedAt))

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

