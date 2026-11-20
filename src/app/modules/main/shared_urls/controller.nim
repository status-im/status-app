import ./io_interface

import ../../../core/eventemitter
import ../../../core/unique_event_emitter
import ../../../../app_service/service/shared_urls/service as urls_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: UniqueUUIDEventEmitter
    sharedUrlsService: urls_service.Service

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    sharedUrlsService: urls_service.Service,
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = initUniqueUUIDEventEmitter(events)
  result.sharedUrlsService = sharedUrlsService

proc delete*(self: Controller) =
  self.events.disconnect()

proc init*(self: Controller) =
  self.events.on(SIGNAL_PROFILE_URLS_RESOLVED) do(args: Args):
    self.delegate.profileUrlsResolved(ProfileUrlsResolvedArgs(args).profilesJson)

proc parseCommunitySharedUrl*(self: Controller, url: string): CommunityUrlDataDto =
  let data = self.sharedUrlsService.parseSharedUrl(url)
  return data.community

proc parseCommunityChannelSharedUrl*(self: Controller, url: string): CommunityChannelUrlDataDto =
  let data = self.sharedUrlsService.parseSharedUrl(url)
  return data.channel

proc parseContactSharedUrl*(self: Controller, url: string): ContactUrlDataDto =
  let data = self.sharedUrlsService.parseSharedUrl(url)
  return data.contact

proc resolveProfileUrls*(self: Controller, urlsJson: string): string =
  self.sharedUrlsService.resolveProfileUrls(urlsJson)

proc releaseProfileUrls*(self: Controller, urlsJson: string) =
  self.sharedUrlsService.releaseProfileUrls(urlsJson)

proc createMessageUrl*(self: Controller, chatId: string, messageId: string): string =
  return self.sharedUrlsService.createMessageUrl(chatId, messageId)

proc parseMessageUrl*(self: Controller, url: string): MessageUrlDataDto =
  return self.sharedUrlsService.parseMessageUrl(url)

proc parseSharedUrl*(self: Controller, url: string): UrlDataDto =
  return self.sharedUrlsService.parseSharedUrl(url)

proc createThreadUrl*(self: Controller, chatId: string, threadId: string): string =
  return self.sharedUrlsService.createThreadUrl(chatId, threadId)

proc parseThreadUrl*(self: Controller, url: string): ThreadUrlDataDto =
  return self.sharedUrlsService.parseThreadUrl(url)
