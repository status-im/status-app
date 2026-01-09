import nimqml, tables, chronicles, json, sequtils, std/strformat, sugar, marshal

import io_interface
import ../io_interface as delegate_interface
import view, controller, active_item
import model as chats_model
import item as chat_item

import app/modules/shared_models/message_item as member_msg_item
import app/modules/shared_models/message_model as member_msg_model
import app/modules/shared_models/user_item as user_item
import app/modules/shared_models/user_model as user_model
import app/modules/shared_models/[token_permissions_model, token_permission_item, token_criteria_item, token_criteria_model, token_permission_chat_list_model, contacts_utils]

import chat_content/module as chat_content_module
import chat_content/users/module as users_module

import app/global/global_singleton
import app/core/eventemitter
import app/core/unique_event_emitter
import app/core/notifications/details as notification_details
import app_service/common/types
import app_service/common/utils as service_common_utils
import app_service/service/settings/service as settings_service
import app_service/service/node_configuration/service as node_configuration_service
import app_service/service/contacts/service as contact_service
import app_service/service/chat/service as chat_service
import app_service/service/network/service as network_service
import app_service/service/community/service as community_service
import app_service/service/message/service as message_service
import app_service/service/mailservers/service as mailservers_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/token/service as token_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/shared_urls/service as shared_urls_service
import app_service/service/contacts/dto/contacts as contacts_dto
import app/core/signals/types
import backend/collectibles_types

export io_interface

logScope:
  topics = "chat-section-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    chatContentModules: OrderedTable[string, chat_content_module.AccessInterface]
    moduleLoaded: bool
    chatsLoaded: bool
    membersListModule: users_module.AccessInterface

# Forward declaration
proc buildChatSectionUI(
  self: Module,
  community: CommunityDto,
  chats: seq[ChatDto],
  events: UniqueUUIDEventEmitter,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  contactService: contact_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  mailserversService: mailservers_service.Service,
  sharedUrlsService: shared_urls_service.Service,
)
proc reevaluateRequiresTokenPermissionToJoin(self: Module)
proc changeCanPostValues*(self: Module, chatId: string, canPost, canView, canPostReactions, viewersCanPostReactions: bool)
method onCommunityCheckPermissionsToJoinResponse*(self: Module, checkPermissionsToJoinResponse: CheckPermissionsToJoinResponseDto)
method onCommunityCheckChannelPermissionsResponse*(self: Module, chatId: string, checkChannelPermissionsResponse: CheckChannelPermissionsResponseDto)
method onCommunityCheckAllChannelsPermissionsResponse*(self: Module, checkAllChannelsPermissionsResponse: CheckAllChannelsPermissionsResponseDto)
method addOrUpdateChat(self: Module,
    chat: ChatDto,
    community: CommunityDto,
    belongsToCommunity: bool,
    events: UniqueUUIDEventEmitter,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    sharedUrlsService: shared_urls_service.Service,
    setChatAsActive: bool = true,
    insertIntoModel: bool = true,
    isSectionBuild: bool = false,
  ): ChatItem
proc updateParentBadgeNotifications(self: Module)

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    sectionId: string,
    isCommunity: bool,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    walletAccountService: wallet_account_service.Service,
    tokenService: token_service.Service,
    communityTokensService: community_tokens_service.Service,
    sharedUrlsService: shared_urls_service.Service,
    networkService: network_service.Service,
  ): Module =
  result = Module()
  result.delegate = delegate
  result.controller = controller.newController(result, sectionId, isCommunity, events, settingsService,
    nodeConfigurationService, contactService, chatService, communityService, messageService,
    mailserversService, walletAccountService, tokenService, communityTokensService, sharedUrlsService, networkService)
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.moduleLoaded = false
  result.chatsLoaded = false

  result.chatContentModules = initOrderedTable[string, chat_content_module.AccessInterface]()
  if isCommunity:
    result.membersListModule = users_module.newModule(events, sectionId, chatId = "", isCommunity,
      isUsersListAvailable = true, contactService, chatService, communityService, messageService, isSectionMemberList = true)
  else:
    result.membersListModule = nil

proc currentUserWalletContainsAddress(self: Module, address: string): bool =
  if (address.len == 0):
    return false
  let accounts = self.controller.getWalletAccounts()
  for acc in accounts:
    if (acc.address == address):
      return true
  return false

# TODO: duplicates in chats and messages
proc buildCommunityMemberMessageItem(self: Module, message: MessageDto): member_msg_item.Item =
  let contactDetails = self.controller.getContactDetails(message.`from`)
  let communityChats = self.controller.getAllChats(self.getMySectionId())
  var quotedMessageAuthorDetails = ContactDetails()
  if message.quotedMessage.`from` != "":
    if message.`from` == message.quotedMessage.`from`:
      quotedMessageAuthorDetails = contactDetails
    else:
      quotedMessageAuthorDetails = self.controller.getContactDetails(message.quotedMessage.`from`)

  var transactionContract = message.transactionParameters.contract
  var transactionValue = message.transactionParameters.value
  var isCurrentUser = contactDetails.isCurrentUser
  if message.contentType == ContentType.Transaction:
    (transactionContract, transactionValue) = self.controller.getTransactionDetails(message)
    if message.transactionParameters.fromAddress != "":
      isCurrentUser = self.currentUserWalletContainsAddress(message.transactionParameters.fromAddress)

  return member_msg_model.createMessageItemFromDtos(
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

method delete*(self: Module) =
  self.controller.delete
  self.view.delete
  self.viewVariant.delete
  for cModule in self.chatContentModules.values:
    cModule.delete
  self.chatContentModules.clear
  if self.membersListModule != nil:
    self.membersListModule.delete

method isCommunity*(self: Module): bool =
  return self.controller.isCommunity()

method getMySectionId*(self: Module): string =
  return self.controller.getMySectionId()

proc getUserMemberRole(self: Module, members: seq[ChatMember]): MemberRole =
  for m in members:
    if m.id == singletonInstance.userProfile.getPubKey():
      return m.role
  return MemberRole.None

proc addSubmodule(
    self: Module,
    chatId: string,
    belongToCommunity: bool,
    isUsersListAvailable: bool,
    events: EventEmitter,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    sharedUrlsService: shared_urls_service.Service,
  ) =
  self.chatContentModules[chatId] = chat_content_module.newModule(self, events, self.controller.getMySectionId(), chatId,
    belongToCommunity, isUsersListAvailable, settingsService, nodeConfigurationService, contactService, chatService, communityService,
    messageService, mailserversService, sharedUrlsService)

proc removeSubmodule(self: Module, chatId: string) =
  if(not self.chatContentModules.contains(chatId)):
    return
  self.chatContentModules.del(chatId)


proc addCategoryItem(self: Module, category: Category, memberRole: MemberRole, communityId: string, insertIntoModel: bool = true): ChatItem =
  let hasUnreadMessages = self.controller.categoryHasUnreadMessages(communityId, category.id)
  result = chat_item.initChatItem(
        id = category.id,
        category.name,
        usesDefaultName = false,
        icon = "",
        color = "",
        emoji = "",
        description = "",
        `type` = chat_item.CATEGORY_TYPE,
        memberRole,
        lastMessageTimestamp = 0,
        lastMessageText = "",
        hasUnreadMessages,
        notificationsCount = 0,
        muted = false,
        blocked = false,
        active = false,
        position = -1, # Set position as -1, so that the Category Item is on top of its Channels
        category.id,
        category.position,
        categoryOpened = not category.collapsed,
        hideIfPermissionsNotMet = false,
        missingEncryptionKey = false,
        permissionsCheckOngoing = false,
      )

  if insertIntoModel:
    self.view.chatsModel().appendItem(result)

proc buildChatSectionUI(
    self: Module,
    community: CommunityDto,
    chats: seq[ChatDto],
    events: UniqueUUIDEventEmitter,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    sharedUrlsService: shared_urls_service.Service,
  ) =
  var selectedItemId = ""
  let sectionLastOpenChat = singletonInstance.localAccountSensitiveSettings.getSectionLastOpenChat(self.controller.getMySectionId())
  var items: seq[ChatItem] = @[]
  for categoryDto in community.categories:
    # Add items for the categories. We use a special type to identify categories
    items.add(self.addCategoryItem(categoryDto, community.memberRole, community.id))

  for chatDto in chats:
    # Add an empty chat item that has the category info
    var isActive = false
    # restore on a startup last open channel for the section or
    # make the first channel which doesn't belong to any category active
    if (selectedItemId.len == 0 and sectionLastOpenChat.len == 0) or chatDto.id == sectionLastOpenChat:
      selectedItemId = chatDto.id
      isActive = true

    items.add(self.addOrUpdateChat(
      chatDto,
      community,
      belongsToCommunity = chatDto.communityId.len > 0,
      events,
      settingsService,
      nodeConfigurationService,
      contactService,
      chatService,
      communityService,
      messageService,
      mailserversService,
      sharedUrlsService,
      setChatAsActive = false,
      insertIntoModel = false,
      isSectionBuild = true,
    ))

  self.view.chatsModel.setData(items)
  self.setActiveItem(selectedItemId)

proc createItemFromPublicKey(self: Module, publicKey: string): UserItem =
  let contactDetails = self.controller.getContactDetails(publicKey)

  return createItemFromDto(
    contactDetails,
    toOnlineStatus(self.controller.getStatusForContactWithId(publicKey).statusType),
    contactRequest = ContactRequestState.None,
  )

proc initContactRequestsModel(self: Module) =
  var contactsWhoAddedMe: seq[UserItem]
  let contacts = self.controller.getContacts(ContactsGroup.IncomingPendingContactRequests)
  for c in contacts:
    let item = self.createItemFromPublicKey(c.id)
    contactsWhoAddedMe.add(item)

  self.view.contactRequestsModel().addItems(contactsWhoAddedMe)

proc rebuildCommunityTokenPermissionsModel(self: Module) =
  let community = self.controller.getMyCommunity()
  var tokenPermissionsItems: seq[TokenPermissionItem] = @[]

  for _, tokenPermission in community.tokenPermissions:
    let chats = community.getCommunityChats(tokenPermission.chatIds)
    let tokenPermissionItem = buildTokenPermissionItem(tokenPermission, chats)
    tokenPermissionsItems.add(tokenPermissionItem)

  self.view.tokenPermissionsModel().setItems(tokenPermissionsItems)
  self.reevaluateRequiresTokenPermissionToJoin()

proc reevaluateRequiresTokenPermissionToJoin(self: Module) =
  let community = self.controller.getMyCommunity()
  var joinPermissionsChanged = false
  for _, tokenPermission in community.tokenPermissions:
    if tokenPermission.`type` == TokenPermissionType.BecomeMember or
        tokenPermission.`type` == TokenPermissionType.BecomeAdmin or
        tokenPermission.`type` == TokenPermissionType.BecomeTokenMaster:
      joinPermissionsChanged = true
      break
  self.view.setRequiresTokenPermissionToJoin(joinPermissionsChanged)

proc initCommunityTokenPermissionsModel(self: Module) =
  self.rebuildCommunityTokenPermissionsModel()

proc convertPubKeysToJson(self: Module, pubKeys: string): seq[string] =
  return map(parseJson(pubKeys).getElems(), proc(x:JsonNode):string = x.getStr)

proc showPermissionUpdateNotification(self: Module, community: CommunityDto, tokenPermission: CommunityTokenPermissionDto): bool =
  return tokenPermission.state == TokenPermissionState.Approved and (community.isControlNode or not tokenPermission.isPrivate) and community.isMember

method load*(self: Module, buildChats: bool = false) =
  self.controller.init()
  if buildChats:
    self.controller.getChatsAndBuildUI()

  self.view.load()

method onChatsLoaded*(
    self: Module,
    community: CommunityDto,
    chats: seq[ChatDto],
    events: UniqueUUIDEventEmitter,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    sharedUrlsService: shared_urls_service.Service,
  ) =
  self.chatsLoaded = true

  self.buildChatSectionUI(community, chats, events, settingsService, nodeConfigurationService,
    contactService, chatService, communityService, messageService, mailserversService, sharedUrlsService)

  # Generate members list
  if self.membersListModule != nil:
    self.membersListModule.load()

  if not self.controller.isCommunity():
    # we do this only in case of chat section (not in case of communities)
    self.initContactRequestsModel()
  else:
    self.view.setAmIMember(community.joined)
    self.view.setWaitingOnNewCommunityOwnerToConfirmRequestToRejoin(self.controller.waitingOnNewCommunityOwnerToConfirmRequestToRejoin(community.id))
    var requestToJoinState = RequestToJoinState.None
    if self.controller.isMyCommunityRequestPending():
      requestToJoinState = RequestToJoinState.Requested

    self.view.setRequestToJoinState(requestToJoinState)
    self.initCommunityTokenPermissionsModel()

  let activeChatId = self.controller.getActiveChatId()
  let isCurrentSectionActive = self.controller.getIsCurrentSectionActive()
  if isCurrentSectionActive:
    for chatId, cModule in self.chatContentModules:
      if chatId == activeChatId:
        cModule.onMadeActive()

  self.view.chatsLoaded()

proc checkIfModuleDidLoad(self: Module) =
  if self.moduleLoaded:
    return

  for cModule in self.chatContentModules.values:
    if(not cModule.isLoaded()):
      return

  self.moduleLoaded = true
  if(self.controller.isCommunity()):
    self.delegate.communitySectionDidLoad()
  else:
    self.delegate.chatSectionDidLoad()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method getSectionMemberList*(self: Module): QVariant =
  return self.membersListModule.getUsersListVariant()

method updateCommunityMemberList*(self: Module, members: seq[ChatMember]) =
  self.membersListModule.updateMembersList(members)

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method chatContentDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method setActiveItem*(self: Module, itemId: string) =
  self.controller.setActiveItem(itemId)

proc updateActiveChatMembership*(self: Module) =
  let activeChatId = self.controller.getActiveChatId()
  let chat = self.controller.getChatDetails(activeChatId)

  if chat.chatType == ChatType.PrivateGroupChat:
    let amIMember = any(chat.members, proc (member: ChatMember): bool = member.id == singletonInstance.userProfile.getPubKey())
    self.view.setAmIMember(amIMember)

method activeItemSet*(self: Module, itemId: string) =
  let mySectionId = self.controller.getMySectionId()
  if itemId == "":
    self.view.activeItem().resetActiveItemData()
    singletonInstance.localAccountSensitiveSettings.removeSectionChatRecord(mySectionId)
    return

  let chat_item = self.view.chatsModel().getItemById(itemId)
  if chat_item.isNil:
    # Should never be here
    error "chat-view unexisting item id: ", itemId, methodName="activeItemSet"
    return

  if not self.chatContentModules[itemId].isLoaded:
    self.chatContentModules[itemId].load(chat_item)

  # update view maintained by this module
  self.view.activeItemSet(chat_item)
  self.view.chatsModel().setActiveItem(itemId)

  self.updateActiveChatMembership()

  let activeChatId = self.controller.getActiveChatId()

  # # update child modules
  for chatId, chatContentModule in self.chatContentModules:
    if chatId == activeChatId:
      chatContentModule.onMadeActive()
    else:
      chatContentModule.onMadeInactive()

  # save last open chat in settings for restore on the next app launch
  singletonInstance.localAccountSensitiveSettings.setSectionLastOpenChat(mySectionId, activeChatId)

  let (deactivateSectionId, deactivateChatId) = singletonInstance.loaderDeactivator.addChatInMemory(mySectionId, activeChatId)

  # notify parent module about active chat/channel
  self.delegate.onActiveChatChange(mySectionId, activeChatId)
  self.delegate.onDeactivateChatLoader(deactivateSectionId, deactivateChatId)

  if self.controller.isCommunity():
    let community = self.controller.getMyCommunity()
    if not community.isPrivilegedUser:
      if not chat_item.missingEncryptionKey and (not chat_item.canView or not chat_item.canPost):
        # User doesn't have full access to this channel. Check permissions to know what is missing
        self.controller.asyncCheckChannelPermissions(mySectionId, activeChatId)

      self.onCommunityCheckChannelPermissionsResponse(activeChatId, CheckChannelPermissionsResponseDto(
        viewOnlyPermissions: ViewOnlyOrViewAndPostPermissionsResponseDto(
          satisfied: chat_item.canView
        ),
        viewAndPostPermissions: ViewOnlyOrViewAndPostPermissionsResponseDto(
          satisfied: chat_item.canPost
        ),
      ))

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method getChatContentModule*(self: Module, chatId: string): QVariant =
  if(not self.chatContentModules.contains(chatId)):
    error "getChatContentModule: unexisting chat key", chatId, methodName="getChatContentModule"
    return

  return self.chatContentModules[chatId].getModuleAsVariant()

proc updateParentBadgeNotifications(self: Module) =
  var sectionIsMuted = false
  if self.controller.isCommunity:
    let myCommunity = self.controller.getMyCommunity()
    sectionIsMuted = myCommunity.muted

  let (unviewedMessagesCount, unviewedMentionsCount) = self.controller.sectionUnreadMessagesAndMentionsCount(
    self.controller.getMySectionId(),
    sectionIsMuted,
  )
  self.delegate.onNotificationsUpdated(
    self.controller.getMySectionId(),
    unviewedMessagesCount > 0,
    unviewedMentionsCount
  )

proc updateChatLocked(self: Module, communityChat: ChatDto) =
  if not self.controller.isCommunity():
    return
  self.view.chatsModel().setItemLocked(communityChat.id, communityChat.tokenGated and not communityChat.canPost)

proc updatePermissionsRequiredOnChat(self: Module, communityChat: ChatDto) =
  if not self.controller.isCommunity():
    return
  self.view.chatsModel().setItemPermissionsRequired(communityChat.id, communityChat.tokenGated)

proc updateBadgeNotifications(self: Module, chat: ChatDto, hasUnreadMessages: bool, unviewedMentionsCount: int) =
  let chatId = chat.id

  if self.chatsLoaded:
    self.view.chatsModel().updateNotificationsForItemById(chatId, hasUnreadMessages, unviewedMentionsCount)

    if self.chatContentModules.contains(chatId):
      self.chatContentModules[chatId].onNotificationsUpdated(hasUnreadMessages, unviewedMentionsCount)

    if self.isCommunity:
      let myCommunity = self.controller.getMyCommunity()
      let communityChat = myCommunity.getCommunityChat(chatId)

      if communityChat.categoryId != "":
        let hasUnreadMessages = self.controller.categoryHasUnreadMessages(communityChat.communityId, communityChat.categoryId)
        self.view.chatsModel().setCategoryHasUnreadMessages(communityChat.categoryId, hasUnreadMessages)

  self.updateParentBadgeNotifications()

method updateLastMessage*(self: Module, chatId: string, lastMessageTimestamp: int, lastMessage: MessageDto) =
  var communityChats: seq[ChatDto] = @[]
  if self.controller.isCommunity():
    let community = self.controller.getMyCommunity()
    communityChats = community.chats
  self.view.chatsModel().updateLastMessageOnItemById(
    chatId,
    self.controller.getMessagesParsedPlainText(lastMessage, communityChats),
    lastMessageTimestamp,
  )

method onActiveSectionChange*(self: Module, sectionId: string) =
  if sectionId != self.controller.getMySectionId():
    self.controller.setIsCurrentSectionActive(false)
    return
  var firstLoad = false
  if not self.view.getChatsLoaded:
    firstLoad = true
    self.controller.getChatsAndBuildUI()

  self.controller.setIsCurrentSectionActive(true)
  let activeChatId = self.controller.getActiveChatId()
  if activeChatId == "":
    self.setFirstChannelAsActive()
  else:
    self.setActiveItem(activeChatId)

  if self.isCommunity():
    let community = self.controller.getMyCommunity()
    if not community.isPrivilegedUser:
      if not community.joined:
        self.controller.asyncCheckPermissionsToJoin()
      else:
        # We do not care about the combinations when we do satisfy
        self.onCommunityCheckPermissionsToJoinResponse(CheckPermissionsToJoinResponseDto(
          satisfied: true
        ))

  self.delegate.onActiveChatChange(self.controller.getMySectionId(), self.controller.getActiveChatId())

method chatsModel*(self: Module): chats_model.Model =
  return self.view.chatsModel()

proc getChatItemFromChatDto(
    self: Module,
    chatDto: ChatDto,
    community: CommunityDto,
    setChatAsActive: bool = true,
    ): ChatItem =

  let hasNotification = chatDto.unviewedMessagesCount > 0
  let notificationsCount = chatDto.unviewedMentionsCount

  var chatName = chatDto.name
  var chatImage = chatDto.icon
  var blocked = false
  var usesDefaultName = false
  var colorId: int = 0
  var onlineStatus = OnlineStatus.Inactive
  var categoryPosition = -1

  if chatDto.chatType == ChatType.OneToOne:
    let contactDetails = self.controller.getContactDetails(chatDto.id)
    chatName = contactDetails.defaultDisplayName
    usesDefaultName = resolveUsesDefaultName(
      contactDetails.dto.localNickname,
      contactDetails.dto.name,
      contactDetails.dto.displayName,
    )
    chatImage = contactDetails.icon
    blocked = contactDetails.dto.isBlocked()
    colorId = self.controller.getColorId(chatDto.id)
    onlineStatus = toOnlineStatus(self.controller.getStatusForContactWithId(chatDto.id).statusType)

  elif chatDto.chatType == ChatType.PrivateGroupChat:
    chatImage = chatDto.icon

  var memberRole = self.getUserMemberRole(chatDto.members)

  if chatDto.chatType != ChatType.PrivateGroupChat:
    memberRole = community.memberRole

  if memberRole == MemberRole.None and len(chatDto.communityId) != 0:
    memberRole = community.memberRole
    if memberRole == MemberRole.None:
      memberRole = community.memberRole

  var categoryOpened = true
  let categories = community.categories

  if chatDto.categoryId != "":
    let categoryIndex = findIndexById(chatDto.categoryId, categories)
    let category = categories[categoryIndex]
    if category.id == "":
      error "No category found for chat", chatName=chatDto.name, categoryId=chatDto.categoryId
    else:
      categoryOpened = not category.collapsed
      categoryPosition = category.position

  var canPost = true
  var canView = true
  var canPostReactions = true
  var hideIfPermissionsNotMet = false
  var viewersCanPostReactions = true
  var missingEncryptionKey = false
  var tokenGated = false
  if self.controller.isCommunity:
    # NOTE: workaround for new community chat, which is delivered in chatDto before the community will know about that
    if community.hasCommunityChat(chatDto.id):
      let communityChat = community.getCommunityChat(chatDto.id)
      # Some properties are only available on CommunityChat (they are useless for normal chats)
      canPost = communityChat.canPost
      canView = communityChat.canView
      canPostReactions = communityChat.canPostReactions
      hideIfPermissionsNotMet = communityChat.hideIfPermissionsNotMet
      viewersCanPostReactions = communityChat.viewersCanPostReactions
      missingEncryptionKey = communityChat.missingEncryptionKey
      tokenGated = communityChat.tokenGated
    else:
      canPost = chatDto.canPost
      canView = chatDto.canView
      canPostReactions = chatDto.canPostReactions
      hideIfPermissionsNotMet = chatDto.hideIfPermissionsNotMet
      viewersCanPostReactions = chatDto.viewersCanPostReactions
      missingEncryptionKey = chatDto.missingEncryptionKey

  result = chat_item.initChatItem(
    chatDto.id,
    chatName,
    usesDefaultName,
    chatImage,
    chatDto.color,
    chatDto.emoji,
    chatDto.description,
    chatDto.chatType.int,
    memberRole,
    chatDto.timestamp.int,
    self.controller.getMessagesParsedPlainText(chatDto.lastMessage, community.chats),
    hasNotification,
    notificationsCount,
    chatDto.muted,
    blocked,
    setChatAsActive,
    chatDto.position,
    chatDto.categoryId,
    categoryPosition,
    colorId,
    chatDto.highlight,
    categoryOpened,
    onlineStatus = onlineStatus,
    loaderActive = setChatAsActive,
    locked = tokenGated and not canPost,
    requiresPermissions = tokenGated,
    canPost = canPost,
    canView = canView,
    canPostReactions = canPostReactions,
    viewersCanPostReactions = viewersCanPostReactions,
    hideIfPermissionsNotMet = hideIfPermissionsNotMet,
    missingEncryptionKey = missingEncryptionKey,
    permissionsCheckOngoing = false,
  )

proc addNewChat(
    self: Module,
    chatItem: ChatItem,
    chatDto: ChatDto,
    belongsToCommunity: bool,
    events: EventEmitter,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    sharedUrlsService: shared_urls_service.Service,
    setChatAsActive: bool = true,
    insertIntoModel: bool = true,
  ) =

  let isUsersListAvailable = chatDto.chatType != ChatType.OneToOne

  self.addSubmodule(
    chatDto.id,
    belongsToCommunity,
    isUsersListAvailable,
    events,
    settingsService,
    nodeConfigurationService,
    contactService,
    chatService,
    communityService,
    messageService,
    mailserversService,
    sharedUrlsService,
  )

  if insertIntoModel:
    self.view.chatsModel().appendItem(chatItem)
  if setChatAsActive:
    self.setActiveItem(chatItem.id)

method switchToChannel*(self: Module, channelName: string) =
  if(not self.controller.isCommunity()):
    return
  let chats = self.controller.getAllChats(self.controller.getMySectionId())
  for c in chats:
    if c.name == channelName:
      self.setActiveItem(c.id)
      return

method doesCatOrChatExist*(self: Module, id: string): bool =
  return self.view.chatsModel().isItemWithIdAdded(id)

method doesTopLevelChatExist*(self: Module, chatId: string): bool =
  return self.view.chatsModel().isItemWithIdAdded(chatId)

method removeCommunityChat*(self: Module, chatId: string) =
  if(not self.chatContentModules.contains(chatId)):
    return
  self.controller.removeCommunityChat(chatId)

method onCommunityCategoryEdited*(self: Module, cat: Category, chats: seq[ChatDto]) =
  # Update category itself
  self.view.chatsModel().updateCategoryDetailsById(
    cat.id,
    cat.name,
    cat.position
  )
  # Update chat items that have that category
  self.view.chatsModel().updateItemsWithCategoryDetailsById(
    chats,
    cat.id,
    cat.position,
  )

method onCommunityCategoryCreated*(self: Module, cat: Category, chats: seq[ChatDto], communityId: string) =
  if (self.doesCatOrChatExist(cat.id)):
    return

  let community = self.controller.getMyCommunity()
  discard self.addCategoryItem(cat, community.memberRole, communityId)
  # Update chat items that now belong to that category
  self.view.chatsModel().updateItemsWithCategoryDetailsById(
    chats,
    cat.id,
    cat.position,
  )

method onCommunityCategoryDeleted*(self: Module, cat: Category, chats: seq[ChatDto]) =
  self.view.chatsModel().removeCategory(cat.id, chats)

method setFirstChannelAsActive*(self: Module) =
  if(self.view.chatsModel().getCount() == 0):
    self.setActiveItem("")
    return

  let chat_items = self.view.chatsModel().items()
  for chat_item in chat_items:
    if chat_item.`type` != CATEGORY_TYPE:
      self.setActiveItem(chat_item.id)
      break

method onReorderChat*(self: Module, updatedChat: ChatDto) =
  self.view.chatsModel().reorderChats(@[updatedChat])

method onReorderChats*(self: Module, updatedChats: seq[ChatDto]) =
  self.view.chatsModel().reorderChats(updatedChats)

method onReorderCategory*(self: Module, catId: string, position: int) =
  self.view.chatsModel().reorderCategoryById(catId, position)

method onCategoryNameChanged*(self: Module, category: Category) =
  self.view.chatsModel().renameCategory(category.id, category.name)

method onCommunityChannelDeletedOrChatLeft*(self: Module, chatId: string) =
  if not self.chatContentModules.contains(chatId):
    return
  self.view.chatsModel().removeItemById(chatId)
  self.removeSubmodule(chatId)

  let activeChatId = self.controller.getActiveChatId()
  if chatId == activeChatId:
    self.setFirstChannelAsActive()

  self.updateParentBadgeNotifications()

proc refreshHiddenBecauseNotPermittedState(self: Module) =
  self.view.refreshAllChannelsAreHiddenBecauseNotPermittedChanged()

  let activeChatItem = self.view.chatsModel().activeItem()
  if activeChatItem == nil:
    return

  let activeItemShouldBeHidden = self.view.chatsModel().itemShouldBeHiddenBecauseNotPermitted(activeChatItem)
  if activeItemShouldBeHidden:
    let firstNotHiddenItemId = self.view.chatsModel().firstNotHiddenItemId()
    self.setActiveItem(firstNotHiddenItemId)

method onCommunityChannelEdited*(self: Module, chat: ChatDto) =
  if(not self.chatContentModules.contains(chat.id)):
    return
  self.changeCanPostValues(chat.id, chat.canPost, chat.canView, chat.canPostReactions, chat.viewersCanPostReactions)
  discard self.view.chatsModel().updateCommunityItemDetailsById(chat.id, chat.name, chat.description, chat.emoji, chat.color, chat.hideIfPermissionsNotMet)
  self.refreshHiddenBecauseNotPermittedState()

method switchToOrCreateOneToOneChat*(self: Module, chatId: string) =
  # One To One chat is available only in the `Chat` section
  if (self.controller.getMySectionId() != singletonInstance.userProfile.getPubKey()):
    return

  if (self.delegate.getActiveSectionId() != self.controller.getMySectionId()):
    self.delegate.setActiveSectionById(self.controller.getMySectionId())

  if(self.chatContentModules.hasKey(chatId)):
    self.setActiveItem(chatId)
    return

  self.controller.createOneToOneChat("", chatId, "")

method createOneToOneChat*(self: Module, communityID: string, chatId: string, ensName: string) =
  if self.controller.isCommunity():
     # initiate chat creation in the `Chat` section module.
     self.controller.switchToOrCreateOneToOneChat(chatId, ensName)
     return

  # Adding this call here we have the same as we had before (didn't inspect what are all cases when this
  # `createOneToOneChat` is called), but I am sure that after checking all cases and inspecting them, this can be improved.
  self.switchToOrCreateOneToOneChat(chatId)

method leaveChat*(self: Module, chatId: string) =
  self.controller.leaveChat(chatId)

method muteChat*(self: Module, chatId: string, interval: int) =
  self.controller.muteChat(chatId, interval)

method unmuteChat*(self: Module, chatId: string) =
  self.controller.unmuteChat(chatId)

method muteCategory*(self: Module, categoryId: string, interval: int) =
  self.controller.muteCategory(categoryId, interval)

method unmuteCategory*(self: Module, categoryId: string) =
  self.controller.unmuteCategory(categoryId)

method onCategoryMuted*(self: Module, categoryId: string) =
  self.view.chatsModel().changeMutedOnItemByCategoryId(categoryId, true)

method onCategoryUnmuted*(self: Module, categoryId: string) =
  self.view.chatsModel().changeMutedOnItemByCategoryId(categoryId, false)

method changeMutedOnChat*(self: Module, chatId: string, muted: bool) =
  self.view.chatsModel().changeMutedOnItemById(chatId, muted)
  self.updateParentBadgeNotifications()

proc changeCanPostValues*(self: Module, chatId: string, canPost, canView, canPostReactions, viewersCanPostReactions: bool) =
  discard self.view.chatsModel().changeCanPostValues(chatId, canPost, canView, canPostReactions, viewersCanPostReactions)

proc updateChatsRequiredPermissions(self: Module, communityChats: seq[ChatDto]) =
  for communityChat in communityChats:
    self.updatePermissionsRequiredOnChat(communityChat)

proc displayTokenPermissionChangeNotification(self: Module, title: string, message: string, community: CommunityDto, tokenPermission: CommunityTokenPermissionDto) =
  if self.showPermissionUpdateNotification(community, tokenPermission):
    singletonInstance.globalEvents.showCommunityTokenPermissionCreatedNotification(community.id, title, message)

method onCommunityTokenPermissionDeleted*(self: Module, communityId: string, tokenPermission: CommunityTokenPermissionDto) =
  self.view.tokenPermissionsModel.removeItemWithId(tokenPermission.id)
  self.reevaluateRequiresTokenPermissionToJoin()
  let community = self.controller.getMyCommunity()
  let communityChats = community.getCommunityChats(tokenPermission.chatIds)

  self.updateChatsRequiredPermissions(communityChats)
  self.displayTokenPermissionChangeNotification("Community permission deleted", "A token permission has been removed", community, tokenPermission)

method onCommunityTokenPermissionCreated*(self: Module, communityId: string, tokenPermission: CommunityTokenPermissionDto) =
  let community = self.controller.getMyCommunity()
  let communityChats = community.getCommunityChats(tokenPermission.chatIds)
  let tokenPermissionItem = buildTokenPermissionItem(tokenPermission, communityChats)

  self.updateChatsRequiredPermissions(communityChats)
  self.view.tokenPermissionsModel.addItem(tokenPermissionItem)
  self.reevaluateRequiresTokenPermissionToJoin()
  self.displayTokenPermissionChangeNotification("Community permission created", "A token permission has been added", community, tokenPermission)

# Returns true if there was an update
proc updateTokenPermissionModel*(self: Module, permissions: Table[string, CheckPermissionsResultDto], community: CommunityDto): bool =
  var thereWasAnUpdate = false
  for id, criteriaResult in permissions:
    if community.tokenPermissions.hasKey(id):
      let tokenPermissionItem = self.view.tokenPermissionsModel.getItemById(id)
      if tokenPermissionItem.id == "":
        continue

      var updatedTokenCriteriaItems: seq[TokenCriteriaItem] = @[]
      var permissionSatisfied = true
      var aCriteriaChanged = false

      for index, tokenCriteriaItem in tokenPermissionItem.getTokenCriteria().getItems():
        let criteriaMet = criteriaResult.criteria[index]

        if tokenCriteriaItem.criteriaMet != criteriaMet:
          aCriteriaChanged = true

        let updatedTokenCriteriaItem = initTokenCriteriaItem(
          tokenCriteriaItem.symbol,
          tokenCriteriaItem.name,
          tokenCriteriaItem.amount,
          tokenCriteriaItem.`type`,
          tokenCriteriaItem.ensPattern,
          criteriaResult.criteria[index],
          tokenCriteriaItem.addresses
        )

        if criteriaResult.criteria[index] == false:
          permissionSatisfied = false

        updatedTokenCriteriaItems.add(updatedTokenCriteriaItem)

      if not aCriteriaChanged:
        continue

      thereWasAnUpdate = true
      let updatedTokenPermissionItem = initTokenPermissionItem(
          tokenPermissionItem.id,
          tokenPermissionItem.`type`,
          updatedTokenCriteriaItems,
          tokenPermissionItem.getChatList().getItems(),
          tokenPermissionItem.isPrivate,
          permissionSatisfied,
          tokenPermissionItem.state
      )
      self.view.tokenPermissionsModel().updateItem(id, updatedTokenPermissionItem)

    return thereWasAnUpdate

proc updateCommunityPermissionsView*(self: Module) =
  let tokenPermissionsItems = self.view.tokenPermissionsModel().getItems()

  let memberPermissions = filter(tokenPermissionsItems, tokenPermissionsItem =>
    tokenPermissionsItem.getType() == TokenPermissionType.BecomeMember.int)

  let adminPermissions = filter(tokenPermissionsItems, tokenPermissionsItem =>
    tokenPermissionsItem.getType() == TokenPermissionType.BecomeAdmin.int)

  let tokenMasterPermissions = filter(tokenPermissionsItems, tokenPermissionsItem =>
    tokenPermissionsItem.getType() == TokenPermissionType.BecomeTokenMaster.int)

  # multiple permissions of the same type act as logical OR
  # so if at least one of them is fulfilled we can mark the view
  # as all lights green
  let memberRequirementMet = memberPermissions.len() > 0 and any(memberPermissions,
    proc (item: TokenPermissionItem): bool = item.tokenCriteriaMet)

  let adminRequirementMet = adminPermissions.len() > 0 and any(adminPermissions, proc (item: TokenPermissionItem): bool = item.tokenCriteriaMet)

  let tmRequirementMet = tokenMasterPermissions.len() > 0 and any(tokenMasterPermissions, proc (item: TokenPermissionItem): bool = item.tokenCriteriaMet)


  let requiresPermissionToJoin = memberPermissions.len() > 0

  let tokenRequirementsMet = if requiresPermissionToJoin:
      tmRequirementMet or adminRequirementMet or memberRequirementMet
    else:
      true

  self.view.setAllTokenRequirementsMet(tokenRequirementsMet)
  self.view.setRequiresTokenPermissionToJoin(requiresPermissionToJoin)

proc updateChannelPermissionViewData*(
    self: Module,
    chatId: string,
    viewOnlyPermissions: ViewOnlyOrViewAndPostPermissionsResponseDto,
    viewAndPostPermissions: ViewOnlyOrViewAndPostPermissionsResponseDto,
    community: CommunityDto
  ) =

  let viewOnlyUpdated = self.updateTokenPermissionModel(viewOnlyPermissions.permissions, community)
  let viewAndPostUpdated = self.updateTokenPermissionModel(viewAndPostPermissions.permissions, community)
  if viewOnlyUpdated or viewAndPostUpdated:
    let communityChat = community.getCommunityChat(chatId)
    self.updatePermissionsRequiredOnChat(communityChat)
    self.updateChatLocked(communityChat)

  self.view.chatsModel().updatePermissionsCheckOngoing(chatId, false)
  self.refreshHiddenBecauseNotPermittedState()

method onCommunityCheckPermissionsToJoinResponse*(self: Module, checkPermissionsToJoinResponse: CheckPermissionsToJoinResponseDto) =
  let community = self.controller.getMyCommunity()
  self.view.setAllTokenRequirementsMet(checkPermissionsToJoinResponse.satisfied)
  discard self.updateTokenPermissionModel(checkPermissionsToJoinResponse.permissions, community)
  self.updateCommunityPermissionsView()
  self.setPermissionsToJoinCheckOngoing(false)

method onCommunityTokenPermissionUpdated*(self: Module, communityId: string, tokenPermission: CommunityTokenPermissionDto) =
  let community = self.controller.getMyCommunity()
  let chats = community.getCommunityChats(tokenPermission.chatIds)
  let tokenPermissionItem = buildTokenPermissionItem(tokenPermission, chats)
  self.view.tokenPermissionsModel.updateItem(tokenPermission.id, tokenPermissionItem)
  self.reevaluateRequiresTokenPermissionToJoin()

  if self.showPermissionUpdateNotification(community, tokenPermission):
    singletonInstance.globalEvents.showCommunityTokenPermissionUpdatedNotification(communityId, "Community permission updated", "A token permission has been updated")

method onCommunityTokenPermissionCreationFailed*(self: Module, communityId: string) =
  singletonInstance.globalEvents.showCommunityTokenPermissionCreationFailedNotification(communityId, "Failed to create community permission", "Something went wrong")

method onCommunityTokenPermissionUpdateFailed*(self: Module, communityId: string) =
  singletonInstance.globalEvents.showCommunityTokenPermissionUpdateFailedNotification(communityId, "Failed to update community permission", "Something went wrong")

method onCommunityTokenPermissionDeletionFailed*(self: Module, communityId: string) =
  singletonInstance.globalEvents.showCommunityTokenPermissionDeletionFailedNotification(communityId, "Failed to delete community permission", "Something went wrong")

method onCommunityCheckChannelPermissionsResponse*(self: Module, chatId: string, checkChannelPermissionsResponse: CheckChannelPermissionsResponseDto) =
  let community = self.controller.getMyCommunity()
  if community.id != "":
    self.updateChannelPermissionViewData(chatId, checkChannelPermissionsResponse.viewOnlyPermissions, checkChannelPermissionsResponse.viewAndPostPermissions, community)

method onCommunityCheckAllChannelsPermissionsResponse*(self: Module, checkAllChannelsPermissionsResponse: CheckAllChannelsPermissionsResponseDto) =
  let community = self.controller.getMyCommunity()
  if community.id == "":
    return

  for chatId, permissionResult in checkAllChannelsPermissionsResponse.channels:
    self.updateChannelPermissionViewData(chatId, permissionResult.viewOnlyPermissions, permissionResult.viewAndPostPermissions, community)

method onKickedFromCommunity*(self: Module) =
  self.view.setAmIMember(false)
  let communityId = self.controller.getMySectionId()
  self.view.setWaitingOnNewCommunityOwnerToConfirmRequestToRejoin(self.controller.waitingOnNewCommunityOwnerToConfirmRequestToRejoin(communityId))

method onJoinedCommunity*(self: Module) =
  self.rebuildCommunityTokenPermissionsModel()
  self.view.setAmIMember(true)
  self.view.setWaitingOnNewCommunityOwnerToConfirmRequestToRejoin(false)
  self.view.setRequestToJoinState(RequestToJoinState.None)

method onMarkAllMessagesRead*(self: Module, chat: ChatDto) =
  self.updateBadgeNotifications(chat, hasUnreadMessages=false, unviewedMentionsCount=0)

method onMarkMessageAsUnread*(self: Module, chat: ChatDto) =
  self.updateBadgeNotifications(chat, hasUnreadMessages=true, chat.unviewedMentionsCount)

method onSectionMutedChanged*(self: Module) =
  self.updateParentBadgeNotifications()

method markAllMessagesRead*(self: Module, chatId: string) =
  self.controller.markAllMessagesRead(chatId)

method requestMoreMessages*(self: Module, chatId: string) =
  self.controller.requestMoreMessages(chatId)

method clearChatHistory*(self: Module, chatId: string) =
  self.controller.clearChatHistory(chatId)

method acceptContactRequest*(self: Module, publicKey: string, contactRequestId: string) =
  self.controller.acceptContactRequest(publicKey, contactRequestId)

method onContactAdded*(self: Module, publicKey: string, frombackup: bool = false) =
  self.view.contactRequestsModel().removeItemById(publicKey)

  let contact = self.controller.getContactById(publicKey)
  if contact.isContact and not frombackup:
    self.switchToOrCreateOneToOneChat(publicKey)

method acceptAllContactRequests*(self: Module) =
  let pubKeys = self.view.contactRequestsModel().getItemIds()
  for pk in pubKeys:
    self.acceptContactRequest(pk, "")

method dismissContactRequest*(self: Module, publicKey: string, contactRequestId: string) =
  self.controller.dismissContactRequest(publicKey, contactRequestId)

method onContactRejected*(self: Module, publicKey: string) =
  self.view.contactRequestsModel().removeItemById(publicKey)

method dismissAllContactRequests*(self: Module) =
  let pubKeys = self.view.contactRequestsModel().getItemIds()
  for pk in pubKeys:
    self.dismissContactRequest(pk, "")

method blockContact*(self: Module, publicKey: string) =
  self.controller.blockContact(publicKey)

method onContactBlocked*(self: Module, publicKey: string) =
  self.view.contactRequestsModel().removeItemById(publicKey)
  self.view.chatsModel().changeBlockedOnItemById(publicKey, blocked=true)
  self.onCommunityChannelDeletedOrChatLeft(publicKey)

method onContactUnblocked*(self: Module, publicKey: string) =
  self.view.chatsModel().changeBlockedOnItemById(publicKey, blocked=false)
  self.onContactDetailsUpdated(publicKey)

method onContactDetailsUpdated*(self: Module, publicKey: string) =
  if(self.controller.isCommunity()):
    return
  let contactDetails = self.controller.getContactDetails(publicKey)
  if (contactDetails.dto.isContactRequestReceived() and
    not contactDetails.dto.isContactRequestSent() and
    not contactDetails.dto.isBlocked() and
    not self.view.contactRequestsModel().isContactWithIdAdded(publicKey)):
      let item = self.createItemFromPublicKey(publicKey)
      self.view.contactRequestsModel().addItem(item)
      singletonInstance.globalEvents.showNewContactRequestNotification("New Contact Request",
      fmt "{contactDetails.defaultDisplayName} added you as contact",
        singletonInstance.userProfile.getPubKey())

  let chatName = contactDetails.defaultDisplayName
  let chatImage = contactDetails.icon
  let trustStatus = contactDetails.dto.trustStatus
  let usesUsedDefaultName = resolveUsesDefaultName(
    contactDetails.dto.localNickname,
    contactDetails.dto.name,
    contactDetails.dto.displayName,
  )
  self.view.chatsModel().updateUserItemDetailsById(publicKey, chatName, usesUsedDefaultName, chatImage, trustStatus)

method onNewMessagesReceived*(self: Module, sectionIdMsgBelongsTo: string, chatIdMsgBelongsTo: string,
    chatTypeMsgBelongsTo: ChatType, lastMessageTimestamp: int, unviewedMessagesCount: int, unviewedMentionsCount: int,
    message: MessageDto) =
  self.updateLastMessage(chatIdMsgBelongsTo, lastMessageTimestamp, message)

  # Any type of message coming from ourselves should never be shown as notification
  # and no need in badge notification update
  let myPK = singletonInstance.userProfile.getPubKey()
  if myPK == message.from:
    return

  let chatDetails = self.controller.getChatDetails(chatIdMsgBelongsTo)
  let community = self.controller.getMyCommunity()

  if (chatDetails.muted or community.muted):
    # No need to send a notification
    return

  if chatDetails.categoryId != "":
    self.view.chatsModel().setCategoryHasUnreadMessages(chatDetails.categoryId, true)

  # Prepare notification
  var notificationType = notification_details.NotificationType.NewMessage
  if(message.isPersonalMention(myPK)):
    notificationType = notification_details.NotificationType.NewMessageWithPersonalMention
  elif(message.isGlobalMention()):
    notificationType = notification_details.NotificationType.NewMessageWithGlobalMention

  var senderDisplayName: string =
    if message.contentType == ContentType.BridgeMessage:
      message.bridgeMessage.userName
    else:
      self.controller.getContactDetails(message.`from`).defaultDisplayName

  let plainText = self.controller.getMessagesParsedPlainText(message, community.chats)

  var notificationTitle = senderDisplayName

  case chatDetails.chatType:
    of ChatType.PrivateGroupChat:
      notificationTitle.add(fmt" ({chatDetails.name})")
    of ChatType.CommunityChat:
      if (chatDetails.categoryId.len == 0):
        notificationTitle.add(fmt" (#{chatDetails.name})")
      else:
        let categoryDetails = self.controller.getCommunityCategoryDetails(chatDetails.communityId, chatDetails.categoryId)
        notificationTitle.add(fmt" (#{chatDetails.name}, {categoryDetails.name})")
    else:
      discard

  let messageBelongsToActiveSection = sectionIdMsgBelongsTo == self.controller.getMySectionId() and
    self.controller.getMySectionId() == self.delegate.getActiveSectionId()
  let messageBelongsToActiveChat = self.controller.getActiveChatId() == chatIdMsgBelongsTo

  singletonInstance.globalEvents.showMessageNotification(notificationTitle, plainText, sectionIdMsgBelongsTo,
    self.controller.isCommunity(), messageBelongsToActiveSection, chatIdMsgBelongsTo, messageBelongsToActiveChat,
    message.id, notificationType.int, chatTypeMsgBelongsTo == ChatType.OneToOne,
    chatTypeMsgBelongsTo == ChatType.PrivateGroupChat)

method addGroupMembers*(self: Module, chatId: string, pubKeys: string) =
  self.controller.addGroupMembers(chatId, self.convertPubKeysToJson(pubKeys))

method removeMemberFromGroupChat*(self: Module, communityID: string, chatId: string, pubKey: string) =
  self.controller.removeMemberFromGroupChat(communityID, chatId, pubKey)

method removeMembersFromGroupChat*(self: Module, communityID: string, chatId: string, pubKeys: string) =
  self.controller.removeMembersFromGroupChat(communityID, chatId, self.convertPubKeysToJson(pubKeys))

method renameGroupChat*(self: Module, chatId: string, newName: string) =
  self.controller.renameGroupChat(chatId, newName)

method updateGroupChatDetails*(self: Module, chatId: string, newGroupName: string, newGroupColor: string, newGroupImageJson: string) =
  self.controller.updateGroupChatDetails(chatId, newGroupName, newGroupColor, newGroupImageJson)

method makeAdmin*(self: Module, communityID: string, chatId: string, pubKey: string) =
  self.controller.makeAdmin(communityID, chatId, pubKey)

method createGroupChat*(self: Module, communityID: string, groupName: string, pubKeys: string) =
  self.controller.createGroupChat(communityID, groupName, self.convertPubKeysToJson(pubKeys))

method createGroupChat*(self: Module, groupName: string, pubKeys: seq[string]) =
  self.controller.createGroupChat("", groupName, pubKeys)

method onChatRenamed*(self: Module, chatId: string, newName: string) =
  self.view.chatsModel().renameItemById(chatId, newName)
  self.view.tokenPermissionsModel().renameChatById(chatId, newName)

method onGroupChatDetailsUpdated*(self: Module, chatId, newName, newColor, newImage: string) =
  self.view.chatsModel().updateNameColorIconOnGroupItemById(chatId, newName, newColor, newImage)

method acceptRequestToJoinCommunity*(self: Module, requestId: string, communityId: string) =
  self.controller.acceptRequestToJoinCommunity(requestId, communityId)

method declineRequestToJoinCommunity*(self: Module, requestId: string, communityId: string) =
  self.controller.declineRequestToJoinCommunity(requestId, communityId)

method onAcceptRequestToJoinFailedNoPermission*(self: Module, communityId: string, memberKey: string, requestId: string) =
  let community = self.controller.getMyCommunity()
  let contact = self.controller.getContactById(memberKey)
  self.view.emitOpenNoPermissionsToJoinPopupSignal(community.name, contact.displayName,  community.id, requestId)

method createCommunityChannel*(self: Module, name, description, emoji, color, categoryId: string, viewersCanPostReactions: bool, hideIfPermissionsNotMet: bool) =
  self.controller.createCommunityChannel(name, description, emoji, color, categoryId, viewersCanPostReactions, hideIfPermissionsNotMet)

method editCommunityChannel*(self: Module, channelId, name, description, emoji, color,
    categoryId: string, position: int, viewersCanPostReactions: bool, hideIfPermissionsNotMet: bool) =
  self.controller.editCommunityChannel(channelId, name, description, emoji, color, categoryId,
    position, viewersCanPostReactions, hideIfPermissionsNotMet)

method createCommunityCategory*(self: Module, name: string, channels: seq[string]) =
  self.controller.createCommunityCategory(name, channels)

method editCommunityCategory*(self: Module, categoryId: string, name: string, channels: seq[string]) =
  self.controller.editCommunityCategory(categoryId, name, channels)

method deleteCommunityCategory*(self: Module, categoryId: string) =
  self.controller.deleteCommunityCategory(categoryId)

method leaveCommunity*(self: Module) =
  self.controller.leaveCommunity()

method removeUserFromCommunity*(self: Module, pubKey: string) =
  self.controller.removeUserFromCommunity(pubKey)

method banUserFromCommunity*(self: Module, pubKey: string, deleteAllMessages: bool) =
  self.controller.banUserFromCommunity(pubkey, deleteAllMessages)

method unbanUserFromCommunity*(self: Module, pubKey: string) =
  self.controller.unbanUserFromCommunity(pubkey)

method editCommunity*(self: Module, name: string,
                        description, introMessage, outroMessage: string,
                        access: int, color: string, tags: string,
                        logoJsonStr: string,
                        bannerJsonStr: string,
                        historyArchiveSupportEnabled: bool,
                        pinMessageAllMembersEnabled: bool) =
  self.controller.editCommunity(name, description, introMessage, outroMessage, access, color, tags, logoJsonStr,
                                bannerJsonStr, historyArchiveSupportEnabled, pinMessageAllMembersEnabled)

method exportCommunity*(self: Module): string =
  self.controller.exportCommunity()

method setCommunityMuted*(self: Module, mutedType: int) =
  self.controller.setCommunityMuted(mutedType)

method shareCommunityToUsers*(self: Module, pubKeysJSON: string, inviteMessage: string): string =
  result = self.controller.shareCommunityToUsers(pubKeysJSON, inviteMessage)

method prepareEditCategoryModel*(self: Module, categoryId: string) =
  self.view.editCategoryChannelsModel().clearItems()
  let communityId = self.controller.getMySectionId()
  let chats = self.controller.getChats(communityId, categoryId="")
  for chat in chats:
    let chatDto = self.controller.getChatDetails(chat.id)
    let chatItem = chat_item.initChatItem(
      chatDto.id,
      chatDto.name,
      usesDefaultName = false,
      icon="",
      chatDto.color,
      chatDto.emoji,
      chatDto.description,
      chatDto.chatType.int,
      memberRole=MemberRole.None,
      lastMessageTimestamp=(-1),
      lastMessageText = "", # Last message text is not needed in edit category model
      hasUnreadMessages=false,
      notificationsCount=0,
      chatDto.muted,
      blocked=false,
      active=false,
      chatDto.position,
      categoryId = "",
      hideIfPermissionsNotMet=false,
      missingEncryptionKey=false,
      permissionsCheckOngoing=false,
    )
    self.view.editCategoryChannelsModel().appendItem(chatItem)
  let catChats = self.controller.getChats(communityId, categoryId)
  for chat in catChats:
    let chatDto = self.controller.getChatDetails(chat.id)
    let chatItem = chat_item.initChatItem(
      chatDto.id,
      chatDto.name,
      usesDefaultName = false,
      icon="",
      chatDto.color,
      chatDto.emoji,
      chatDto.description,
      chatDto.chatType.int,
      memberRole=MemberRole.None,
      lastMessageTimestamp=(-1),
      lastMessageText = "", # Last message text is not needed in edit category model
      hasUnreadMessages=false,
      notificationsCount=0,
      chatDto.muted,
      blocked=false,
      active=false,
      chatDto.position,
      categoryId,
      hideIfPermissionsNotMet=false,
      missingEncryptionKey=false,
      permissionsCheckOngoing=false,
    )
    self.view.editCategoryChannelsModel().appendItem(chatItem, ignoreCategory = true)

method reorderCommunityCategories*(self: Module, categoryId: string, categoryPosition: int) =
  var finalPosition = categoryPosition
  if finalPosition < 0:
    finalPosition = 0

  self.controller.reorderCommunityCategories(categoryId, finalPosition)

method toggleCollapsedCommunityCategoryAsync*(self: Module, categoryId: string, collapsed: bool) =
  self.controller.toggleCollapsedCommunityCategoryAsync(categoryId, collapsed)

method reorderCommunityChat*(self: Module, categoryId: string, chatId: string, toPosition: int) =
  self.controller.reorderCommunityChat(categoryId, chatId, toPosition + 1)

method setLoadingHistoryMessagesInProgress*(self: Module, isLoading: bool) =
  self.view.setLoadingHistoryMessagesInProgress(isLoading)

method addOrUpdateChat(self: Module,
    chat: ChatDto,
    community: CommunityDto,
    belongsToCommunity: bool,
    events: UniqueUUIDEventEmitter,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service,
    contactService: contact_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    messageService: message_service.Service,
    mailserversService: mailservers_service.Service,
    sharedUrlsService: shared_urls_service.Service,
    setChatAsActive: bool = true,
    insertIntoModel: bool = true,
    isSectionBuild: bool = false,
  ): ChatItem =
  let sectionId = self.controller.getMySectionId()
  if belongsToCommunity and sectionId != chat.communityId or
    not belongsToCommunity and sectionId != singletonInstance.userProfile.getPubKey():
    return

  if not isSectionBuild:
    self.updateBadgeNotifications(chat, chat.unviewedMessagesCount > 0, chat.unviewedMentionsCount)

  if not self.chatsLoaded:
    return

  let activeChatId = self.controller.getActiveChatId()
  if chat.id == activeChatId:
    self.updateActiveChatMembership()

  result = self.getChatItemFromChatDto(chat, community, setChatAsActive)

  if self.doesCatOrChatExist(chat.id):
    if self.chatContentModules.contains(chat.id):
      self.chatContentModules[chat.id].onChatUpdated(result)

    self.changeMutedOnChat(chat.id, chat.muted)
    self.changeCanPostValues(chat.id, result.canPost, result.canView, result.canPostReactions, result.viewersCanPostReactions)
    self.view.chatsModel().setItemPermissionsRequired(chat.id, result.requiresPermissions)
    self.view.chatsModel().setItemLocked(chat.id, result.locked)
    self.view.chatsModel().updateMissingEncryptionKey(chat.id, result.missingEncryptionKey)
    if (chat.chatType == ChatType.PrivateGroupChat):
      self.onGroupChatDetailsUpdated(chat.id, chat.name, chat.color, chat.icon)
    elif (chat.chatType != ChatType.OneToOne):
      self.onChatRenamed(chat.id, chat.name)
    return

  self.addNewChat(
      result,
      chat,
      belongsToCommunity,
      events.eventsEmitter(),
      settingsService,
      nodeConfigurationService,
      contactService,
      chatService,
      communityService,
      messageService,
      mailserversService,
      sharedUrlsService,
      setChatAsActive,
      insertIntoModel,
    )

method contactsStatusUpdated*(self: Module, statusUpdates: seq[StatusUpdateDto]) =
  for s in statusUpdates:
    let status = toOnlineStatus(s.statusType)
    self.view.chatsModel().updateItemOnlineStatusById(s.publicKey, status)

method createOrEditCommunityTokenPermission*(self: Module, permissionId: string, permissionType: int, tokenCriteriaJson: string, channelIDs: seq[string], isPrivate: bool) =

  var tokenPermission = CommunityTokenPermissionDto()
  tokenPermission.id = permissionId
  tokenPermission.isPrivate = isPrivate
  tokenPermission.`type` = TokenPermissionType(permissionType)
  tokenPermission.chatIDs = channelIDs

  if tokenPermission.`type` != TokenPermissionType.View and tokenPermission.`type` != TokenPermissionType.ViewAndPost:
    tokenPermission.chatIDs = @[]

  let emitUnexistingKeyError = proc(key: string) =
    error "unexisting key: ", key, methodName="createOrEditCommunityTokenPermission"
    let communityId = self.controller.getMySectionId()
    if permissionId == "":
      self.onCommunityTokenPermissionCreationFailed(communityId)
      return
    self.onCommunityTokenPermissionUpdateFailed(communityId)

  let tokenCriteriaJsonObj = tokenCriteriaJson.parseJson
  for tokenCriteria in tokenCriteriaJsonObj:
    let key = tokenCriteria{"key"}.getStr() # can be group key or token key or community token key or collectible key
    var contractAddresses = initTable[int, string]()
    var tokenCriteriaDto = tokenCriteria.toTokenCriteriaDto

    if tokenCriteriaDto.`type` != TokenType.ENS:
      if not service_common_utils.isTokenKey(key):
        # handle token group
        var tokens = self.controller.getTokensByGroupKey(key)
        if tokens.len == 0:
          # fallback to get token by key or group key from all tokens
          let token = self.controller.getTokenByKeyOrGroupKeyFromAllTokens(key)
          if not token.isNil:
            tokens = @[token]
        if tokens.len == 0:
          emitUnexistingKeyError(key)
          return
        for token in tokens:
          contractAddresses[token.chainId] = token.address
          tokenCriteriaDto.name = token.name
          tokenCriteriaDto.symbol = token.symbol
          tokenCriteriaDto.decimals = token.decimals
      else:
        let tokenKey = service_common_utils.communityKeyToTokenKey(key)
        var token = self.controller.getTokenByKey(tokenKey)
        if token.isNil and tokenCriteriaDto.`type` != TokenType.ENS:
          # if tokens is nil, could be that it's a collectible and we figure out the contract addresses from the key
          try:
            let contractId = toContractID(key)
            token = createTokenItem(TokenDto(
                address: contractId.address,
                chainId: contractId.chainID,
                decimals: 0
              ), TokenType.ERC721)
          except Exception:
            discard
        if token.isNil:
          emitUnexistingKeyError(key)
          return
        contractAddresses[token.chainId] = token.address
        tokenCriteriaDto.name = token.name
        tokenCriteriaDto.symbol = token.symbol
        tokenCriteriaDto.decimals = token.decimals

    tokenCriteriaDto.amountInWei = tokenCriteria{"amount"}.getStr
    tokenCriteriaDto.contractAddresses = contractAddresses
    tokenPermission.tokenCriteria.add(tokenCriteriaDto)

  self.controller.createOrEditCommunityTokenPermission(tokenPermission)

method deleteCommunityTokenPermission*(self: Module, permissionId: string) =
  self.controller.deleteCommunityTokenPermission(permissionId)

method onDeactivateChatLoader*(self: Module, chatId: string) =
  self.view.chatsModel().disableChatLoader(chatId)

method collectCommunityMetricsMessagesTimestamps*(self: Module, intervals: string) =
  self.controller.collectCommunityMetricsMessagesTimestamps(intervals)

method setCommunityMetrics*(self: Module, metrics: CommunityMetricsDto) =
  self.view.setCommunityMetrics($$metrics)

method collectCommunityMetricsMessagesCount*(self: Module, intervals: string) =
  self.controller.collectCommunityMetricsMessagesCount(intervals)

method getPermissionsToJoinCheckOngoing*(self: Module): bool =
  self.view.getPermissionsCheckOngoing()

method setPermissionsToJoinCheckOngoing*(self: Module, value: bool) =
  self.view.setPermissionsCheckOngoing(value)

method getChannelsPermissionsCheckOngoing*(self: Module): bool =
  for id, chat_item in self.view.chatsModel().items():
    if self.view.chatsModel().getItemPermissionsRequired(chat_item.id):
      return chat_item.permissionsCheckOngoing
  return false

method setChannelsPermissionsCheckOngoing*(self: Module, value: bool) =
  for id, chat_item in self.view.chatsModel().items():
    if self.view.chatsModel().getItemPermissionsRequired(chat_item.id):
      self.view.chatsModel().updatePermissionsCheckOngoing(chat_item.id, true)

method onWaitingOnNewCommunityOwnerToConfirmRequestToRejoin*(self: Module) =
  self.view.setWaitingOnNewCommunityOwnerToConfirmRequestToRejoin(true)

method loadCommunityMemberMessages*(self: Module, communityId: string, memberPubKey: string) =
  self.view.getMemberMessagesModel().clear()
  self.controller.loadCommunityMemberMessages(communityId, memberPubKey)

method onCommunityMemberMessagesLoaded*(self: Module, messages: seq[MessageDto]) =
  var viewItems: seq[member_msg_item.Item]
  for message in messages:
    let item = self.buildCommunityMemberMessageItem(message)
    viewItems.add(item)

  if viewItems.len == 0:
    return

  self.view.getMemberMessagesModel().insertItemsBasedOnClock(viewItems)

method deleteCommunityMemberMessages*(self: Module, memberPubKey: string, messageId: string, chatId: string) =
  self.controller.deleteCommunityMemberMessages(memberPubKey, messageId, chatId)

method onCommunityMemberMessagesDeleted*(self: Module, deletedMessages: seq[string]) =
  if self.view.getMemberMessagesModel().rowCount > 0:
    for deletedMessageId in deletedMessages:
      self.view.getMemberMessagesModel().removeItem(deletedMessageId)

method communityContainsChat*(self: Module, chatId: string): bool =
  return self.chatContentModules.hasKey(chatId)

method openCommunityChatAndScrollToMessage*(self: Module, chatId: string, messageId: string) =
  if chatId in self.chatContentModules:
    self.setActiveItem(chatId)
    self.chatContentModules[chatId].scrollToMessage(messageId)

method updateRequestToJoinState*(self: Module, state: RequestToJoinState) =
  self.view.setRequestToJoinState(state)

method communityMemberReevaluationStatusUpdated*(self: Module, status: CommunityMemberReevaluationStatus) =
  self.view.setCommunityMemberReevaluationStatus(status.int)

method markAllReadInCommunity*(self: Module) =
  self.controller.markAllReadInCommunity()
