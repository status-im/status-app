import nimqml, chronicles

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface
import app_service/service/general/service as general_service

export io_interface

logScope:
  topics = "profile-section-logos-network-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    generalService: general_service.Service,
  ): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, generalService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.logosNetworkModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method refreshPeerCount*(self: Module) =
  try:
    let count = self.controller.getPeerCount()
    self.view.setPeerCount(count)
    self.view.setPeerCountError("")
  except Exception as e:
    error "failed to refresh Logos network peer count", errName = e.name, errDescription = e.msg
    self.view.setPeerCountError(e.msg)
  finally:
    self.view.setPeerCountLoading(false)
