import nimqml, sugar, sequtils, chronicles
import ../io_interface as delegate_interface

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/following_address/service as following_address_service

import io_interface, view, controller, model, item

export io_interface

logScope:
  topics = "following-addresses-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    controller: Controller

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  followingAddressService: following_address_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, events, followingAddressService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete

method loadFollowingAddresses*(self: Module, userAddress: string) =
  let followingAddresses = self.controller.getFollowingAddresses(userAddress)
  self.view.setItems(
    followingAddresses.map(f => initItem(
      f.address,
      f.ensName,
      f.tags,
      f.avatar,
    ))
  )
  self.view.totalFollowingCountChanged()
  self.view.followingAddressesUpdated(userAddress)

method load*(self: Module) =
  try:
    singletonInstance.setSessionContextProperty("walletSectionFollowingAddresses", self.viewVariant)
    self.controller.init()
    self.view.load()
  except Exception as e:
    error "following_addresses load() failed", msg=e.msg

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.followingAddressesModuleDidLoad()

method fetchFollowingAddresses*(self: Module, userAddress: string, search: string = "", limit: int = 10, offset: int = 0) =
  self.controller.fetchFollowingAddresses(userAddress, search, limit, offset)

method getTotalFollowingCount*(self: Module): int =
  return self.controller.getTotalFollowingCount()
