import tables, chronicles
import io_interface

import ../../../global/app_signals
import ../../../global/global_singleton
import ../../../../app_service/service/contacts/service as contact_service
import ../../../../app_service/service/chat/service as chat_service
import ../../../../app_service/service/community/service as community_service
import ../../../../app_service/service/message/service as message_service
import ../../../../app_service/service/visual_identity/service as procs_from_visual_identity_service

import ../../../core/signals/types
import ../../../core/eventemitter

logScope:
  topics = "app-search-module-controller"

type ResultItemDetails = object
  sectionId*: string
  channelId*: string
  messageId*: string

proc isEmpty(self: ResultItemDetails): bool =
  self.sectionId.len == 0 and
  self.channelId.len == 0 and
  self.messageId.len == 0

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    contactsService: contact_service.Service
    chatService: chat_service.Service
    communityService: community_service.Service
    messageService: message_service.Service
    activeSectionId: string
    activeChatId: string
    searchLocation: string
    searchSubLocation: string
    searchTerm: string
    resultItems: Table[string, ResultItemDetails] # [resultItemId, ResultItemDetails]

proc newController*(delegate: io_interface.AccessInterface, events: EventEmitter, contactsService: contact_service.Service,
  chatService: chat_service.Service, communityService: community_service.Service,
  messageService: message_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.contactsService = contactsService
  result.chatService = chatService
  result.communityService = communityService
  result.messageService = messageService
  result.resultItems = initTable[string, ResultItemDetails]()

proc delete*(self: Controller) =
  self.resultItems.clear

proc init*(self: Controller) =
  self.events.on(SIGNAL_SEARCH_MESSAGES_LOADED) do(e:Args):
    let args = MessagesArgs(e)
    self.delegate.onSearchMessagesDone(args.messages)

  self.events.on(SIGNAL_CHAT_UPDATE) do(e: Args):
    var args = ChatUpdateArgs(e)
    self.delegate.updateChatItems(args.chats)

  self.events.on(SIGNAL_COMMUNITY_CHANNEL_EDITED) do(e: Args):
    let args = CommunityChatArgs(e)
    self.delegate.updateChatItems(@[args.chat])

  self.events.on(SIGNAL_CONTACT_UPDATED) do(e: Args):
    let args = ContactArgs(e)
    self.delegate.contactUpdated(args.contactId)

  self.events.on(SIGNAL_COMMUNITIES_UPDATE) do(e:Args):
    let args = CommunitiesArgs(e)
    for community in args.communities:
      self.delegate.communityEdited(community)

  self.events.on(SIGNAL_CHAT_CREATED) do(e: Args):
    var args = CreatedChatArgs(e)
    self.delegate.chatAdded(args.chat)

  self.events.on(SIGNAL_COMMUNITY_CHANNEL_CREATED) do(e:Args):
    let args = CommunityChatArgs(e)
    self.delegate.chatAdded(args.chat)

  self.events.on(SIGNAL_COMMUNITY_CHANNEL_DELETED) do(e:Args):
    let args = CommunityChatIdArgs(e)
    self.delegate.chatRemoved(args.chatId)

  self.events.on(SIGNAL_CHAT_LEFT) do(e:Args):
    let args = ChatArgs(e)
    self.delegate.chatRemoved(args.chatId)

  self.events.on(SIGNAL_SENDING_SUCCESS) do(e:Args):
    let args = MessageSendingSuccess(e)
    self.delegate.updateLastMessage(args.chat.id, args.chat.communityId, args.chat.chatType, args.chat.lastMessage,
      args.chat.timestamp.int)

  self.events.on(SIGNAL_NEW_MESSAGE_RECEIVED) do(e: Args):
    let args = MessagesArgs(e)
    if args.messages.len == 0:
      return
    self.delegate.updateLastMessage(args.chatId, args.sectionId, args.chatType, args.messages[0],
      args.lastMessageTimestamp)

proc activeSectionId*(self: Controller): string =
  return self.activeSectionId

proc activeChatId*(self: Controller): string =
  return self.activeChatId

proc setActiveSectionIdAndChatId*(self: Controller, sectionId: string, chatId: string) =
    self.activeSectionId = sectionId
    self.activeChatId = chatId

proc searchTerm*(self: Controller): string =
  return self.searchTerm

proc searchLocation*(self: Controller): string =
  return self.searchLocation

proc searchSubLocation*(self: Controller): string =
  return self.searchSubLocation

proc setSearchLocation*(self: Controller, location: string, subLocation: string) =
    ## Setting location and subLocation to an empty string means we're
    ## searching in all available chats/channels/communities.
    self.searchLocation = location
    self.searchSubLocation = subLocation

proc getCommunityById*(self: Controller, communityId: string): lent CommunityDto =
  return self.communityService.getCommunityById(communityId)

iterator joinedAndSpectatedCommunities*(self: Controller): lent CommunityDto =
  for c in self.communityService.joinedAndSpectatedCommunities():
    yield c

proc getChatsForPersonalSection*(self: Controller): seq[ChatDto] =
  return self.chatService.getChatsForPersonalSection()

proc getChatDetailsForChatTypes*(self: Controller, types: seq[ChatType]): seq[ChatDto] =
  return self.chatService.getChatsOfChatTypes(types)

proc getChatDetails*(self: Controller, communityId, chatId: string): lent ChatDto =
  let fullId = communityId & chatId
  return self.chatService.getChatById(fullId)

proc searchMessages*(self: Controller, searchTerm: string) =
  self.resultItems.clear
  self.searchTerm = searchTerm

  var chats: seq[string]
  var communities: seq[string]

  if (self.searchSubLocation.len > 0):
    chats.add(self.searchSubLocation)
  elif (self.searchLocation.len > 0):
    # If user's pubkey is set for the meassgeSearchLocation that means we need to search in all chats from the personal chat section.
    if (self.searchLocation != singletonInstance.userProfile.getPubKey()):
      communities.add(self.searchLocation)
    else:
      let types = @[ChatType.OneToOne, ChatType.PrivateGroupChat]
      let displayedChats = self.getChatDetailsForChatTypes(types)
      for c in displayedChats:
        chats.add(c.id)

  if (communities.len == 0 and chats.len == 0):
    let types = @[ChatType.OneToOne, ChatType.PrivateGroupChat]
    let displayedChats = self.getChatDetailsForChatTypes(types)
    for c in displayedChats:
      chats.add(c.id)

    let communitiesIds = self.communityService.getCommunityIds()
    for cId in communitiesIds:
      communities.add(cId)

  if (communities.len == 0 and chats.len == 0):
    self.delegate.onSearchMessagesDone(@[])
    return

  self.messageService.asyncSearchMessages(communities, chats, self.searchTerm, false)

proc getOneToOneChatNameAndImage*(self: Controller, chatId: string):
    tuple[name: string, image: string, largeImage: string] =
  return self.chatService.getOneToOneChatNameAndImage(chatId)

proc getContactNameAndImage*(self: Controller, contactId: string):
    tuple[name: string, image: string, largeImage: string] =
  return self.contactsService.getContactNameAndImage(contactId)

proc addResultItemDetails*(self: Controller, itemId: string, sectionId = "", channelId = "", messageId = "") =
  self.resultItems[itemId] = ResultItemDetails(sectionId: sectionId, channelId: channelId, messageId: messageId)

proc resultItemClicked*(self: Controller, itemId: string) =
  let itemDetails = self.resultItems.getOrDefault(itemId)
  if(itemDetails.isEmpty()):
    # we shouldn't be here ever
    info "important: we don't have stored details for a searched result item with id: ", itemId
    return

  let data = ActiveSectionChatArgs(sectionId: itemDetails.sectionId,
    chatId: itemDetails.channelId,
    messageId: itemDetails.messageId)
  self.events.emit(SIGNAL_MAKE_SECTION_CHAT_ACTIVE, data)

proc getRenderedText*(self: Controller, parsedTextArray: seq[ParsedText], communityChats: openArray[ChatDto]): string =
  return self.messageService.getRenderedText(parsedTextArray, communityChats)

proc getColorId*(self: Controller, pubkey: string): int =
  procs_from_visual_identity_service.colorIdOf(pubkey)

proc getAllChats*(self: Controller): seq[ChatDto] =
  result = self.chatService.getAllChats()

proc getContactDetails*(self: Controller, contactId: string): ContactDetails =
  return self.contactsService.getContactDetails(contactId)

proc getMessagesParsedPlainText*(self: Controller, message: MessageDto, communityChats: openArray[ChatDto]): string =
  return self.messageService.getMessagesParsedPlainText(message, communityChats)
