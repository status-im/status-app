import chronicles
import io_interface

import ../../../../core/eventemitter
import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/chat/service as chat_service
import ../../../../../app_service/service/contacts/service as contact_service
import ../../../../../app_service/service/community/service as community_service

logScope:
  topics = "profile-section-notifications-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    settingsService: settings_service.Service
    chatService: chat_service.Service
    contactService: contact_service.Service
    communityService: community_service.Service
    chatsLoaded: bool
    communitiesLoaded: bool

proc newController*(delegate: io_interface.AccessInterface,
    events: EventEmitter,
    settingsService: settings_service.Service,
    chatService: chat_service.Service,
    contactService: contact_service.Service,
    communityService: community_service.Service,
  ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.settingsService = settingsService
  result.chatService = chatService
  result.contactService = contactService
  result.communityService = communityService
  result.chatsLoaded = false
  result.communitiesLoaded = false

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_COMMUNITY_JOINED) do(e:Args):
    let args = CommunityArgs(e)
    if(args.error.len > 0):
      return
    self.delegate.addCommunity(args.community)

  self.events.on(SIGNAL_COMMUNITY_CREATED) do(e:Args):
    let args = CommunityArgs(e)
    if(args.error.len > 0):
      return
    self.delegate.addCommunity(args.community)

  self.events.on(SIGNAL_COMMUNITY_IMPORTED) do(e:Args):
    let args = CommunityArgs(e)
    if(args.error.len > 0):
      return
    self.delegate.addCommunity(args.community)

  self.events.on(SIGNAL_COMMUNITY_LEFT) do(e:Args):
    let args = CommunityIdArgs(e)
    self.delegate.removeItemWithId(args.communityId)

  self.events.on(SIGNAL_COMMUNITY_EDITED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.editCommunity(args.community)

  self.events.on(SIGNAL_COMMUNITIES_UPDATE) do(e:Args):
    let args = CommunitiesArgs(e)
    for community in args.communities:
      self.delegate.editCommunity(community)
  
  self.events.on(chat_service.SIGNAL_CHAT_ADDED_OR_UPDATED) do(e: Args):
    let args = chat_service.ChatArgs(e)
    self.delegate.addChat(args.chatId)

  self.events.on(chat_service.SIGNAL_CHAT_LEFT) do(e: Args):
    let args = chat_service.ChatArgs(e)
    self.delegate.removeItemWithId(args.chatId)

  self.events.on(SIGNAL_CHAT_UPDATE) do(e: Args):
    var args = ChatUpdateArgs(e)
    for chat in args.chats:
      self.delegate.addChat(chat)

  self.events.on(SIGNAL_CHAT_RENAMED) do(e: Args):
    var args = ChatRenameArgs(e)
    self.delegate.setName(args.id, args.newName)

  self.events.on(SIGNAL_CHAT_SWITCH_TO_OR_CREATE_1_1_CHAT) do(e:Args):
    let args = ChatExtArgs(e)
    self.delegate.addChat(args.chatId)

proc getNotifSettingExemptions*(self: Controller, id: string): NotificationsExemptions =
  return self.settingsService.getNotifSettingExemptions(id)

proc setNotifSettingExemptions*(self: Controller, id: string, exemptions: NotificationsExemptions): bool =
  return self.settingsService.setNotifSettingExemptions(id, exemptions)

proc removeNotifSettingExemptions*(self: Controller, id: string): bool =
  return self.settingsService.removeNotifSettingExemptions(id)

proc getChatsForPersonalSection*(self: Controller): seq[ChatDto] =
  return self.chatService.getChatsForPersonalSection()

proc getChatDetails*(self: Controller, chatId: string): lent ChatDto =
  return self.chatService.getChatById(chatId)

proc getContactDetails*(self: Controller, id: string): ContactDetails =
  return self.contactService.getContactDetails(id)

iterator joinedAndSpectatedCommunities*(self: Controller): lent CommunityDto =
  for c in self.communityService.joinedAndSpectatedCommunities():
    yield c
