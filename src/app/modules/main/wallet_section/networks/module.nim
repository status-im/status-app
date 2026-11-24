import nimqml
import ../io_interface as delegate_interface
import io_interface, view, controller
import app/global/global_singleton
import app/core/eventemitter
import app_service/service/network/service as network_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/settings/service as settings_service
import app_service/service/network/network_item

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
  networkService: networkService.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, networkService, walletAccountService, settingsService)
  result.moduleLoaded = false

  singletonInstance.setSessionContextProperty("networksModule", result.viewVariant)

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method refreshNetworks*(self: Module) =
  self.view.setAreTestNetworksEnabled(self.controller.areTestNetworksEnabled())
  self.view.refreshModel()

method load*(self: Module) =
  self.controller.init()
  self.view.load()
  self.refreshNetworks()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc areTestNetworksEnabled*(self: Module): bool =
  return self.controller.areTestNetworksEnabled()

proc checkIfModuleDidLoad(self: Module) =
  self.moduleLoaded = true
  self.delegate.networksModuleDidLoad()

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method toggleTestNetworksEnabled*(self: Module) =
  self.controller.toggleTestNetworksEnabled()
  self.refreshNetworks()

method setNetworkActive*(self: Module, chainId: int, active: bool) =
  self.controller.setNetworkActive(chainId, active)
  self.refreshNetworks()

method setNetworksState*(self: Module, chainIds: seq[int], enabled: bool) =
  self.controller.setNetworksState(chainIds, enabled)

method updateNetworkEndPointValues*(self: Module, chainId: int, newMainRpcInput, newFailoverRpcUrl: string) =
  self.controller.updateNetworkEndPointValues(chainId, newMainRpcInput, newFailoverRpcUrl)

method fetchChainIdForUrl*(self: Module, url: string, isMainUrl: bool) =
  self.controller.fetchChainIdForUrl(url, isMainUrl)

method chainIdFetchedForUrl*(self: Module, url: string, chainId: int, success: bool, isMainUrl: bool) =
  self.view.chainIdFetchedForUrl(url, chainId, success, isMainUrl)

# Interfaces for getting lists from the service files into the abstract models

method getNetworksDataSource*(self: Module): NetworksDataSource =
  return (
    getFlatNetworksList: proc(): var seq[NetworkItem] = self.controller.getFlatNetworks(),
    getRpcProvidersList: proc(): var seq[RpcProviderItem] = self.controller.getRpcProviders(),
  )
