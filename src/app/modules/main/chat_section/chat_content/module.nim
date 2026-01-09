import nimqml, chronicles, sequtils
import io_interface
import ../io_interface as delegate_interface
import view, controller

import ../item as chat_item
import ./chat_details
import ../../../shared_models/message_model as pinned_msg_model
import ../../../shared_models/message_item as pinned_msg_item
import ../../../../global/global_singleton
import ../../../../core/eventemitter

import input_area/module as input_area_module
import messages/module as messages_module
import users/module as users_module

import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/node_configuration/service as node_configuration_service
import ../../../../../app_service/service/contacts/service as contact_service
import ../../../../../app_service/service/chat/service as chat_service
import ../../../../../app_service/service/community/service as community_service
import ../../../../../app_service/service/message/service as message_service
import ../../../../../app_service/service/mailservers/service as mailservers_service
import ../../../../../app_service/service/shared_urls/service as shared_urls_service
import ../../../../../app_service/common/types

export io_interface

logScope:
  topics = "chat-section-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    inputAreaModule: input_area_module.AccessInterface
    messagesModule: messages_module.AccessInterface
    usersModule: users_module.AccessInterface
    moduleLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface, events: EventEmitter, sectionId: string, chatId: string,
    belongsToCommunity: bool, isUsersListAvailable: bool, settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service, contactService: contact_service.Service,
    chatService: chat_service.Service, communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service, sharedUrlsService: shared_urls_service.Service):
  Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, sectionId, chatId, belongsToCommunity,
    isUsersListAvailable, settingsService, nodeConfigurationService, contactService, chatService, communityService,
    messageService)
  result.moduleLoaded = false

  result.inputAreaModule = input_area_module.newModule(result, events, sectionId, chatId, belongsToCommunity,
    chatService, communityService, contactService, messageService, settingsService)
  result.messagesModule = messages_module.newModule(result, events, sectionId, chatId, belongsToCommunity,
    contactService, communityService, chatService, messageService, mailserversService, sharedUrlsService)
  result.usersModule = users_module.newModule(events, sectionId, chatId, belongsToCommunity,
    isUsersListAvailable, contactService, chat_service, communityService, messageService)

method delete*(self: Module) =
  self.controller.delete
  self.view.delete
  self.viewVariant.delete
  self.inputAreaModule.delete
  self.messagesModule.delete
  if self.usersModule != nil:
    self.usersModule.delete

method load*(self: Module, chatItem: ChatItem) =
  self.controller.init()

  var chatName = chatItem.name
  var chatImage = chatItem.icon
  var isContact = false
  var trustStatus = TrustStatus.Unknown
  if chatItem.`type` == ChatType.OneToOne.int:
    let contactDto = self.controller.getContactById(self.controller.getMyChatId())
    chatName = contactDto.userDefaultDisplayName()
    isContact = contactDto.isContact
    trustStatus = contactDto.trustStatus
    if(contactDto.image.thumbnail.len > 0):
      chatImage = contactDto.image.thumbnail

  self.usersModule.load()

  self.view.load()
  self.view.chatDetails.setChatDetails(chatItem.id, chatItem.`type`, self.controller.belongsToCommunity(),
    self.controller.isUsersListAvailable(), chatName, chatImage,
    chatItem.color, chatItem.description, chatItem.emoji, chatItem.hasUnreadMessages, chatItem.notificationsCount,
    chatItem.highlight, chatItem.muted, chatItem.position, trustStatus,
    isContact, chatItem.blocked, chatItem.canPost, chatItem.canView, chatItem.canPostReactions,
    chatItem.hideIfPermissionsNotMet, chatItem.missingEncryptionKey, chatItem.requiresPermissions)
  
  self.view.chatDetailsChanged()

  self.inputAreaModule.load()
  self.messagesModule.load()

proc checkIfModuleDidLoad(self: Module) =
  if self.moduleLoaded:
    return

  if(not self.inputAreaModule.isLoaded()):
    return

  if (not self.messagesModule.isLoaded()):
    return

  if (not self.usersModule.isLoaded()):
    return

  self.moduleLoaded = true
  self.delegate.chatContentDidLoad()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method inputAreaDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method messagesDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method usersDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method getInputAreaModule*(self: Module): QVariant =
  return self.inputAreaModule.getModuleAsVariant()

method getMessagesModule*(self: Module): QVariant =
  return self.messagesModule.getModuleAsVariant()

method getUsersModule*(self: Module): QVariant =
  return self.usersModule.getModuleAsVariant()

proc currentUserWalletContainsAddress(self: Module, address: string): bool =
  if (address.len == 0):
    return false
  let accounts = self.controller.getWalletAccounts()
  for acc in accounts:
    if (acc.address == address):
      return true
  return false

proc buildPinnedMessageItem(self: Module, message: MessageDto, actionInitiatedBy: string,
    item: var pinned_msg_item.Item, reactions: seq[ReactionDto]):bool =

  let contactDetails = self.controller.getContactDetails(message.`from`)
  let communityChats = self.controller.getCommunityDetails().chats
  var quotedMessageAuthorDetails = ContactDetails()
  if message.quotedMessage.`from` != "":
    if(message.`from` == message.quotedMessage.`from`):
      quotedMessageAuthorDetails = contactDetails
    else:
      quotedMessageAuthorDetails = self.controller.getContactDetails(message.quotedMessage.`from`)

  var transactionContract = message.transactionParameters.contract
  var transactionValue = message.transactionParameters.value
  var isCurrentUser = contactDetails.isCurrentUser
  if(message.contentType == ContentType.Transaction):
    (transactionContract, transactionValue) = self.controller.getTransactionDetails(message)
    if message.transactionParameters.fromAddress != "":
      isCurrentUser = self.currentUserWalletContainsAddress(message.transactionParameters.fromAddress)

  item = pinned_msg_model.createMessageItemFromDtos(
    message,
    message.communityId,
    contactDetails,
    isCurrentUser,
    self.controller.getRenderedText(message.parsedText, communityChats),
    clearText = message.text,
    albumImages = @[],
    albumMessageIds = @[],
    deletedByContactDetails = ContactDetails(),
    quotedMessageAuthorDetails,
    self.controller.getRenderedText(message.quotedMessage.parsedText, communityChats),
    transactionContract,
    transactionValue,
  )
  item.pinned = true
  item.pinnedBy = actionInitiatedBy

  for r in reactions:
    if r.messageId == message.id:
      let userWhoAddedThisReaction = self.controller.getContactById(r.`from`)
      let didIReactWithThisEmoji = userWhoAddedThisReaction.id == singletonInstance.userProfile.getPubKey()
      item.addReaction(r.emoji, didIReactWithThisEmoji, userWhoAddedThisReaction.id,
        userWhoAddedThisReaction.userDefaultDisplayName(), r.id)

  return true

method newPinnedMessagesLoaded*(self: Module, pinnedMessages: seq[PinnedMessageDto], reactions: seq[ReactionDto]) =
  var viewItems: seq[pinned_msg_item.Item]
  for p in pinnedMessages:
    var item: pinned_msg_item.Item
    if(not self.buildPinnedMessageItem(p.message, p.pinnedBy, item, reactions)):
      continue

    viewItems = item & viewItems # messages are sorted from the most recent to the least recent one

  if(viewItems.len == 0):
    return
  self.view.pinnedModel().insertItemsBasedOnClock(viewItems)

method unpinMessage*(self: Module, messageId: string) =
  self.controller.unpinMessage(messageId)

method onUnpinMessage*(self: Module, messageId: string) =
  self.view.pinnedModel().removeItem(messageId)

method onPinMessage*(self: Module, messageId: string, actionInitiatedBy: string) =
  var item: pinned_msg_item.Item
  let response = self.controller.getMessageById(messageId)
  if response.error.len > 0:
    return

  if not self.buildPinnedMessageItem(response.message, actionInitiatedBy, item, @[]):
    return

  self.controller.asyncLoadReactionsForMessage(messageId)
  self.view.pinnedModel().insertItemBasedOnClock(item)

method onMessageEdited*(self: Module, message: MessageDto) =
  let index = self.view.pinnedModel().findIndexForMessageId(message.id)
  if index == -1:
    return

  let itemBeforeChange = self.view.pinnedModel().getItemWithMessageId(message.id)
  let mentionedUsersPks = itemBeforeChange.mentionedUsersPks
  let communityChats = self.controller.getCommunityDetails().chats

  self.view.pinnedModel().updateEditedMsg(
    message.id,
    self.controller.getRenderedText(message.parsedText, communityChats),
    message.text,
    message.parsedText,
    message.contentType,
    message.mentioned,
    message.containsContactMentions(),
    message.links,
    message.mentionedUsersPks
  )

method getMyChatId*(self: Module): string =
  self.controller.getMyChatId()

method muteChat*(self: Module, interval: int) =
  self.controller.muteChat(interval)

method unmuteChat*(self: Module) =
  self.controller.unmuteChat()

method unblockChat*(self: Module) =
  self.controller.unblockChat()

method markAllMessagesRead*(self: Module) =
  self.controller.markAllMessagesRead()

method requestMoreMessages*(self: Module) =
  self.controller.requestMoreMessages()

method markMessageRead*(self: Module, msgID: string) =
  self.controller.markMessageRead(msgID)

method clearChatHistory*(self: Module) =
  self.controller.clearChatHistory()

method leaveChat*(self: Module) =
  self.controller.leaveChat()

method onChatMuted*(self: Module) =
  self.view.setMuted(true)

method onChatUnmuted*(self: Module) =
  self.view.setMuted(false)

method onReactionAdded*(self: Module, messageId: string, emoji: string, reactionId: string) =
  let myPublicKey = singletonInstance.userProfile.getPubKey()
  let myName = singletonInstance.userProfile.getName()
  self.view.pinnedModel().addReaction(messageId, emoji, didIReactWithThisEmoji = true, myPublicKey, myName, reactionId)

method onReactionRemoved*(self: Module, messageId: string, emoji: string, reactionId: string) =
  self.view.pinnedModel().removeReaction(messageId, emoji, reactionId, didIRemoveThisReaction = true)

method toggleReactionFromOthers*(self: Module, messageId: string, emoji: string, reactionId: string, reactionFrom: string) =
  let item = self.view.pinnedModel().getItemWithMessageId(messageId)
  if item.isNil:
    return

  if item.shouldAddReaction(emoji, reactionFrom):
    let userWhoAddedThisReaction = self.controller.getContactById(reactionFrom)
    self.view.pinnedModel().addReaction(messageId, emoji, didIReactWithThisEmoji = false,
      userWhoAddedThisReaction.id, userWhoAddedThisReaction.userDefaultDisplayName(), reactionId)
  else:
    self.view.pinnedModel().removeReaction(messageId, emoji, reactionId, didIRemoveThisReaction = false)

method onReactionsLoaded*(self: Module, messageId: string, reactions: seq[ReactionDto]) =
  let myPublicKey = singletonInstance.userProfile.getPubKey()
  for reaction in reactions:
    let userWhoAddedThisReaction = self.controller.getContactById(reaction.`from`)
    self.view.pinnedModel().addReaction(
      messageId,
      reaction.emoji,
      didIReactWithThisEmoji = (reaction.`from` == myPublicKey),
      userWhoAddedThisReaction.id,
      userWhoAddedThisReaction.userDefaultDisplayName(),
      reaction.id
    )

method onContactDetailsUpdated*(self: Module, contactId: string) =
  let updatedContact = self.controller.getContactDetails(contactId)
  for item in self.view.pinnedModel().modelContactUpdateIterator(contactId):
    if item.senderId == contactId:
      item.senderDisplayName = updatedContact.defaultDisplayName
      item.senderOptionalName = updatedContact.optionalName
      item.senderEnsVerified = updatedContact.dto.ensVerified
      item.senderIcon = updatedContact.icon
      item.senderTrustStatus = updatedContact.dto.trustStatus

    if item.quotedMessageAuthorDetails.dto.id == contactId:
      item.quotedMessageAuthorDetails = updatedContact
      item.quotedMessageAuthorDisplayName = updatedContact.defaultDisplayName
      item.quotedMessageAuthorAvatar = updatedContact.icon

    if item.messageContainsMentions and item.mentionedUsersPks.anyIt(it == contactId):
      let communityChats = self.controller.getCommunityDetails().chats
      item.messageText = self.controller.getRenderedText(item.parsedText, communityChats)

  if self.controller.getMyChatId() == contactId:
    self.view.updateChatDetailsNameAndIcon(updatedContact.defaultDisplayName, updatedContact.icon)
    self.view.updateTrustStatus(updatedContact.dto.trustStatus)
    self.view.updateChatBlocked(updatedContact.dto.blocked)

method onNotificationsUpdated*(self: Module, hasUnreadMessages: bool, notificationCount: int) =
  self.view.updateChatDetailsNotifications(hasUnreadMessages, notificationCount)

method onChatUpdated*(self: Module, chatItem: ChatItem) =
  if chatItem.`type` != ChatType.OneToOne.int:
    self.view.chatDetails.setName(chatItem.name)
    self.view.chatDetails.setIcon(chatItem.icon)
  self.view.chatDetails.setDescription(chatItem.description)
  self.view.chatDetails.setEmoji(chatItem.emoji)
  self.view.chatDetails.setColor(chatItem.color)
  self.view.chatDetails.setMuted(chatItem.muted)
  self.view.chatDetails.setCanPost(chatItem.canPost)
  self.view.chatDetails.setCanView(chatItem.canView)
  self.view.chatDetails.setCanPostReactions(chatItem.canPostReactions)
  self.view.chatDetails.setHideIfPermissionsNotMet(chat_item.hideIfPermissionsNotMet)
  self.view.chatDetails.setMissingEncryptionKey(chat_item.missingEncryptionKey)
  self.view.chatDetails.setRequiresPermissions(chat_item.requiresPermissions)

  self.messagesModule.updateChatFetchMoreMessages()
  self.messagesModule.updateChatIdentifier()

method onCommunityChannelEdited*(self: Module, chatDto: ChatDto) =
  # This is CommunityChat ChatDto
  self.view.chatDetails.setDescription(chatDto.description)
  self.view.chatDetails.setEmoji(chatDto.emoji)
  self.view.chatDetails.setColor(chatDto.color)
  self.view.chatDetails.setMuted(chatDto.muted)
  self.view.chatDetails.setCanPost(chatDto.canPost)
  self.view.chatDetails.setCanView(chatDto.canView)
  self.view.chatDetails.setCanPostReactions(chatDto.canPostReactions)
  self.view.chatDetails.setHideIfPermissionsNotMet(chatDto.hideIfPermissionsNotMet)
  self.view.chatDetails.setName(chatDto.name)
  self.view.chatDetails.setIcon(chatDto.icon)
  self.view.chatDetails.setMissingEncryptionKey(chatDto.missingEncryptionKey)

  if self.view.chatDetails.getRequiresPermissions() != chatDto.tokenGated:
    # The channel permission status changed. Update the member list
    self.view.chatDetails.setRequiresPermissions(chatDto.tokenGated)
    self.usersModule.updateMembersList()

  self.messagesModule.updateChatFetchMoreMessages()
  self.messagesModule.updateChatIdentifier()

method onChatRenamed*(self: Module, newName: string) =
  self.view.updateChatDetailsName(newName)
  self.messagesModule.updateChatIdentifier()

method onGroupChatDetailsUpdated*(self: Module, newName: string, newColor: string, newImage: string) =
  self.view.updateChatDetailsNameColorIcon(newName, newColor, newImage)
  self.messagesModule.updateChatIdentifier()

method onMutualContactChanged*(self: Module) =
  let contactDto = self.controller.getContactById(self.controller.getMyChatId())
  let isContact = contactDto.isContact
  self.view.onMutualContactChanged(isContact)

method onMadeActive*(self: Module) =
  # The new messages marker is reset each time the chat is made active,
  # as messages may arrive out of order and relying on the previous
  # new messages marker could yield incorrect results.
  if not self.messagesModule.isFirstUnseenMessageInitialized() or
     self.controller.getChatDetails().unviewedMessagesCount > 0:
    self.messagesModule.resetAndScrollToNewMessagesMarker()
  self.messagesModule.reevaluateViewLoadingState()
  self.view.setActive()

method onMadeInactive*(self: Module) =
  if self.controller.getChatDetails().unviewedMessagesCount == 0:
    self.messagesModule.removeNewMessagesMarker()
  self.view.setInactive()

method amIChatAdmin*(self: Module): bool =
  if not self.controller.belongsToCommunity():
    let chatDto = self.controller.getChatDetails()
    for member in chatDto.members:
      if member.id == singletonInstance.userProfile.getPubKey():
        return member.role == MemberRole.Owner or member.role == MemberRole.Admin or member.role == MemberRole.TokenMaster
    return false
  else:
    let communityDto = self.controller.getCommunityDetails()
    return communityDto.memberRole == MemberRole.Owner or
      communityDto.memberRole == MemberRole.Admin or communityDto.memberRole == MemberRole.TokenMaster

method scrollToMessage*(self: Module, messageId: string) =
  self.messagesModule.scrollToMessage(messageId)
