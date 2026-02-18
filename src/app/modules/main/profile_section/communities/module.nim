import nimqml

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface

import ../../../../../app_service/service/community/service as community_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface,
  communityService: community_service.Service):
  Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, communityService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete

method load*(self: Module) =
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.communitiesModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method leaveCommunity*(self: Module, communityID: string) =
  self.controller.leaveCommunity(communityID)

method setCommunityMuted*(self: Module, communityID: string, mutedType: int) =
  self.controller.setCommunityMuted(communityID, mutedType)
