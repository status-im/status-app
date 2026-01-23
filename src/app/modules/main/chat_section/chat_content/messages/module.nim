import nimqml, chronicles, sequtils, uuids, sets, times, tables, system
import io_interface
import ../io_interface as delegate_interface
import view, controller
import ../../../../shared_models/[message_model, message_item, contacts_utils]
import ../../../../shared_models/link_preview_model
import ../../../../../global/global_singleton
import ../../../../../core/eventemitter
import ../../../../../../app_service/service/contacts/dto/contacts
import ../../../../../../app_service/service/contacts/service as contact_service
import ../../../../../../app_service/service/community/service as community_service
import ../../../../../../app_service/service/chat/service as chat_service
import ../../../../../../app_service/service/message/service as message_service
import ../../../../../../app_service/service/mailservers/service as mailservers_service
import ../../../../../../app_service/service/shared_urls/service as shared_urls_service
import ../../../../../../app_service/service/contacts/dto/contact_details
import ../../../../../../app_service/common/types
import ../../../../../global/global_singleton

export io_interface

logScope:
  topics = "messages-module"

const CHAT_IDENTIFIER_MESSAGE_ID = "chat-identifier-message-id"
const CHAT_IDENTIFIER_CLOCK = -2
const FETCH_MORE_MESSAGES_MESSAGE_ID = "fetch-more_messages-message-id"
const FETCH_MORE_MESSAGES_CLOCK = -1

type
  FirstUnseenMessageState = tuple
    initialized: bool
    fetching: bool
    scrollToWhenFetched: bool

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool
    initialMessagesLoaded: bool
    firstUnseenMessageState: FirstUnseenMessageState
    getMessageRequestId: UUID

proc newModule*(delegate: delegate_interface.AccessInterface, events: EventEmitter, sectionId: string, chatId: string,
    belongsToCommunity: bool, contactService: contact_service.Service, communityService: community_service.Service,
    chatService: chat_service.Service, messageService: message_service.Service,
    mailserversService: mailservers_service.Service, sharedUrlsService: shared_urls_service.Service):
  Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, sectionId, chatId, belongsToCommunity, contactService,
    communityService, chatService, messageService, mailserversService, sharedUrlsService)
  result.moduleLoaded = false
  result.initialMessagesLoaded = false
  result.firstUnseenMessageState = (false, false, false)

# Forward declaration
proc createChatIdentifierItem(self: Module): Item
proc createFetchMoreMessagesItem(self: Module): Item
proc setChatDetails(self: Module, chatDetails: ChatDto)
proc updateItemsByAlbum(self: Module, items: var seq[Item], message: MessageDto): bool
proc updateLinkPreviewsContacts(self: Module, item: Item, requestFromMailserver: bool)
proc updateLinkPreviewsCommunities(self: Module, item: Item, requestFromMailserver: bool)
proc currentUserWalletContainsAddress(self: Module, address: string): bool
proc updateQuotedImages(self: Module, items: var seq[Item], message: MessageDto)

method delete*(self: Module) =
  self.controller.delete
  self.view.delete
  self.viewVariant.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  let chatDto = self.controller.getChatDetails()
  if chatDto.hasMoreMessagesToRequest():
    self.view.model().insertItemBasedOnClock(self.createFetchMoreMessagesItem())

  self.updateChatIdentifier()
  self.view.setAmIChatAdmin(self.amIChatAdmin())
  self.view.setIsPinMessageAllowedForMembers(self.pinMessageAllowedForMembers())
  self.moduleLoaded = true
  self.delegate.messagesDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

proc createMessageItemsFromMessageDtos(self: Module, messages: seq[MessageDto], reactions: seq[ReactionDto] = @[]): seq[Item] =
  for message in messages:
    # https://github.com/status-im/status-app/issues/7632 will introduce deleteFroMe feature.
    # Now we just skip deleted messages
    if message.deletedForMe:
      continue

    # Add image to album if album already exists
    if (message.contentType == ContentType.Image and len(message.albumId) != 0):
      if (self.view.model().updateAlbumIfExists(message.albumId, message.image, message.id)):
        continue

      self.updateQuotedImages(result, message)

      if (self.updateItemsByAlbum(result, message)):
        continue

    let sender = self.controller.getContactDetails(message.`from`)

    var quotedMessageAuthorDetails = ContactDetails()
    if message.quotedMessage.`from` != "":
      if(message.`from` == message.quotedMessage.`from`):
        quotedMessageAuthorDetails = sender
      else:
        quotedMessageAuthorDetails = self.controller.getContactDetails(message.quotedMessage.`from`)

    var deletedByContactDetails = ContactDetails()
    if message.deletedBy != "":
      if(message.`from` == message.deletedBy):
        deletedByContactDetails = sender
      else:
        deletedByContactDetails = self.controller.getContactDetails(message.deletedBy)

    # remove a message which has replace parameters filled
    let index = self.view.model().findIndexForMessageId(message.replace)
    if(index != -1):
      self.view.model().removeItem(message.replace)

    var communityChats: seq[ChatDto]
    communityChats = self.controller.getCommunityDetails().chats

    var renderedMessageText = self.controller.getRenderedText(message.parsedText, communityChats)

    var transactionContract = message.transactionParameters.contract
    var transactionValue = message.transactionParameters.value
    var isCurrentUser = sender.isCurrentUser
    if(message.contentType == ContentType.Transaction):
      (transactionContract, transactionValue) = self.controller.getTransactionDetails(message)
      if message.transactionParameters.fromAddress != "":
        isCurrentUser = self.currentUserWalletContainsAddress(message.transactionParameters.fromAddress)

    var item = message_model.createMessageItemFromDtos(
      message,
      message.communityId,
      sender,
      isCurrentUser,
      renderedMessageText,
      clearText = message.text,
      albumImages = @[],
      albumMessageIds = @[],
      deletedByContactDetails,
      quotedMessageAuthorDetails,
      self.controller.getRenderedText(message.quotedMessage.parsedText, communityChats),
      transactionContract,
      transactionValue,
    )

    self.updateLinkPreviewsContacts(item, requestFromMailserver = item.seen)
    self.updateLinkPreviewsCommunities(item, requestFromMailserver = item.seen)

    for r in reactions:
      if r.messageId == message.id:
        let userWhoAddedThisReaction = self.controller.getContactById(r.`from`)
        let didIReactWithThisEmoji = userWhoAddedThisReaction.id == singletonInstance.userProfile.getPubKey()
        item.addReaction(r.emoji, didIReactWithThisEmoji, userWhoAddedThisReaction.id,
          userWhoAddedThisReaction.userDefaultDisplayName(), r.id)

    if message.editedAt != 0:
      item.isEdited = true

    if(message.contentType == ContentType.Gap):
      item.gapFrom = message.gapParameters.`from`
      item.gapTo = message.gapParameters.to

    result.add(item)


proc createFetchMoreMessagesItem(self: Module): Item =
  let chatDto = self.controller.getChatDetails()
  result = message_model.createMessageItemFromDtos(
    message = MessageDto(
      id: FETCH_MORE_MESSAGES_MESSAGE_ID,
      clock: FETCH_MORE_MESSAGES_CLOCK,
      contentType: ContentType.FetchMoreMessagesButton,
    ),
    communityId = "",
    sender = ContactDetails(
      dto: ContactsDto(
        id: chatDto.id,
      ),
    ),
    isCurrentUser = false,
    renderedMessageText = "",
    clearText = "",
  )

proc createChatIdentifierItem(self: Module): Item =
  let chatDto = self.controller.getChatDetails()
  var chatName = chatDto.name
  var smallImage = ""
  var chatIcon = ""
  var senderIsAdded = false
  if chatDto.chatType == ChatType.OneToOne:
    let sender = self.controller.getContactDetails(chatDto.id)
    senderIsAdded = sender.dto.added
    (chatName, smallImage, chatIcon) = self.controller.getOneToOneChatNameAndImage()

  result = message_model.createMessageItemFromDtos(
    message = MessageDto(
      id: CHAT_IDENTIFIER_MESSAGE_ID,
      clock: CHAT_IDENTIFIER_CLOCK,
      contentType: ContentType.ChatIdentifier,
      seen: true,
    ),
    communityId = "",
    sender = ContactDetails(
    defaultDisplayName: chatName,
    icon: chatIcon,
    dto: ContactsDto(
      id: chatDto.id,
      added: senderIsAdded,
    ),
  ),
    isCurrentUser = false,
    renderedMessageText = "",
    clearText = "",
  )

proc checkIfMessageLoadedAndScroll(self: Module) =
  let searchedMessageId = self.controller.getSearchedMessageId()

  if searchedMessageId.len == 0:
    return

  let index = self.view.model().findIndexForMessageId(searchedMessageId)
  if index == -1:
    self.controller.increaseLoadingMessagesPerPageFactor()
    if self.controller.loadMoreMessages():
      warn "failed to start loading more messages"
      return
    # If failed to `loadMoreMessages`, then the most recent message is already loaded.
    # Then message is not found.

  self.controller.clearSearchedMessageId()
  self.controller.resetLoadingMessagesPerPageFactor()
  if index != -1:
    self.view.emitScrollToMessageSignal(index)
  self.view.setMessageSearchOngoing(false)
  self.reevaluateViewLoadingState()

proc currentUserWalletContainsAddress(self: Module, address: string): bool =
  if (address.len == 0):
    return false
  let accounts = self.controller.getWalletAccounts()
  for acc in accounts:
    if (acc.address == address):
      return true
  return false

method reevaluateViewLoadingState*(self: Module) =
  let loading = not self.initialMessagesLoaded or
                not self.firstUnseenMessageState.initialized or
                self.firstUnseenMessageState.fetching or
                self.view.getMessageSearchOngoing()
  self.view.setLoading(loading)

method newMessagesLoaded*(self: Module, messages: seq[MessageDto], reactions: seq[ReactionDto]) =
  if messages.len > 0:
    var viewItems = self.createMessageItemsFromMessageDtos(messages, reactions)

    if self.controller.getChatDetails().hasMoreMessagesToRequest():
      viewItems.add(self.createFetchMoreMessagesItem())
    viewItems.add(self.createChatIdentifierItem())
    self.view.model().removeItem(FETCH_MORE_MESSAGES_MESSAGE_ID)
    self.view.model().removeItem(CHAT_IDENTIFIER_MESSAGE_ID)
    # Add new loaded messages
    self.view.model().insertItemsBasedOnClock(viewItems)
    self.view.model().resetNewMessagesMarker()

    # check if this loading was caused by the click on a messages from the app search result
    self.checkIfMessageLoadedAndScroll()

  self.initialMessagesLoaded = true
  self.reevaluateViewLoadingState()

method messagesAdded*(self: Module, messages: seq[MessageDto]) =
  let items = self.createMessageItemsFromMessageDtos(messages)

  self.view.model().insertItemsBasedOnClock(items)

method removeNewMessagesMarker*(self: Module)

method onSendingMessageSuccess*(self: Module, message: MessageDto) =
  self.messagesAdded(@[message])
  self.view.emitSendingMessageSuccessSignal()
  self.removeNewMessagesMarker()

method onSendingMessageError*(self: Module, error: string) =
  self.view.emitSendingMessageErrorSignal(error)

method onEnvelopeSent*(self: Module, messagesIds: seq[string]) =
  for messageId in messagesIds:
    self.view.model().itemSent(messageId)

method onEnvelopeExpired*(self: Module, messagesIds: seq[string]) =
  for messageId in messagesIds:
    self.view.model().itemExpired(messageId)

method onMessageDelivered*(self: Module, messageId: string) =
  self.view.model().itemDelivered(messageId)

method loadMoreMessages*(self: Module) =
  discard self.controller.loadMoreMessages()

method toggleReaction*(self: Module, messageId: string, emoji: string) =
  let item = self.view.model().getItemWithMessageId(messageId)
  if item.isNil:
    return

  let myPublicKey = singletonInstance.userProfile.getPubKey()
  if item.shouldAddReaction(emoji, myPublicKey):
    self.controller.addReaction(messageId, emoji)
  else:
    let reactionId = item.getReactionId(emoji, myPublicKey)
    self.controller.removeReaction(messageId, emoji, reactionId)

method onReactionAdded*(self: Module, messageId: string, emoji: string, reactionId: string) =
  let myPublicKey = singletonInstance.userProfile.getPubKey()
  let myName = singletonInstance.userProfile.getName()
  self.view.model().addReaction(messageId, emoji, didIReactWithThisEmoji = true, myPublicKey, myName, reactionId)

method onReactionRemoved*(self: Module, messageId: string, emoji: string, reactionId: string) =
  self.view.model().removeReaction(messageId, emoji, reactionId, didIRemoveThisReaction = true)

method toggleReactionFromOthers*(self: Module, messageId: string, emoji: string, reactionId: string,
  reactionFrom: string) =
  let item = self.view.model().getItemWithMessageId(messageId)
  if(item.isNil):
    info "message with this id is not loaded yet ", msgId=messageId, methodName="toggleReactionFromOthers"
    return
  if(item.shouldAddReaction(emoji, reactionFrom)):
    let userWhoAddedThisReaction = self.controller.getContactById(reactionFrom)
    self.view.model().addReaction(messageId, emoji, didIReactWithThisEmoji = false,
    userWhoAddedThisReaction.id, userWhoAddedThisReaction.userDefaultDisplayName(), reactionId)
  else:
    self.view.model().removeReaction(messageId, emoji, reactionId, didIRemoveThisReaction = false)

method pinUnpinMessage*(self: Module, messageId: string, pin: bool) =
  self.controller.pinUnpinMessage(messageId, pin)

method markMessageAsUnread*(self: Module, messageId: string) =
  self.controller.markMessageAsUnread(messageId)

method onPinMessage*(self: Module, messageId: string, actionInitiatedBy: string) =
  self.view.model().pinUnpinMessage(messageId, true, actionInitiatedBy)

method onUnpinMessage*(self: Module, messageId: string) =
  self.view.model().pinUnpinMessage(messageId, false, "")

method onMarkMessageAsUnread*(self: Module, messageId: string) =
  self.view.model().markMessageAsUnread(messageId)

method getSectionId*(self: Module): string =
  return self.controller.getMySectionId()

method getChatId*(self: Module): string =
  return self.controller.getMyChatId()

method getChatType*(self: Module): int =
  let chatDto = self.controller.getChatDetails()
  return chatDto.chatType.int

method getChatColor*(self: Module): string =
  let chatDto = self.controller.getChatDetails()
  return chatDto.color

method getChatIcon*(self: Module): string =
  let chatDto = self.controller.getChatDetails()
  return chatDto.icon

method amIChatAdmin*(self: Module): bool =
  if not self.controller.belongsToCommunity():
    let chatDto = self.controller.getChatDetails()
    for member in chatDto.members:
      if (member.id == singletonInstance.userProfile.getPubKey()):
        # TODO untangle this. There is no special roles for group chats
        return member.role == MemberRole.Owner or member.role == MemberRole.Admin or member.role == MemberRole.TokenMaster
    return false
  else:
    let communityDto = self.controller.getCommunityDetails()
    return communityDto.isPrivilegedUser

method pinMessageAllowedForMembers*(self: Module): bool =
  if(self.controller.belongsToCommunity()):
    let communityDto = self.controller.getCommunityDetails()
    return communityDto.adminSettings.pinMessageAllMembersEnabled
  return false

method getNumberOfPinnedMessages*(self: Module): int =
  return self.controller.getNumOfPinnedMessages()

method updateContactDetails*(self: Module, contactId: string) =
  let updatedContact = self.controller.getContactDetails(contactId)

  for item in self.view.model().modelContactUpdateIterator(contactId):
    if item.senderId == contactId:
      item.senderDisplayName = updatedContact.defaultDisplayName
      item.senderUsesDefaultName = resolveUsesDefaultName(updatedContact.dto.localNickname, updatedContact.dto.name, updatedContact.dto.displayName)
      item.senderOptionalName = updatedContact.optionalName
      item.senderIcon = updatedContact.icon
      item.senderIsAdded = updatedContact.dto.added
      item.senderTrustStatus = updatedContact.dto.trustStatus
      item.senderEnsVerified = updatedContact.dto.ensVerified

    if item.quotedMessageAuthorDetails.dto.id == contactId:
      item.quotedMessageAuthorDetails = updatedContact
      item.quotedMessageAuthorDisplayName = updatedContact.defaultDisplayName
      item.quotedMessageAuthorAvatar = updatedContact.icon

    if item.messageContainsMentions and item.mentionedUsersPks.anyIt(it == contactId):
      let communityChats = self.controller.getCommunityDetails().chats
      item.messageText = self.controller.getRenderedText(item.parsedText, communityChats)

    item.linkPreviewModel.setContactInfo(updatedContact)

method deleteMessage*(self: Module, messageId: string) =
  self.controller.deleteMessage(messageId)

method onMessageRemoved*(self: Module, messageId, removedBy: string) =
  var removedByValue = removedBy
  if removedBy == "":
    # removedBy is empty if it was removed by the sender
    let messageItem = self.view.model().getItemWithMessageId(messageId)
    if(messageItem.isNil):
      return
    if messageItem.id == "":
      return
    removedByValue = messageItem.senderId
  var removedByContactDetails = self.controller.getContactDetails(removedByValue)
  self.view.model().messageRemoved(messageId, removedByValue, removedByContactDetails)

method onMessagesDeleted*(self: Module, messageIds: seq[string]) =
  for messageId in messageIds:
    self.view.model().removeItem(messageId)

method editMessage*(self: Module, messageId: string, updatedMsg: string) =
  self.controller.editMessage(messageId, updatedMsg)

method onMessageEdited*(self: Module, message: MessageDto) =
  let itemBeforeChange = self.view.model().getItemWithMessageId(message.id)
  if(itemBeforeChange.isNil):
    # We received the edited message before we received the real message. Just show the final message as is
    self.messagesAdded(@[message])
    return

  let mentionedUsersPks = itemBeforeChange.mentionedUsersPks
  let communityChats = self.controller.getCommunityDetails().chats

  var updatedText = ""
  if message.contentType == ContentType.BridgeMessage:
    # message from bridge does not have any tags, we need to add them here to show correctly edited message
    updatedText = "<p>" & message.bridgeMessage.content & "</p>"
  else:
    updatedText = self.controller.getRenderedText(message.parsedText, communityChats)

  self.view.model().updateEditedMsg(
    message.id,
    updatedText,
    message.text,
    message.parsedText,
    message.contentType,
    message.mentioned,
    message.containsContactMentions(),
    message.links,
    message.mentionedUsersPks
    )

method onHistoryCleared*(self: Module) =
  self.view.model().clear()
  # Add ChatIdentifier back after model is cleared, so that the chat screen is not blank
  self.view.model().insertItemBasedOnClock(self.createChatIdentifierItem())

method updateChatIdentifier*(self: Module) =
  let chatDto = self.controller.getChatDetails()
  self.setChatDetails(chatDto)
  # Delete the old ChatIdentifier message first
  self.view.model().removeItem(CHAT_IDENTIFIER_MESSAGE_ID)
  # Add new loaded messages
  self.view.model().insertItemBasedOnClock(self.createChatIdentifierItem())

method updateChatFetchMoreMessages*(self: Module) =
  self.view.model().removeItem(FETCH_MORE_MESSAGES_MESSAGE_ID)

  if (self.controller.getChatDetails().hasMoreMessagesToRequest()):
    self.view.model().insertItemBasedOnClock(self.createFetchMoreMessagesItem())

proc switchToMessage*(self: Module, messageId: string) =
  let index = self.view.model().findIndexForMessageId(messageId)
  if index != -1:
    self.controller.clearSearchedMessageId()
    self.view.emitSwitchToMessageSignal(index)
  else:
    self.controller.setSearchedMessageId(messageId)

method scrollToMessage*(self: Module, messageId: string) =
  if messageId == "":
    return

  if self.view.getMessageSearchOngoing():
    return

  self.getMessageRequestId = self.controller.asyncGetMessageById(messageId)
  self.controller.setSearchedMessageId(messageId)
  self.view.setMessageSearchOngoing(true)

method onGetMessageById*(self: Module, requestId: UUID, messageId: string, message: MessageDto, errorMessage: string) =
  if self.getMessageRequestId != requestId:
    return

  if errorMessage != "":
    error "attempted to scroll to a not fetched message", errorMessage, messageId, chatId = self.controller.getMyChatId()
    self.view.setMessageSearchOngoing(false)
    return

  if message.contentType == ContentType.ContactIdentityVerification:
    warn "attempted to scroll to a non-visual message", messageId, contentType = $message.contentType
    self.view.setMessageSearchOngoing(false)
    return

  self.checkIfMessageLoadedAndScroll()
  self.reevaluateViewLoadingState()

method fillGaps*(self: Module, messageId: string) =
  self.controller.fillGaps(messageId)

method leaveChat*(self: Module) =
  self.controller.leaveChat()

method onChatMemberUpdated*(self: Module, publicKey: string, memberRole: MemberRole, joined: bool) =
  let chatDto = self.controller.getChatDetails()
  if(chatDto.chatType != ChatType.PrivateGroupChat):
    return

  let myPublicKey = singletonInstance.userProfile.getPubKey()
  if(publicKey != myPublicKey):
    return

  self.view.model().refreshItemWithId(CHAT_IDENTIFIER_MESSAGE_ID)

method onMailserverSynced*(self: Module, syncedFrom: int64) =
  let chatDto = self.controller.getChatDetails()
  if (not chatDto.hasMoreMessagesToRequest(syncedFrom)):
    self.view.model().removeItem(FETCH_MORE_MESSAGES_MESSAGE_ID)

method resendChatMessage*(self: Module, messageId: string): string =
  return self.controller.resendChatMessage(messageId)

method resetNewMessagesMarker*(self: Module) =
  self.firstUnseenMessageState.fetching = true
  self.firstUnseenMessageState.scrollToWhenFetched = false
  self.controller.getAsyncFirstUnseenMessageId()

method resetAndScrollToNewMessagesMarker*(self: Module) =
  self.firstUnseenMessageState.fetching = true
  self.firstUnseenMessageState.scrollToWhenFetched = true
  self.controller.getAsyncFirstUnseenMessageId()

method removeNewMessagesMarker*(self: Module) =
  self.view.model().setFirstUnseenMessageId("")
  self.view.model().resetNewMessagesMarker()

method markAllMessagesRead*(self: Module) =
  self.view.model().markAllAsSeen()

method markMessagesAsRead*(self: Module, messages: seq[string]) =
  self.view.model().markAsSeen(messages)

method updateCommunityDetails*(self: Module, community: CommunityDto) =
  if community.id == self.getSectionId():
    self.view.setAmIChatAdmin(community.isPrivilegedUser)
    self.view.setIsPinMessageAllowedForMembers(community.adminSettings.pinMessageAllMembersEnabled)

  for item in self.view.model().items:
    item.linkPreviewModel.setCommunityInfo(community)

proc setChatDetails(self: Module, chatDetails: ChatDto) =
  self.view.setChatColor(chatDetails.color)
  self.view.setChatIcon(chatDetails.icon)
  self.view.setChatType(chatDetails.chatType.int)

proc updateQuotedImages(self: Module, items: var seq[Item], message: MessageDto) =
  for i in 0 ..< items.len:
    let item = items[i]

    if len(message.quotedMessage.albumImages) > 0 and not message.deleted:
      var quotedAlbumImages = item.quotedMessageAlbumMessageImages
      quotedAlbumImages.add(message.quotedMessage.albumImages)
      item.quotedMessageAlbumMessageImages = quotedAlbumImages

proc updateItemsByAlbum(self: Module, items: var seq[Item], message: MessageDto): bool =
  for i in 0 ..< items.len:
    let item = items[i]
    if item.albumId == message.albumId:
      # Check if message already in album
      for j in 0 ..< item.albumMessageIds.len:
        if item.albumMessageIds[j] == message.id:
          return true

        var albumImages = item.albumMessageImages
        var albumMessagesIds = item.albumMessageIds
        albumMessagesIds.add(message.id)
        albumImages.add(message.image)
        item.albumMessageImages = albumImages
        item.albumMessageIds = albumMessagesIds
        items[i] = item
        return true
  return false

method isFirstUnseenMessageInitialized*(self: Module): bool =
  return self.firstUnseenMessageState.initialized

method onFirstUnseenMessageLoaded*(self: Module, messageId: string) =
  self.view.model().setFirstUnseenMessageId(messageId)
  self.view.model().resetNewMessagesMarker()
  if self.firstUnseenMessageState.scrollToWhenFetched:
    self.scrollToMessage(messageId)
  self.firstUnseenMessageState.initialized = true
  self.firstUnseenMessageState.fetching = false
  self.reevaluateViewLoadingState()

method forceLinkPreviewsLocalData*(self: Module, messageId: string) =
  let item = self.view.model().getItemWithMessageId(messageId)
  debug "forceLinkPreviewsLocalData", messageId, itemFound = $(item != nil)
  if item == nil:
    return
  self.updateLinkPreviewsContacts(item, requestFromMailserver = true)
  self.updateLinkPreviewsCommunities(item, requestFromMailserver = true)

proc updateLinkPreviewsContacts(self: Module, item: Item, requestFromMailserver: bool) =
  for contactId in item.linkPreviewModel.getContactIds().items:
    let contact = self.controller.getContactDetails(contactId)

    if contact.dto.displayName != "":
      item.linkPreviewModel.setContactInfo(contact)

    if not requestFromMailserver:
      continue

    debug "updateLinkPreviewsContacts: contact not found, requesting from mailserver", contactId
    item.linkPreviewModel.onContactDataRequested(contactId)
    self.controller.requestContactInfo(contactId)

proc updateLinkPreviewsCommunities(self: Module, item: Item, requestFromMailserver: bool) =
  for communityId, url in item.linkPreviewModel.getCommunityLinks().pairs:
    let community = self.controller.getCommunityById(communityId)

    if community.id != "":
      item.linkPreviewModel.setCommunityInfo(community)

    if not requestFromMailserver:
      continue

    debug "updateLinkPreviewsCommunites: requesting from mailserver", communityId
    let urlData = self.controller.parseSharedUrl(url)
    item.linkPreviewModel.onCommunityInfoRequested(communityId)
    self.controller.requestCommunityInfo(communityId, useDatabase = false, initDuration(minutes = 10))

