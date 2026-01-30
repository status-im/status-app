import nimqml, strutils, sequtils, sugar, tables, stint, chronicles, json

import ./io_interface
import ../io_interface as delegate_interface
import ./view, ./controller
import ./models/curated_community_item
import ./models/curated_community_model
import ./models/discord_category_item
import ./models/discord_categories_model
import ./models/discord_channel_item
import ./models/discord_channels_model
import ./models/discord_file_list_model
import ./models/discord_import_task_item
import ./models/discord_import_tasks_model
import app/modules/shared_models/[section_model, section_item, token_permissions_model, token_permission_item,
  token_list_item, token_list_model, token_criteria_item, token_criteria_model, token_permission_chat_list_model, keypair_model]
import app/global/global_singleton
import app/global/app_signals
import app/core/eventemitter
import app_service/common/types
import app_service/common/utils as common_utils
import app_service/service/community/service as community_service
import app_service/service/chat/service as chat_service
import app_service/service/network/service as networks_service
import app_service/service/transaction/service as transaction_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/chat/dto/chat
import app_service/service/keycard/service as keycard_service
import ./tokens/module as community_tokens_module

import app/modules/shared/keypairs

export io_interface

type
  ImportCommunityState {.pure.} = enum
    Imported = 0
    ImportingInProgress
    ImportingError
    ImportingCanceled

type
  Action {.pure.} = enum
    None = 0,
    JoinCommunity
    EditSharedAddresses

type
  AddressToShareDetails = object
    keyUid: string
    address: string
    path: string
    isAirdropAddress: bool
    messageToBeSigned: string
    signature: string

type
  JoiningCommunityDetails = object
    communityId: string
    communityIdForPermissions: string
    communityIdForRevealedAccounts: string
    ensName: string
    addressesToShare: OrderedTable[string, AddressToShareDetails] ## [address, AddressToShareDetails]
    profilePassword: string
    profilePin: string
    action: Action

proc clear(self: var JoiningCommunityDetails) =
  self = JoiningCommunityDetails()

proc allSigned(self: JoiningCommunityDetails): bool =
  for _, details in self.addressesToShare.pairs:
    if details.signature.len == 0:
      return false
  return true

type
  Module*  = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    events: EventEmitter
    curatedCommunitiesLoaded: bool
    communityTokensModule: community_tokens_module.AccessInterface
    checkingPermissionToJoinInProgress: bool
    checkingAllChannelPermissionsInProgress: bool
    joiningCommunityDetails: JoiningCommunityDetails

# Forward declaration
method setCommunityTags*(self: Module, communityTags: string)
method setAllCommunities*(self: Module, communities: seq[CommunityDto])
method setCuratedCommunities*(self: Module, curatedCommunities: seq[CommunityDto])
proc buildTokensAndCollectiblesFromAllCommunities(self: Module)
proc buildTokensAndCollectiblesFromCommunities(self: Module, communities: seq[CommunityDto])
proc setCheckingPermissionToJoinInProgress(self: Module, inProgress: bool)

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    communityService: community_service.Service,
    communityTokensService: community_tokens_service.Service,
    networksService: networks_service.Service,
    transactionService: transaction_service.Service,
    tokensService: token_service.Service,
    chatService: chat_service.Service,
    walletAccountService: wallet_account_service.Service,
    keycardService: keycard_service.Service,
    ): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(
    result,
    events,
    communityService,
    communityTokensService,
    networksService,
    tokensService,
    chatService,
    walletAccountService,
    keycardService,
  )
  result.communityTokensModule = community_tokens_module.newCommunityTokensModule(result, events, walletAccountService,
  communityTokensService, transactionService, networksService, communityService, keycardService)
  result.moduleLoaded = false
  result.events = events
  result.curatedCommunitiesLoaded = false
  result.setCheckingPermissionToJoinInProgress(false)
  result.checkingAllChannelPermissionsInProgress = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete
  self.communityTokensModule.delete

method cleanJoinEditCommunityData*(self: Module) =
  self.joiningCommunityDetails.clear()

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("communitiesModule", self.viewVariant)
  self.controller.init()
  self.communityTokensModule.load()
  self.view.load()
  self.onWalletAccountTokensRebuilt()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true

  self.delegate.communitiesModuleDidLoad()

method communityDataLoaded*(self: Module) =
  self.setCommunityTags(self.controller.getCommunityTags())
  self.setAllCommunities(self.controller.getAllCommunities())
  self.buildTokensAndCollectiblesFromAllCommunities()

method onActivated*(self: Module) =
  if self.curatedCommunitiesLoaded:
    return
  self.controller.asyncLoadCuratedCommunities()

method curatedCommunitiesLoaded*(self: Module, curatedCommunities: seq[CommunityDto]) =
  self.curatedCommunitiesLoaded = true
  self.setCuratedCommunities(curatedCommunities)
  self.view.setCuratedCommunitiesLoading(false)

method curatedCommunitiesLoading*(self: Module) =
  self.view.setCuratedCommunitiesLoading(true)

method curatedCommunitiesLoadingFailed*(self: Module) =
  # TODO we probably want to show an error in the UI later
  self.curatedCommunitiesLoaded = true
  self.view.setCuratedCommunitiesLoading(false)

method getCommunityItem(self: Module, community: CommunityDto): SectionItem =
  return initSectionItem(
      community.id,
      SectionType.Community,
      community.name,
      community.memberRole,
      community.isControlNode,
      community.description,
      community.introMessage,
      community.outroMessage,
      community.images.thumbnail,
      community.images.banner,
      icon = "",
      community.color,
      community.tags,
      hasNotification = false,
      notificationsCount = 0,
      active = false,
      enabled = true,
      community.joined,
      community.canJoin,
      community.spectated,
      community.canManageUsers,
      community.canRequestAccess,
      community.isMember,
      isBanned = false,
      community.permissions.access,
      community.permissions.ensOnly,
      community.muted,
      # No need to add the members as this module's communities are only used for display purposes
      joinedMembersCount = community.members.len,
      historyArchiveSupportEnabled = community.settings.historyArchiveSupportEnabled,
      encrypted = community.encrypted,
      communityTokens = @[],
      activeMembersCount = int(community.activeMembersCount),
    )

proc getCuratedCommunityItem(self: Module, community: CommunityDto): CuratedCommunityItem =
  var tokenPermissionsItems: seq[TokenPermissionItem] = @[]

  for id, tokenPermission in community.tokenPermissions:
    let chats = community.getCommunityChats(tokenPermission.chatIds)
    let tokenPermissionItem = buildTokenPermissionItem(tokenPermission, chats)
    tokenPermissionsItems.add(tokenPermissionItem)

  let myPublicKey = singletonInstance.userProfile.getPubKey()
  var amIbanned = false
  if myPublicKey in community.pendingAndBannedMembers:
    let state = community.pendingAndBannedMembers[myPublicKey]
    amIbanned = isBanned(state)

  return initCuratedCommunityItem(
    community.id,
    community.name,
    community.description,
    community.isAvailable,
    community.images.thumbnail,
    community.images.banner,
    community.color,
    community.tags,
    len(community.members),
    int(community.activeMembersCount),
    community.featuredInDirectory,
    tokenPermissionsItems,
    amIbanned,
    community.joined,
    community.encrypted,
  )

proc getDiscordCategoryItem(self: Module, c: DiscordCategoryDto): DiscordCategoryItem =
  return initDiscordCategoryItem(
      c.id,
      c.name,
      true)

proc getDiscordChannelItem(self: Module, c: DiscordChannelDto): DiscordChannelItem =
  return initDiscordChannelItem(
      c.id,
      c.categoryId,
      c.name,
      c.description,
      c.filePath,
      true)

method isDisplayNameDupeOfCommunityMember*(self: Module, displayName: string): bool =
  self.controller.isDisplayNameDupeOfCommunityMember(displayName)

method setCommunityTags*(self: Module, communityTags: string) =
  self.view.setCommunityTags(communityTags)

method setAllCommunities*(self: Module, communities: seq[CommunityDto]) =
  var items: seq[SectionItem] = @[]
  for community in communities:
    items.add(self.getCommunityItem(community))
  self.view.model.addItems(items)

method communityAdded*(self: Module, community: CommunityDto) =
  self.view.addItem(self.getCommunityItem(community))

method spectateCommunity*(self: Module, communityId: string): string =
  self.controller.spectateCommunity(communityId)

method navigateToCommunity*(self: Module, communityId: string) =
  let community = self.view.model().getItemById(communityId)
  if community.isEmpty() or not (community.spectated() or community.joined()):
    discard self.controller.spectateCommunity(communityId)
  else:
    self.delegate.setActiveSectionById(communityId)

method communityEdited*(self: Module, community: CommunityDto) =
  self.view.updateItem(self.getCommunityItem(community))

method setCuratedCommunities*(self: Module, curatedCommunities: seq[CommunityDto]) =
  for community in curatedCommunities:
    self.view.curatedCommunitiesModel().addItem(self.getCuratedCommunityItem(community))

method curatedCommunityAdded*(self: Module, community: CommunityDto) =
  self.view.curatedCommunitiesModel().addItem(self.getCuratedCommunityItem(community))

method curatedCommunityEdited*(self: Module, community: CommunityDto) =
  if (self.view.curatedCommunitiesModel.containsItemWithId(community.id)):
    # FIXME: CommunityDto should not contain fields not present in the stauts-go's community update,
    # otherwise the state will vanish. For instance, the `listedInDirectory` and `featuredInDirectory`
    # fields are vanished when community update is received.
    var communityCopy = community
    communityCopy.featuredInDirectory = self.view.curatedCommunitiesModel.getItemById(community.id).getFeatured()
    self.view.curatedCommunitiesModel().addItem(self.getCuratedCommunityItem(communityCopy))

method createCommunity*(self: Module, name: string,
                        description, introMessage: string, outroMessage: string,
                        access: int, color: string, tags: string,
                        imagePath: string,
                        aX: int, aY: int, bX: int, bY: int,
                        historyArchiveSupportEnabled: bool,
                        pinMessageAllMembersEnabled: bool,
                        bannerJsonStr: string) =
  self.controller.createCommunity(name, description, introMessage, outroMessage, access, color, tags,
                                  imagePath, aX, aY, bX, bY, historyArchiveSupportEnabled, pinMessageAllMembersEnabled,
                                  bannerJsonStr)

method communityMuted*(self: Module, communityId: string, muted: bool) =
  self.view.model().setMuted(communityId, muted)

method communityAccessRequested*(self: Module, communityId: string) =
  self.cleanJoinEditCommunityData()
  self.view.communityAccessRequested(communityId)

method communityAccessFailed*(self: Module, communityId, err: string) =
  error "communities: ", err
  self.cleanJoinEditCommunityData()
  self.delegate.updateRequestToJoinState(communityId, RequestToJoinState.None)
  self.view.communityAccessFailed(communityId, err)

method communityEditSharedAddressesSucceeded*(self: Module, communityId: string) =
  self.cleanJoinEditCommunityData()
  self.view.communityEditSharedAddressesSucceeded(communityId)

method communityEditSharedAddressesFailed*(self: Module, communityId, error: string) =
  self.cleanJoinEditCommunityData()
  self.view.communityEditSharedAddressesFailed(communityId, error)

method communityHistoryArchivesDownloadStarted*(self: Module, communityId: string) =
  self.view.setDownloadingCommunityHistoryArchives(true)

method communityHistoryArchivesDownloadFinished*(self: Module, communityId: string) =
  self.view.setDownloadingCommunityHistoryArchives(false)

method discordCategoriesAndChannelsExtracted*(self: Module, categories: seq[DiscordCategoryDto], channels: seq[DiscordChannelDto], oldestMessageTimestamp: int, errors: Table[string, DiscordImportError], errorsCount: int) =

  for filePath in errors.keys:
    self.view.discordFileListModel().updateErrorState(filePath, errors[filePath].message, errors[filePath].code)

  self.view.discordFileListModel().setAllValidated()

  self.view.discordCategoriesModel().clearItems()
  self.view.discordChannelsModel().clearItems()
  self.view.setDiscordOldestMessageTimestamp(oldestMessageTimestamp)

  for discordCategory in categories:
    self.view.discordCategoriesModel().addItem(self.getDiscordCategoryItem(discordCategory))
  for discordChannel in channels:
    self.view.discordChannelsModel().addItem(self.getDiscordChannelItem(discordChannel))

  self.view.setDiscordDataExtractionInProgress(false)
  self.view.setDiscordImportErrorsCount(errorsCount)
  self.view.discordChannelsModel().hasSelectedItemsChanged()

method cancelRequestToJoinCommunity*(self: Module, communityId: string) =
  self.controller.cancelRequestToJoinCommunity(communityId)

method requestCommunityInfo*(self: Module, communityId: string, importing: bool) =
  self.controller.requestCommunityInfo(communityId, importing)

method isUserMemberOfCommunity*(self: Module, communityId: string): bool =
  self.controller.isUserMemberOfCommunity(communityId)

method isMyCommunityRequestPending*(self: Module, communityId: string): bool =
  self.controller.isMyCommunityRequestPending(communityId)

method communityDataImported*(self: Module, community: CommunityDto) =
  self.view.addItem(self.getCommunityItem(community))
  self.buildTokensAndCollectiblesFromCommunities(@[community])
  self.view.emitCommunityInfoRequestCompleted(community.id, "")

method communityInfoRequestFailed*(self: Module, communityId: string, errorMsg: string) =
  self.view.emitCommunityInfoRequestCompleted(communityId, errorMsg)

method onImportCommunityErrorOccured*(self: Module, communityId: string, error: string) =
  self.view.emitImportingCommunityStateChangedSignal(communityId, ImportCommunityState.ImportingError.int, error)

method requestExtractDiscordChannelsAndCategories*(self: Module, filesToImport: seq[string]) =
  self.view.setDiscordDataExtractionInProgress(true)
  self.controller.requestExtractDiscordChannelsAndCategories(filesToImport)

method requestImportDiscordCommunity*(self: Module, name: string, description, introMessage, outroMessage: string, access: int,
                        color: string, tags: string, imagePath: string, aX: int, aY: int, bX: int, bY: int,
                        historyArchiveSupportEnabled: bool, pinMessageAllMembersEnabled: bool, filesToImport: seq[string],
                        fromTimestamp: int) =
  self.view.setDiscordImportHasCommunityImage(imagePath != "")
  self.controller.requestImportDiscordCommunity(name, description, introMessage, outroMessage, access, color, tags, imagePath, aX, aY, bX, bY, historyArchiveSupportEnabled, pinMessageAllMembersEnabled, filesToImport, fromTimestamp)

method requestImportDiscordChannel*(self: Module, name: string, discordChannelId: string, communityId: string, description: string,
                        color: string, emoji: string, filesToImport: seq[string],
                        fromTimestamp: int) =
  self.controller.requestImportDiscordChannel(name, discordChannelId, communityId, description, color, emoji, filesToImport, fromTimestamp)

proc getDiscordImportTaskItem(self: Module, t: DiscordImportTaskProgress): DiscordImportTaskItem =
  return initDiscordImportTaskItem(
      t.`type`,
      t.progress,
      t.state,
      t.errors,
      t.stopped,
      t.errorsCount,
      t.warningsCount)

method discordImportProgressUpdated*(
    self: Module,
    communityId: string,
    communityName: string,
    communityImage: string,
    tasks: seq[DiscordImportTaskProgress],
    progress: float,
    errorsCount: int,
    warningsCount: int,
    stopped: bool,
    totalChunksCount: int,
    currentChunk: int
  ) =
  for task in tasks:
    if not self.view.discordImportTasksModel().hasItemByType(task.`type`):
      self.view.discordImportTasksModel().addItem(self.getDiscordImportTaskItem(task))
    else:
      self.view.discordImportTasksModel().updateItem(task)

  self.view.setDiscordImportCommunityId(communityId)
  self.view.setDiscordImportCommunityName(communityName)
  self.view.setDiscordImportCommunityImage(communityImage)
  self.view.setDiscordImportErrorsCount(errorsCount)
  self.view.setDiscordImportWarningsCount(warningsCount)
  # For some reason, exposing the global `progress` as QtProperty[float]`
  # doesn't translate well into QML.
  # That's why we pass it as integer instead.
  self.view.setDiscordImportProgress((progress*100).int)
  self.view.setDiscordImportProgressStopped(stopped)
  self.view.setDiscordImportProgressTotalChunksCount(totalChunksCount)
  self.view.setDiscordImportProgressCurrentChunk(currentChunk)
  if stopped or progress.int >= 1:
    self.view.setDiscordImportInProgress(false)

method removeCommunityChat*(self: Module, communityId: string, channelId: string) =
  self.controller.removeCommunityChat(communityId, channelId)

method discordImportChannelFinished*(self: Module, communityId: string, channelId: string) =
    self.view.setDiscordImportedChannelCommunityId(communityId)
    self.view.setDiscordImportedChannelId(channelId)
    self.view.setDiscordImportProgress(100)
    self.view.setDiscordImportProgressStopped(true)
    self.view.setDiscordImportInProgress(false)

method discordImportChannelCanceled*(self: Module, channelId: string) =
  if self.view.getDiscordImportChannelId() == channelId:
    self.view.setDiscordImportProgress(0)
    self.view.setDiscordImportProgressStopped(true)
    self.view.setDiscordImportInProgress(false)

method discordImportChannelProgressUpdated*(
    self: Module,
    channelId: string,
    channelName: string,
    tasks: seq[DiscordImportTaskProgress],
    progress: float,
    errorsCount: int,
    warningsCount: int,
    stopped: bool,
    totalChunksCount: int,
    currentChunk: int
  ) =
  for task in tasks:
    if not self.view.discordImportTasksModel().hasItemByType(task.`type`):
      self.view.discordImportTasksModel().addItem(self.getDiscordImportTaskItem(task))
    else:
      self.view.discordImportTasksModel().updateItem(task)

  self.view.setDiscordImportChannelId(channelId)
  self.view.setDiscordImportChannelName(channelName)
  self.view.setDiscordImportErrorsCount(errorsCount)
  self.view.setDiscordImportWarningsCount(warningsCount)
  # For some reason, exposing the global `progress` as QtProperty[float]`
  # doesn't translate well into QML.
  # That's why we pass it as integer instead.
  self.view.setDiscordImportProgress((progress*100).int)
  self.view.setDiscordImportProgressStopped(stopped)
  self.view.setDiscordImportProgressTotalChunksCount(totalChunksCount)
  self.view.setDiscordImportProgressCurrentChunk(currentChunk)
  if stopped or progress.int >= 1:
    self.view.setDiscordImportInProgress(false)

method requestCancelDiscordCommunityImport*(self: Module, id: string) =
  self.controller.requestCancelDiscordCommunityImport(id)

method requestCancelDiscordChannelImport*(self: Module, discordChannelId: string) =
  self.controller.requestCancelDiscordChannelImport(discordChannelId)

proc createCommunityTokenItem(self: Module, token: CommunityTokensMetadataDto, communityId: string, supply: string,
    infiniteSupply: bool, privilegesLevel: int): token_list_item.TokenListItem =
  let communityTokenDecimals = if token.tokenType == TokenType.ERC20: 18 else: 0
  let key = token.getContractIdFromFirstAddress()
  result = initTokenListItem(
    key = key,
    name = token.name,
    symbol = token.symbol,
    color = "", # community tokens don't have `color`
    image = token.image,
    category = ord(TokenListItemCategory.Community),
    communityId = communityId,
    supply,
    infiniteSupply,
    communityTokenDecimals,
    privilegesLevel
  )

proc buildCommunityTokenItemFallback(self: Module, communityTokens: seq[CommunityTokenDto],
    token: CommunityTokensMetadataDto, communityId: string): token_list_item.TokenListItem =
  # Set fallback supply to infinite in case we don't have it
  var supply = "1"
  var infiniteSupply = true
  var privilegesLevel = PrivilegesLevel.Community.int
  for communityToken in communityTokens:
    if communityToken.symbol == token.symbol:
      supply = communityToken.supply.toString(10)
      infiniteSupply = communityToken.infiniteSupply
      privilegesLevel = communityToken.privilegesLevel.int
      break
  return self.createCommunityTokenItem(token, communityId, supply, infiniteSupply, privilegesLevel)

proc buildTokensAndCollectiblesFromCommunities(self: Module, communities: seq[CommunityDto]) =
  var tokenListItems: seq[token_list_item.TokenListItem]
  var collectiblesListItems: seq[token_list_item.TokenListItem]

  let communityTokens = self.controller.getAllCommunityTokens()
  for community in communities:
    for tokenMetadata in community.communityTokensMetadata:
      var communityTokenItem = self.buildCommunityTokenItemFallback(communityTokens, tokenMetadata, community.id)

      if tokenMetadata.tokenType == TokenType.ERC20 and
        not self.view.tokenListModel().hasItem(tokenMetadata.symbol, community.id):
      # Community ERC20 tokens
        tokenListItems.add(communityTokenItem)

      if tokenMetadata.tokenType == TokenType.ERC721 and
        not self.view.collectiblesListModel().hasItem(tokenMetadata.symbol, community.id):
      # Community collectibles (ERC721 and others)
        collectiblesListItems.add(communityTokenItem)

  self.view.tokenListModel.addItems(tokenListItems)
  self.view.collectiblesListModel.addItems(collectiblesListItems)

proc buildTokensAndCollectiblesFromAllCommunities(self: Module) =
  let communities = self.controller.getAllCommunities()
  self.buildTokensAndCollectiblesFromCommunities(communities)

proc buildTokensAndCollectiblesFromWallet(self: Module) =
  var tokenListItems: seq[token_list_item.TokenListItem]

  # TODO: needs to be revisited, cause the UI displays tokens by symbol, while we're working with groups of tokens
  # this is ok, until all tokens belonging to the same group have the same crossChainId, otherwise the UI will display
  # those tokens as two items in the dropdown list (even they should be the same token group).
  # To fix this we need to change the UI of dropdown list and display chains next to selected token.
  # Or the contract addresses should be in tooltip or expanded for the item in dropdown list (just to be clear which token
  # is selected in the dropdown list in case of multiple tokens with the same symbol).

  # Common ERC20 tokens
  let allNetworks = self.controller.getCurrentNetworksChainIds()
  let tokenGroups = self.controller.getAllTokenGroupsForActiveNetworksMode()
  for tokenGroup in tokenGroups:
    let tokensForSelectedChains = tokenGroup.tokens.filter(t => allNetworks.contains(t.chainId))
    if tokensForSelectedChains.len <= 0:
      continue
    var privilegesLevel = PrivilegesLevel.Community.int
    let communityRelatedTokens = tokensForSelectedChains.filter(t => t.communityData.id.len > 0)
    if communityRelatedTokens.len > 0:
      for communityRelatedToken in communityRelatedTokens:
        let communityTokens = self.controller.getCommunityTokens(communityRelatedToken.communityData.id)
        for communityToken in communityTokens:
          if communityToken.symbol == communityRelatedToken.symbol:
            privilegesLevel = communityToken.privilegesLevel.int
            break

        let tokenListItem = initTokenListItem(
          key = communityRelatedToken.key,
          name = communityRelatedToken.name,
          symbol = communityRelatedToken.symbol,
          color = "",
          communityId = communityRelatedToken.communityData.id,
          image = "",
          category = ord(TokenListItemCategory.General),
          decimals = communityRelatedToken.decimals,
          privilegesLevel = privilegesLevel
        )
        tokenListItems.add(tokenListItem)
      continue

    let tokenListItem = initTokenListItem(
      key = tokenGroup.key,
      name = tokenGroup.name,
      symbol = tokenGroup.symbol,
      color = "",
      communityId = "",
      image = "",
      category = ord(TokenListItemCategory.General),
      decimals = tokenGroup.decimals,
      privilegesLevel = privilegesLevel
    )
    tokenListItems.add(tokenListItem)

  self.view.tokenListModel.setWalletTokenItems(tokenListItems)

method onWalletAccountTokensRebuilt*(self: Module) =
  self.buildTokensAndCollectiblesFromWallet()

method onCommunityTokenMetadataAdded*(self: Module, communityId: string, tokenMetadata: CommunityTokensMetadataDto) =
  let communityTokens = self.controller.getCommunityTokens(communityId)
  var tokenListItem = self.buildCommunityTokenItemFallback(communityTokens, tokenMetadata, communityId)

  if tokenMetadata.tokenType == TokenType.ERC721 and
      not self.view.collectiblesListModel().hasItem(tokenMetadata.symbol, communityId):
    self.view.collectiblesListModel.addItems(@[tokenListItem])
    return

  if tokenMetadata.tokenType == TokenType.ERC20 and
      not self.view.tokenListModel().hasItem(tokenMetadata.symbol, communityId):
    self.view.tokenListModel.addItems(@[tokenListItem])

method shareCommunityUrlWithChatKey*(self: Module, communityId: string): string =
  return self.controller.shareCommunityUrlWithChatKey(communityId)

method shareCommunityUrlWithData*(self: Module, communityId: string): string =
  return self.controller.shareCommunityUrlWithData(communityId)

method shareCommunityChannelUrlWithChatKey*(self: Module, communityId: string, chatId: string): string =
  return self.controller.shareCommunityChannelUrlWithChatKey(communityId, chatId)

method shareCommunityChannelUrlWithData*(self: Module, communityId: string, chatId: string): string =
  return self.controller.shareCommunityChannelUrlWithData(communityId, chatId)

proc signRevealedAddressesForNonKeycardKeypairs(self: Module): bool =
  var signingParams: seq[SignParamsDto]
  for address, details in self.joiningCommunityDetails.addressesToShare.pairs:
    if details.signature.len > 0:
      continue
    let keypair = self.controller.getKeypairByAccountAddress(address)
    if keypair.isNil:
      self.communityAccessFailed(self.joiningCommunityDetails.communityId, "cannot resolve keypair for address" & address)
      return false
    if keypair.migratedToKeycard():
      continue
    var finalPassword = self.joiningCommunityDetails.profilePassword
    if not singletonInstance.userProfile.getIsKeycardUser():
      finalPassword = common_utils.hashPassword(self.joiningCommunityDetails.profilePassword)
    signingParams.add(
      SignParamsDto(
        address: address,
        data: details.messageToBeSigned,
        password: finalPassword,
      )
    )
  if signingParams.len == 0:
    return true
  # signatures are returned in the same order as signingParams
  let signatures = self.controller.signCommunityRequests(self.joiningCommunityDetails.communityId, signingParams)
  if signatures.len != signingParams.len:
    return false
  for i in 0 ..< len(signingParams):
    self.joiningCommunityDetails.addressesToShare[signingParams[i].address].signature = signatures[i]
    self.view.keypairsSigningModel().setOwnershipVerified(self.joiningCommunityDetails.addressesToShare[signingParams[i].address].keyUid, true)
  return true

proc signRevealedAddressesForNonKeycardKeypairsAndEmitSignal(self: Module) =
  if self.signRevealedAddressesForNonKeycardKeypairs() and self.joiningCommunityDetails.allSigned():
    self.view.sendAllSharedAddressesSignedSignal()

proc anyProfileKeyPairAddressSelectedToBeRevealed(self: Module): bool =
  let profileKeypair = self.controller.getKeypairByKeyUid(singletonInstance.userProfile.getKeyUid())
  if profileKeypair.isNil:
    error "profile keypair not found"
    return false
  for acc in profileKeypair.accounts:
    for addrToReveal in self.joiningCommunityDetails.addressesToShare.keys:
      if cmpIgnoreCase(addrToReveal, acc.address) == 0:
        return true
  return false

method onUserAuthenticated*(self: Module, pin: string, password: string, keyUid: string) =
  if password == "" and pin == "":
    info "unsuccesful authentication"
    return

  self.joiningCommunityDetails.profilePassword = password
  self.joiningCommunityDetails.profilePin = pin

  # If any profile keypair address selected to be revealed and if the profile is a keycard user, we need to sign the request
  # for revealed profile addresses first, then using pubic encryption key to sign other non keycard key pairs.
  # If the profile is not a keycard user, we sign the request for it calling `signRevealedAddressesForNonKeycardKeypairs` function.
  if keyUid == singletonInstance.userProfile.getKeyUid() and
    singletonInstance.userProfile.getIsKeycardUser() and
    self.anyProfileKeyPairAddressSelectedToBeRevealed():
      self.signSharedAddressesForKeypair(keyUid, pin)
      return
  self.signRevealedAddressesForNonKeycardKeypairsAndEmitSignal()

method onDataSigned*(self: Module, keyUid: string, path: string, r: string, s: string, v: string, pin: string) =
  if keyUid.len == 0 or path.len == 0 or r.len == 0 or s.len == 0 or v.len == 0 or pin.len == 0:
    # being here is not an error
    return

  let vFixed = toLower(uint8(parseUint(v) + 27).toHex())

  for address, details in self.joiningCommunityDetails.addressesToShare.pairs:
    if details.keyUid != keyUid or details.path != path:
      continue
    self.joiningCommunityDetails.addressesToShare[address].signature = "0x" & r & s & vFixed
    break
  self.signSharedAddressesForKeypair(keyUid, pin)

  # Only if the signed request is for the profile revealed addresses, we need to try to sign other revealed addresses
  # for non profile key pairs. If they are already signed or moved to keycard we skip them (handled in signRevealedAddressesForNonKeycardKeypairsAndEmitSignal)
  if keyUid == singletonInstance.userProfile.getKeyUid():
    self.signRevealedAddressesForNonKeycardKeypairsAndEmitSignal()

method prepareKeypairsForSigning*(self: Module, communityId, ensName: string, addresses: string,
  airdropAddress: string, editMode: bool) =
  var addressesToShare: seq[string]
  try:
    addressesToShare = map(parseJson(addresses).getElems(), proc(x:JsonNode):string = x.getStr())
  except Exception as e:
    self.communityAccessFailed(communityId, "error parsing addresses: " & e.msg)
    return

  let allKeypairs = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = false,
    excludePrivateKeyKeypairs = false)
  for it in allKeypairs:
    let addressesToRemove = it.getAccountsModel().getItems()
      .map(x => x.getAddress())
      .filter(x => addressesToShare.filter(y => cmpIgnoreCase(y, x) == 0).len == 0)
    for address in addressesToRemove:
      it.removeAccountByAddress(address)
  let keypairsForSigning = allKeypairs.filter(x => x.getAccountsModel().getCount() > 0)
  self.view.setKeypairsSigningModelItems(keypairsForSigning)

  self.joiningCommunityDetails.communityId = communityId

  var signingParams: seq[SignParamsDto]
  if editMode:
    self.joiningCommunityDetails.action = Action.EditSharedAddresses
    signingParams = self.controller.generateEditCommunityRequestsForSigning(
      singletonInstance.userProfile.getPubKey(), communityId, addressesToShare)
  else:
    self.joiningCommunityDetails.action = Action.JoinCommunity
    self.joiningCommunityDetails.ensName = ensName
    signingParams = self.controller.generateJoiningCommunityRequestsForSigning(
      singletonInstance.userProfile.getPubKey(), communityId, addressesToShare)

  let findKeyUidAndPathForAddress = proc (items: seq[KeyPairItem], address: string): tuple[keyUid: string, path: string] =
    for it in items:
      for acc in it.getAccountsModel().getItems():
        if cmpIgnoreCase(acc.getAddress(), address) == 0:
          return (it.getKeyUid(), acc.getPath())
    return ("", "")

  for param in signingParams:
    let (keyUid, path) = findKeyUidAndPathForAddress(keypairsForSigning, param.address)
    let details = AddressToShareDetails(
      keyUid: keyUid,
      address: param.address,
      path: path,
      isAirdropAddress: if cmpIgnoreCase(param.address, airdropAddress) == 0: true else: false,
      messageToBeSigned: param.data
    )
    self.joiningCommunityDetails.addressesToShare[param.address] = details

method signProfileKeypairAndAllNonKeycardKeypairs*(self: Module) =
  self.controller.authenticate()

# if pin is provided we're signing on a keycard silently
method signSharedAddressesForKeypair*(self: Module, keyUid: string, pin: string) =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil:
    self.communityAccessFailed(self.joiningCommunityDetails.communityId, "cannot resolve keypair for keyUid " & keyUid)
    return
  for acc in keypair.accounts:
    for address, details in self.joiningCommunityDetails.addressesToShare.pairs:
      if cmpIgnoreCase(address, acc.address) != 0:
        continue
      if details.signature.len > 0:
        continue
      self.controller.runSigningOnKeycard(keyUid, details.path, details.messageToBeSigned, pin)
      return
  self.view.keypairsSigningModel().setOwnershipVerified(keyUid, true)
  if self.joiningCommunityDetails.allSigned():
    self.view.sendAllSharedAddressesSignedSignal()

method joinCommunityOrEditSharedAddresses*(self: Module) =
  if not self.joiningCommunityDetails.allSigned():
    self.communityAccessFailed(self.joiningCommunityDetails.communityId, "unexpected call to join community function before all addresses are signed")
    return
  var
    addressesToShare: seq[string]
    airdropAddress: string
    signatures: seq[string]

  for _, details in self.joiningCommunityDetails.addressesToShare.pairs:
    addressesToShare.add(details.address)
    if details.isAirdropAddress:
      airdropAddress = details.address
    signatures.add(details.signature)

  if self.joiningCommunityDetails.action == Action.JoinCommunity:
    self.controller.asyncRequestToJoinCommunity(self.joiningCommunityDetails.communityId,
      self.joiningCommunityDetails.ensName,
      addressesToShare,
      airdropAddress,
      signatures)

    self.delegate.updateRequestToJoinState(self.joiningCommunityDetails.communityId, RequestToJoinState.InProgress)

    # The user reveals address after sending join coummunity request, before that he sees only the name of the wallet account, not the address.
    self.events.emit(MARK_WALLET_ADDRESSES_AS_SHOWN, WalletAddressesArgs(addresses: addressesToShare))
    return
  if self.joiningCommunityDetails.action == Action.EditSharedAddresses:
    self.controller.asyncEditSharedAddresses(self.joiningCommunityDetails.communityId,
      addressesToShare,
      airdropAddress,
      signatures)
    # The user reveals address after sending edit coummunity request, before that he sees only the name of the wallet account, not the address.
    self.events.emit(MARK_WALLET_ADDRESSES_AS_SHOWN, WalletAddressesArgs(addresses: addressesToShare))
    return
  self.communityAccessFailed(self.joiningCommunityDetails.communityId, "unexpected action")

method getCommunityPublicKeyFromPrivateKey*(self: Module, communityPrivateKey: string): string =
  result = self.controller.getCommunityPublicKeyFromPrivateKey(communityPrivateKey)

method checkPermissions*(self: Module, communityId: string, sharedAddresses: seq[string]) =
  self.joiningCommunityDetails.communityIdForPermissions = communityId

  self.controller.asyncCheckPermissionsToJoin(communityId, sharedAddresses)
  self.view.setJoinPermissionsCheckSuccessful(false)
  self.setCheckingPermissionToJoinInProgress(true)

  self.controller.asyncCheckAllChannelsPermissions(communityId, sharedAddresses)
  self.view.setChannelsPermissionsCheckSuccessful(false)
  self.checkingAllChannelPermissionsInProgress = true

  self.view.setCheckingPermissionsInProgress(inProgress = true)

method prepareTokenModelForCommunity*(self: Module, communityId: string) =
  self.joiningCommunityDetails.communityIdForRevealedAccounts = communityId
  self.controller.asyncGetRevealedAccountsForMember(communityId, singletonInstance.userProfile.getPubKey())

  let community = self.controller.getCommunityById(communityId)
  var tokenPermissionsItems: seq[TokenPermissionItem] = @[]

  for id, tokenPermission in community.tokenPermissions:
    let chats = community.getCommunityChats(tokenPermission.chatIds)
    let tokenPermissionItem = buildTokenPermissionItem(tokenPermission, chats)
    tokenPermissionsItems.add(tokenPermissionItem)

  self.view.spectatedCommunityPermissionModel.setItems(tokenPermissionsItems)
  self.checkPermissions(communityId, @[])

method prepareTokenModelForCommunityChat*(self: Module, communityId: string, chatId: string) =
  let community = self.controller.getCommunityById(communityId)
  var tokenPermissionsItems: seq[TokenPermissionItem] = @[]
  for id, tokenPermission in community.tokenPermissions:
    var containsChat = false
    for id in tokenPermission.chatIds:
      if id == chatId:
        containsChat = true
        break
    if not containsChat:
      continue

    let chats = community.getCommunityChats(tokenPermission.chatIds)
    let tokenPermissionItem = buildTokenPermissionItem(tokenPermission, chats)
    tokenPermissionsItems.add(tokenPermissionItem)

  self.view.spectatedCommunityPermissionModel.setItems(tokenPermissionsItems)
  self.checkPermissions(communityId, @[])

proc applyPermissionResponse*(self: Module, communityId: string, permissions: Table[string, CheckPermissionsResultDto]) =
  let community = self.controller.getCommunityById(communityId)
  for id, criteriaResult in permissions:
    if not community.tokenPermissions.hasKey(id):
      warn "unknown permission", id
      continue

    let tokenPermissionItem = self.view.spectatedCommunityPermissionModel.getItemById(id)
    if tokenPermissionItem.id == "":
      warn "no permission in model", id
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

    let updatedTokenPermissionItem = initTokenPermissionItem(
        tokenPermissionItem.id,
        tokenPermissionItem.`type`,
        updatedTokenCriteriaItems,
        tokenPermissionItem.getChatList().getItems(),
        tokenPermissionItem.isPrivate,
        permissionSatisfied,
        tokenPermissionItem.state
    )
    self.view.spectatedCommunityPermissionModel.updateItem(id, updatedTokenPermissionItem)

proc updateCheckingPermissionsInProgressIfNeeded(self: Module, inProgress = false) =
  if self.checkingPermissionToJoinInProgress != self.checkingAllChannelPermissionsInProgress:
    # Wait until both join and channel permissions have returned to update the loading
    return
  self.view.setCheckingPermissionsInProgress(inProgress)

method getCheckingPermissionToJoinInProgress*(self: Module): bool =
  self.checkingPermissionToJoinInProgress

proc setCheckingPermissionToJoinInProgress(self: Module, inProgress: bool) =
  if self.checkingPermissionToJoinInProgress == inProgress:
    return
  self.checkingPermissionToJoinInProgress = inProgress
  self.view.checkingPermissionToJoinInProgressChanged()

method onCommunityCheckPermissionsToJoinFailed*(self: Module, communityId: string, error: string) =
  self.view.setJoinPermissionsCheckSuccessful(false)
  self.setCheckingPermissionToJoinInProgress(false)
  self.updateCheckingPermissionsInProgressIfNeeded(inProgress = false)

method onCommunityCheckAllChannelPermissionsFailed*(self: Module, communityId: string, error: string) =
  self.view.setChannelsPermissionsCheckSuccessful(false)
  self.checkingAllChannelPermissionsInProgress = false
  self.updateCheckingPermissionsInProgressIfNeeded(inProgress = false)

method onCommunityCheckPermissionsToJoinResponse*(self: Module, communityId: string,
    checkPermissionsToJoinResponse: CheckPermissionsToJoinResponseDto) =
  if not self.checkingPermissionToJoinInProgress and
      self.joiningCommunityDetails.communityIdForPermissions != communityId:
    return
  self.applyPermissionResponse(communityId, checkPermissionsToJoinResponse.permissions)
  self.setCheckingPermissionToJoinInProgress(false)
  self.view.setJoinPermissionsCheckSuccessful(true)
  self.updateCheckingPermissionsInProgressIfNeeded(inProgress = false)

method onCommunityCheckAllChannelsPermissionsResponse*(self: Module, communityId: string,
    checkChannelPermissionsResponse: CheckAllChannelsPermissionsResponseDto) =
  if not self.checkingAllChannelPermissionsInProgress and
      self.joiningCommunityDetails.communityIdForPermissions != communityId:
    return
  self.checkingAllChannelPermissionsInProgress = false
  self.view.setChannelsPermissionsCheckSuccessful(true)
  self.updateCheckingPermissionsInProgressIfNeeded(inProgress = false)
  for _, channelPermissionResponse in checkChannelPermissionsResponse.channels:
    self.applyPermissionResponse(
      communityId,
      channelPermissionResponse.viewOnlyPermissions.permissions,
    )
    self.applyPermissionResponse(
      communityId,
      channelPermissionResponse.viewAndPostPermissions.permissions,
    )

method onCommunityMemberRevealedAccountsLoaded*(self: Module, communityId, memberPubkey: string,
    revealedAccounts: seq[RevealedAccount]) =
  if self.joiningCommunityDetails.communityIdForRevealedAccounts != communityId:
    return
  if memberPubkey == singletonInstance.userProfile.getPubKey():
    var addresses: seq[string] = @[]
    var airdropAddress = ""
    for revealedAccount in revealedAccounts:
      addresses.add(revealedAccount.address)
      if revealedAccount.isAirdropAddress:
        airdropAddress = revealedAccount.address

    self.view.setMyRevealedAddressesForCurrentCommunity($(%*addresses), airdropAddress)

method promoteSelfToControlNode*(self: Module, communityId: string) =
  self.controller.promoteSelfToControlNode(communityId)
