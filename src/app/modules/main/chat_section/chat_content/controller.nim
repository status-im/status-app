import nimqml, tables, json
import io_interface

import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/node_configuration/service as node_configuration_service
import ../../../../../app_service/service/contacts/service as contact_service
import ../../../../../app_service/service/chat/service as chat_service
import ../../../../../app_service/service/community/service as community_service
import ../../../../../app_service/service/message/service as message_service
import ../../../../../app_service/service/mailservers/service as mailservers_service
import ../../../../../app_service/service/wallet_account/service as wallet_account_service

import ../../../../core/signals/types
import ../../../../core/eventemitter
import ../../../../core/unique_event_emitter
import ../../../shared_models/message_item


type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: UniqueUUIDEventEmitter
    sectionId: string
    chatId: string
    belongsToCommunity: bool
    isUsersListAvailable: bool #users list is not available for 1:1 chat
    nodeConfigurationService: node_configuration_service.Service
    settingsService: settings_service.Service
    mailserversService: mailservers_service.Service
    contactService: contact_service.Service
    chatService: chat_service.Service
    communityService: community_service.Service
    messageService: message_service.Service

# Forward declaration
proc getChatDetails*(self: Controller): ChatDto

proc newController*(delegate: io_interface.AccessInterface, events: EventEmitter, sectionId: string, chatId: string,
    belongsToCommunity: bool, isUsersListAvailable: bool, settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service, contactService: contact_service.Service,
    chatService: chat_service.Service, communityService: community_service.Service,
    messageService: message_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = initUniqueUUIDEventEmitter(events)
  result.sectionId = sectionId
  result.chatId = chatId
  result.belongsToCommunity = belongsToCommunity
  result.isUsersListAvailable = isUsersListAvailable
  result.settingsService = settingsService
  result.nodeConfigurationService = nodeConfigurationService
  result.contactService = contactService
  result.chatService = chatService
  result.communityService = communityService
  result.messageService = messageService

proc delete*(self: Controller) =
  self.events.disconnect()

proc init*(self: Controller) =
  self.events.on(SIGNAL_PINNED_MESSAGES_LOADED) do(e:Args):
    let args = PinnedMessagesLoadedArgs(e)
    if(self.chatId != args.chatId or args.pinnedMessages.len == 0):
      return
    self.delegate.newPinnedMessagesLoaded(args.pinnedMessages, args.reactions)

  self.events.on(SIGNAL_MESSAGE_PINNED) do(e:Args):
    let args = MessagePinUnpinArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onPinMessage(args.messageId, args.actionInitiatedBy)

  self.events.on(SIGNAL_MESSAGE_UNPINNED) do(e:Args):
    let args = MessagePinUnpinArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onUnpinMessage(args.messageId)

  self.events.on(SIGNAL_CHAT_MUTED) do(e:Args):
    let args = ChatArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onChatMuted()

  self.events.on(SIGNAL_CHAT_UNMUTED) do(e:Args):
    let args = ChatArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onChatUnmuted()

  self.events.on(SIGNAL_MESSAGE_REACTION_ADDED) do(e:Args):
    let args = MessageAddRemoveReactionArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onReactionAdded(args.messageId, args.emoji, args.reactionId)

  self.events.on(SIGNAL_MESSAGE_REACTION_REMOVED) do(e:Args):
    let args = MessageAddRemoveReactionArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onReactionRemoved(args.messageId, args.emoji, args.reactionId)

  self.events.on(SIGNAL_MESSAGE_REACTION_FROM_OTHERS) do(e:Args):
    let args = MessageAddRemoveReactionArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.toggleReactionFromOthers(args.messageId, args.emoji, args.reactionId, args.reactionFrom)

  self.events.on(SIGNAL_REACTIONS_FOR_MESSAGE_LOADED) do(e:Args):
    let args = ReactionsLoadedArgs(e)
    if(self.chatId != args.chatId or args.messageId.len == 0):
      return
    self.delegate.onReactionsLoaded(args.messageId, args.reactions)

  self.events.on(SIGNAL_CONTACT_NICKNAME_CHANGED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactDetailsUpdated(args.contactId)

  self.events.on(SIGNAL_CONTACT_UNTRUSTWORTHY) do(e: Args):
    var args = TrustArgs(e)
    self.delegate.onContactDetailsUpdated(args.publicKey)

  self.events.on(SIGNAL_CONTACT_TRUSTED) do(e: Args):
    var args = TrustArgs(e)
    self.delegate.onContactDetailsUpdated(args.publicKey)

  self.events.on(SIGNAL_REMOVED_TRUST_STATUS) do(e: Args):
    var args = TrustArgs(e)
    self.delegate.onContactDetailsUpdated(args.publicKey)

  self.events.on(SIGNAL_CONTACT_UPDATED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactDetailsUpdated(args.contactId)
    if (args.contactId == self.chatId):
      self.delegate.onMutualContactChanged()

  let chatDto = self.getChatDetails()
  if(chatDto.chatType == ChatType.OneToOne):
    self.events.on(SIGNAL_CONTACT_ADDED) do(e: Args):
      var args = ContactArgs(e)
      if (args.contactId == self.chatId):
        self.delegate.onMutualContactChanged()

    self.events.on(SIGNAL_CONTACT_REMOVED) do(e: Args):
      var args = ContactArgs(e)
      if (args.contactId == self.chatId):
        self.delegate.onMutualContactChanged()

    self.events.on(SIGNAL_CONTACT_BLOCKED) do(e: Args):
      var args = ContactArgs(e)
      if (args.contactId == self.chatId):
        self.delegate.onMutualContactChanged()
        self.delegate.onContactDetailsUpdated(args.contactId)

    self.events.on(SIGNAL_CONTACT_UNBLOCKED) do(e: Args):
      var args = ContactArgs(e)
      if (args.contactId == self.chatId):
        self.delegate.onMutualContactChanged()
        self.delegate.onContactDetailsUpdated(args.contactId)

  self.events.on(SIGNAL_MESSAGE_REMOVED) do(e: Args):
    let args = MessageRemovedArgs(e)
    if(self.chatId != args.chatId):
      return
    # remove from pinned messages model
    self.delegate.onUnpinMessage(args.messageId)

  self.events.on(SIGNAL_MESSAGES_DELETED) do(e: Args):
    let args = MessagesDeletedArgs(e)
    if self.chatId in args.deletedMessages:
      for deletedMessage in args.deletedMessages[self.chatId]:
        # delete from pinned messages model
        self.delegate.onUnpinMessage(deletedMessage)

  self.events.on(SIGNAL_COMMUNITY_CHANNEL_EDITED) do(e:Args):
    let args = CommunityChatArgs(e)
    if(args.chat.communityId != self.sectionId or args.chat.id != self.chatId):
      return
    self.delegate.onCommunityChannelEdited(args.chat)

  self.events.on(SIGNAL_CHAT_RENAMED) do(e: Args):
    var args = ChatRenameArgs(e)
    if(self.chatId != args.id):
      return
    self.delegate.onChatRenamed(args.newName)

  self.events.on(SIGNAL_GROUP_CHAT_DETAILS_UPDATED) do(e: Args):
    var args = ChatUpdateDetailsArgs(e)
    if(self.chatId != args.id):
      return
    self.delegate.onGroupChatDetailsUpdated(args.newName, args.newColor, args.newImage)

  self.events.on(SIGNAL_MESSAGE_EDITED) do(e: Args):
    let args = MessageEditedArgs(e)
    if(self.chatId != args.chatId):
      return
    self.delegate.onMessageEdited(args.message)

proc getMyChatId*(self: Controller): string =
  return self.chatId

proc getChatDetails*(self: Controller): ChatDto =
  return self.chatService.getChatById(self.chatId)

proc getCommunityDetails*(self: Controller): CommunityDto =
  return self.communityService.getCommunityById(self.sectionId)

proc getOneToOneChatNameAndImage*(self: Controller): tuple[name: string, image: string, largeImage: string] =
  return self.chatService.getOneToOneChatNameAndImage(self.chatId)

proc belongsToCommunity*(self: Controller): bool =
  return self.belongsToCommunity

proc unpinMessage*(self: Controller, messageId: string) =
  self.messageService.pinUnpinMessage(self.chatId, messageId, false)

proc getMessageById*(self: Controller, messageId: string): GetMessageResult =
  return self.messageService.getMessageByMessageId(messageId)

proc isUsersListAvailable*(self: Controller): bool =
  return self.isUsersListAvailable

proc muteChat*(self: Controller, interval: int) =
  self.chatService.muteChat(self.chatId, interval)

proc unmuteChat*(self: Controller) =
  self.chatService.unmuteChat(self.chatId)

proc unblockChat*(self: Controller) =
  self.contactService.unblockContact(self.chatId)

proc markAllMessagesRead*(self: Controller) =
  self.messageService.markAllMessagesRead(self.chatId)

proc requestMoreMessages*(self: Controller) =
  self.mailserversService.requestMoreMessages(self.chatId)

proc markMessageRead*(self: Controller, msgID: string) =
  self.messageService.markCertainMessagesRead(self.chatId, @[msgID])

proc clearChatHistory*(self: Controller) =
  self.chatService.clearChatHistory(self.chatId)

proc leaveChat*(self: Controller) =
  self.chatService.leaveChat(self.chatId)

proc asyncLoadReactionsForMessage*(self: Controller, messageId: string) =
  self.messageService.asyncLoadReactionsForMessage(self.chatId, messageId)

proc getContactById*(self: Controller, contactId: string): ContactsDto =
  return self.contactService.getContactById(contactId)

proc getContactDetails*(self: Controller, contactId: string): ContactDetails =
  return self.contactService.getContactDetails(contactId)

proc getRenderedText*(self: Controller, parsedTextArray: seq[ParsedText], communityChats: seq[ChatDto]): string =
  return self.messageService.getRenderedText(parsedTextArray, communityChats)

proc getTransactionDetails*(self: Controller, message: MessageDto): (string,string) =
  return self.messageService.getTransactionDetails(message)

proc getWalletAccounts*(self: Controller): seq[wallet_account_service.WalletAccountDto] =
  return self.messageService.getWalletAccounts()
