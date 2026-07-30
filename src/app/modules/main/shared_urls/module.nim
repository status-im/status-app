import nimqml

import io_interface, view, controller
import ../io_interface as delegate_interface

import ../../../../app_service/service/shared_urls/service as urls_service

import ../../../global/global_singleton
import ../../../core/eventemitter

export io_interface

type
  Module*  = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    sharedUrlsService: urls_service.Service,
    ): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(
      result,
      events,
      sharedUrlsService,
  )
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("sharedUrlsModule", self.viewVariant)
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true

method parseSharedUrl*(self: Module, url: string): UrlDataDto =
  return self.controller.parseSharedUrl(url)

method parseCommunitySharedUrl*(self: Module, url: string): string =
  let communityData = self.controller.parseCommunitySharedUrl(url)
  return $communityData

method parseCommunityChannelSharedUrl*(self: Module, url: string): string =
  let channelData = self.controller.parseCommunityChannelSharedUrl(url)
  return $channelData

method parseContactSharedUrl*(self: Module, url: string): string =
  let contactData = self.controller.parseContactSharedUrl(url)
  return $contactData

method createMessageUrl*(self: Module, chatId: string, messageId: string): string =
  return self.controller.createMessageUrl(chatId, messageId)

method parseMessageUrl*(self: Module, url: string): MessageUrlDataDto =
  return self.controller.parseMessageUrl(url)
