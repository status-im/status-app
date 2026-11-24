import nimqml, sequtils, sugar

import ./io_interface, ./view, ./controller, ./utils
import ../io_interface as delegate_interface
import ../../../../global/global_singleton
import ../../../../core/eventemitter
import app_service/service/ramp/service as ramp_service
import app_service/service/ramp/dto

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
  rampService: ramp_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, rampService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete
  self.controller.delete

method fetchProviders*(self: Module) =
  self.controller.fetchCryptoRampProviders()
  self.view.setIsFetching(true)

method fetchProviderUrl*(self: Module, uuid: string, providerID: string, parameters: CryptoRampParametersDto) =
  self.controller.fetchCryptoRampUrl(uuid, providerID, parameters)

method updateRampProviders*(self: Module, cryptoServices: seq[CryptoRampDto]) =
  let items = cryptoServices.map(i => i.dtoToItem())
  self.view.setItems(items)
  self.view.setIsFetching(false)

method onRampProviderUrlReady*(self: Module, uuid: string, url: string) =
  self.view.onProviderUrlReady(uuid, url)

method load*(self: Module) =
  singletonInstance.setSessionContextProperty("walletSectionBuySellCrypto", self.viewVariant)
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.buySellCryptoModuleDidLoad()
