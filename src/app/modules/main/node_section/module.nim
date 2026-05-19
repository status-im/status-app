import nimqml

import io_interface
import ../io_interface as delegate_interface
import view, controller

import ../../../global/global_singleton
import ../../../core/signals/types
import ../../../core/eventemitter
import ../../../../app_service/service/settings/service as settings_service
import ../../../../app_service/service/node/service as node_service
import ../../../../app_service/service/node_configuration/service as node_configuration_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  settingsService: settings_service.Service,
  nodeService: node_service.Service,
  nodeConfigurationService:  node_configuration_service.Service
  ): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, settingsService, nodeService, nodeConfigurationService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("nodeModel", self.viewVariant)
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.nodeSectionDidLoad()

method sendRPCMessageRaw*(self: Module, inputJSON: string): string =
  return self.controller.sendRPCMessageRaw(inputJSON)

method setLightClient*(self: Module, enabled: bool) =
  if(self.controller.setLightClient(enabled)):
    singletonInstance.application.quit() # TODO: change this to logout instead when supported

method isLightClient*(self: Module): bool =
  return self.controller.isLightClient()

method isFullNode*(self: Module): bool =
   return self.controller.isFullNode()

method getWakuVersion*(self: Module): int =
   return self.controller.getWakuVersion()

method setLastMessage*(self: Module, lastMessage: string) =
  self.view.setLastMessage(lastMessage)

method setStats*(self: Module, stats: Stats) =
  self.view.setStats(stats)

method log*(self: Module, logContent: string) =
  self.view.log(logContent)

method setPeerSize*(self: Module, peerSize: int) =
  self.view.setPeerSize(peerSize)
