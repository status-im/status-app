import nimqml
import json, strutils, chronicles, sequtils, tables, std/algorithm
import io_interface
import ../io_interface as delegate_interface
import view, controller
import ./models/[result_model, result_item, chat_search_item, chat_search_model, location_menu_model, location_menu_item, location_menu_sub_item]
import ../../shared_models/message_item
from ../../shared_models/section_item import SectionType

import ../../../global/global_singleton
import app/core/eventemitter
import app_service/service/contacts/service as contact_service
import app_service/service/chat/service as chat_service
import app_service/service/community/service as community_service
import app_service/service/message/service as message_service

export io_interface

logScope:
  topics = "app-search-module"

# Constants used in this module
const SEARCH_MENU_LOCATION_CHAT_SECTION_NAME = "Chat"
const SEARCH_RESULT_COMMUNITIES_SECTION_NAME = "Communities"
const SEARCH_RESULT_CHATS_SECTION_NAME = "Chats"
const SEARCH_RESULT_CHANNELS_SECTION_NAME = "Channels"
const SEARCH_RESULT_MESSAGES_SECTION_NAME = "Messages"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool
    chatsLoaded: bool
    communitiesLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface, events: EventEmitter, contactsService: contact_service.Service,
  chatService: chat_service.Service, communityService: community_service.Service, messageService: message_service.Service):
  Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, contactsService, chatService, communityService,
  messageService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.appSearchDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

proc getChatSubItems(self: Module, chats: seq[ChatDto], categories: seq[Category] = @[]): seq[location_menu_sub_item.SubItem] =
  var highestPosition = 0
  var categoryChats: OrderedTable[int, seq[ChatDto]] = initOrderedTable[int, seq[ChatDto]]()

  for chatDto in chats:
    if not chatDto.canView and not chatDto.missingEncryptionKey:
      continue
    
    var chatName = chatDto.name
    var chatImage = chatDto.icon
    var colorId: int = 0
    let isOneToOneChat = chatDto.chatType == ChatType.OneToOne
    if isOneToOneChat:
      (chatName, chatImage, _) = self.controller.getOneToOneChatNameAndImage(chatDto.id)
      colorId = self.controller.getColorId(chatDto.id)
    elif chatDto.chatType == ChatType.CommunityChat:
      if chatDto.categoryId != "":
        for cat in categories:
          if cat.id == chatDto.categoryId:
            if not categoryChats.hasKey(cat.position):
              categoryChats[cat.position] = @[]
            categoryChats[cat.position].add(chatDto)
            break
        continue
      else:
        if chatDto.position > highestPosition:
          highestPosition = chatDto.position

    let subItem = location_menu_sub_item.initSubItem(
      chatDto.id,
      chatName,
      image = if (chatImage != ""): chatImage else: chatDto.emoji,
      icon = "",
      chatDto.color,
      isOneToOneChat,
      isImage = chatImage != "",
      chatDto.position,
      chatDto.timestamp.int,
      colorId,
    )
    result.add(subItem)

  # Add category chats by adjusting the position by taking into account the category position
  let sortedKeys = toSeq(categoryChats.keys).sorted()
  for categoryPosition in sortedKeys:
    highestPosition.inc()
    for chat in categoryChats[categoryPosition]:
      let chatPosition = chat.position + highestPosition
      result.add(location_menu_sub_item.initSubItem(
        chat.id,
        chat.name,
        chat.emoji,
        icon = "",
        chat.color,
        isUserIcon = false,
        isImage = false,
        chatPosition,
        chat.timestamp.int,
      ))
    highestPosition += categoryChats[categoryPosition].len

proc buildLocationMenuForCommunity(self: Module, community: CommunityDto): location_menu_item.Item =
  var item = location_menu_item.initItem(
    community.id,
    community.name,
    community.images.thumbnail,
    icon="",
    community.color
  )

  var subItems = self.getChatSubItems(community.chats, community.categories)
  item.setSubItems(subItems)

  return item

method prepareLocationMenuModel*(self: Module) =
  var items: seq[location_menu_item.Item]

  # Personal Section
  let myPubKey = singletonInstance.userProfile.getPubKey()
  var personalItem = location_menu_item.initItem(
    value = myPubKey,
    text = SEARCH_MENU_LOCATION_CHAT_SECTION_NAME,
    image = "",
    icon = "chat",
  )

  var subItems = self.getChatSubItems(self.controller.getChatsForPersonalSection())
  personalItem.setSubItems(subItems)
  items.add(personalItem)

  # Community sections
  for c in self.controller.joinedAndSpectatedCommunities():
    if c.joined:
      items.add(self.buildLocationMenuForCommunity(c))

  self.view.locationMenuModel().setItems(items)

method onActiveChatChange*(self: Module, sectionId: string, chatId: string) =
  self.controller.setActiveSectionIdAndChatId(sectionId, chatId)

method setSearchLocation*(self: Module, location: string, subLocation: string) =
  self.controller.setSearchLocation(location, subLocation)

method getSearchLocationObject*(self: Module): string =
  ## This method returns location and subLocation with their details so we
  ## may set initial search location on the side of qml.
  var jsonObject = %* {
    "location": "",
    "subLocation": ""
  }

  if(self.controller.activeSectionId().len == 0):
    return Json.encode(jsonObject)

  let item = self.view.locationMenuModel().getItemForValue(self.controller.activeSectionId())
  if(not item.isNil):
    jsonObject["location"] = item.toJsonNode()

    if(self.controller.activeChatId().len > 0):
      let subItem = item.getSubItemForValue(self.controller.activeChatId())
      if(not subItem.isNil):
        jsonObject["subLocation"] = subItem.toJsonNode()

  return Json.encode(jsonObject)

method searchMessages*(self: Module, searchTerm: string) =
  if (searchTerm.len == 0):
    self.view.searchResultModel().clear()
    self.view.emitAppSearchCompletedSignal()
    return

  self.controller.searchMessages(searchTerm)

proc getResultItemFromChats(self: Module, sectionId: string, chats: seq[ChatDto], sectionName: string): seq[result_item.Item] =
  if (self.controller.searchSubLocation().len == 0 and self.controller.searchLocation().len == 0) or
      self.controller.searchLocation() == sectionId:
    
    let searchTerm = self.controller.searchTerm().toLower
    for chatDto in chats:
      if chatDto.isHiddenChat:
        continue

      var chatName = chatDto.name
      var chatImage = chatDto.icon
      var colorId: int = 0
      let isOneToOneChat = chatDto.chatType == ChatType.OneToOne
      if(isOneToOneChat):
        (chatName, chatImage, _) = self.controller.getOneToOneChatNameAndImage(chatDto.id)
        colorId = self.controller.getColorId(chatDto.id)

      var rawChatName = chatName
      if(chatName.startsWith("@")):
        rawChatName = chatName[1 ..^ 1]

      if rawChatName.toLower.contains(searchTerm):
        let item = result_item.initItem(
          chatDto.id,
          content="",
          time="",
          titleId=chatDto.id,
          title=chatName,
          SEARCH_RESULT_CHANNELS_SECTION_NAME,
          chatImage,
          chatDto.color,
          badgePrimaryText="",
          badgeSecondaryText="",
          chatImage,
          chatDto.color,
          false,
          isOneToOneChat,
          colorId)

        self.controller.addResultItemDetails(chatDto.id, sectionId, chatDto.id)
        result.add(item)

method onSearchMessagesDone*(self: Module, messages: seq[MessageDto]) =
  var items: seq[result_item.Item]

  # Add Personal section chats
  let myPubKey = singletonInstance.userProfile.getPubKey()
  let personalItems = self.getResultItemFromChats(myPubKey, self.controller.getChatsForPersonalSection(), SEARCH_RESULT_CHATS_SECTION_NAME)
  var channels = personalItems

  # Add Communities
  let searchTerm = self.controller.searchTerm().toLower
  for community in self.controller.joinedAndSpectatedCommunities():
    if self.controller.searchLocation().len == 0 and
        community.name.toLower.contains(searchTerm):
      let item = result_item.initItem(
        community.id,
        content="",
        time="",
        titleId=community.id,
        title=community.name,
        SEARCH_RESULT_COMMUNITIES_SECTION_NAME,
        community.images.thumbnail,
        community.color,
        badgePrimaryText="",
        badgeSecondaryText="",
        community.images.thumbnail,
        community.color,
        badgeIsLetterIdenticon=false)

      self.controller.addResultItemDetails(community.id, community.id)
      items.add(item)

    # Add channels
    let communityChatItems = self.getResultItemFromChats(community.id, community.chats, SEARCH_RESULT_CHANNELS_SECTION_NAME)
    if communityChatItems.len > 0:
      channels = channels.concat(channels, communityChatItems)

  # Add channels in order as requested by the design
  items.add(channels)

  # Add messages
  for m in messages:
    if (m.contentType != ContentType.Message):
      continue

    let chatDto = self.controller.getChatDetails("", m.chatId)
    var (senderName, senderImage, _) = self.controller.getContactNameAndImage(m.`from`)
    if(m.`from` == singletonInstance.userProfile.getPubKey()):
      senderName = "You"

    let community {.cursor.} = self.controller.getCommunityById(chatDto.communityId)
    let renderedMessageText = self.controller.getRenderedText(m.parsedText, community.chats)
    let colorId = self.controller.getColorId(m.`from`)

    if(chatDto.communityId.len == 0):
      var chatName = chatDto.name
      var chatImage = chatDto.icon
      if(chatDto.chatType == ChatType.OneToOne):
        (chatName, chatImage, _) = self.controller.getOneToOneChatNameAndImage(chatDto.id)
      let item = result_item.initItem(m.id, renderedMessageText, $m.timestamp, m.`from`, senderName,
        SEARCH_RESULT_MESSAGES_SECTION_NAME, senderImage, chatDto.color, chatName, "", chatImage,
        chatDto.color, false, true, colorId)

      self.controller.addResultItemDetails(m.id, singletonInstance.userProfile.getPubKey(),
        chatDto.id, m.id)
      items.add(item)
    else:
      let channelName = "#" & chatDto.name
      let item = result_item.initItem(m.id, renderedMessageText, $m.timestamp, m.`from`, senderName,
        SEARCH_RESULT_MESSAGES_SECTION_NAME, senderImage, chatDto.color,
        community.name,
        channelName,
        community.images.thumbnail,
        community.color, false, true, colorId)

      self.controller.addResultItemDetails(m.id, chatDto.communityId, chatDto.id, m.id)
      items.add(item)

  self.view.searchResultModel().set(items)
  self.view.emitAppSearchCompletedSignal()

method resultItemClicked*(self: Module, itemId: string) =
  self.controller.resultItemClicked(itemId)

method updateSearchLocationIfPointToChatWithId*(self: Module, chatId: string) =
  if self.controller.activeChatId() == chatId:
    self.controller.setSearchLocation(self.controller.activeSectionId(), "")

proc createChatSearchItem(self: Module, chat: ChatDto, personalChatSectionId, personalChatSectionName: string): ChatSearchItem =
  let isCommunity = chat.chatType == ChatType.CommunityChat and chat.communityId != ""

  # skip hidden chats
  if isCommunity:
    let community {.cursor.} = self.controller.getCommunityById(chat.communityId)
    if not community.hasCommunityChat(chat.id):
      return nil
    if community.getCommunityChat(chat.id).isHiddenChat:
      return nil

  var chatName = chat.name
  var chatImage = chat.icon
  var colorId: int = 0
  var sectionId = personalChatSectionId
  var sectionName = personalChatSectionName
  if chat.chatType == ChatType.OneToOne:
    # TODO find a way to populate the chat with the contact details and use as single source of truth
    let contactDetails = self.controller.getContactDetails(chat.id)
    chatName = contactDetails.defaultDisplayName
    chatImage = contactDetails.icon
    colorId = self.controller.getColorId(chat.id)
  elif chat.chatType == ChatType.CommunityChat:
    sectionId = chat.communityId
    sectionName = self.delegate.getSectionName(sectionId)
  return chat_search_item.initItem(
    chat.id,
    chatName,
    chat.color,
    colorId,
    chatImage,
    sectionId,
    sectionName,
    chat.emoji,
    chat.chatType.int,
    lastMessageText =
      if isCommunity:
        self.controller.getMessagesParsedPlainText(chat.lastMessage,
          self.controller.getCommunityById(chat.communityId).chats)
      else:
        self.controller.getMessagesParsedPlainText(chat.lastMessage, []),
  )

method buildChatSearchModel*(self: Module) =
  var items: seq[ChatSearchItem] = @[]

  let personalChatSectionId = self.delegate.getSectionId(SectionType.Chat)
  let personalChatSectionName = self.delegate.getSectionName(personalChatSectionId)

  for chat in self.controller.getAllChats():
    let item = self.createChatSearchItem(chat, personalChatSectionId, personalChatSectionName)
    if item == nil:
      continue
    items.add(item)

  self.view.chatSearchModel().setItems(items)

method updateChatItems*(self: Module, updatedChats: seq[ChatDto]) =
  for chat in updatedChats:
    let index = self.view.chatSearchModel().getItemIndexById(chat.id)

    if not chat.active and index == -1:
      # If the chat is not active and not in the model, we skip it
      continue

    # Chat is active and not in the model, so we add it
    if chat.active and index == -1:
      let item = self.createChatSearchItem(chat, self.delegate.getSectionId(SectionType.Chat),
        self.delegate.getSectionName(self.delegate.getSectionId(SectionType.Chat)))
      if item == nil:
        continue
      self.view.chatSearchModel().addItem(item)
      continue

    if not chat.active and index > -1:
      # If the chat is not active and in the model, we remove it
      self.view.chatSearchModel().removeItemByIndex(index)
      continue

    if chat.chatType == ChatType.OneToOne:
      # 1-1 chat properties are updated when a contact is updated, so we can skip it here
      continue
    self.view.chatSearchModel().updateChatItem(chat.id, chat.name, chat.color, chat.icon, chat.emoji)

method contactUpdated*(self: Module, contactId: string) =
  let contactDetails = self.controller.getContactDetails(contactId)
  self.view.chatSearchModel().updateChatItem(contactId, contactDetails.defaultDisplayName, color = "",
    contactDetails.icon, emoji = "")

method communityEdited*(self: Module, community: CommunityDto) =
  self.view.chatSearchModel().updateSectionNameOnChats(community.id, community.name)

method chatAdded*(self: Module, chat: ChatDto) =
  let personalChatSectionId = self.delegate.getSectionId(SectionType.Chat)
  let personalChatSectionName = self.delegate.getSectionName(personalChatSectionId)

  let item = self.createChatSearchItem(chat, personalChatSectionId, personalChatSectionName)
  if item == nil:
    return
  self.view.chatSearchModel().addItem(item)

method chatRemoved*(self: Module, chatId: string) =
  self.view.chatSearchModel().removeItemById(chatId)

method updateLastMessage*(self: Module, chatId, communityId: string, chatType: ChatType, lastMessage: MessageDto) =
  self.view.chatSearchModel().updateLastMessageTextOnChatItem(
    chatId,
    if chatType == ChatType.CommunityChat and communityId != "":
      self.controller.getMessagesParsedPlainText(lastMessage,
        self.controller.getCommunityById(communityId).chats)
    else:
      self.controller.getMessagesParsedPlainText(lastMessage, [])
  )
