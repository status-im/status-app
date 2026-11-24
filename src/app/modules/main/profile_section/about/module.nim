import nimqml

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface
import ../../../../global/global_singleton
import ../../../../core/eventemitter
import ../../../../../app_service/service/about/service as about_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    aboutService: about_service.Service
    ): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, aboutService)
  result.moduleLoaded = false

  singletonInstance.setSessionContextProperty("aboutModule", result.viewVariant)

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.view.load()
  self.controller.init()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.aboutModuleDidLoad()

method getAppVersion*(self: Module): string =
  return self.controller.getAppVersion()

method getGitCommit*(self: Module): string =
  return self.controller.getGitCommit()

method getNodeVersion*(self: Module): string =
  return self.controller.getNodeVersion()

method getStatusGoVersion*(self: Module): string =
  self.controller.getStatusGoVersion()

method checkForUpdates*(self: Module) =
  self.controller.checkForUpdates()

method versionFetched*(self: Module, available: bool, version: string, url: string) =
  self.view.versionFetched(available, version, url)
