import nimqml

import app/global/global_singleton
import app/core/eventemitter
import app/core/cow_seq
import app_service/service/token/service as token_service
import app_service/service/currency/service as currency_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  tokenService: token_service.Service,
  currencyService: currency_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, walletAccountService, networkService, tokenService, currencyService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionAssets", self.viewVariant)

  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e:Args):
    self.view.modelsUpdated()
    self.view.setHasBalanceCache(self.controller.getHasBalanceCache())
    self.view.setHasMarketValuesCache(self.controller.getHasMarketValuesCache())

  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e:Args):
    self.view.setHasBalanceCache(self.controller.getHasBalanceCache())
    self.view.setHasMarketValuesCache(self.controller.getHasMarketValuesCache())

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.assetsModuleDidLoad()

# Interfaces for getting lists from the service files into the abstract models

method getGroupedAccountAssetsDataSource*(self: Module): GroupedAccountAssetsDataSource =
  return (
    getGroupedAssetsList: proc(): CowSeq[AssetGroupItem] = self.controller.getGroupedAssetsList()
  )

method filterChanged*(self: Module, addresses: seq[string], chainIds: seq[int]) =
  discard
