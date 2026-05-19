import ./io_interface
import ../../../core/eventemitter
import ../../../../app_service/service/network_connection/service as network_connection_service
import ../../../../app_service/service/node/service as node_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    networkConnectionService: network_connection_service.Service

proc newController*(
  delegate: io_interface.AccessInterface,
  events: EventEmitter,
  networkConnectionService: network_connection_service.Service
): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.networkConnectionService = networkConnectionService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  let chains = self.networkConnectionService.loadUnsupportedCollectibleChains()
  self.delegate.onUnsupportedCollectibleChainsLoaded(chains)

  self.events.on(SIGNAL_CONNECTION_UPDATE) do(e:Args):
    let args = NetworkConnectionsArgs(e)
    self.delegate.networkConnectionStatusUpdate(args.website, args.completelyDown, ord(args.connectionState), args.chainIds, args.lastCheckedAt)

  self.events.on(SIGNAL_NETWORK_CONNECTED) do(e: Args):
    self.networkConnectionService.networkConnected(true)

  self.events.on(SIGNAL_NETWORK_DISCONNECTED) do(e: Args):
    self.networkConnectionService.networkConnected(false)

proc refreshBlockchainValues*(self: Controller) =
  self.networkConnectionService.blockchainsRetry()

proc refreshMarketValues*(self: Controller) =
  self.networkConnectionService.marketRetry()

proc refreshCollectiblesValues*(self: Controller) =
  self.networkConnectionService.collectiblesRetry()
