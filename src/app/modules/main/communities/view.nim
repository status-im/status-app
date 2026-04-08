import nimqml, json, strutils, sequtils

import ./io_interface
import ../../shared_models/[section_model, section_item, token_list_model,
  token_permissions_model, keypair_model]
import ./models/curated_community_model
import ./models/discord_file_list_model
import ./models/discord_file_item
import ./models/discord_categories_model
import ./models/discord_channels_model
import ./models/discord_channel_item
import ./models/discord_import_tasks_model

QtObject:
  type
    View* = ref object of QObject
      communityTags: QVariant
      delegate: io_interface.AccessInterface
      model: SectionModel
      modelVariant: QVariant
      spectatedCommunityPermissionModel: TokenPermissionsModel
      spectatedCommunityPermissionModelVariant: QVariant
      curatedCommunitiesModel: CuratedCommunityModel
      curatedCommunitiesModelVariant: QVariant
      curatedCommunitiesLoading: bool
      tokenListLoading: bool
      tokenListModel: TokenListModel
      tokenListModelVariant: QVariant
      collectiblesListModel: TokenListModel
      collectiblesListModelVariant: QVariant
      discordFileListModel: DiscordFileListModel
      discordFileListModelVariant: QVariant
      discordCategoriesModel: DiscordCategoriesModel
      discordCategoriesModelVariant: QVariant
      discordChannelsModel: DiscordChannelsModel
      discordChannelsModelVariant: QVariant
      discordOldestMessageTimestamp: int
      discordImportErrorsCount: int
      discordImportWarningsCount: int
      discordImportProgress: int
      discordImportInProgress: bool
      discordImportCancelled: bool
      discordImportProgressStopped: bool
      discordImportProgressTotalChunksCount: int
      discordImportProgressCurrentChunk: int
      discordImportTasksModel: DiscordImportTasksModel
      discordImportTasksModelVariant: QVariant
      discordDataExtractionInProgress: bool
      discordImportCommunityId: string
      discordImportCommunityName: string
      discordImportChannelId: string
      discordImportChannelName: string
      discordImportCommunityImage: string
      discordImportedChannelId: string
      discordImportedChannelCommunityId: string
      discordImportHasCommunityImage: bool
      downloadingCommunityHistoryArchives: bool
      checkingPermissionsInProgress: bool
      joinPermissionsCheckCompletedWithoutErrors: bool
      channelsPermissionsCheckSuccessful: bool
      myRevealedAddressesStringForCurrentCommunity: string
      myRevealedAirdropAddressForCurrentCommunity: string
      keypairsSigningModel: KeyPairModel
      keypairsSigningModelVariant: QVariant

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.communityTags = newQVariant("")
    result.delegate = delegate
    result.model = newModel()
    result.modelVariant = newQVariant(result.model)
    result.spectatedCommunityPermissionModel = newTokenPermissionsModel()
    result.spectatedCommunityPermissionModelVariant = newQVariant(result.spectatedCommunityPermissionModel)
    result.curatedCommunitiesModel = newCuratedCommunityModel()
    result.curatedCommunitiesModelVariant = newQVariant(result.curatedCommunitiesModel)
    result.curatedCommunitiesLoading = false
    result.discordFileListModel = newDiscordFileListModel()
    result.discordFileListModelVariant = newQVariant(result.discordFileListModel)
    result.discordCategoriesModel = newDiscordCategoriesModel()
    result.discordCategoriesModelVariant = newQVariant(result.discordCategoriesModel)
    result.discordChannelsModel = newDiscordChannelsModel()
    result.discordChannelsModelVariant = newQVariant(result.discordChannelsModel)
    result.discordOldestMessageTimestamp = 0
    result.discordDataExtractionInProgress = false
    result.discordImportWarningsCount = 0
    result.discordImportErrorsCount = 0
    result.discordImportProgress = 0
    result.discordImportInProgress = false
    result.discordImportCancelled = false
    result.discordImportProgressStopped = false
    result.discordImportHasCommunityImage = false
    result.discordImportTasksModel = newDiscordDiscordImportTasksModel()
    result.discordImportTasksModelVariant = newQVariant(result.discordImportTasksModel)
    result.downloadingCommunityHistoryArchives = false
    result.tokenListModel = newTokenListModel()
    result.tokenListModelVariant = newQVariant(result.tokenListModel)
    result.collectiblesListModel = newTokenListModel()
    result.collectiblesListModelVariant = newQVariant(result.collectiblesListModel)
    result.checkingPermissionsInProgress = false
    result.joinPermissionsCheckCompletedWithoutErrors = false
    result.channelsPermissionsCheckSuccessful = false

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc cleanJoinEditCommunityData*(self: View) {.slot.} =
    self.delegate.cleanJoinEditCommunityData()

  proc communityAdded*(self: View, communityId: string) {.signal.}
  proc communityChanged*(self: View, communityId: string) {.signal.}
  proc discordOldestMessageTimestampChanged*(self: View) {.signal.}
  proc discordImportErrorsCountChanged*(self: View) {.signal.}
  proc communityAccessRequested*(self: View, communityId: string) {.signal.}
  proc communityAccessFailed*(self: View, communityId: string, error: string) {.signal.}
  proc communityEditSharedAddressesSucceeded*(self: View, communityId: string) {.signal.}
  proc communityEditSharedAddressesFailed*(self: View, communityId: string, error: string) {.signal.}

  proc communityTagsChanged*(self: View) {.signal.}

  proc setCommunityTags*(self: View, communityTags: string) =
    self.communityTags = newQVariant(communityTags)
    self.communityTagsChanged()

  proc setDiscordOldestMessageTimestamp*(self: View, timestamp: int) {.slot.} =
    if (self.discordOldestMessageTimestamp == timestamp): return
    self.discordOldestMessageTimestamp = timestamp
    self.discordOldestMessageTimestampChanged()

  proc getDiscordOldestMessageTimestamp*(self: View): int {.slot.} =
    return self.discordOldestMessageTimestamp

  QtProperty[int] discordOldestMessageTimestamp:
    read = getDiscordOldestMessageTimestamp
    notify = discordOldestMessageTimestampChanged

  proc downloadingCommunityHistoryArchivesChanged*(self: View) {.signal.}

  proc setDownloadingCommunityHistoryArchives*(self: View, flag: bool) =
    if (self.downloadingCommunityHistoryArchives == flag): return
    self.downloadingCommunityHistoryArchives = flag
    self.downloadingCommunityHistoryArchivesChanged()

  proc getDownloadingCommunityHistoryArchives*(self: View): bool {.slot.} =
    return self.downloadingCommunityHistoryArchives

  QtProperty[bool] downloadingCommunityHistoryArchives:
    read = getDownloadingCommunityHistoryArchives
    notify = downloadingCommunityHistoryArchivesChanged

  proc discordImportHasCommunityImageChanged*(self: View) {.signal.}

  proc setDiscordImportHasCommunityImage*(self: View, hasImage: bool) =
    if (self.discordImportHasCommunityImage == hasImage): return
    self.discordImportHasCommunityImage = hasImage
    self.discordImportHasCommunityImageChanged()

  proc getDiscordImportHasCommunityImage*(self: View): bool {.slot.} =
    return self.discordImportHasCommunityImage

  QtProperty[bool] discordImportHasCommunityImage:
    read = getDiscordImportHasCommunityImage
    notify = discordImportHasCommunityImageChanged

  proc discordImportWarningsCountChanged*(self: View) {.signal.}

  proc setDiscordImportWarningsCount*(self: View, count: int) =
    if (self.discordImportWarningsCount == count): return
    self.discordImportWarningsCount = count
    self.discordImportWarningsCountChanged()

  proc getDiscordImportWarningsCount*(self: View): int {.slot.} =
    return self.discordImportWarningsCount

  QtProperty[int] discordImportWarningsCount:
    read = getDiscordImportWarningsCount
    notify = discordImportWarningsCountChanged

  proc discordImportedChannelIdChanged*(self: View) {.signal.}

  proc setDiscordImportedChannelId*(self: View, id: string) =
    if (self.discordImportedChannelId == id): return
    self.discordImportedChannelId = id
    self.discordImportedChannelIdChanged()

  proc getDiscordImportedChannelId*(self: View): string {.slot.} =
    return self.discordImportedChannelId

  QtProperty[int] discordImportedChannelId:
    read = getDiscordImportedChannelId
    notify = discordImportedChannelIdChanged

  proc setDiscordImportErrorsCount*(self: View, count: int) =
    if (self.discordImportErrorsCount == count): return
    self.discordImportErrorsCount = count
    self.discordImportErrorsCountChanged()

  proc getDiscordImportErrorsCount*(self: View): int {.slot.} =
    return self.discordImportErrorsCount

  QtProperty[int] discordImportErrorsCount:
    read = getDiscordImportErrorsCount
    notify = discordImportErrorsCountChanged

  proc discordImportProgressChanged*(self: View) {.signal.}

  proc setDiscordImportProgress*(self: View, value: int) =
    if (self.discordImportProgress == value): return
    self.discordImportProgress = value
    self.discordImportProgressChanged()

  proc getDiscordImportProgress*(self: View): int {.slot.} =
    return self.discordImportProgress

  QtProperty[int] discordImportProgress:
    read = getDiscordImportProgress
    notify = discordImportProgressChanged

  proc discordImportInProgressChanged*(self: View) {.signal.}

  proc setDiscordImportInProgress*(self: View, value: bool) =
    if (self.discordImportInProgress == value): return
    self.discordImportInProgress = value
    self.discordImportInProgressChanged()

  proc getDiscordImportInProgress*(self: View): bool {.slot.} =
    return self.discordImportInProgress

  QtProperty[bool] discordImportInProgress:
    read = getDiscordImportInProgress
    notify = discordImportInProgressChanged

  proc discordImportCancelledChanged*(self: View) {.signal.}

  proc setDiscordImportCancelled*(self: View, value: bool) =
    if (self.discordImportCancelled == value): return
    self.discordImportCancelled = value
    self.discordImportCancelledChanged()

  proc getDiscordImportCancelled*(self: View): bool {.slot.} =
    return self.discordImportCancelled

  QtProperty[bool] discordImportCancelled:
    read = getDiscordImportCancelled
    notify = discordImportCancelledChanged

  proc discordImportProgressStoppedChanged*(self: View) {.signal.}

  proc setDiscordImportProgressStopped*(self: View, stopped: bool) =
    if (self.discordImportProgressStopped == stopped): return
    self.discordImportProgressStopped = stopped
    self.discordImportProgressStoppedChanged()

  proc getDiscordImportProgressStopped*(self: View): bool {.slot.} =
    return self.discordImportProgressStopped

  QtProperty[int] discordImportProgressStopped:
    read = getDiscordImportProgressStopped
    notify = discordImportProgressStoppedChanged

  proc discordImportProgressTotalChunksCountChanged*(self: View) {.signal.}

  proc setDiscordImportProgressTotalChunksCount*(self: View, count: int) =
    if (self.discordImportProgressTotalChunksCount == count): return
    self.discordImportProgressTotalChunksCount = count
    self.discordImportProgressTotalChunksCountChanged()

  proc getDiscordImportProgressTotalChunksCount*(self: View): int {.slot.} =
    return self.discordImportProgressTotalChunksCount

  QtProperty[int] discordImportProgressTotalChunksCount:
    read = getDiscordImportProgressTotalChunksCount
    notify = discordImportProgressTotalChunksCountChanged

  proc discordImportProgressCurrentChunkChanged*(self: View) {.signal.}

  proc setDiscordImportProgressCurrentChunk*(self: View, count: int) =
    if (self.discordImportProgressCurrentChunk == count): return
    self.discordImportProgressCurrentChunk = count
    self.discordImportProgressCurrentChunkChanged()

  proc getDiscordImportProgressCurrentChunk*(self: View): int {.slot.} =
    return self.discordImportProgressCurrentChunk

  QtProperty[int] discordImportProgressCurrentChunk:
    read = getDiscordImportProgressCurrentChunk
    notify = discordImportProgressCurrentChunkChanged

  proc addItem*(self: View, item: SectionItem) =
    self.model.addItem(item)
    self.communityAdded(item.id)

  proc updateItem*(self: View, item: SectionItem) =
    self.model.editItem(item)
    self.communityChanged(item.id)

  proc addOrUpdateItem*(self: View, item: SectionItem) =
    if self.model.itemExists(item.id):
      self.updateItem(item)
    else:
      self.addItem(item)

  proc model*(self: View): SectionModel =
    result = self.model

  proc getTags(self: View): QVariant {.slot.} =
    return self.communityTags

  QtProperty[QVariant] tags:
    read = getTags
    notify = communityTagsChanged

  proc getModel(self: View): QVariant {.slot.} =
    return self.modelVariant

  QtProperty[QVariant] model:
    read = getModel

  proc spectatedCommunityPermissionModel*(self: View): TokenPermissionsModel =
    result = self.spectatedCommunityPermissionModel

  proc prepareTokenModelForCommunity(self: View, communityId: string) {.slot.} =
    self.delegate.prepareTokenModelForCommunity(communityId)

  proc prepareTokenModelForCommunityChat(self: View, communityId: string, chatId: string) {.slot.} =
    self.delegate.prepareTokenModelForCommunityChat(communityId, chatId)

  proc signProfileKeypairAndAllNonKeycardKeypairs*(self: View) {.slot.} =
    self.delegate.signProfileKeypairAndAllNonKeycardKeypairs()

  proc signSharedAddressesForKeypair*(self: View, keyUid: string) {.slot.} =
    self.delegate.signSharedAddressesForKeypair(keyUid, pin = "")

  proc joinCommunityOrEditSharedAddresses*(self: View) {.slot.} =
    self.delegate.joinCommunityOrEditSharedAddresses()

  proc checkPermissions*(self: View, communityId: string, addressesToShare: string) {.slot.} =
    try:
      let sharedAddresses = map(parseJson(addressesToShare).getElems(), proc(x:JsonNode):string = x.getStr())
      self.delegate.checkPermissions(communityId, sharedAddresses)
    except Exception as e:
      echo "Error updating token model with addresses: ", e.msg

  proc getSpectatedCommunityPermissionModel(self: View): QVariant {.slot.} =
    return self.spectatedCommunityPermissionModelVariant

  QtProperty[QVariant] spectatedCommunityPermissionModel:
    read = getSpectatedCommunityPermissionModel

  proc curatedCommunitiesModel*(self: View): CuratedCommunityModel =
    result = self.curatedCommunitiesModel

  proc getCuratedCommunitiesModel(self: View): QVariant {.slot.} =
    return self.curatedCommunitiesModelVariant

  QtProperty[QVariant] curatedCommunities:
    read = getCuratedCommunitiesModel

  proc curatedCommunitiesLoadingChanged*(self: View) {.signal.}

  proc setCuratedCommunitiesLoading*(self: View, flag: bool) =
    if (self.curatedCommunitiesLoading == flag): return
    self.curatedCommunitiesLoading = flag
    self.curatedCommunitiesLoadingChanged()

  proc getCuratedCommunitiesLoading*(self: View): bool {.slot.} =
    return self.curatedCommunitiesLoading

  QtProperty[bool] curatedCommunitiesLoading:
    read = getCuratedCommunitiesLoading
    notify = curatedCommunitiesLoadingChanged

  proc discordFileListModel*(self: View): DiscordFileListModel =
    result = self.discordFileListModel

  proc getDiscordFileListModel(self: View): QVariant{.slot.} =
    return self.discordFileListModelVariant

  QtProperty[QVariant] discordFileList:
    read = getDiscordFileListModel

  proc discordCategoriesModel*(self: View): DiscordCategoriesModel =
    result = self.discordCategoriesModel

  proc getDiscordCategoriesModel*(self: View): QVariant {.slot.} =
    return self.discordCategoriesModelVariant

  QtProperty[QVariant] discordCategories:
    read = getDiscordCategoriesModel

  proc discordChannelsModel*(self: View): DiscordChannelsModel =
    result = self.discordChannelsModel

  proc getDiscordChannelsModel*(self: View): QVariant {.slot.} =
    return self.discordChannelsModelVariant

  QtProperty[QVariant] discordChannels:
    read = getDiscordChannelsModel

  proc discordImportTasksModel*(self: View): DiscordImportTasksModel =
    result = self.discordImportTasksModel

  proc getDiscordImportTasksModel(self: View): QVariant {.slot.} =
    return self.discordImportTasksModelVariant

  QtProperty[QVariant] discordImportTasks:
    read = getDiscordImportTasksModel

  proc discordDataExtractionInProgressChanged*(self: View) {.signal.}

  proc getDiscordDataExtractionInProgress(self: View): bool {.slot.} =
    return self.discordDataExtractionInProgress

  proc setDiscordDataExtractionInProgress*(self: View, inProgress: bool) {.slot.} =
    if (self.discordDataExtractionInProgress == inProgress): return
    self.discordDataExtractionInProgress = inProgress
    self.discordDataExtractionInProgressChanged()

  QtProperty[bool] discordDataExtractionInProgress:
    read = getDiscordDataExtractionInProgress
    notify = discordDataExtractionInProgressChanged

  proc discordImportCommunityIdChanged*(self: View) {.signal.}

  proc getDiscordImportCommunityId(self: View): string {.slot.} =
    return self.discordImportCommunityId

  proc setDiscordImportCommunityId*(self: View, id: string) {.slot.} =
    if (self.discordImportCommunityId == id): return
    self.discordImportCommunityId = id
    self.discordImportCommunityIdChanged()

  QtProperty[string] discordImportCommunityId:
    read = getDiscordImportCommunityId
    notify = discordImportCommunityIdChanged

  proc discordImportCommunityImageChanged*(self: View) {.signal.}

  proc getDiscordImportCommunityImage(self: View): string {.slot.} =
    return self.discordImportCommunityImage

  proc setDiscordImportCommunityImage*(self: View, image: string) {.slot.} =
    if (self.discordImportCommunityImage == image): return
    self.discordImportCommunityImage = image
    self.discordImportCommunityImageChanged()

  QtProperty[string] discordImportCommunityImage:
    read = getDiscordImportCommunityImage
    notify = discordImportCommunityImageChanged

  proc discordImportCommunityNameChanged*(self: View) {.signal.}

  proc getDiscordImportCommunityName(self: View): string {.slot.} =
    return self.discordImportCommunityName

  proc setDiscordImportCommunityName*(self: View, name: string) {.slot.} =
    if (self.discordImportCommunityName == name): return
    self.discordImportCommunityName = name
    self.discordImportCommunityNameChanged()

  QtProperty[string] discordImportCommunityName:
    read = getDiscordImportCommunityName
    notify = discordImportCommunityNameChanged

  proc navigateToCommunity*(self: View, communityId: string) {.slot.} =
    self.delegate.navigateToCommunity(communityId)

  proc spectateCommunity*(self: View, communityId: string) {.slot.} =
    discard self.delegate.spectateCommunity(communityId)

  proc isDisplayNameDupeOfCommunityMember*(self: View, displayName: string): bool {.slot.} =
    return self.delegate.isDisplayNameDupeOfCommunityMember(displayName)

  proc createCommunity*(self: View, name: string,
                        description: string, introMessage: string, outroMessage: string,
                        access: int, color: string, tags: string,
                        imagePath: string,
                        aX: int, aY: int, bX: int, bY: int,
                        historyArchiveSupportEnabled: bool,
                        pinMessageAllMembersEnabled: bool, bannerJsonStr: string) {.slot.} =
    self.delegate.createCommunity(name, description, introMessage, outroMessage, access, color, tags,
                                  imagePath, aX, aY, bX, bY, historyArchiveSupportEnabled, pinMessageAllMembersEnabled,
                                  bannerJsonStr)

  proc clearFileList*(self: View) {.slot.} =
    self.discordFileListModel.clearItems()
    self.setDiscordImportErrorsCount(0)
    self.setDiscordImportWarningsCount(0)

  proc clearDiscordCategoriesAndChannels*(self: View) {.slot.} =
    self.discordCategoriesModel.clearItems()
    self.discordChannelsModel.clearItems()

  proc resetDiscordImport*(self: View, cancelled: bool) {.slot.} =
    self.clearFileList()
    self.clearDiscordCategoriesAndChannels()
    self.discordImportTasksModel.clearItems()
    self.setDiscordImportProgress(0)
    self.setDiscordImportProgressStopped(false)
    self.setDiscordImportErrorsCount(0)
    self.setDiscordImportWarningsCount(0)
    self.setDiscordImportCommunityId("")
    self.setDiscordImportCommunityName("")
    self.discordImportChannelId = ""
    self.discordImportChannelName = ""
    self.discordImportedChannelId = ""
    self.discordImportedChannelCommunityId = ""
    self.setDiscordImportCommunityImage("")
    self.setDiscordImportHasCommunityImage(false)
    self.setDiscordImportInProgress(false)
    self.setDiscordImportCancelled(cancelled)


  proc requestImportDiscordCommunity*(self: View, name: string,
                        description: string, introMessage: string, outroMessage: string,
                        access: int, color: string, tags: string,
                        imagePath: string,
                        aX: int, aY: int, bX: int, bY: int,
                        historyArchiveSupportEnabled: bool,
                        pinMessageAllMembersEnabled: bool,
                        fromTimestamp: int) {.slot.} =
    let selectedItems = self.discordChannelsModel.getSelectedItems()
    var filesToImport: seq[string] = @[]

    for i in 0 ..< selectedItems.len:
      filesToImport.add(selectedItems[i].getFilePath())

    self.resetDiscordImport(false)
    self.setDiscordImportInProgress(true)
    self.delegate.requestImportDiscordCommunity(name, description, introMessage, outroMessage, access, color, tags,
                                  imagePath, aX, aY, bX, bY, historyArchiveSupportEnabled, pinMessageAllMembersEnabled,
                                  filesToImport, fromTimestamp)

  proc requestImportDiscordChannel*(self: View, name: string, discordChannelId: string, communityId: string,
                        description: string, color: string, emoji: string,
                        fromTimestamp: int) {.slot.} =
    let selectedItems = self.discordChannelsModel.getSelectedItems()
    var filesToImport: seq[string] = @[]

    for i in 0 ..< selectedItems.len:
      filesToImport.add(selectedItems[i].getFilePath())

    self.resetDiscordImport(false)
    self.setDiscordImportInProgress(true)
    self.delegate.requestImportDiscordChannel(
            name,
            discordChannelId,
            communityId,
            description,
            color,
            emoji,
            filesToImport,
            fromTimestamp)

  proc cancelRequestToJoinCommunity*(self: View, communityId: string) {.slot.} =
    self.delegate.cancelRequestToJoinCommunity(communityId)

  proc requestCommunityInfo*(self: View, communityId: string, importing: bool) {.slot.} =
    self.delegate.requestCommunityInfo(communityId, importing)

  proc getCommunityDetails*(self: View, communityId: string): string {.slot.} =
    let communityItem = self.model.getItemById(communityId)
    if (communityItem.id == ""):
      return ""

    # TODO: unify with observed community approach
    let jsonObj = %* {
      "name": communityItem.name,
      "image": communityItem.image,
      "color": communityItem.color,
      "isControlNode": communityItem.isControlNode,
    }
    return $jsonObj

  proc isUserMemberOfCommunity*(self: View, communityId: string): bool {.slot.} =
    self.delegate.isUserMemberOfCommunity(communityId)

  proc isMyCommunityRequestPending*(self: View, communityId: string): bool {.slot.} =
    self.delegate.isMyCommunityRequestPending(communityId)

  proc importingCommunityStateChanged*(self:View, communityId: string, state: int, errorMsg: string) {.signal.}
  proc emitImportingCommunityStateChangedSignal*(self: View, communityId: string, state: int, errorMsg: string) =
    self.importingCommunityStateChanged(communityId, state, errorMsg)

  proc communityInfoRequestCompleted*(self: View, communityId: string, errorMsg: string) {.signal.}
  proc emitCommunityInfoRequestCompleted*(self: View, communityId: string, errorMsg: string) =
    self.communityInfoRequestCompleted(communityId, errorMsg)

  proc removeFileListItem*(self: View, filePath: string) {.slot.} =
    var path = filePath
    if path.startsWith("file://"):
      path = replace(path, "file://", "")

    let categoryId = self.discordChannelsModel.getChannelCategoryIdByFilePath(path)

    # file list still uses full path, so relying on `filePath` here
    self.discordFileListModel.removeItem(filePath)
    self.discordChannelsModel.removeItemsByFilePath(path)

    if categoryId != "" and not self.discordChannelsModel.hasItemsWithCategoryId(categoryId):
      self.discordCategoriesModel.removeItem(categoryId)

  proc setFileListItems*(self: View, filePaths: string) {.slot.} =
    let filePaths = filePaths.split(',')
    var fileItems: seq[DiscordFileItem] = @[]

    for filePath in filePaths:
      var fileItem = DiscordFileItem()
      fileItem.filePath = filePath
      fileItem.errorMessage = ""
      fileItem.errorCode = 0
      fileItem.selected = true
      fileItem.validated = false
      fileItems.add(fileItem)
    self.discordFileListModel.setItems(fileItems)
    self.setDiscordImportErrorsCount(0)
    self.setDiscordImportWarningsCount(0)

  proc requestExtractDiscordChannelsAndCategories*(self: View) {.slot.} =
    let filePaths = self.discordFileListModel.getSelectedFilePaths()
    self.delegate.requestExtractDiscordChannelsAndCategories(filePaths)

  proc requestCancelDiscordCommunityImport*(self: View, id: string) {.slot.} =
    self.delegate.requestCancelDiscordCommunityImport(id)
    self.resetDiscordImport(true)

  proc requestCancelDiscordChannelImport*(self: View, discordChannelId: string) {.slot.} =
    self.delegate.requestCancelDiscordChannelImport(discordChannelId)
    self.resetDiscordImport(true)

  proc removeImportedDiscordChannel*(self: View) {.slot.} =
    self.delegate.removeCommunityChat(self.discordImportedChannelCommunityId, self.discordImportedChannelId)
    self.resetDiscordImport(true)

  proc resetImport*(self: View) {.slot.} =
    self.resetDiscordImport(true)

  proc toggleDiscordCategory*(self: View, id: string, selected: bool) {.slot.} =
    if selected:
      self.discordCategoriesModel.selectItem(id)
      self.discordChannelsModel.selectItemsByCategoryId(id)
    else:
      self.discordCategoriesModel.unselectItem(id)
      self.discordChannelsModel.unselectItemsByCategoryId(id)

  proc toggleDiscordChannel*(self: View, id: string, selected: bool) {.slot.} =
    if selected:
      self.discordChannelsModel.selectItem(id)
      let item = self.discordChannelsModel.getItem(id)
      self.discordCategoriesModel.selectItem(item.getCategoryId())
    else:
      self.discordChannelsModel.unselectItem(id)
      let item = self.discordChannelsModel.getItem(id)
      if self.discordChannelsModel.allChannelsByCategoryUnselected(item.getCategoryId()):
        self.discordCategoriesModel.unselectItem(item.getCategoryId())

  proc discordImportChannelChanged*(self: View) {.signal.}

  proc toggleOneDiscordChannel*(self: View, id: string) {.slot.} =
    let item = self.discordChannelsModel.getItem(id)
    self.discordChannelsModel.selectOneItem(id)
    self.discordCategoriesModel.selectOneItem(item.getCategoryId())
    self.discordImportChannelId = id
    self.discordImportChannelName = item.getName()
    self.discordImportChannelChanged()

  proc setDiscordImportedChannelCommunityId*(self: View, id: string) =
    if (self.discordImportedChannelCommunityId == id): return
    self.discordImportedChannelCommunityId = id

  proc setDiscordImportChannelId*(self: View, id: string) {.slot.} =
    if (self.discordImportChannelId == id): return
    self.discordImportChannelId = id
    self.discordImportChannelChanged()

  proc getDiscordImportChannelId*(self: View): string {.slot.} =
    return self.discordImportChannelId

  QtProperty[string] discordImportChannelId:
    read = getDiscordImportChannelId
    notify = discordImportChannelChanged

  proc setDiscordImportChannelName*(self: View, name: string) {.slot.} =
    if (self.discordImportChannelName == name): return
    self.discordImportChannelName = name
    self.discordImportChannelChanged()

  proc getDiscordImportChannelName(self: View): string {.slot.} =
    return self.discordImportChannelName

  QtProperty[string] discordImportChannelName:
    read = getDiscordImportChannelName
    notify = discordImportChannelChanged

  proc tokenListModel*(self: View): TokenListModel =
    result = self.tokenListModel

  proc getTokenListModel(self: View): QVariant{.slot.} =
    return self.tokenListModelVariant

  QtProperty[QVariant] tokenList:
    read = getTokenListModel

  proc tokenListLoadingChanged*(self: View) {.signal.}
  proc getTokenListLoading(self: View): bool {.slot.} =
    return self.tokenListLoading
  proc setTokenListLoading*(self: View, loading: bool) =
    if self.tokenListLoading == loading:
      return
    self.tokenListLoading = loading
    self.tokenListLoadingChanged()
  QtProperty[bool] tokenListLoading:
    read = getTokenListLoading
    notify = tokenListLoadingChanged

  proc loadTokenList*(self: View) {.slot.} =
    self.delegate.loadTokenList()

  proc collectiblesListModel*(self: View): TokenListModel =
    result = self.collectiblesListModel

  proc getCollectiblesListModel(self: View): QVariant{.slot.} =
    return self.collectiblesListModelVariant

  QtProperty[QVariant] collectiblesModel:
    read = getCollectiblesListModel

  proc shareCommunityUrlWithChatKey*(self: View, communityId: string): string {.slot.} =
    return self.delegate.shareCommunityUrlWithChatKey(communityId)

  proc shareCommunityUrlWithData*(self: View, communityId: string): string {.slot.} =
    return self.delegate.shareCommunityUrlWithData(communityId)

  proc shareCommunityChannelUrlWithChatKey*(self: View, communityId: string, chatId: string): string {.slot.} =
    return self.delegate.shareCommunityChannelUrlWithChatKey(communityId, chatId)

  proc shareCommunityChannelUrlWithData*(self: View, communityId: string, chatId: string): string {.slot.} =
    return self.delegate.shareCommunityChannelUrlWithData(communityId, chatId)

  proc prepareKeypairsForSigning*(self: View, communityId: string, ensName: string, addresses: string,
    airdropAddress: string, editMode: bool) {.slot.} =
    self.delegate.prepareKeypairsForSigning(communityId, ensName, addresses, airdropAddress, editMode)

  proc getCommunityPublicKeyFromPrivateKey*(self: View, communityPrivateKey: string): string {.slot.} =
    result = self.delegate.getCommunityPublicKeyFromPrivateKey(communityPrivateKey)

  proc myRevealedAirdropAddressesForCurrentCommunityChanged*(self: View) {.signal.}

  proc setMyRevealedAddressesForCurrentCommunity*(self: View, revealedAddress, airdropAddress: string) =
    self.myRevealedAddressesStringForCurrentCommunity = revealedAddress
    self.myRevealedAirdropAddressForCurrentCommunity = airdropAddress
    self.myRevealedAirdropAddressesForCurrentCommunityChanged()

  proc getMyRevealedAddressesStringForCurrentCommunity*(self: View): string {.slot.} =
    return self.myRevealedAddressesStringForCurrentCommunity

  QtProperty[string] myRevealedAddressesStringForCurrentCommunity:
    read = getMyRevealedAddressesStringForCurrentCommunity
    notify = myRevealedAirdropAddressesForCurrentCommunityChanged


  proc getMyRevealedAirdropAddressStringForCurrentCommunity*(self: View): string {.slot.} =
    return self.myRevealedAirdropAddressForCurrentCommunity

  QtProperty[string] myRevealedAirdropAddressForCurrentCommunity:
    read = getMyRevealedAirdropAddressStringForCurrentCommunity
    notify = myRevealedAirdropAddressesForCurrentCommunityChanged

  proc checkingPermissionsInProgressChanged*(self: View) {.signal.}

  proc setCheckingPermissionsInProgress*(self: View, inProgress: bool) =
    if (self.checkingPermissionsInProgress == inProgress): return
    self.checkingPermissionsInProgress = inProgress
    self.checkingPermissionsInProgressChanged()

  proc getCheckingPermissionsInProgress*(self: View): bool {.slot.} =
    return self.checkingPermissionsInProgress

  QtProperty[bool] requirementsCheckPending:
    read = getCheckingPermissionsInProgress
    notify = checkingPermissionsInProgressChanged

  proc getCheckingPermissionToJoinInProgress*(self: View): bool {.slot.} =
    self.delegate.getCheckingPermissionToJoinInProgress

  proc checkingPermissionToJoinInProgressChanged*(self: View) {.signal.}

  QtProperty[bool] checkingPermissionToJoinInProgress:
    read = getCheckingPermissionToJoinInProgress
    notify = checkingPermissionToJoinInProgressChanged

  proc joinPermissionsCheckSuccessfulChanged*(self: View) {.signal.}

  proc setJoinPermissionsCheckSuccessful*(self: View, successful: bool) =
    if (self.joinPermissionsCheckCompletedWithoutErrors == successful): return
    self.joinPermissionsCheckCompletedWithoutErrors = successful
    self.joinPermissionsCheckSuccessfulChanged()

  proc getJoinPermissionsCheckSuccessful*(self: View): bool {.slot.} =
    return self.joinPermissionsCheckCompletedWithoutErrors

  QtProperty[bool] joinPermissionsCheckCompletedWithoutErrors:
    read = getJoinPermissionsCheckSuccessful
    notify = joinPermissionsCheckSuccessfulChanged

  proc channelsPermissionsCheckSuccessfulChanged*(self: View) {.signal.}

  proc setChannelsPermissionsCheckSuccessful*(self: View, successful: bool) =
    if (self.channelsPermissionsCheckSuccessful == successful): return
    self.channelsPermissionsCheckSuccessful = successful
    self.channelsPermissionsCheckSuccessfulChanged()

  proc getChannelsPermissionsCheckSuccessful*(self: View): bool {.slot.} =
    return self.channelsPermissionsCheckSuccessful

  QtProperty[bool] channelsPermissionsCheckSuccessful:
    read = getChannelsPermissionsCheckSuccessful
    notify = channelsPermissionsCheckSuccessfulChanged

  proc keypairsSigningModel*(self: View): KeyPairModel =
    return self.keypairsSigningModel

  proc keypairsSigningModelChanged*(self: View) {.signal.}
  proc getKeypairsSigningModel(self: View): QVariant {.slot.} =
    return (if self.keypairsSigningModel.isNil: newQVariant() else: newQVariant(self.keypairsSigningModel))

  QtProperty[QVariant] keypairsSigningModel:
    read = getKeypairsSigningModel
    notify = keypairsSigningModelChanged

  proc setKeypairsSigningModelItems*(self: View, items: seq[KeyPairItem]) =
    if self.keypairsSigningModel.isNil:
      self.keypairsSigningModel = newKeyPairModel()
    if self.keypairsSigningModelVariant.isNil:
      self.keypairsSigningModelVariant = newQVariant(self.keypairsSigningModel)
    self.keypairsSigningModel.setItems(items)
    self.keypairsSigningModelChanged()

  proc allSharedAddressesSigned*(self: View) {.signal.}
  proc sendAllSharedAddressesSignedSignal*(self: View) =
    self.allSharedAddressesSigned()

  proc promoteSelfToControlNode*(self: View, communityId: string) {.slot.} =
    self.delegate.promoteSelfToControlNode(communityId)

  proc delete*(self: View) =
    self.QObject.delete

