import nimqml

import io_interface, view, controller
import ../io_interface as delegate_interface
import ../../../global/global_singleton
import ../../../core/eventemitter
import ../../../../app_service/service/network_connection/service as network_connection_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  networkConnectionService: network_connection_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, networkConnectionService)
  result.moduleLoaded = false

  singletonInstance.engine.setRootContextProperty("networkConnectionModule", result.viewVariant)

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc checkIfModuleDidLoad(self: Module) =
  self.moduleLoaded = true
  self.delegate.networkConnectionModuleDidLoad()

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method networkConnectionStatusUpdate*(self: Module, website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAt: int) =
  self.view.updateNetworkConnectionStatus(website, completelyDown, connectionState, chainIds, lastCheckedAt)

method refreshBlockchainValues*(self: Module) =
  self.controller.refreshBlockchainValues()

method refreshMarketValues*(self: Module) =
  self.controller.refreshMarketValues()

method refreshCollectiblesValues*(self: Module) =
  self.controller.refreshCollectiblesValues()

method onUnsupportedCollectibleChainsLoaded*(self: Module, chains: seq[int]) =
  self.view.setUnsupportedCollectibleChains(chains)
