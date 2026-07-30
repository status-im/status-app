import ./io_interface

import ../../../core/signals/types
import ../../../core/eventemitter
import ../../../../app_service/service/shared_urls/service as urls_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    sharedUrlsService: urls_service.Service

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    sharedUrlsService: urls_service.Service,
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.sharedUrlsService = sharedUrlsService

proc delete*(self: Controller) =
  discard

proc parseCommunitySharedUrl*(self: Controller, url: string): CommunityUrlDataDto =
  let data = self.sharedUrlsService.parseSharedUrl(url)
  return data.community

proc parseCommunityChannelSharedUrl*(self: Controller, url: string): CommunityChannelUrlDataDto =
  let data = self.sharedUrlsService.parseSharedUrl(url)
  return data.channel

proc parseContactSharedUrl*(self: Controller, url: string): ContactUrlDataDto =
  let data = self.sharedUrlsService.parseSharedUrl(url)
  return data.contact

proc createMessageUrl*(self: Controller, chatId: string, messageId: string): string =
  return self.sharedUrlsService.createMessageUrl(chatId, messageId)

proc parseMessageUrl*(self: Controller, url: string): MessageUrlDataDto =
  return self.sharedUrlsService.parseMessageUrl(url)

proc parseSharedUrl*(self: Controller, url: string): UrlDataDto =
  return self.sharedUrlsService.parseSharedUrl(url)
