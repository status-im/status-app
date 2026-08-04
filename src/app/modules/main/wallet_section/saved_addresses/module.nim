import nimqml, json, sugar, sequtils
import ../io_interface as delegate_interface

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/saved_address/service as saved_address_service

import io_interface, view, controller, model

export io_interface

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
  savedAddressService: saved_address_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, events, savedAddressService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete

method loadSavedAddresses*(self: Module) =
  let savedAddresses = self.controller.getSavedAddresses()
  self.view.setItems(
    savedAddresses.map(s => initItem(
      s.name,
      s.address,
      s.mixedcaseAddress,
      s.ens,
      s.colorId,
      s.isTest,
    ))
  )

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionSavedAddresses", self.viewVariant)

  self.loadSavedAddresses()
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.savedAddressesModuleDidLoad()

method createOrUpdateSavedAddress*(self: Module, name: string, address: string, ens: string, colorId: string) =
  self.controller.createOrUpdateSavedAddress(name, address, ens, colorId)

method deleteSavedAddress*(self: Module, address: string) =
  self.controller.deleteSavedAddress(address)

method savedAddressUpdated*(self: Module, name: string, address: string, isTestAddress: bool, errorMsg: string) =
  if isTestAddress != self.controller.areTestNetworksEnabled():
    return
  let item = self.view.getModel().getItemByAddress(address, isTestAddress)
  self.loadSavedAddresses()
  self.view.savedAddressAddedOrUpdated(item.isEmpty(), name, address, errorMsg)

method savedAddressDeleted*(self: Module, address: string, isTestAddress: bool, errorMsg: string) =
  if isTestAddress != self.controller.areTestNetworksEnabled():
    return
  let item = self.view.getModel().getItemByAddress(address, isTestAddress)
  self.loadSavedAddresses()
  self.view.savedAddressDeleted(item.getName(), address, errorMsg)

method savedAddressNameExists*(self: Module, name: string): bool =
  return self.view.getModel().nameExists(name, self.controller.areTestNetworksEnabled())

method getSavedAddressAsJson*(self: Module, address: string): string =
  let saDto = self.controller.getSavedAddress(address, ignoreNetworkMode = false)
  if saDto.isNil:
    return $newJNull()
  let jsonObj = %* {
    "name": saDto.name,
    "address": saDto.address,
    "ens": saDto.ens,
    "colorId": saDto.colorId,
    "isTest": saDto.isTest,
  }
  return $jsonObj

method remainingCapacityForSavedAddresses*(self: Module): int =
  return self.controller.remainingCapacityForSavedAddresses()
