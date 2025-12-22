import tables

import io_interface

import ../../../../app_service/service/settings/service as settings_service
import ../../../../app_service/service/node_configuration/service as node_configuration_service
import ../../../../app_service/service/contacts/service as contact_service
import ../../../../app_service/service/chat/service as chat_service
import ../../../../app_service/service/network/service as network_service
import ../../../../app_service/service/community/service as community_service
import ../../../../app_service/service/message/service as message_service
import ../../../../app_service/service/mailservers/service as mailservers_service
import ../../../../app_service/service/wallet_account/service as wallet_account_service
import ../../../../app_service/service/token/service as token_service
import ../../../../app_service/service/community_tokens/service as community_tokens_service
import ../../../../app_service/service/visual_identity/service as procs_from_visual_identity_service
import ../../../../app_service/service/shared_urls/service as shared_urls_service
import ../../../../app_service/common/types

import ../../../core/signals/types
import ../../../core/eventemitter
import ../../../core/unique_event_emitter

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    sectionId: string
    isCommunitySection: bool
    activeItemId: string
    isCurrentSectionActive: bool
    allChannelsPermissionCheckOngoing: bool
    events: UniqueUUIDEventEmitter
    settingsService: settings_service.Service
    nodeConfigurationService: node_configuration_service.Service
    contactService: contact_service.Service
    chatService: chat_service.Service
    communityService: community_service.Service
    messageService: message_service.Service
    mailserversService: mailservers_service.Service
    walletAccountService: wallet_account_service.Service
    tokenService: token_service.Service
    communityTokensService: community_tokens_service.Service
    sharedUrlsService: shared_urls_service.Service
    networkService: network_service.Service

# Forward declarations
proc getMyCommunity*(self: Controller): CommunityDto

proc newController*(delegate: io_interface.AccessInterface, sectionId: string, isCommunity: bool, events: EventEmitter,
    settingsService: settings_service.Service, nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service, chatService: chat_service.Service,
    communityService: community_service.Service, messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    walletAccountService: wallet_account_service.Service, tokenService: token_service.Service,
    communityTokensService: community_tokens_service.Service,
    sharedUrlsService: shared_urls_service.Service, networkService: network_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.sectionId = sectionId
  result.isCommunitySection = isCommunity
  result.isCurrentSectionActive = false
  result.events = initUniqueUUIDEventEmitter(events)
  result.settingsService = settingsService
  result.nodeConfigurationService = nodeConfigurationService
  result.contactService = contactService
  result.chatService = chatService
  result.communityService = communityService
  result.messageService = messageService
  result.mailserversService = mailserversService
  result.walletAccountService = walletAccountService
  result.tokenService = tokenService
  result.communityTokensService = communityTokensService
  result.sharedUrlsService = sharedUrlsService
  result.networkService = networkService

proc delete*(self: Controller) =
  self.events.disconnect()

proc getActiveChatId*(self: Controller): string =
  return self.activeItemId

proc getIsCurrentSectionActive*(self: Controller): bool =
  return self.isCurrentSectionActive

proc setIsCurrentSectionActive*(self: Controller, active: bool) =
  self.isCurrentSectionActive = active

proc getMySectionId*(self: Controller): string =
  return self.sectionId

proc asyncCheckPermissionsToJoin*(self: Controller) =
  if self.delegate.getPermissionsToJoinCheckOngoing():
    return
  self.communityService.asyncCheckPermissionsToJoin(self.getMySectionId(), addresses = @[])
  self.delegate.setPermissionsToJoinCheckOngoing(true)

proc asyncCheckChannelPermissions*(self: Controller, communityId: string, chatId: string) =
  self.chatService.asyncCheckChannelPermissions(communityId, chatId)

proc init*(self: Controller) =
  self.events.on(SIGNAL_SENDING_SUCCESS) do(e:Args):
    let args = MessageSendingSuccess(e)
    self.delegate.updateLastMessage(args.chat.id, args.chat.timestamp.int, args.chat.lastMessage)

  self.events.on(SIGNAL_NEW_MESSAGE_RECEIVED) do(e: Args):
    let args = MessagesArgs(e)
    if (self.sectionId != args.sectionId or args.messages.len == 0):
      return
    self.delegate.onNewMessagesReceived(args.sectionId, args.chatId, args.chatType, args.lastMessageTimestamp,
      args.unviewedMessagesCount, args.unviewedMentionsCount, args.messages[0])

  self.events.on(chat_service.SIGNAL_CHAT_MUTED) do(e:Args):
    let args = chat_service.ChatArgs(e)
    self.delegate.changeMutedOnChat(args.chatId, true)

  self.events.on(chat_service.SIGNAL_CHAT_UNMUTED) do(e:Args):
    let args = chat_service.ChatArgs(e)
    self.delegate.changeMutedOnChat(args.chatId, false)

  self.events.on(message_service.SIGNAL_MESSAGES_MARKED_AS_READ) do(e: Args):
    let args = message_service.MessagesMarkedAsReadArgs(e)
    # update chat entity in chat service
    let chat = self.chatService.getChatById(args.chatId)
    if ((self.isCommunitySection and chat.communityId != self.sectionId) or
        (not self.isCommunitySection and chat.communityId != "")):
      return
    self.chatService.updateUnreadMessagesAndMentions(args.chatId, args.allMessagesMarked, args.messagesCount, args.messagesWithMentionsCount)
    self.delegate.onMarkAllMessagesRead(chat)

  self.events.on(message_service.SIGNAL_MESSAGE_MARKED_AS_UNREAD) do(e:Args):
    let args = message_service.MessageMarkMessageAsUnreadArgs(e)
    let chat = self.chatService.getChatById(args.chatId)
    if ((self.isCommunitySection and chat.communityId != self.sectionId) or
        (not self.isCommunitySection and chat.communityId != "")):
      return
    self.delegate.onMarkMessageAsUnread(chat)

  self.events.on(chat_service.SIGNAL_CHAT_LEFT) do(e: Args):
    let args = chat_service.ChatArgs(e)
    self.delegate.onCommunityChannelDeletedOrChatLeft(args.chatId)

  self.events.on(SIGNAL_CONTACT_ADDED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactAdded(args.contactId, args.fromBackup)

  self.events.on(SIGNAL_CONTACT_REMOVED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactRejected(args.contactId)

  self.events.on(SIGNAL_CONTACT_BLOCKED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactBlocked(args.contactId)

  self.events.on(SIGNAL_CONTACT_UNBLOCKED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactUnblocked(args.contactId)

  self.events.on(SIGNAL_CHAT_UPDATE) do(e: Args):
    var args = ChatUpdateArgs(e)
    for chat in args.chats:
      let belongsToCommunity = chat.communityId.len > 0
      var community = CommunityDto()
      if belongsToCommunity:
        community = self.getMyCommunity()
      discard self.delegate.addOrUpdateChat(chat, community, belongsToCommunity, self.events, self.settingsService, self.nodeConfigurationService,
        self.contactService, self.chatService, self.communityService, self.messageService,
        self.mailserversService, self.sharedUrlsService, setChatAsActive = false)

  self.events.on(SIGNAL_CHAT_CREATED) do(e: Args):
    var args = CreatedChatArgs(e)
    let belongsToCommunity = args.chat.communityId.len > 0
    var community = CommunityDto()
    if belongsToCommunity:
      community = self.getMyCommunity()
    discard self.delegate.addOrUpdateChat(args.chat, community, belongsToCommunity, self.events, self.settingsService, self.nodeConfigurationService,
      self.contactService, self.chatService, self.communityService, self.messageService,
      self.mailserversService, self.sharedUrlsService, setChatAsActive = true)

  if (self.isCommunitySection):
    self.events.on(SIGNAL_COMMUNITY_CHANNEL_CREATED) do(e:Args):
      let args = CommunityChatArgs(e)
      let belongsToCommunity = args.chat.communityId.len > 0
      var community = CommunityDto()
      if belongsToCommunity:
        community = self.getMyCommunity()
      discard self.delegate.addOrUpdateChat(args.chat, community, belongsToCommunity, self.events, self.settingsService,
        self.nodeConfigurationService, self.contactService, self.chatService, self.communityService,
        self.messageService, self.mailserversService, self.sharedUrlsService, setChatAsActive = true)

    self.events.on(SIGNAL_COMMUNITY_METRICS_UPDATED) do(e: Args):
      let args = CommunityMetricsArgs(e)
      if args.communityId == self.sectionId:
        let metrics = self.communityService.getCommunityMetrics(args.communityId, args.metricsType)
        self.delegate.setCommunityMetrics(metrics)

    self.events.on(SIGNAL_COMMUNITY_CHANNEL_DELETED) do(e:Args):
      let args = CommunityChatIdArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityChannelDeletedOrChatLeft(args.chatId)

    self.events.on(SIGNAL_COMMUNITY_CHANNEL_EDITED) do(e:Args):
      let args = CommunityChatArgs(e)
      if (args.chat.communityId == self.sectionId):
        self.delegate.onCommunityChannelEdited(args.chat)

    self.events.on(SIGNAL_COMMUNITY_CATEGORY_CREATED) do(e:Args):
      let args = CommunityCategoryArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityCategoryCreated(args.category, args.chats, args.communityId)

    self.events.on(SIGNAL_COMMUNITY_CATEGORY_DELETED) do(e:Args):
      let args = CommunityCategoryArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityCategoryDeleted(args.category, args.chats)

    self.events.on(SIGNAL_COMMUNITY_CATEGORY_EDITED) do(e:Args):
      let args = CommunityCategoryArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityCategoryEdited(args.category, args.chats)

    self.events.on(SIGNAL_COMMUNITY_CATEGORY_REORDERED) do(e:Args):
      let args = CommunityCategoryOrderArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onReorderCategory(args.categoryId, args.position)

    self.events.on(SIGNAL_COMMUNITY_CATEGORY_NAME_EDITED) do(e:Args):
      let args = CommunityCategoryArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCategoryNameChanged(args.category)

    self.events.on(SIGNAL_COMMUNITY_CHANNEL_REORDERED) do(e:Args):
      let args = CommunityChatOrderArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onReorderChat(args.chat)

    self.events.on(SIGNAL_COMMUNITY_CHANNELS_REORDERED) do(e:Args):
      let args = CommunityChatsOrderArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onReorderChats(args.chats)

    self.events.on(SIGNAL_COMMUNITY_CHANNEL_CATEGORY_CHANGED) do(e:Args):
      let args = CommunityChatOrderArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onReorderChat(args.chat)

    self.events.on(SIGNAL_RELOAD_MESSAGES) do(e: Args):
      let args = ReloadMessagesArgs(e)
      if (args.communityId == self.sectionId):
        self.messageService.asyncLoadInitialMessagesForChat(self.getActiveChatId())

    self.events.on(SIGNAL_CATEGORY_MUTED) do(e: Args):
      let args = CategoryArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCategoryMuted(args.categoryId)

    self.events.on(SIGNAL_CATEGORY_UNMUTED) do(e: Args):
      let args = CategoryArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCategoryUnmuted(args.categoryId)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATION_OR_UPDATE_SUCCEEDED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionCreationOrUpdateSucceeded(args.communityId)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATION_FAILED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionCreationFailed(args.communityId)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATE_FAILED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionUpdateFailed(args.communityId)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionCreated(args.communityId, args.tokenPermission)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionUpdated(args.communityId, args.tokenPermission)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_DELETED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionDeleted(args.communityId, args.tokenPermission)

    self.events.on(SIGNAL_COMMUNITY_TOKEN_PERMISSION_DELETION_FAILED) do(e: Args):
      let args = CommunityTokenPermissionArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityTokenPermissionDeletionFailed(args.communityId)

    self.events.on(SIGNAL_CHECK_PERMISSIONS_TO_JOIN_RESPONSE) do(e: Args):
      let args = CheckPermissionsToJoinResponseArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onCommunityCheckPermissionsToJoinResponse(args.checkPermissionsToJoinResponse)

    self.events.on(SIGNAL_CHECK_PERMISSIONS_TO_JOIN_FAILED) do(e: Args):
      let args = CheckPermissionsToJoinFailedArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.setPermissionsToJoinCheckOngoing(false)

    self.events.on(SIGNAL_CHECK_CHANNEL_PERMISSIONS_RESPONSE) do(e: Args):
      let args = CheckChannelPermissionsResponseArgs(e)
      if args.communityId == self.sectionId:
        self.delegate.onCommunityCheckChannelPermissionsResponse(args.chatId, args.checkChannelPermissionsResponse)

    self.events.on(SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_FAILED) do(e: Args):
      let args = CheckChannelsPermissionsErrorArgs(e)
      if args.communityId == self.sectionId:
        self.allChannelsPermissionCheckOngoing = false
        self.delegate.setPermissionsToJoinCheckOngoing(false)

    self.events.on(SIGNAL_WAITING_ON_NEW_COMMUNITY_OWNER_TO_CONFIRM_REQUEST_TO_REJOIN) do(e: Args):
      let args = CommunityIdArgs(e)
      if args.communityId == self.sectionId:
        self.delegate.onWaitingOnNewCommunityOwnerToConfirmRequestToRejoin()

    self.events.on(SIGNAL_COMMUNITY_KICKED) do (e: Args):
      let args = CommunityArgs(e)
      if (args.community.id == self.sectionId):
        self.delegate.onKickedFromCommunity()

    self.events.on(SIGNAL_COMMUNITY_JOINED) do (e: Args):
      let args = CommunityArgs(e)
      if (args.community.id == self.sectionId):
        self.delegate.onJoinedCommunity()

    self.events.on(SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED_NO_PERMISSION) do(e: Args):
      var args = CommunityMemberArgs(e)
      if (args.communityId == self.sectionId):
        self.delegate.onAcceptRequestToJoinFailedNoPermission(args.communityId, args.pubKey, args.requestId)

    self.events.on(SIGNAL_MEMBER_REEVALUATION_STATUS) do(e: Args):
      let args = CommunityMemberReevaluationStatusArg(e)
      if args.communityId == self.sectionId:
        self.delegate.communityMemberReevaluationStatusUpdated(args.status)

    self.events.on(SIGNAL_COMMUNITY_MUTED) do(e: Args):
      let args = CommunityMutedArgs(e)
      if args.communityId == self.sectionId:
        self.delegate.onSectionMutedChanged()

    self.events.on(SIGNAL_COMMUNITY_MEMBERS_CHANGED) do(e: Args):
      let args = CommunityMembersArgs(e)
      if args.communityId == self.sectionId:
        self.delegate.updateCommunityMemberList(args.members)

    self.events.on(SIGNAL_COMMUNITY_MY_REQUEST_ADDED) do(e:Args):
      let args = CommunityRequestArgs(e)
      if args.communityRequest.communityId == self.sectionId:
        self.delegate.updateRequestToJoinState(RequestToJoinState.Requested)

    self.events.on(SIGNAL_REQUEST_TO_JOIN_COMMUNITY_CANCELED) do(e:Args):
      let args = community_service.CanceledCommunityRequestArgs(e)
      if args.communityId == self.sectionId:
        self.delegate.updateRequestToJoinState(RequestToJoinState.None)

    self.events.on(SIGNAL_COMMUNITY_MEMBER_ALL_MESSAGES) do(e:Args):
      var args = CommunityMemberMessagesArgs(e)
      if args.communityId == self.sectionId:
        self.delegate.onCommunityMemberMessagesLoaded(args.messages)

  self.events.on(SIGNAL_CONTACT_NICKNAME_CHANGED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.onContactDetailsUpdated(args.contactId)

  self.events.on(SIGNAL_CONTACT_UPDATED) do(e: Args):
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

  self.events.on(SIGNAL_CHAT_RENAMED) do(e: Args):
    var args = ChatRenameArgs(e)
    self.delegate.onChatRenamed(args.id, args.newName)

  self.events.on(SIGNAL_GROUP_CHAT_DETAILS_UPDATED) do(e: Args):
    var args = ChatUpdateDetailsArgs(e)
    self.delegate.onGroupChatDetailsUpdated(args.id, args.newName, args.newColor, args.newImage)

  if (not self.isCommunitySection):
    self.events.on(SIGNAL_CHAT_SWITCH_TO_OR_CREATE_1_1_CHAT) do(e:Args):
      let args = ChatExtArgs(e)
      self.delegate.createOneToOneChat(args.communityId, args.chatId, args.ensName)

  self.events.on(SIGNAL_CONTACTS_STATUS_UPDATED) do(e: Args):
    let args = ContactsStatusUpdatedArgs(e)
    self.delegate.contactsStatusUpdated(args.statusUpdates)

  self.events.on(SIGNAL_MAILSERVER_HISTORY_REQUEST_STARTED) do(e: Args):
    self.delegate.setLoadingHistoryMessagesInProgress(true)

  self.events.on(SIGNAL_MAILSERVER_HISTORY_REQUEST_COMPLETED) do(e:Args):
    self.delegate.setLoadingHistoryMessagesInProgress(false)

  self.events.on(SIGNAL_MESSAGES_DELETED) do(e:Args):
    var args = MessagesDeletedArgs(e)
    let isSectionEmpty = args.communityId == ""
    if args.communityId == self.sectionId or isSectionEmpty:
      for chatId, messagesIds in args.deletedMessages:
        if isSectionEmpty and not self.delegate.communityContainsChat(chatId):
          continue
        self.delegate.onCommunityMemberMessagesDeleted(messagesIds)

proc isCommunity*(self: Controller): bool =
  return self.isCommunitySection

proc getMyCommunity*(self: Controller): CommunityDto =
  return self.communityService.getCommunityById(self.sectionId)

proc getCategories*(self: Controller, communityId: string): seq[Category] =
  return self.communityService.getCategories(communityId)

proc getChats*(self: Controller, communityId: string, categoryId: string): seq[ChatDto] =
  return self.communityService.getChats(communityId, categoryId)

proc getAllChats*(self: Controller, communityId: string): seq[ChatDto] =
  return self.communityService.getAllChats(communityId)

proc getChatsAndBuildUI*(self: Controller) =
  var chats: seq[ChatDto]
  var community: CommunityDto
  if self.isCommunity():
    community = self.getMyCommunity()
    let normalChats = self.chatService.getChatsForCommunity(community.id)

    # TODO remove this once we do this refactor https://github.com/status-im/status-app/issues/11694
    var fullChats: seq[ChatDto] = @[]
    for communityChat in community.chats:
      for chat in normalChats:
        if chat.id == communityChat.id:
          var c = chat
          c.updateMissingFields(communityChat)
          fullChats.add(c)
          break
    chats = fullChats
  else:
    community = CommunityDto()
    chats = self.chatService.getChatsForPersonalSection()

  # Build chat section with the preloaded community (empty community for personal chat)
  self.delegate.onChatsLoaded(
        community,
        chats,
        self.events,
        self.settingsService,
        self.nodeConfigurationService,
        self.contactService,
        self.chatService,
        self.communityService,
        self.messageService,
        self.mailserversService,
        self.sharedUrlsService,
      )

proc sectionUnreadMessagesAndMentionsCount*(self: Controller, communityId: string, sectionIsMuted: bool):
    tuple[unviewedMessagesCount: int, unviewedMentionsCount: int] =
  return self.chatService.sectionUnreadMessagesAndMentionsCount(communityId, sectionIsMuted)

proc getChatDetails*(self: Controller, chatId: string): ChatDto =
  return self.chatService.getChatById(chatId)

proc getChatDetailsForChatTypes*(self: Controller, types: seq[ChatType]): seq[ChatDto] =
  return self.chatService.getChatsOfChatTypes(types)

proc getChatDetailsByIds*(self: Controller, chatIds: seq[string]): seq[ChatDto] =
  return self.chatService.getChatsByIds(chatIds)

proc categoryHasUnreadMessages*(self: Controller, communityId: string, categoryId: string): bool =
  return self.communityService.categoryHasUnreadMessages(communityId, categoryId)

proc getCommunityCategoryDetails*(self: Controller, communityId: string, categoryId: string): Category =
  return self.communityService.getCategoryById(communityId, categoryId)

proc setActiveItem*(self: Controller, itemId: string) =
  self.activeItemId = itemId
  let isSectionActive = self.getIsCurrentSectionActive()
  if not isSectionActive:
    return
  if self.activeItemId != "":
    self.messageService.asyncLoadInitialMessagesForChat(self.activeItemId)

  # We need to take other actions here like notify status go that unviewed mentions count is updated and so...
  self.delegate.activeItemSet(self.activeItemId)

proc removeCommunityChat*(self: Controller, itemId: string) =
  self.communityService.deleteCommunityChat(self.getMySectionId(), itemId)

proc getOneToOneChatNameAndImage*(self: Controller, chatId: string):
    tuple[name: string, image: string, largeImage: string] =
  return self.chatService.getOneToOneChatNameAndImage(chatId)

proc createOneToOneChat*(self: Controller, communityID: string, chatId: string, ensName: string) =
  let response = self.chatService.createOneToOneChat(communityID, chatId, ensName)
  if response.success:
    discard self.delegate.addOrUpdateChat(response.chatDto, CommunityDto(), false, self.events, self.settingsService, self.nodeConfigurationService,
      self.contactService, self.chatService, self.communityService, self.messageService,
      self.mailserversService, self.sharedUrlsService)

proc switchToOrCreateOneToOneChat*(self: Controller, chatId: string, ensName: string) =
  self.chatService.switchToOrCreateOneToOneChat(chatId, ensName)

proc leaveChat*(self: Controller, chatId: string) =
  self.chatService.leaveChat(chatId)

proc muteChat*(self: Controller, chatId: string, interval: int) =
  self.chatService.muteChat(chatId, interval)

proc unmuteChat*(self: Controller, chatId: string) =
  self.chatService.unmuteChat(chatId)

proc markAllMessagesRead*(self: Controller, chatId: string) =
  self.messageService.markAllMessagesRead(chatId)

proc requestMoreMessages*(self: Controller, chatId: string) =
  self.mailserversService.requestMoreMessages(chatId)

proc clearChatHistory*(self: Controller, chatId: string) =
  self.chatService.clearChatHistory(chatId)

proc getContacts*(self: Controller, group: ContactsGroup): seq[ContactsDto] =
  return self.contactService.getContactsByGroup(group)

proc getContactById*(self: Controller, id: string): ContactsDto =
  return self.contactService.getContactById(id)

proc getContactDetails*(self: Controller, id: string): ContactDetails =
  return self.contactService.getContactDetails(id)

proc getStatusForContactWithId*(self: Controller, publicKey: string): StatusUpdateDto =
  return self.contactService.getStatusForContactWithId(publicKey)

proc acceptContactRequest*(self: Controller, publicKey: string, contactRequestId: string) =
  self.contactService.acceptContactRequest(publicKey, contactRequestId)

proc dismissContactRequest*(self: Controller, publicKey: string, contactRequestId: string) =
  self.contactService.dismissContactRequest(publicKey, contactRequestId)

proc blockContact*(self: Controller, publicKey: string) =
  self.contactService.blockContact(publicKey)

proc addGroupMembers*(self: Controller, chatId: string, pubKeys: seq[string]) =
  let communityId = if self.isCommunitySection: self.sectionId else: ""
  self.chatService.addGroupMembers(communityId, chatId, pubKeys)

proc removeMemberFromGroupChat*(self: Controller, communityID: string, chatId: string, pubKey: string) =
   self.chatService.removeMemberFromGroupChat(communityID, chatId, pubKey)

proc removeMembersFromGroupChat*(self: Controller, communityID: string, chatId: string, pubKeys: seq[string]) =
   self.chatService.removeMembersFromGroupChat(communityID, chatId, pubKeys)

proc renameGroupChat*(self: Controller, chatId: string, newName: string) =
  let communityId = if self.isCommunitySection: self.sectionId else: ""
  self.chatService.renameGroupChat(communityId, chatId, newName)

proc updateGroupChatDetails*(self: Controller, chatId: string, newGroupName: string, newGroupColor: string, newGroupImageJson: string) =
  let communityId = if self.isCommunitySection: self.sectionId else: ""
  self.chatService.updateGroupChatDetails(communityId, chatId, newGroupName, newGroupColor, newGroupImageJson)

proc makeAdmin*(self: Controller, communityID: string, chatId: string, pubKey: string) =
  self.chatService.makeAdmin(communityID, chatId, pubKey)

proc createGroupChat*(self: Controller, communityID: string, groupName: string, pubKeys: seq[string]) =
  let response = self.chatService.createGroupChat(communityID, groupName, pubKeys)
  if response.success:
    discard self.delegate.addOrUpdateChat(response.chatDto, CommunityDto(), false, self.events, self.settingsService, self.nodeConfigurationService,
      self.contactService, self.chatService, self.communityService, self.messageService,
      self.mailserversService, self.sharedUrlsService)

proc acceptRequestToJoinCommunity*(self: Controller, requestId: string, communityId: string) =
  self.communityService.asyncAcceptRequestToJoinCommunity(communityId, requestId)

proc declineRequestToJoinCommunity*(self: Controller, requestId: string, communityId: string) =
  self.communityService.declineRequestToJoinCommunity(communityId, requestId)

proc createCommunityChannel*(
    self: Controller,
    name: string,
    description: string,
    emoji: string,
    color: string,
    categoryId: string,
    viewersCanPostReactions: bool,
    hideIfPermissionsNotMet: bool,
    ) =
  self.communityService.createCommunityChannel(self.sectionId, name, description, emoji, color,
    categoryId, viewersCanPostReactions, hideIfPermissionsNotMet)

proc editCommunityChannel*(
    self: Controller,
    channelId: string,
    name: string,
    description: string,
    emoji: string,
    color: string,
    categoryId: string,
    position: int,
    viewersCanPostReactions: bool,
    hideIfPermissionsNotMet: bool,
    ) =
  self.communityService.editCommunityChannel(
    self.sectionId,
    channelId,
    name,
    description,
    emoji,
    color,
    categoryId,
    position,
    viewersCanPostReactions,
    hideIfPermissionsNotMet)

proc createCommunityCategory*(self: Controller, name: string, channels: seq[string]) =
  self.communityService.createCommunityCategory(self.sectionId, name, channels)

proc editCommunityCategory*(self: Controller, categoryId: string, name: string, channels: seq[string]) =
  self.communityService.editCommunityCategory(self.sectionId, categoryId, name, channels)

proc deleteCommunityCategory*(self: Controller, categoryId: string) =
  self.communityService.deleteCommunityCategory(self.sectionId, categoryId)

proc leaveCommunity*(self: Controller) =
  self.communityService.leaveCommunity(self.sectionId)

proc removeUserFromCommunity*(self: Controller, pubKey: string) =
  self.communityService.asyncRemoveUserFromCommunity(self.sectionId, pubKey)

proc banUserFromCommunity*(self: Controller, pubKey: string, deleteAllMessages: bool) =
  self.communityService.asyncBanUserFromCommunity(self.sectionId, pubKey, deleteAllMessages)

proc unbanUserFromCommunity*(self: Controller, pubKey: string) =
  self.communityService.asyncUnbanUserFromCommunity(self.sectionId, pubKey)

proc editCommunity*(
    self: Controller,
    name: string,
    description: string,
    introMessage: string,
    outroMessage: string,
    access: int,
    color: string,
    tags: string,
    logoJsonStr: string,
    bannerJsonStr: string,
    historyArchiveSupportEnabled: bool,
    pinMessageAllMembersEnabled: bool) =
  self.communityService.editCommunity(
    self.sectionId,
    name,
    description,
    introMessage,
    outroMessage,
    access,
    color,
    tags,
    logoJsonStr,
    bannerJsonStr,
    historyArchiveSupportEnabled,
    pinMessageAllMembersEnabled)

proc exportCommunity*(self: Controller): string =
  self.communityService.exportCommunity(self.sectionId)

proc muteCategory*(self: Controller, categoryId: string, interval: int) =
  self.communityService.muteCategory(self.sectionId, categoryId, interval)

proc unmuteCategory*(self: Controller, categoryId: string) =
  self.communityService.unmuteCategory(self.sectionId, categoryId)

proc setCommunityMuted*(self: Controller, mutedType: int) =
  self.communityService.setCommunityMuted(self.sectionId, mutedType)

proc shareCommunityToUsers*(self: Controller, pubKeys: string, inviteMessage: string): string =
  result = self.communityService.shareCommunityToUsers(self.sectionId, pubKeys, inviteMessage)

proc reorderCommunityCategories*(self: Controller, categoryId: string, position: int) =
  self.communityService.reorderCommunityCategories(self.sectionId, categoryId, position)

proc toggleCollapsedCommunityCategoryAsync*(self: Controller, categoryId: string, collapsed: bool) =
  self.communityService.toggleCollapsedCommunityCategoryAsync(self.sectionId, categoryId, collapsed)

proc reorderCommunityChat*(self: Controller, categoryId: string, chatId: string, position: int) =
  self.communityService.reorderCommunityChat(self.sectionId, categoryId, chatId, position)

proc getRenderedText*(self: Controller, parsedTextArray: seq[ParsedText], communityChats: seq[ChatDto]): string =
  return self.messageService.getRenderedText(parsedTextArray, communityChats)

proc getMessagesParsedPlainText*(self: Controller, message: MessageDto, communityChats: seq[ChatDto]): string =
  return self.messageService.getMessagesParsedPlainText(message, communityChats)

proc getColorId*(self: Controller, pubkey: string): int =
  procs_from_visual_identity_service.colorIdOf(pubkey)

proc getTokenByKey*(self: Controller, tokenKey: string): TokenItem =
  return self.tokenService.getTokenByKey(tokenKey)

proc getTokensByGroupKey*(self: Controller, groupKey: string): seq[TokenItem] =
  return self.tokenService.getTokensByGroupKey(groupKey)

proc getTokenByKeyOrGroupKeyFromAllTokens*(self: Controller, key: string): TokenItem =
  return self.tokenService.getTokenByKeyOrGroupKeyFromAllTokens(key)

proc createOrEditCommunityTokenPermission*(self: Controller, tokenPermission: CommunityTokenPermissionDto) =
  self.communityService.createOrEditCommunityTokenPermission(self.sectionId, tokenPermission)

proc deleteCommunityTokenPermission*(self: Controller, permissionId: string) =
  self.communityService.deleteCommunityTokenPermission(self.sectionId, permissionId)

proc getCommunityTokenList*(self: Controller): seq[CommunityTokenDto] =
  return self.communityTokensService.getCommunityTokens(self.getMySectionId())

proc collectCommunityMetricsMessagesTimestamps*(self: Controller, intervals: string) =
  self.communityService.collectCommunityMetricsMessagesTimestamps(self.getMySectionId(), intervals)

proc collectCommunityMetricsMessagesCount*(self: Controller, intervals: string) =
  self.communityService.collectCommunityMetricsMessagesCount(self.getMySectionId(), intervals)

proc waitingOnNewCommunityOwnerToConfirmRequestToRejoin*(self: Controller, communityId: string): bool =
  self.communityService.waitingOnNewCommunityOwnerToConfirmRequestToRejoin(communityId)

proc loadCommunityMemberMessages*(self: Controller, communityId: string, memberPubKey: string) =
  self.messageService.asyncLoadCommunityMemberAllMessages(communityId, memberPubKey)

proc getTransactionDetails*(self: Controller, message: MessageDto): (string,string) =
  return self.messageService.getTransactionDetails(message)

proc getWalletAccounts*(self: Controller): seq[wallet_account_service.WalletAccountDto] =
  return self.messageService.getWalletAccounts()

proc deleteCommunityMemberMessages*(self: Controller, memberPubKey: string, messageId: string, chatId: string) =
  self.messageService.deleteCommunityMemberMessages(self.getMySectionId(), memberPubKey, messageId, chatId)

proc isMyCommunityRequestPending*(self: Controller): bool =
  return self.communityService.isMyCommunityRequestPending(self.sectionId)

proc markAllReadInCommunity*(self: Controller) =
  self.communityService.markAllReadInCommunity(self.sectionId)
