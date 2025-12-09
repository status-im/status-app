import nimqml

import io_interface, view, controller
import app/global/global_singleton
import app/core/eventemitter
import ./constants

export io_interface
export constants

type
  Module* = ref object of io_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool

proc newModule*(
  events: EventEmitter,
): Module =
  result = Module()
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events)
  result.moduleLoaded = false

  singletonInstance.engine.setRootContextProperty("keycardChannelModule", result.viewVariant)

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

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method setKeycardChannelState*(self: Module, state: string) =
  self.view.setKeycardChannelState(state)

