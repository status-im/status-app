import nimqml, json, sequtils, strutils
import model as chats_model
import item, active_item
import ../../shared_models/user_model as user_model
import ../../shared_models/message_model as member_msg_model
import ../../shared_models/token_permissions_model
import ../../../../app_service/common/types
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: chats_model.Model
      modelVariant: QVariant
      activeItem: ActiveItem
      activeItemVariant: QVariant
      tmpChatId: string # shouldn't be used anywhere except in prepareChatContentModuleForChatId/getChatContentModule procs
      contactRequestsModel: user_model.Model
      contactRequestsModelVariant: QVariant
      editCategoryChannelsModel: chats_model.Model
      editCategoryChannelsVariant: QVariant
      loadingHistoryMessagesInProgress: bool
      tokenPermissionsModel: TokenPermissionsModel
      tokenPermissionsVariant: QVariant
      allTokenRequirementsMet: bool
      requiresTokenPermissionToJoin: bool
      amIMember: bool
      chatsLoaded: bool
      communityMetrics: string # NOTE: later this should be replaced with QAbstractListModel-based model
      permissionsCheckOngoing: bool
      isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin: bool
      allChannelsAreHiddenBecauseNotPermitted: bool
      memberMessagesModel: member_msg_model.Model
      memberMessagesModelVariant: QVariant
      requestToJoinState: RequestToJoinState
      communityMemberReevaluationStatus: int
      permissionSaveInProgress: bool
      errorSavingPermission: string

  proc setPermissionSaveInProgress*(self: View, value: bool)
  proc setErrorSavingPermission*(self: View, value: string)

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = chats_model.newModel()
    result.modelVariant = newQVariant(result.model)
    result.editCategoryChannelsModel = chats_model.newModel()
    result.editCategoryChannelsVariant = newQVariant(result.editCategoryChannelsModel)
    result.activeItem = newActiveItem()
    result.activeItemVariant = newQVariant(result.activeItem)
    result.contactRequestsModel = user_model.newModel()
    result.contactRequestsModelVariant = newQVariant(result.contactRequestsModel)
    result.loadingHistoryMessagesInProgress = false
    result.tokenPermissionsModel = newTokenPermissionsModel()
    result.tokenPermissionsVariant = newQVariant(result.tokenPermissionsModel)
    result.amIMember = false
    result.requiresTokenPermissionToJoin = false
    result.chatsLoaded = false
    result.communityMetrics = "[]"
    result.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin = false
    result.memberMessagesModel = member_msg_model.newModel()
    result.memberMessagesModelVariant = newQVariant(result.memberMessagesModel)
    result.requestToJoinState = RequestToJoinState.None
    result.communityMemberReevaluationStatus = 0
    result.permissionSaveInProgress = false
    result.errorSavingPermission = ""

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc isCommunity(self: View): bool {.slot.} =
    return self.delegate.isCommunity()

  proc getMySectionId*(self: View): string {.slot.} =
    return self.delegate.getMySectionId()

  proc chatsModel*(self: View): chats_model.Model =
    return self.model

  proc getModel(self: View): QVariant {.slot.} =
    return self.modelVariant

  QtProperty[QVariant] model:
    read = getModel

  proc chatsLoadedChanged(self: View) {.signal.}

  proc chatsLoaded*(self: View) =
    self.chatsLoaded = true
    self.chatsLoadedChanged()

  proc getChatsLoaded*(self: View): bool {.slot.} =
    return self.chatsLoaded
  QtProperty[bool] chatsLoaded:
    read = getChatsLoaded
    notify = chatsLoadedChanged

  proc editCategoryChannelsModel*(self: View): chats_model.Model =
    return self.editCategoryChannelsModel

  proc getEditCategoryChannels(self: View): QVariant {.slot.} =
    return self.editCategoryChannelsVariant

  QtProperty[QVariant] editCategoryChannelsModel:
    read = getEditCategoryChannels

  proc contactRequestsModel*(self: View): user_model.Model =
    return self.contactRequestsModel

  proc getContactRequestsModel(self: View): QVariant {.slot.} =
    return self.contactRequestsModelVariant
  QtProperty[QVariant] contactRequestsModel:
    read = getContactRequestsModel

  proc activeItemChanged*(self:View) {.signal.}

  proc getActiveItem(self: View): QVariant {.slot.} =
    return self.activeItemVariant

  QtProperty[QVariant] activeItem:
    read = getActiveItem
    notify = activeItemChanged

  proc activeItemSet*(self: View, item: ChatItem) =
    self.activeItem.setActiveItemData(item)
    self.activeItemChanged()

  proc setActiveItem*(self: View, itemId: string) {.slot.} =
    self.delegate.setActiveItem(itemId)

  proc switchToChannel*(self: View, channelName: string) {.slot.} =
    self.delegate.switchToChannel(channelName)

  proc activeItem*(self: View): ActiveItem =
    result = self.activeItem

  # Since we cannot return QVariant from the proc which has arguments, so cannot have proc like this:
  # prepareChatContentModuleForChatId(self: View, chatId: string): QVariant {.slot.}
  # we're using combinaiton of
  # prepareChatContentModuleForChatId/getChatContentModule procs
  proc prepareChatContentModuleForChatId*(self: View, chatId: string) {.slot.} =
    self.tmpChatId = chatId

  proc getChatContentModule*(self: View): QVariant {.slot.} =
    var chatContentVariant = self.delegate.getChatContentModule(self.tmpChatId)
    self.tmpChatId = ""
    if(chatContentVariant.isNil):
      return newQVariant()

    return chatContentVariant

  proc createOneToOneChat*(self: View, communityID: string, chatId: string, ensName: string) {.slot.} =
    self.delegate.createOneToOneChat(communityID, chatId, ensName)

  proc leaveChat*(self: View, id: string) {.slot.} =
    self.delegate.leaveChat(id)

  proc getItemAsJson*(self: View, itemId: string): string {.slot.} =
    let jsonObj = self.model.getItemByIdAsJson(itemId)
    if jsonObj == nil or jsonObj.kind != JObject:
      return
    return $jsonObj

  proc muteChat*(self: View, chatId: string, interval: int) {.slot.} =
    self.delegate.muteChat(chatId, interval)

  proc unmuteChat*(self: View, chatId: string) {.slot.} =
    self.delegate.unmuteChat(chatId)

  proc muteCategory*(self: View, categoryId: string, interval: int) {.slot.} =
    self.delegate.muteCategory(categoryId, interval)

  proc unmuteCategory*(self: View, categoryId: string) {.slot.} =
    self.delegate.unmuteCategory(categoryId)

  proc markAllMessagesRead*(self: View, chatId: string) {.slot.} =
    self.delegate.markAllMessagesRead(chatId)

  proc requestMoreMessages*(self: View, chatId: string) {.slot.} =
    self.delegate.requestMoreMessages(chatId)

  proc clearChatHistory*(self: View, chatId: string) {.slot.} =
    self.delegate.clearChatHistory(chatId)

  proc acceptContactRequest*(self: View, publicKey: string, contactRequestId: string) {.slot.} =
    self.delegate.acceptContactRequest(publicKey, contactRequestId)

  proc acceptAllContactRequests*(self: View) {.slot.} =
    self.delegate.acceptAllContactRequests()

  proc dismissContactRequest*(self: View, publicKey: string, contactRequestId: string) {.slot.} =
    self.delegate.dismissContactRequest(publicKey, contactRequestId)

  proc dismissAllContactRequests*(self: View) {.slot.} =
    self.delegate.dismissAllContactRequests()

  proc blockContact*(self: View, publicKey: string) {.slot.} =
    self.delegate.blockContact(publicKey)

  proc removeCommunityChat*(self: View, chatId: string) {.slot} =
    self.delegate.removeCommunityChat(chatId)

  proc addGroupMembers*(self: View, chatId: string, pubKeys: string) {.slot.} =
    self.delegate.addGroupMembers(chatId, pubKeys)

  proc removeMemberFromGroupChat*(self: View, communityID: string, chatId: string, pubKey: string) {.slot.} =
    self.delegate.removeMemberFromGroupChat(communityID, chatId, pubKey)

  proc removeMembersFromGroupChat*(self: View, communityID: string, chatId: string, pubKeys: string) {.slot.} =
    self.delegate.removeMembersFromGroupChat(communityID, chatId, pubKeys)

  proc renameGroupChat*(self: View, chatId: string, newName: string) {.slot.} =
    self.delegate.renameGroupChat(chatId, newName)

  proc updateGroupChatDetails(self: View, chatId: string, newGroupName: string, newGroupColor: string, newGroupImage: string) {.slot.} =
    self.delegate.updateGroupChatDetails(chatId, newGroupName, newGroupColor, newGroupImage)

  proc makeAdmin*(self: View, communityID: string, chatId: string, pubKey: string) {.slot.} =
    self.delegate.makeAdmin(communityID, chatId, pubKey)

  proc createGroupChat*(self: View, communityID: string, groupName: string, pubKeys: string) {.slot.} =
    self.delegate.createGroupChat(communityID, groupName, pubKeys)

  proc acceptRequestToJoinCommunity*(self: View, requestId: string, communityId: string) {.slot.} =
    self.delegate.acceptRequestToJoinCommunity(requestId, communityId)

  proc declineRequestToJoinCommunity*(self: View, requestId: string, communityId: string) {.slot.} =
    self.delegate.declineRequestToJoinCommunity(requestId, communityId)

  proc openNoPermissionsToJoinPopup*(self:View, communityName: string, userName: string, communityId: string, requestId: string) {.signal.}
  proc emitOpenNoPermissionsToJoinPopupSignal*(self: View, communityName: string, userName: string, communityId: string, requestId: string) =
    self.openNoPermissionsToJoinPopup(communityName, userName, communityId, requestId)

  proc createCommunityChannel*(
      self: View,
      name: string,
      description: string,
      emoji: string,
      color: string,
      categoryId: string,
      viewersCanPostReactions: bool,
      hideIfPermissionsNotMet: bool,
      ) {.slot.} =
    self.delegate.createCommunityChannel(name, description, emoji, color, categoryId, viewersCanPostReactions, hideIfPermissionsNotMet)

  proc editCommunityChannel*(
      self: View,
      channelId: string,
      name: string,
      description: string,
      emoji: string,
      color: string,
      categoryId: string,
      position: int,
      viewersCanPostReactions: bool,
      hideIfPermissionsNotMet: bool
    ) {.slot.} =
    self.delegate.editCommunityChannel(
      channelId,
      name,
      description,
      emoji,
      color,
      categoryId,
      position,
      viewersCanPostReactions,
      hideIfPermissionsNotMet
    )

  proc leaveCommunity*(self: View) {.slot.} =
    self.delegate.leaveCommunity()

  proc removeUserFromCommunity*(self: View, pubKey: string) {.slot.} =
    self.delegate.removeUserFromCommunity(pubKey)

  proc banUserFromCommunity*(self: View, pubKey: string, deleteAllMessages: bool) {.slot.} =
    self.delegate.banUserFromCommunity(pubKey, deleteAllMessages)

  proc editCommunity*(self: View, name: string, description: string, introMessage: string, outroMessage: string, access: int,
                      color: string, tags: string, logoJsonData: string, bannerJsonData: string, historyArchiveSupportEnabled: bool,
                      pinMessageAllMembersEnabled: bool) {.slot.} =
    self.delegate.editCommunity(name, description, introMessage, outroMessage, access, color, tags,
                                logoJsonData, bannerJsonData, historyArchiveSupportEnabled, pinMessageAllMembersEnabled)

  proc unbanUserFromCommunity*(self: View, pubKey: string) {.slot.} =
    self.delegate.unbanUserFromCommunity(pubKey)

  proc exportCommunity*(self: View): string {.slot.} =
    self.delegate.exportCommunity()

  proc setCommunityMuted*(self: View, mutedType: int) {.slot.} =
    self.delegate.setCommunityMuted(mutedType)

  proc shareCommunityToUsers*(self: View, pubKeysJSON: string, inviteMessage: string): string {.slot.} =
    result = self.delegate.shareCommunityToUsers(pubKeysJSON, inviteMessage)

  proc createCommunityCategory*(self: View, name: string, channels: string) {.slot.} =
    let channelsSeq = map(parseJson(channels).getElems(), proc(x:JsonNode):string = x.getStr())
    self.delegate.createCommunityCategory(name, channelsSeq)

  proc editCommunityCategory*(self: View, categoryId: string, name: string, channels: string) {.slot.} =
    let channelsSeq = map(parseJson(channels).getElems(), proc(x:JsonNode):string = x.getStr())
    self.delegate.editCommunityCategory(categoryId, name, channelsSeq)

  proc deleteCommunityCategory*(self: View, categoryId: string) {.slot.} =
    self.delegate.deleteCommunityCategory(categoryId)

  proc prepareEditCategoryModel*(self: View, categoryId: string) {.slot.} =
    self.delegate.prepareEditCategoryModel(categoryId)

  proc reorderCommunityCategories*(self: View, categoryId: string, categoryPosition: int) {.slot} =
    self.delegate.reorderCommunityCategories(categoryId, categoryPosition)

  proc toggleCollapsedCommunityCategory*(self: View, categoryId: string, collapsed: bool) {.slot} =
    self.model.changeCategoryOpened(categoryId, not collapsed)
    self.delegate.toggleCollapsedCommunityCategoryAsync(categoryId, collapsed)

  proc reorderCommunityChat*(self: View, categoryId: string, chatId: string, position: int) {.slot} =
    self.delegate.reorderCommunityChat(categoryId, chatId, position)

  proc loadingHistoryMessagesInProgressChanged*(self: View) {.signal.}

  proc getLoadingHistoryMessagesInProgress*(self: View): bool {.slot.} =
    return self.loadingHistoryMessagesInProgress

  QtProperty[bool] loadingHistoryMessagesInProgress:
    read = getLoadingHistoryMessagesInProgress
    notify = loadingHistoryMessagesInProgressChanged

  proc setLoadingHistoryMessagesInProgress*(self: View, value: bool) = # this is not a slot
    if (value == self.loadingHistoryMessagesInProgress):
      return
    self.loadingHistoryMessagesInProgress = value
    self.loadingHistoryMessagesInProgressChanged()

  proc tokenPermissionsModel*(self: View): TokenPermissionsModel =
    result = self.tokenPermissionsModel

  proc getTokenPermissionsModel(self: View): QVariant{.slot.} =
    return self.tokenPermissionsVariant

  QtProperty[QVariant] permissionsModel:
    read = getTokenPermissionsModel

  proc createOrEditCommunityTokenPermission*(self: View, permissionId: string, permissionType: int, tokenCriteriaJson: string, channelIDs: string, isPrivate: bool) {.slot.} =
    self.setPermissionSaveInProgress(true)
    self.setErrorSavingPermission("")
    let chatIDs = channelIDs.split(',')
    self.delegate.createOrEditCommunityTokenPermission(permissionId, permissionType, tokenCriteriaJson, chatIDs, isPrivate)

  proc deleteCommunityTokenPermission*(self: View, permissionId: string) {.slot.} =
    self.delegate.deleteCommunityTokenPermission(permissionId)

  proc requiresTokenPermissionToJoinChanged*(self: View) {.signal.}

  proc getRequiresTokenPermissionToJoin(self: View): bool {.slot.} =
    return self.requiresTokenPermissionToJoin

  proc setRequiresTokenPermissionToJoin*(self: View, value: bool) =
    if (value == self.requiresTokenPermissionToJoin):
      return
    self.requiresTokenPermissionToJoin = value
    self.requiresTokenPermissionToJoinChanged()

  QtProperty[bool] requiresTokenPermissionToJoin:
    read = getRequiresTokenPermissionToJoin
    notify = requiresTokenPermissionToJoinChanged

  proc getAmIMember*(self: View): bool {.slot.} =
    return self.amIMember

  proc amIMemberChanged*(self: View) {.signal.}

  proc setAmIMember*(self: View, value: bool) =
    if (value == self.amIMember):
      return
    self.amIMember = value
    self.amIMemberChanged()

  QtProperty[bool] amIMember:
    read = getAmIMember
    notify = amIMemberChanged

  proc getAllTokenRequirementsMet*(self: View): bool {.slot.} =
    return self.allTokenRequirementsMet

  proc allTokenRequirementsMetChanged*(self: View) {.signal.}

  proc setAllTokenRequirementsMet*(self: View, value: bool) =
    if (value == self.allTokenRequirementsMet):
      return
    self.allTokenRequirementsMet = value
    self.allTokenRequirementsMetChanged()

  QtProperty[bool] allTokenRequirementsMet:
    read = getAllTokenRequirementsMet
    notify = allTokenRequirementsMetChanged

  proc getOverviewChartData*(self: View): QVariant {.slot.} =
    return newQVariant(self.communityMetrics)

  proc overviewChartDataChanged*(self: View) {.signal.}

  QtProperty[QVariant] overviewChartData:
    read = getOverviewChartData
    notify = overviewChartDataChanged

  proc setCommunityMetrics*(self: View, communityMetrics: string) =
    self.communityMetrics = communityMetrics
    self.overviewChartDataChanged()

  proc collectCommunityMetricsMessagesTimestamps*(self: View, intervals: string) {.slot.} =
    self.delegate.collectCommunityMetricsMessagesTimestamps(intervals)

  proc collectCommunityMetricsMessagesCount*(self: View, intervals: string) {.slot.} =
    self.delegate.collectCommunityMetricsMessagesCount(intervals)

  proc getPermissionsCheckOngoing*(self: View): bool {.slot.} =
    return self.permissionsCheckOngoing

  proc permissionsCheckOngoingChanged*(self: View) {.signal.}

  QtProperty[bool] permissionsCheckOngoing:
    read = getPermissionsCheckOngoing
    notify = permissionsCheckOngoingChanged

  proc setPermissionsCheckOngoing*(self: View, value: bool) =
    if (value == self.permissionsCheckOngoing):
      return
    self.permissionsCheckOngoing = value
    self.permissionsCheckOngoingChanged()

  proc getWaitingOnNewCommunityOwnerToConfirmRequestToRejoin*(self: View): bool {.slot.} =
    return self.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin

  proc isWaitingOnNewCommunityOwnerToConfirmRequestToRejoinChanged*(self: View) {.signal.}

  proc setWaitingOnNewCommunityOwnerToConfirmRequestToRejoin*(self: View, value: bool) =
    if (value == self.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin):
      return
    self.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin = value
    self.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoinChanged()

  QtProperty[bool] isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin:
    read = getWaitingOnNewCommunityOwnerToConfirmRequestToRejoin
    notify = isWaitingOnNewCommunityOwnerToConfirmRequestToRejoinChanged

  proc allChannelsAreHiddenBecauseNotPermittedChanged*(self: View) {.signal.}

  proc getAllChannelsAreHiddenBecauseNotPermitted*(self: View): bool {.slot.} =
    return self.allChannelsAreHiddenBecauseNotPermitted

  QtProperty[bool] allChannelsAreHiddenBecauseNotPermitted:
    read = getAllChannelsAreHiddenBecauseNotPermitted
    notify = allChannelsAreHiddenBecauseNotPermittedChanged

  proc refreshAllChannelsAreHiddenBecauseNotPermittedChanged*(self: View) =
    let allAreHidden = self.model.allChannelsAreHiddenBecauseNotPermitted()
    if (allAreHidden == self.allChannelsAreHiddenBecauseNotPermitted):
      return
    self.allChannelsAreHiddenBecauseNotPermitted = allAreHidden
    self.allChannelsAreHiddenBecauseNotPermittedChanged()
  proc getMemberMessagesModel*(self: View): member_msg_model.Model =
    return self.memberMessagesModel

  proc getMemberMessagesModelVariant(self: View): QVariant {.slot.} =
    return self.memberMessagesModelVariant

  QtProperty[QVariant] memberMessagesModel:
    read = getMemberMessagesModelVariant

  proc loadCommunityMemberMessages*(self: View, communityId: string, memberPubKey: string) {.slot.} =
    self.delegate.loadCommunityMemberMessages(communityId, memberPubKey)

  proc deleteCommunityMemberMessages*(self: View, memberPubKey: string, messageId: string, chatId: string) {.slot.} =
    self.delegate.deleteCommunityMemberMessages(memberPubKey, messageId, chatId)

  proc openCommunityChatAndScrollToMessage*(self: View, chatId: string, messageId: string) {.slot.} =
    self.delegate.openCommunityChatAndScrollToMessage(chatId, messageId)

  proc requestToJoinStateChanged*(self: View) {.signal.}

  proc getRequestToJoinState*(self: View): int {.slot.} =
    return self.requestToJoinState.int

  QtProperty[int] requestToJoinState:
    read = getRequestToJoinState
    notify = requestToJoinStateChanged

  proc setRequestToJoinState*(self: View, requestToJoinState: RequestToJoinState) =
    if self.requestToJoinState == requestToJoinState:
      return
    self.requestToJoinState = requestToJoinState
    self.requestToJoinStateChanged()

  proc communityMemberReevaluationStatusChanged*(self: View) {.signal.}

  proc getCommunityMemberReevaluationStatus*(self: View): int {.slot.} =
    return self.communityMemberReevaluationStatus

  QtProperty[int] communityMemberReevaluationStatus:
    read = getCommunityMemberReevaluationStatus
    notify = communityMemberReevaluationStatusChanged

  proc setCommunityMemberReevaluationStatus*(self: View, value: int) =
    if self.communityMemberReevaluationStatus == value:
      return
    self.communityMemberReevaluationStatus = value
    self.communityMemberReevaluationStatusChanged()

  proc membersModelChanged*(self: View) {.signal.}
  proc getMembersModel(self: View): QVariant {.slot.} =
    return self.delegate.getSectionMemberList()

  QtProperty[QVariant] membersModel:
    read = getMembersModel
    notify = membersModelChanged

  proc markAllReadInCommunity*(self: View) {.slot.} =
    self.delegate.markAllReadInCommunity()

  proc permissionSavedSuccessfully*(self: View) {.signal.}

  proc permissionSaveInProgressChanged*(self: View) {.signal.}

  proc getPermissionSaveInProgress*(self: View): bool {.slot.} =
    return self.permissionSaveInProgress

  proc setPermissionSaveInProgress*(self: View, value: bool) =
    if self.permissionSaveInProgress == value:
      return
    self.permissionSaveInProgress = value
    self.permissionSaveInProgressChanged()

  QtProperty[bool] permissionSaveInProgress:
    read = getPermissionSaveInProgress
    notify = permissionSaveInProgressChanged

  proc errorSavingPermissionChanged*(self: View) {.signal.}

  proc setErrorSavingPermission*(self: View, value: string) =
    if self.errorSavingPermission == value:
      return
    self.errorSavingPermission = value
    self.errorSavingPermissionChanged()

  proc getErrorSavingPermission*(self: View): string {.slot.} =
    return self.errorSavingPermission
  QtProperty[string] errorSavingPermission:
    read = getErrorSavingPermission
    notify = errorSavingPermissionChanged

  proc delete*(self: View) =
    self.QObject.delete
