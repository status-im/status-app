import nimqml, chronicles

import controller, view
import ./io_interface as io_interface
import ../io_interface as delegate_interface

import app/core/eventemitter
import app/global/global_singleton
import app_service/service/market/service as market_service

logScope:
  topics = "market-section-module"

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    moduleLoaded: bool
    controller: controller.Controller
    view: View
    viewVariant: QVariant
    marketService: market_service.Service

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  marketService: market_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.marketService = marketService
  result.moduleLoaded = false
  result.controller = newController(result, events, marketService)
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)

method delete*(self: Module) =
  self.controller.delete
  self.viewVariant.delete
  self.view.delete

method load*(self: Module) =
  singletonInstance.setSessionContextProperty("marketSection", self.viewVariant)
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc checkIfModuleDidLoad(self: Module) =
  if(not self.isLoaded()):
    return

  self.moduleLoaded = true
  self.delegate.walletSectionDidLoad()

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method loadPage*(self: Module) =
  self.view.loadPage()

method updatePage*(self: Module, updates: seq[LeaderboardTokenUpdated]) =
  self.view.updatePage(updates)

method requestMarketTokenPage*(self: Module, page: int, pageSize: int = 100, sortOrder: int = 0) =
  self.controller.requestMarketTokenPage(page, pageSize, sortOrder)

method unsubscribeFromUpdates*(self: Module) =
  self.controller.unsubscribeFromUpdates()

# Interfaces for getting lists from the service files into the abstract models

method getMarketLeaderboardDataSource*(self: Module): MarketLeaderboardDataSource =
  return (
    getMarketLeaderboardList: proc(): var seq[MarketItem] = self.controller.getMarketLeaderboardList()
  )

method getMarketLeaderboardLoading*(self: Module): bool =
  return self.controller.getMarketLeaderboardLoading()

method getTotalMarketLeaderboardModelCount*(self: Module): int =
  return self.controller.getTotalMarketLeaderboardModelCount()

method getCurrentPage*(self: Module): int =
  return self.controller.getCurrentPage()
