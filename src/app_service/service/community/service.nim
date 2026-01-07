import nimqml, tables, json, sequtils, std/sets, std/algorithm, std/strformat, strutils, chronicles, sugar, times
import json_serialization/std/tables as ser_tables # Needed to serialize tables inside objects

import json_serialization
import ./dto/community as community_dto
import ./dto/sign_params as sign_params_dto
import ../community_tokens/dto/community_token as community_token_dto

import ../activity_center/service as activity_center_service
import ../message/service as message_service
import ../chat/service as chat_service

import ../../common/activity_center

import ../../../app/global/global_singleton
import ../../../app/core/signals/types
import ../../../app/core/eventemitter
import ../../../app/core/[main]
import ../../../app/core/tasks/[qt, threadpool]
import ../../../backend/communities as status_go
import ../../../backend/shared_urls as shared_urls
import ../../../backend/community_tokens as tokens_backend

import ../../../app_service/common/types

include ./async_tasks

export community_dto, sign_params_dto

logScope:
  topics = "community-service"

type
  CommunityArgs* = ref object of Args
    community*: CommunityDto
    communityId*: string # should be set when community is nil (i.e. error occured)
    error*: string
    fromUserAction*: bool
    isPendingOwnershipRequest*: bool

  CommunitiesArgs* = ref object of Args
    communities*: seq[CommunityDto]

  CommunityChatArgs* = ref object of Args
    chat*: ChatDto

  CommunityIdArgs* = ref object of Args
    communityId*: string

  ChannelIdArgs* = ref object of Args
    channelId*: string

  CommunityChatIdArgs* = ref object of Args
    communityId*: string
    chatId*: string

  CommunityRequestArgs* = ref object of Args
    communityRequest*: CommunityMembershipRequestDto

  CanceledCommunityRequestArgs* = ref object of Args
    communityId*: string
    requestId*: string
    pubKey*: string

  CommunityRequestFailedArgs* = ref object of Args
    communityId*: string
    error*: string

  CommunityChatOrderArgs* = ref object of Args
    communityId*: string
    chat*: ChatDto

  CommunityChatsOrderArgs* = ref object of Args
    communityId*: string
    chats*: seq[ChatDto]

  CommunityCategoryOrderArgs* = ref object of Args
    communityId*: string
    categoryId*: string
    position*: int

  CommunityCategoryCollapsedArgs* = ref object of Args
    communityId*: string
    categoryId*: string
    collapsed*: bool

  CommunityCategoryArgs* = ref object of Args
    communityId*: string
    category*: Category
    chats*: seq[ChatDto]

  CommunityMemberArgs* = ref object of Args
    communityId*: string
    pubKey*: string
    requestId*: string

  CommunityMembersArgs* = ref object of Args
    communityId*: string
    members*: seq[ChatMember]

  CommunityMutedArgs* = ref object of Args
    communityId*: string
    muted*: bool

  CategoryArgs* = ref object of Args
    communityId*: string
    categoryId*: string

  CommunityTokenPermissionArgs* = ref object of Args
    communityId*: string
    tokenPermission*: CommunityTokenPermissionDto
    error*: string

  CommunityTokenMetadataArgs* = ref object of Args
    communityId*: string
    tokenMetadata*: CommunityTokensMetadataDto

  DiscordCategoriesAndChannelsArgs* = ref object of Args
    categories*: seq[DiscordCategoryDto]
    channels*: seq[DiscordChannelDto]
    oldestMessageTimestamp*: int
    errors*: Table[string, DiscordImportError]
    errorsCount*: int

  DiscordImportProgressArgs* = ref object of Args
    communityId*: string
    communityImage*: string
    communityName*: string
    tasks*: seq[DiscordImportTaskProgress]
    progress*: float
    errorsCount*: int
    warningsCount*: int
    stopped*: bool
    totalChunksCount*: int
    currentChunk*: int

  DiscordImportChannelProgressArgs* = ref object of Args
    channelId*: string
    channelName*: string
    tasks*: seq[DiscordImportTaskProgress]
    progress*: float
    errorsCount*: int
    warningsCount*: int
    stopped*: bool
    totalChunksCount*: int
    currentChunk*: int

  CheckPermissionsToJoinResponseArgs* = ref object of Args
    communityId*: string
    checkPermissionsToJoinResponse*: CheckPermissionsToJoinResponseDto

  CheckPermissionsToJoinFailedArgs* = ref object of Args
    communityId*: string
    error*: string

  CommunityMetricsArgs* = ref object of Args
    communityId*: string
    metricsType*: CommunityMetricsType

  CommunityMemberRevealedAccountsArgs* = ref object of Args
    communityId*: string
    memberPubkey*: string
    memberRevealedAccounts*: seq[RevealedAccount]

  CommunityMembersRevealedAccountsArgs* = ref object of Args
    communityId*: string
    membersRevealedAccounts*: MembersRevealedAccounts

  CommunityMemberStatusUpdatedArgs* = ref object of Args
    communityId*: string
    memberPubkey*: string
    state*: MembershipRequestState

  CommunityMemberReevaluationStatusArg* = ref object of Args
    communityId*: string
    status*: CommunityMemberReevaluationStatus

# Signals which may be emitted by this service:
const SIGNAL_COMMUNITY_DATA_LOADED* = "communityDataLoaded"
const SIGNAL_COMMUNITY_JOINED* = "communityJoined"
const SIGNAL_COMMUNITY_SPECTATED* = "communitySpectated"
const SIGNAL_COMMUNITY_MY_REQUEST_ADDED* = "communityMyRequestAdded"
const SIGNAL_COMMUNITY_MY_REQUEST_FAILED* = "communityMyRequestFailed"
const SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_SUCCEEDED* = "communityEditSharedAddressesSucceded"
const SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_FAILED* = "communityEditSharedAddressesFailed"
const SIGNAL_COMMUNITY_MEMBER_REVEALED_ACCOUNTS_LOADED* = "communityMemberRevealedAccountsLoaded"
const SIGNAL_COMMUNITY_MEMBERS_REVEALED_ACCOUNTS_LOADED* = "communityMembersRevealedAccountsLoaded"
const SIGNAL_COMMUNITY_LEFT* = "communityLeft"
const SIGNAL_COMMUNITY_CREATED* = "communityCreated"
const SIGNAL_COMMUNITY_ADDED* = "communityAdded"
const SIGNAL_COMMUNITY_IMPORTED* = "communityImported"
const SIGNAL_COMMUNITY_DATA_IMPORTED* = "communityDataImported" # This one is when just loading the data with requestCommunityInfo
const SIGNAL_COMMUNITY_LOAD_DATA_FAILED* = "communityLoadDataFailed"
const SIGNAL_COMMUNITY_EDITED* = "communityEdited"
const SIGNAL_COMMUNITIES_UPDATE* = "communityUpdated"
const SIGNAL_COMMUNITY_CHANNEL_CREATED* = "communityChannelCreated"
const SIGNAL_COMMUNITY_CHANNEL_EDITED* = "communityChannelEdited"
const SIGNAL_COMMUNITY_CHANNEL_REORDERED* = "communityChannelReordered"
const SIGNAL_COMMUNITY_CHANNELS_REORDERED* = "communityChannelsReordered"
const SIGNAL_COMMUNITY_CHANNEL_DELETED* = "communityChannelDeleted"
const SIGNAL_COMMUNITY_CATEGORY_CREATED* = "communityCategoryCreated"
const SIGNAL_COMMUNITY_CATEGORY_EDITED* = "communityCategoryEdited"
const SIGNAL_COMMUNITY_CATEGORY_NAME_EDITED* = "communityCategoryNameEdited"
const SIGNAL_COMMUNITY_CATEGORY_DELETED* = "communityCategoryDeleted"
const SIGNAL_COMMUNITY_CATEGORY_REORDERED* = "communityCategoryReordered"
const SIGNAL_COMMUNITY_CHANNEL_CATEGORY_CHANGED* = "communityChannelCategoryChanged"
const SIGNAL_COMMUNITY_MEMBER_APPROVED* = "communityMemberApproved"
const SIGNAL_COMMUNITY_MEMBER_STATUS_CHANGED* = "communityMemberStatusChanged"
const SIGNAL_COMMUNITY_MEMBERS_CHANGED* = "communityMembersChanged"
const SIGNAL_COMMUNITY_KICKED* = "communityKicked"
const SIGNAL_NEW_REQUEST_TO_JOIN_COMMUNITY* = "newRequestToJoinCommunity"
const SIGNAL_NEW_REQUEST_TO_JOIN_COMMUNITY_ACCEPTED* = "requestToJoinCommunityAccepted"
const SIGNAL_REQUEST_TO_JOIN_COMMUNITY_CANCELED* = "requestToJoinCommunityCanceled"
const SIGNAL_WAITING_ON_NEW_COMMUNITY_OWNER_TO_CONFIRM_REQUEST_TO_REJOIN* = "waitingOnNewCommunityOwnerToConfirmRequestToRejoin"
const SIGNAL_CURATED_COMMUNITY_FOUND* = "curatedCommunityFound"
const SIGNAL_CURATED_COMMUNITIES_UPDATED* = "curatedCommunitiesUpdated"
const SIGNAL_COMMUNITY_MUTED* = "communityMuted"
const SIGNAL_CATEGORY_MUTED* = "categoryMuted"
const SIGNAL_CATEGORY_UNMUTED* = "categoryUnmuted"
const SIGNAL_COMMUNITY_HISTORY_ARCHIVES_DOWNLOAD_STARTED* = "communityHistoryArchivesDownloadStarted"
const SIGNAL_COMMUNITY_HISTORY_ARCHIVES_DOWNLOAD_FINISHED* = "communityHistoryArchivesDownloadFinished"

const SIGNAL_DISCORD_CATEGORIES_AND_CHANNELS_EXTRACTED* = "discordCategoriesAndChannelsExtracted"
const SIGNAL_DISCORD_COMMUNITY_IMPORT_FINISHED* = "discordCommunityImportFinished"
const SIGNAL_DISCORD_COMMUNITY_IMPORT_PROGRESS* = "discordCommunityImportProgress"
const SIGNAL_DISCORD_COMMUNITY_IMPORT_CANCELED* = "discordCommunityImportCanceled"
const SIGNAL_DISCORD_CHANNEL_IMPORT_FINISHED* = "discordChannelImportFinished"
const SIGNAL_DISCORD_CHANNEL_IMPORT_PROGRESS* = "discordChannelImportProgress"
const SIGNAL_DISCORD_CHANNEL_IMPORT_CANCELED* = "discordChannelImportCanceled"

const SIGNAL_MEMBER_REEVALUATION_STATUS* = "communityMemberReevaluationStatus"

const SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATED* = "communityTokenPermissionCreated"
const SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATION_FAILED* = "communityTokenPermissionCreationFailed"
const SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATED* = "communityTokenPermissionUpdated"
const SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATE_FAILED* = "communityTokenPermissionUpdateFailed"
const SIGNAL_COMMUNITY_TOKEN_PERMISSION_DELETED* = "communityTokenPermissionDeleted"
const SIGNAL_COMMUNITY_TOKEN_PERMISSION_DELETION_FAILED* = "communityTokenPermissionDeletionFailed"
const SIGNAL_COMMUNITY_TOKEN_METADATA_ADDED* = "communityTokenMetadataAdded"

const SIGNAL_CURATED_COMMUNITIES_LOADING* = "curatedCommunitiesLoading"
const SIGNAL_CURATED_COMMUNITIES_LOADED* = "curatedCommunitiesLoaded"
const SIGNAL_CURATED_COMMUNITIES_LOADING_FAILED* = "curatedCommunitiesLoadingFailed"

const SIGNAL_ACCEPT_REQUEST_TO_JOIN_LOADING* = "acceptRequestToJoinLoading"
const SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED* = "acceptRequestToJoinFailed"
const SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED_NO_PERMISSION* = "acceptRequestToJoinFailedNoPermission"

const SIGNAL_CHECK_PERMISSIONS_TO_JOIN_RESPONSE* = "checkPermissionsToJoinResponse"
const SIGNAL_CHECK_PERMISSIONS_TO_JOIN_FAILED* = "checkPermissionsToJoinFailed"

const SIGNAL_COMMUNITY_METRICS_UPDATED* = "communityMetricsUpdated"
const SIGNAL_COMMUNITY_LOST_OWNERSHIP* = "communityLostOwnership"

const SIGNAL_COMMUNITY_TOKENS_CHANGED* = "communityTokensChanged"

QtObject:
  type
    Service* = ref object of QObject
      threadpool: ThreadPool
      events: EventEmitter
      chatService: chat_service.Service
      activityCenterService: activity_center_service.Service
      messageService: message_service.Service
      communityTags: string # JSON string contraining tags map
      communities: Table[string, CommunityDto] # [community_id, CommunityDto]
      historyArchiveDownloadTaskCommunityIds*: HashSet[string]
      communityMetrics: Table[string, CommunityMetricsDto]
      communityInfoRequests: Table[string, Time]

  # Forward declaration
  proc asyncLoadCuratedCommunities*(self: Service)
  proc asyncAcceptRequestToJoinCommunity*(self: Service, communityId: string, requestId: string)
  proc handleCommunityUpdates(self: Service, communities: seq[CommunityDto], updatedChats: seq[ChatDto], removedChats: seq[string])
  proc handleCommunitiesRequestsToJoin(self: Service, membershipRequests: seq[CommunityMembershipRequestDto])
  proc handleCommunitiesSettingsUpdates(self: Service, communitiesSettings: seq[CommunitySettingsDto])
  proc getPendingRequestIndex(self: Service, communityId: string, requestId: string): int
  proc getWaitingForSharedAddressesRequestIndex(self: Service, communityId: string, requestId: string): int
  proc updateMembershipRequestToNewState*(self: Service, communityId: string, requestId: string,
    updatedCommunity: CommunityDto, newState: RequestToJoinType)
  proc getUserPubKeyFromPendingRequest*(self: Service, communityId: string, requestId: string): string

  proc delete*(self: Service) =
    discard

  proc newService*(
      events: EventEmitter,
      threadpool: ThreadPool,
      chatService: chat_service.Service,
      activityCenterService: activity_center_service.Service,
      messageService: message_service.Service
      ): Service =
    result = Service()
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.chatService = chatService
    result.activityCenterService = activityCenterService
    result.messageService = messageService
    result.communityTags = newString(0)
    result.communities = initTable[string, CommunityDto]()
    result.historyArchiveDownloadTaskCommunityIds = initHashSet[string]()
    result.communityMetrics = initTable[string, CommunityMetricsDto]()
    result.communityInfoRequests = initTable[string, Time]()

  proc getFilteredJoinedAndSpectatedCommunities(self: Service): Table[string, CommunityDto] =
    result = initTable[string, CommunityDto]()
    for communityId, community in self.communities.pairs:
      if community.joined or community.spectated:
        result[communityId] = community

  proc getFilteredCuratedCommunities(self: Service): Table[string, CommunityDto] =
    result = initTable[string, CommunityDto]()
    for communityId, community in self.communities.pairs:
      if community.listedInDirectory:
        result[communityId] = community

  proc doConnect(self: Service) =
    self.events.on(SignalType.CommunityFound.event) do(e: Args):
      var receivedData = CommunitySignal(e)
      self.communities[receivedData.community.id] = receivedData.community
      self.events.emit(SIGNAL_COMMUNITY_DATA_IMPORTED, CommunityArgs(community: receivedData.community))

      if self.communities.contains(receivedData.community.id) and
          self.communities[receivedData.community.id].listedInDirectory and not
          self.communities[receivedData.community.id].isAvailable:
        self.events.emit(SIGNAL_CURATED_COMMUNITY_FOUND, CommunityArgs(community: self.communities[receivedData.community.id]))

    self.events.on(SignalType.CuratedCommunitiesUpdated.event) do(e: Args):
      var receivedData = CuratedCommunitiesSignal(e)
      self.events.emit(SIGNAL_CURATED_COMMUNITIES_UPDATED,
        CommunitiesArgs(communities: receivedData.communities))

    self.events.on(SignalType.Message.event) do(e: Args):
      var receivedData = MessageSignal(e)
      # Handling membership requests
      if(receivedData.membershipRequests.len > 0):
        self.handleCommunitiesRequestsToJoin(receivedData.membershipRequests)

      # Handling community updates
      if (receivedData.communities.len > 0):
        # Channel added removed is notified in the chats param
        self.handleCommunityUpdates(receivedData.communities, receivedData.chats, receivedData.removedChats)

      if (receivedData.communitiesSettings.len > 0):
        self.handleCommunitiesSettingsUpdates(receivedData.communitiesSettings)

    self.events.on(SignalType.DiscordCategoriesAndChannelsExtracted.event) do(e: Args):
      var receivedData = DiscordCategoriesAndChannelsExtractedSignal(e)
      self.events.emit(SIGNAL_DISCORD_CATEGORIES_AND_CHANNELS_EXTRACTED, DiscordCategoriesAndChannelsArgs(
        categories: receivedData.categories,
        channels: receivedData.channels,
        oldestMessageTimestamp: receivedData.oldestMessageTimestamp,
        errors: receivedData.errors,
        errorsCount: receivedData.errorsCount
      ))

    self.events.on(SignalType.DiscordCommunityImportFinished.event) do(e: Args):
      var receivedData = DiscordCommunityImportFinishedSignal(e)
      self.events.emit(SIGNAL_DISCORD_COMMUNITY_IMPORT_FINISHED, CommunityIdArgs(communityId: receivedData.communityId))

    self.events.on(SignalType.DiscordCommunityImportCancelled.event) do(e: Args):
      var receivedData = DiscordCommunityImportCancelledSignal(e)
      self.events.emit(SIGNAL_DISCORD_COMMUNITY_IMPORT_CANCELED, CommunityIdArgs(communityId: receivedData.communityId))

    self.events.on(SignalType.DiscordCommunityImportCleanedUp.event) do(e: Args):
      var receivedData = DiscordCommunityImportCleanedUpSignal(e)
      self.events.emit(SIGNAL_COMMUNITY_LEFT, CommunityIdArgs(communityId: receivedData.communityId))

    self.events.on(SignalType.DiscordChannelImportFinished.event) do(e: Args):
      var receivedData = DiscordChannelImportFinishedSignal(e)
      self.events.emit(SIGNAL_DISCORD_CHANNEL_IMPORT_FINISHED, CommunityChatIdArgs(chatId: receivedData.channelId, communityId: receivedData.communityId))

    self.events.on(SignalType.DiscordChannelImportCancelled.event) do(e: Args):
      var receivedData = DiscordChannelImportCancelledSignal(e)
      self.events.emit(SIGNAL_DISCORD_CHANNEL_IMPORT_CANCELED, ChannelIdArgs(channelId: receivedData.channelId))

    self.events.on(SignalType.DiscordCommunityImportProgress.event) do(e: Args):
      var receivedData = DiscordCommunityImportProgressSignal(e)
      self.events.emit(SIGNAL_DISCORD_COMMUNITY_IMPORT_PROGRESS, DiscordImportProgressArgs(
        communityId: receivedData.communityId,
        communityImage: receivedData.communityImages.thumbnail,
        communityName: receivedData.communityName,
        tasks: receivedData.tasks,
        progress: receivedData.progress,
        errorsCount: receivedData.errorsCount,
        warningsCount: receivedData.warningsCount,
        stopped: receivedData.stopped,
        totalChunksCount: receivedData.totalChunksCount,
        currentChunk: receivedData.currentChunk,
      ))

    self.events.on(SignalType.DiscordChannelImportProgress.event) do(e: Args):
      var receivedData = DiscordChannelImportProgressSignal(e)
      self.events.emit(SIGNAL_DISCORD_CHANNEL_IMPORT_PROGRESS, DiscordImportChannelProgressArgs(
        channelId: receivedData.channelId,
        channelName: receivedData.channelName,
        tasks: receivedData.tasks,
        progress: receivedData.progress,
        errorsCount: receivedData.errorsCount,
        warningsCount: receivedData.warningsCount,
        stopped: receivedData.stopped,
        totalChunksCount: receivedData.totalChunksCount,
        currentChunk: receivedData.currentChunk,
      ))

    self.events.on(SignalType.ImportingHistoryArchiveMessages.event) do(e: Args):
      var receivedData = HistoryArchivesSignal(e)
      if receivedData.communityId notin self.historyArchiveDownloadTaskCommunityIds:
        self.historyArchiveDownloadTaskCommunityIds.incl(receivedData.communityId)
        self.events.emit(SIGNAL_COMMUNITY_HISTORY_ARCHIVES_DOWNLOAD_STARTED, CommunityIdArgs(communityId: receivedData.communityId))

    self.events.on(SignalType.DownloadingHistoryArchivesFinished.event) do(e: Args):
      var receivedData = HistoryArchivesSignal(e)
      if receivedData.communityId in self.historyArchiveDownloadTaskCommunityIds:
        self.historyArchiveDownloadTaskCommunityIds.excl(receivedData.communityId)

        if self.historyArchiveDownloadTaskCommunityIds.len == 0:
          # Right now we're only emitting this signal when all download tasks have been marked as finished
          # so passing the `CommunityIdArgs` is not very useful because it'll always emit the latest community
          # id that has finished. We'll handle signals related to individual communities in the future
          # once we've figured out what this should look like in the UI
          #
          # TODO(pascal):
          # Don't just emit this signal when all communities are done downloading history data,
          # but implement a solution for individual updates
          self.events.emit(SIGNAL_COMMUNITY_HISTORY_ARCHIVES_DOWNLOAD_FINISHED, CommunityIdArgs(communityId: receivedData.communityId))

    self.events.on(SignalType.MemberReevaluationStatus.event) do(e: Args):
      var receivedData = CommunityMemberReevaluationStatusSignal(e)
      self.events.emit(SIGNAL_MEMBER_REEVALUATION_STATUS, CommunityMemberReevaluationStatusArg(
        communityId: receivedData.communityId,
        status: receivedData.status,
      ))

  proc findIndexById(id: string, chats: seq[ChatDto]): int =
    var idx = -1
    for chat in chats:
      inc idx
      if(chat.id == id):
        return idx
    return -1

  proc findIndexBySymbol(symbol: string, tokenCriteria: seq[TokenCriteriaDto]): int =
    var idx = -1
    for tc in tokenCriteria:
      inc idx
      if(tc.symbol == symbol):
        return idx
    return -1

  proc findIndexById*(id: string, categories: seq[Category]): int =
    var idx = -1
    for category in categories:
      inc idx
      if(category.id == id):
        return idx
    return -1

  proc findIndexBySymbol(symbol: string, tokens: seq[CommunityTokensMetadataDto]): int =
    var idx = -1
    for token in tokens:
      inc idx
      if(token.symbol == symbol):
        return idx
    return -1

  proc saveUpdatedCommunity(self: Service, community: var CommunityDto) =
    # Community data we get from the signals and responses don't contgain the pending requests
    # therefore, we must keep the old one
    community.pendingRequestsToJoin = self.communities[community.id].pendingRequestsToJoin
    community.declinedRequestsToJoin = self.communities[community.id].declinedRequestsToJoin
    community.canceledRequestsToJoin = self.communities[community.id].canceledRequestsToJoin
    community.waitingForSharedAddressesRequestsToJoin = self.communities[community.id].waitingForSharedAddressesRequestsToJoin

    # Update the joinded community list with the new data
    self.communities[community.id] = community

  proc getChatsInCategory(self: Service, community: var CommunityDto, categoryId: string): seq[ChatDto] =
    result = @[]
    for chat in community.chats:
      if (chat.categoryId == categoryId):
        # TODO: chat.id already contains community.id here but it was not expected, this requires investigation
        var chatDetails = self.chatService.getChatById(chat.id)
        result.add(chatDetails)

  proc handleCommunitiesSettingsUpdates(self: Service, communitiesSettings: seq[CommunitySettingsDto]) =
    for settings in communitiesSettings:
      if self.communities.hasKey(settings.id):
        self.communities[settings.id].settings = settings
        if self.communities[settings.id].joined:
          self.events.emit(SIGNAL_COMMUNITY_EDITED, CommunityArgs(community: self.communities[settings.id]))

  proc checkForCategoryPropertyUpdates(self: Service, community: CommunityDto, prev_community: CommunityDto) =
    for category in community.categories:
      # id is present
      let index = findIndexById(category.id, prev_community.categories)
      if index == -1:
        continue
      # but something is different
      let prev_category = prev_community.categories[index]

      if category.position != prev_category.position:
        self.events.emit(SIGNAL_COMMUNITY_CATEGORY_REORDERED,
          CommunityCategoryOrderArgs(
            communityId: community.id,
            categoryId: category.id,
            position: category.position))
      if category.name != prev_category.name:
        self.events.emit(SIGNAL_COMMUNITY_CATEGORY_NAME_EDITED,
          CommunityCategoryArgs(communityId: community.id, category: category))

  proc communityTokensChanged(community: CommunityDto, prev_community: CommunityDto): bool =
    let communityTokens = community.communityTokensMetadata
    let prevCommunityTokens = prev_community.communityTokensMetadata
    # checking length is sufficient - communityTokensMetadata list can only extend
    return communityTokens.len != prevCommunityTokens.len

  proc updateMemberRole(self: Service, chatId: string, member: ChatMember) =
    self.events.emit(SIGNAL_CHAT_MEMBER_UPDATED,
      ChatMemberUpdatedArgs(chatId: chatId, id: member.id, role: member.role, joined: member.joined))

  proc handleCommunityUpdates(self: Service, communities: seq[CommunityDto], updatedChats: seq[ChatDto], removedChats: seq[string]) =
    try:
      let myPublicKey = singletonInstance.userProfile.getPubKey()
      var community = communities[0]
      if not self.communities.hasKey(community.id):
        self.communities[community.id] = community
        self.events.emit(SIGNAL_COMMUNITY_ADDED, CommunityArgs(community: community))

        if (community.joined and community.isMember):
          self.events.emit(SIGNAL_COMMUNITY_JOINED, CommunityArgs(community: community, fromUserAction: false))
        return

      let prevCommunity = self.communities[community.id]

      # If there's settings without `id` it means the original
      # signal didn't include actual communitySettings, hence we
      # assign the settings we already have, otherwise we risk our
      # settings to be overridden with wrong defaults.
      if community.settings.id == "":
        community.settings = prevCommunity.settings

      # Save the updated community before calling events, because some events triggers look ups on the new community
      # We will save again at the end if other properties were updated
      self.saveUpdatedCommunity(community)

      try:
        let currOwner = community.findOwner()
        let prevOwner = prevCommunity.findOwner()
        if currOwner.id != prevOwner.id:
          for chat in community.chats:
            self.updateMemberRole(chat.id, currOwner)
      except Exception:
        discard

      # ownership lost
      if prevCommunity.isOwner and not community.isOwner:
        self.events.emit(SIGNAL_COMMUNITY_LOST_OWNERSHIP, CommunityIdArgs(communityId: community.id))
        let response = tokens_backend.registerLostOwnershipNotification(community.id)
        checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

      if communityTokensChanged(community, prevCommunity):
        self.events.emit(SIGNAL_COMMUNITY_TOKENS_CHANGED, nil)

      var deletedCategories: seq[string] = @[]

      # category was added
      if(community.categories.len > prevCommunity.categories.len):
        for category in community.categories:
          if findIndexById(category.id, prevCommunity.categories) == -1:
            let chats = self.getChatsInCategory(community, category.id)

            self.events.emit(SIGNAL_COMMUNITY_CATEGORY_CREATED,
              CommunityCategoryArgs(communityId: community.id, category: category, chats: chats))

      # category was removed
      elif(community.categories.len < prevCommunity.categories.len):
        for prv_category in prevCommunity.categories:
          if findIndexById(prv_category.id, community.categories) == -1:
            deletedCategories.add(prv_category.id)
            self.events.emit(SIGNAL_COMMUNITY_CATEGORY_DELETED,
              CommunityCategoryArgs(communityId: community.id, category: Category(id: prv_category.id)))

      # some property has changed
      else:
        self.checkForCategoryPropertyUpdates(community, prevCommunity)

      # channel was added
      if(community.chats.len > prevCommunity.chats.len):
        for chat in community.chats:
          if findIndexById(chat.id, prevCommunity.chats) == -1:
            self.chatService.updateOrAddChat(chat) # we have to update chats stored in the chat service.
            let data = CommunityChatArgs(chat: chat)
            self.events.emit(SIGNAL_COMMUNITY_CHANNEL_CREATED, data)

            # if the chat was created by the current user then it's already in the model and should be reordered if necessary
            self.events.emit(SIGNAL_COMMUNITY_CHANNEL_REORDERED,
              CommunityChatOrderArgs(
                communityId: community.id,
                chat: chat,
              )
            )

      # channel was removed
      elif((community.chats.len-removedChats.len) < prevCommunity.chats.len):
        for prv_chat in prevCommunity.chats:
          if findIndexById(prv_chat.id, community.chats) == -1:
            self.events.emit(SIGNAL_COMMUNITY_CHANNEL_DELETED, CommunityChatIdArgs(communityId: community.id,
            chatId: prv_chat.id))
      # some property has changed
      else:
        for chat in community.chats:
          # id is present
          let index = findIndexById(chat.id, prevCommunity.chats)
          if index == -1:
            continue
          # but something is different
          let prevChat = prevCommunity.chats[index]
          # Handle position changes
          if chat.position != prevChat.position:
            self.events.emit(SIGNAL_COMMUNITY_CHANNEL_REORDERED,
              CommunityChatOrderArgs(
                communityId: community.id,
                chat: chat,
              )
            )

          # Handle channel was added/removed to/from category
          if chat.categoryId != prevChat.categoryId:

            var prevCategoryDeleted = false
            if chat.categoryId == "":
              for catId in deletedCategories:
                if prevChat.categoryId == catId:
                  prevCategoryDeleted = true
                  break

            self.events.emit(SIGNAL_COMMUNITY_CHANNEL_CATEGORY_CHANGED,
              CommunityChatOrderArgs(
                communityId: community.id,
                chat: chat,
              )
            )

          if chat.name != prevChat.name or
              chat.description != prevChat.description or
              chat.color != prevChat.color or
              chat.emoji != prevChat.emoji or
              chat.viewersCanPostReactions != prevChat.viewersCanPostReactions or
              chat.canPost != prevChat.canPost or
              chat.canView != prevChat.canView or
              chat.hideIfPermissionsNotMet != prevChat.hideIfPermissionsNotMet or
              chat.tokenGated != prevChat.tokenGated or
              chat.missingEncryptionKey != prevChat.missingEncryptionKey:
            var updatedChat = chat
            self.chatService.updateOrAddChat(updatedChat) # we have to update chats stored in the chat service.

            let data = CommunityChatArgs(chat: updatedChat)
            self.events.emit(SIGNAL_COMMUNITY_CHANNEL_EDITED, data)

          # Handle channel members update
          if chat.members != prevChat.members:
            self.chatService.updateChannelMembers(chat)

      # members list was changed
      if community.members != prevCommunity.members:
        self.events.emit(SIGNAL_COMMUNITY_MEMBERS_CHANGED,
          CommunityMembersArgs(communityId: community.id, members: community.members))

      # token metadata was added
      if community.communityTokensMetadata.len > prevCommunity.communityTokensMetadata.len:
        for tokenMetadata in community.communityTokensMetadata:
          if findIndexBySymbol(tokenMetadata.symbol, prevCommunity.communityTokensMetadata) == -1:
            self.events.emit(SIGNAL_COMMUNITY_TOKEN_METADATA_ADDED,
                             CommunityTokenMetadataArgs(communityId: community.id,
                                                        tokenMetadata: tokenMetadata))

      # tokenPermission was added
      if community.tokenPermissions.len > prevCommunity.tokenPermissions.len:
        for id, tokenPermission in community.tokenPermissions:
          if not prevCommunity.tokenPermissions.hasKey(id):

            self.events.emit(SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATED,
              CommunityTokenPermissionArgs(communityId: community.id, tokenPermission: tokenPermission))
      elif community.tokenPermissions.len < prevCommunity.tokenPermissions.len:
        for id, prvTokenPermission in prevCommunity.tokenPermissions:
          if not community.tokenPermissions.hasKey(id):
            self.events.emit(SIGNAL_COMMUNITY_TOKEN_PERMISSION_DELETED,
              CommunityTokenPermissionArgs(communityId: community.id, tokenPermission: prvTokenPermission))
      else:
        for id, tokenPermission in community.tokenPermissions:
          if not prevCommunity.tokenPermissions.hasKey(id):
            continue

          let prevTokenPermission = prevCommunity.tokenPermissions[id]

          var permissionUpdated = false

          if tokenPermission.tokenCriteria.len != prevTokenPermission.tokenCriteria.len or
            tokenPermission.isPrivate != prevTokenPermission.isPrivate or
            tokenPermission.chatIds.len != prevTokenPermission.chatIds.len or
            tokenPermission.`type` != prevTokenPermission.`type` or
            tokenPermission.state != prevTokenPermission.state:

              permissionUpdated = true

          for tc in tokenPermission.tokenCriteria:
            let index = findIndexBySymbol(tc.symbol, prevTokenPermission.tokenCriteria)
            if index == -1:
              permissionUpdated = true
            else:

              let prevTc = prevTokenPermission.tokenCriteria[index]
              if tc.amount != prevTc.amount or tc.ensPattern != prevTc.ensPattern or tc.symbol != prevTc.symbol or tc.name != prevTc.name or tc.decimals != prevTc.decimals:
                permissionUpdated = true
                break

          if tokenPermission.chatIds.len == prevTokenPermission.chatIds.len:
            for chatID in tokenPermission.chatIds:
              if not (chatID in prevTokenPermission.chatIds):
                permissionUpdated = true
                break

          if permissionUpdated:
            self.events.emit(SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATED,
              CommunityTokenPermissionArgs(communityId: community.id, tokenPermission: tokenPermission))

      let wasJoined = prevCommunity.joined

      # If the community was not joined before but is now, we signal it
      if not wasJoined and community.joined and community.isMember:
        self.events.emit(SIGNAL_COMMUNITY_JOINED, CommunityArgs(community: community, fromUserAction: false))

      self.events.emit(SIGNAL_COMMUNITIES_UPDATE, CommunitiesArgs(communities: @[community]))

      if wasJoined and not community.joined and not community.isMember:
        # If we were kicked due to ownership change - we will stay in a spectate mode
        if community.spectated:
          self.events.emit(SIGNAL_COMMUNITY_KICKED, CommunityArgs(community: community))
        else:
          # We were kicked or banned, leave the community
          self.events.emit(SIGNAL_COMMUNITY_LEFT, CommunityIdArgs(communityId: community.id))
          var state = MembershipRequestState.Kicked
          if community.pendingAndBannedMembers.hasKey(myPublicKey):
            let status = community.pendingAndBannedMembers[myPublicKey]
            if isBanned(status):
              state = status.toMembershipRequestState()

          self.events.emit(SIGNAL_COMMUNITY_MEMBER_STATUS_CHANGED, CommunityMemberStatusUpdatedArgs(
            communityId: community.id,
            memberPubkey: myPublicKey,
            state: state))

      # Check if we were unbanned
      if not wasJoined and not community.joined and prevCommunity.pendingAndBannedMembers.hasKey(myPublicKey) and not
        community.pendingAndBannedMembers.hasKey(myPublicKey):
        self.events.emit(SIGNAL_COMMUNITY_MEMBER_STATUS_CHANGED, CommunityMemberStatusUpdatedArgs(
            communityId: community.id,
            memberPubkey: myPublicKey,
            state: MembershipRequestState.Unbanned))

    except Exception as e:
      error "Error handling community updates", msg = e.msg

  proc handleCommunitiesRequestsToJoin(self: Service, membershipRequests: seq[CommunityMembershipRequestDto]) =
    for membershipRequest in membershipRequests:
      if (not self.communities.contains(membershipRequest.communityId)):
        error "Received a membership request for an unknown community", communityId=membershipRequest.communityId
        continue

      let requestToJoinState = RequestToJoinType(membershipRequest.state)
      let noAwaitingIndex = self.getWaitingForSharedAddressesRequestIndex(membershipRequest.communityId, membershipRequest.id) == -1
      if requestToJoinState == RequestToJoinType.AwaitingAddress and noAwaitingIndex:
        self.communities[membershipRequest.communityId].waitingForSharedAddressesRequestsToJoin.add(membershipRequest)
        let myPublicKey = singletonInstance.userProfile.getPubKey()
        if myPublicKey == membershipRequest.publicKey:
          self.events.emit(SIGNAL_WAITING_ON_NEW_COMMUNITY_OWNER_TO_CONFIRM_REQUEST_TO_REJOIN, CommunityIdArgs(communityId: membershipRequest.communityId))
      elif requestToJoinState == RequestToJoinType.Pending and self.getPendingRequestIndex(membershipRequest.communityId, membershipRequest.id) == -1:
        self.communities[membershipRequest.communityId].pendingRequestsToJoin.add(membershipRequest)
        self.events.emit(SIGNAL_NEW_REQUEST_TO_JOIN_COMMUNITY,
          CommunityRequestArgs(communityRequest: membershipRequest))
      elif requestToJoinState == RequestToJoinType.Accepted:
        # Request was accepted, update the member's airdrop address
        self.events.emit(SIGNAL_NEW_REQUEST_TO_JOIN_COMMUNITY_ACCEPTED,
          CommunityRequestArgs(communityRequest: membershipRequest))

      try:
        self.updateMembershipRequestToNewState(membershipRequest.communityId, membershipRequest.id, self.communities[membershipRequest.communityId],
          requestToJoinState)
      except Exception as e:
        error "Unknown request", msg = e.msg

  proc init*(self: Service) =
    self.doConnect()

    try:
      let arg = AsyncLoadCommunitiesDataTaskArg(
        tptr: asyncLoadCommunitiesDataTask,
        vptr: cast[uint](self.vptr),
        slot: "asyncCommunitiesDataLoaded",
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error requesting communities data", msg = e.msg

  proc asyncCommunitiesDataLoaded(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if (responseObj{"error"}.kind != JNull and responseObj{"error"}.getStr != ""):
        error "error loading communities data", msg = responseObj{"error"}.getStr
        return

      # Tags
      var resultTags = newString(0)
      toUgly(resultTags, responseObj["tags"]["result"])
      self.communityTags = resultTags

      # Categories
      var categories: seq[Category]
      let collapsedCommunityCategories = responseObj["collapsedCommunityCategories"]
      if collapsedCommunityCategories{"result"}.kind != JNull:
        for jsonCategory in collapsedCommunityCategories["result"]:
          categories.add(jsonCategory.toCollapsedCategoryDto())

      # All communities
      let communities = parseCommunities(responseObj["communities"], categories)
      for community in communities:
        self.communities[community.id] = community

      # Communities settings
      let communitiesSettings = parseCommunitiesSettings(responseObj["settings"])
      for settings in communitiesSettings:
        if self.communities.hasKey(settings.id):
          self.communities[settings.id].settings = settings

      # Non approved requests to join for all communities
      let nonAprrovedRequestsToJoinObj = responseObj["nonAprrovedRequestsToJoin"]

      if nonAprrovedRequestsToJoinObj{"result"}.kind != JNull:
        for jsonCommunityReqest in nonAprrovedRequestsToJoinObj["result"]:
          let communityRequest = jsonCommunityReqest.toCommunityMembershipRequestDto()
          if not (communityRequest.communityId in self.communities):
            warn "community was not found for community request", communityID=communityRequest.communityId, requestId=communityRequest.id
            continue
          case RequestToJoinType(communityRequest.state):
            of RequestToJoinType.Pending, RequestToJoinType.AcceptedPending, RequestToJoinType.DeclinedPending:
              self.communities[communityRequest.communityId].pendingRequestsToJoin.add(communityRequest)
            of RequestToJoinType.Declined:
              self.communities[communityRequest.communityId].declinedRequestsToJoin.add(communityRequest)
            of RequestToJoinType.Canceled:
              self.communities[communityRequest.communityId].canceledRequestsToJoin.add(communityRequest)
            of RequestToJoinType.AwaitingAddress:
              self.communities[communityRequest.communityId].waitingForSharedAddressesRequestsToJoin.add(communityRequest)
            of RequestToJoinType.Accepted:
              continue

      self.events.emit(SIGNAL_COMMUNITY_DATA_LOADED, Args())
    except Exception as e:
      let errDesription = e.msg
      error "error loading all communities: ", errDesription

  proc getCommunityTags*(self: Service): string =
    return self.communityTags

  proc getJoinedAndSpectatedCommunities*(self: Service): seq[CommunityDto] =
    return toSeq(self.getFilteredJoinedAndSpectatedCommunities().values)

  proc getAllCommunities*(self: Service): seq[CommunityDto] =
    return toSeq(self.communities.values)

  proc getCommunityById*(self: Service, communityId: string): CommunityDto =
    if communityId == "":
      return

    if not self.communities.hasKey(communityId):
      return

    return self.communities[communityId]

  proc getCommunityIds*(self: Service): seq[string] =
    return toSeq(self.communities.keys)

  proc isDisplayNameDupeOfCommunityMember*(self: Service, displayName: string): bool =
    try:
      let response = status_go.isDisplayNameDupeOfCommunityMember(displayName)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error scanning communities for member name: " & error.message)

      if response.result.kind != JNull:
        return response.result.getBool

    except Exception as e:
      error "error scanning communities for member name: ", errMsg = e.msg

  proc getCommunityTokenBySymbol*(self: Service, communityId: string, symbol: string): CommunityTokenDto =
    let community = self.getCommunityById(communityId)
    for metadata in community.communityTokensMetadata:
      if metadata.symbol == symbol:
        var communityToken = CommunityTokenDto()
        communityToken.name = metadata.name
        communityToken.symbol = metadata.symbol
        communityToken.description = metadata.description
        communityToken.tokenType = metadata.tokenType

        for chainId, contractAddress in metadata.addresses:
          communityToken.chainId = chainId
          communityToken.address = contractAddress
          break
        return communityToken

  proc sortAsc[T](t1, t2: T): int =
    if(t1.position > t2.position):
      return 1
    elif (t1.position < t2.position):
      return -1
    else:
      return 0

  proc sortDesc[T](t1, t2: T): int =
    if(t1.position < t2.position):
      return 1
    elif (t1.position > t2.position):
      return -1
    else:
      return 0

  proc getCategoryById*(self: Service, communityId: string, categoryId: string): Category =
    if not self.communities.contains(communityId):
      error "trying to get community categories for an unexisting community id"
      return

    let categories = self.getCommunityById(communityId).categories
    let categoryIndex = findIndexById(categoryId, categories)
    return categories[categoryIndex]

  proc getCategories*(self: Service, communityId: string, order: SortOrder = SortOrder.Ascending): seq[Category] =
    if(not self.communities.contains(communityId)):
      error "trying to get community categories for an unexisting community id"
      return

    result = self.getCommunityById(communityId).categories
    if(order == SortOrder.Ascending):
      result.sort(sortAsc[Category])
    else:
      result.sort(sortDesc[Category])

  proc getChats*(self: Service, communityId: string, categoryId = "", order = SortOrder.Ascending): seq[ChatDto] =
    ## By default returns chats which don't belong to any category, for passed `communityId`.
    ## If `categoryId` is set then only chats belonging to that category for passed `communityId` will be returned.
    ## Returned chats are sorted by position following set `order` parameter.
    if(not self.communities.contains(communityId)):
      error "trying to get community chats for an unexisting community id"
      return

    for chat in self.communities[communityId].chats:
      if(chat.categoryId != categoryId):
        continue

      result.add(chat)

    if(order == SortOrder.Ascending):
      result.sort(sortAsc[ChatDto])
    else:
      result.sort(sortDesc[ChatDto])

  proc getAllChats*(self: Service, communityId: string, order = SortOrder.Ascending): seq[ChatDto] =
    ## Returns all chats belonging to the community with passed `communityId`, sorted by position.
    ## Returned chats are sorted by position following set `order` parameter.
    if(not self.communities.contains(communityId)):
      error "trying to get all community chats for an unexisting community id", communityId
      return

    result = self.getCommunityById(communityId).chats

    if(order == SortOrder.Ascending):
      result.sort(sortAsc[ChatDto])
    else:
      result.sort(sortDesc[ChatDto])

  proc isUserMemberOfCommunity*(self: Service, communityId: string): bool =
    if(not self.communities.contains(communityId)):
      return false
    return self.communities[communityId].joined and self.communities[communityId].isMember

  proc isUserSpectatingCommunity*(self: Service, communityId: string): bool =
    if(not self.communities.contains(communityId)):
      return false
    return self.communities[communityId].spectated

  proc processRequestsToJoinCommunity(self: Service, responseResult: JsonNode): bool =
    if responseResult{"requestsToJoinCommunity"} == nil or responseResult{"requestsToJoinCommunity"}.kind == JNull:
      return false

    for jsonCommunityReqest in responseResult["requestsToJoinCommunity"]:
      let communityRequest = jsonCommunityReqest.toCommunityMembershipRequestDto()
      if (not self.communities.contains(communityRequest.communityId)):
        error "Request to join for an unknown community", communityId=communityRequest.communityId
        return false

      var community = self.communities[communityRequest.communityId]
      community.pendingRequestsToJoin.add(communityRequest)
      self.communities[communityRequest.communityId] = community

      self.events.emit(SIGNAL_COMMUNITY_MY_REQUEST_ADDED, CommunityRequestArgs(communityRequest: communityRequest))

    return true

  proc spectateCommunity*(self: Service, communityId: string): string =
    result = ""
    try:
      if (self.isUserSpectatingCommunity(communityId) or self.isUserMemberOfCommunity(communityId)):
        return

      let response = status_go.spectateCommunity(communityId)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error joining community: " & error.message)

      if response.result == nil or response.result.kind == JNull:
        error "error: ", procName="spectateCommunity", errDesription = "result is nil"
        return

      if not response.result.hasKey("communities") or response.result["communities"].kind != JArray or response.result["communities"].len == 0:
        error "error: ", procName="spectateCommunity", errDesription = "no 'communities' key in response"
        return

      if not response.result.hasKey("communitiesSettings") or response.result["communitiesSettings"].kind != JArray or response.result["communitiesSettings"].len == 0:
        error "error: ", procName="spectateCommunity", errDesription = "no 'communitiesSettings' key in response"
        return

      var updatedCommunity = response.result["communities"][0].toCommunityDto()
      let communitySettings = response.result["communitiesSettings"][0].toCommunitySettingsDto()

      updatedCommunity.settings = communitySettings
      self.communities[communityId] = updatedCommunity

      let ownerTokenNotification = self.activityCenterService.getNotificationForTypeAndCommunityId(notification.ActivityCenterNotificationType.OwnerTokenReceived, communityId)

      for k, chat in updatedCommunity.chats:
        var fullChatId = chat.id
        if not chat.id.startsWith(communityId):
          fullChatId = communityId & chat.id
        let currentChat =  self.chatService.getChatById(fullChatId, showWarning = false)

        if (currentChat.id != ""):
          # The chat service already knows that about that chat
          continue
        var chatDto = chat
        chatDto.id = fullChatId
        # TODO find a way to populate missing infos like the color
        self.chatService.updateOrAddChat(chatDto)
        self.messageService.asyncLoadInitialMessagesForChat(fullChatId)

      self.events.emit(SIGNAL_COMMUNITIES_UPDATE, CommunitiesArgs(communities: @[updatedCommunity]))
      self.events.emit(SIGNAL_COMMUNITY_SPECTATED, CommunityArgs(community: updatedCommunity, fromUserAction: true, isPendingOwnershipRequest: (ownerTokenNotification != nil)))
    except Exception as e:
      error "Error joining the community", msg = e.msg
      result = fmt"Error joining the community: {e.msg}"

  proc leaveCommunity*(self: Service, communityId: string) =
    try:
      let response = status_go.leaveCommunity(communityId)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error leaving community: " & error.message)

      if response.result == nil or response.result.kind == JNull:
        error "error: ", procName="leaveCommunity", errDesription = "result is nil"
        return

      # Update community so that joined, member list and isMember are updated
      let updatedCommunity = response.result["communities"][0].toCommunityDto()
      self.communities[communityId] = updatedCommunity
      self.events.emit(SIGNAL_COMMUNITIES_UPDATE, CommunitiesArgs(communities: @[updatedCommunity]))

      for chat in updatedCommunity.chats:
        self.messageService.resetMessageCursor(chat.id)

      self.events.emit(SIGNAL_COMMUNITY_LEFT, CommunityIdArgs(communityId: communityId))
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

    except Exception as e:
      error "Error leaving community", msg = e.msg, communityId

  proc requestImportDiscordCommunity*(
      self: Service,
      name: string,
      description: string,
      introMessage: string,
      outroMessage: string,
      access: int,
      color: string,
      tags: string,
      imageUrl: string,
      aX: int, aY: int, bX: int, bY: int,
      historyArchiveSupportEnabled: bool,
      pinMessageAllMembersEnabled: bool,
      filesToImport: seq[string],
      fromTimestamp: int) =
    try:
      var image = singletonInstance.utils.fromPathUri(imageUrl)
      var tagsString = tags
      if len(tagsString) == 0:
        tagsString = "[]"

      let response = status_go.requestImportDiscordCommunity(
        name,
        description,
        introMessage,
        outroMessage,
        access,
        color,
        tagsString,
        image,
        aX, aY, bX, bY,
        historyArchiveSupportEnabled,
        pinMessageAllMembersEnabled,
        filesToImport,
        fromTimestamp)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error importing discord community: " & error.message)

    except Exception as e:
      error "Error importing discord community", msg = e.msg

  proc requestImportDiscordChannel*(
        self: Service,
        name: string,
        discordChannelId: string,
        communityId: string,
        description: string,
        color: string,
        emoji: string,
        filesToImport: seq[string],
        fromTimestamp: int) =
      try:
        let response = status_go.requestImportDiscordChannel(
          name,
          discordChannelId,
          communityId,
          description,
          color,
          emoji,
          filesToImport,
          fromTimestamp)

        if response.error != nil:
          let error = Json.decode($response.error, RpcError)
          raise newException(RpcException, "Error importing discord channel: " & error.message)

      except Exception as e:
        error "Error importing discord channel", msg = e.msg

  proc createCommunity*(
      self: Service,
      name: string,
      description: string,
      introMessage: string,
      outroMessage: string,
      access: int,
      color: string,
      tags: string,
      imageUrl: string,
      aX: int, aY: int, bX: int, bY: int,
      historyArchiveSupportEnabled: bool,
      pinMessageAllMembersEnabled: bool,
      bannerJsonStr: string) =
    try:
      var bannerJson = bannerJsonStr.parseJson
      bannerJson{"imagePath"} = newJString(singletonInstance.utils.fromPathUri(bannerJson["imagePath"].getStr))
      var tagsString = tags
      if len(tagsString) == 0:
        tagsString = "[]"

      let response = status_go.createCommunity(
        name,
        description,
        introMessage,
        outroMessage,
        access,
        color,
        tagsString,
        singletonInstance.utils.fromPathUri(imageUrl),
        aX, aY, bX, bY,
        historyArchiveSupportEnabled,
        pinMessageAllMembersEnabled,
        $bannerJson)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error creating community: " & error.message)

      if response.result != nil and response.result.kind != JNull:
        var community = response.result["communities"][0].toCommunityDto()
        let communitySettings = response.result["communitiesSettings"][0].toCommunitySettingsDto()


        community.settings = communitySettings
        # add this to the communities list and communitiesSettings
        self.communities[community.id] = community
        for chat in community.chats:
          self.chatService.updateOrAddChat(chat)

        self.events.emit(SIGNAL_COMMUNITY_CREATED, CommunityArgs(community: community))
    except Exception as e:
      error "Error creating community", msg = e.msg

  proc editCommunity*(
      self: Service,
      id: string,
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
    try:
      # TODO: refactor status-go to use `CroppedImage` for logo as it does for banner. This is an API breaking change, sync with mobile
      let logoJson = parseJson(logoJsonStr)
      let cropRectJson = logoJson["cropRect"]
      var tagsString = tags
      var bannerJson = bannerJsonStr.parseJson
      bannerJson{"imagePath"} = newJString(singletonInstance.utils.fromPathUri(bannerJson["imagePath"].getStr))
      if len(tagsString) == 0:
        tagsString = "[]"
      let response = status_go.editCommunity(
        id,
        name,
        description,
        introMessage,
        outroMessage,
        access,
        color,
        tagsString,
        singletonInstance.utils.fromPathUri(logoJson["imagePath"].getStr()),
        int(cropRectJson["x"].getFloat()),
        int(cropRectJson["y"].getFloat()),
        int(cropRectJson["x"].getFloat() + cropRectJson["width"].getFloat()),
        int(cropRectJson["y"].getFloat() + cropRectJson["height"].getFloat()),
        $bannerJson,
        historyArchiveSupportEnabled,
        pinMessageAllMembersEnabled)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error editing community: " & error.message)

      if response.result != nil and response.result.kind != JNull:
        var community = response.result["communities"][0].toCommunityDto()
        var communitySettings = response.result["communitiesSettings"][0].toCommunitySettingsDto()

        community.settings = communitySettings
        self.saveUpdatedCommunity(community)
        self.events.emit(SIGNAL_COMMUNITY_EDITED, CommunityArgs(community: community))
    except Exception as e:
      error "Error editing community", msg = e.msg

  proc createCommunityChannel*(
      self: Service,
      communityId: string,
      name: string,
      description: string,
      emoji: string,
      color: string,
      categoryId: string,
      viewersCanPostReactions: bool,
      hideIfPermissionsNotMet: bool
      ) =
    try:
      let response = status_go.createCommunityChannel(communityId, name, description, emoji, color, categoryId,
        viewersCanPostReactions, hideIfPermissionsNotMet)

      if not response.error.isNil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error creating community channel: " & error.message)

      if response.result.isNil or response.result.kind == JNull:
        error "response is invalid", procName="createCommunityChannel"

      var chatsJArr: JsonNode
      if(not response.result.getProp("chats", chatsJArr)):
        raise newException(RpcException, fmt"createCommunityChannel; there is no `chats` key in the response for community id: {communityId}")

      let chatsForCategory = self.getChats(communityId, categoryId)
      let maxPosition = if chatsForCategory.len > 0: chatsForCategory[^1].position else: -1

      for chatObj in chatsJArr:
        let community = self.communities[communityId]
        var chatDto = chatObj.toChatDto(communityId, community.members)
        chatDto.position = maxPosition + 1
        self.chatService.updateOrAddChat(chatDto)
        self.communities[communityId].chats.add(chatDto)
        let data = CommunityChatArgs(chat: chatDto)
        self.events.emit(SIGNAL_COMMUNITY_CHANNEL_CREATED, data)

    except Exception as e:
      error "Error creating community channel", msg = e.msg, communityId, name, description, procName="createCommunityChannel"

  proc editCommunityChannel*(
      self: Service,
      communityId: string,
      channelId: string,
      name: string,
      description: string,
      emoji: string,
      color: string,
      categoryId: string,
      position: int,
      viewersCanPostReactions: bool,
      hideIfPermissionsNotMet: bool
      ) =
    try:
      let response = status_go.editCommunityChannel(
        communityId,
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

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error editing community channel: " & error.message)

      if response.result.isNil or response.result.kind == JNull:
        error "response is invalid", procName="editCommunityChannel"

      var chatsJArr: JsonNode
      if(not response.result.getProp("chats", chatsJArr)):
        raise newException(RpcException, fmt"editCommunityChannel; there is no `chats` key in the response for community id: {communityId}")

      for chatObj in chatsJArr:
        let community = self.communities[communityId]
        var chatDto = chatObj.toChatDto(communityId, community.members)
        let chatIndex = community.getCommunityChatIndex(chatDto.id)
        if chatIndex > -1:
          self.communities[communityId].chats[chatIndex] = chatDto
        self.chatService.updateOrAddChat(chatDto) # we have to update chats stored in the chat service.

        let data = CommunityChatArgs(chat: chatDto)
        self.events.emit(SIGNAL_COMMUNITY_CHANNEL_EDITED, data)

    except Exception as e:
      error "Error editing community channel", msg = e.msg, communityId, channelId, procName="editCommunityChannel"

  proc reorderCommunityChat*(
      self: Service,
      communityId: string,
      categoryId: string,
      chatId: string,
      position: int) =
    try:
      let response = status_go.reorderCommunityChat(
        communityId,
        categoryId,
        chatId,
        position)

      if not response.error.isNil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error reordering community channel: " & error.message)

      if response.result.isNil or response.result.kind == JNull:
        error "response is invalid", procName="reorderCommunityChat"
        return

      let updatedCommunity = response.result["communities"][0].toCommunityDto()

      var updatedChats: seq[ChatDto] = @[]
      for chat in updatedCommunity.chats:
        let prev_chat_idx = findIndexById(chat.id, self.communities[communityId].chats)
        if prev_chat_idx == -1:
          continue
        let prev_chat = self.getCommunityById(communityId).chats[prev_chat_idx]

        # we are free to do this cause channel must be created before we add it to a category
        var chatDetails = self.chatService.getChatById(chat.id)

        if(chat.position != prev_chat.position and chat.categoryId == categoryId):
          self.communities[communityId].chats[prev_chat_idx].position = chat.position
        elif chat.categoryId != prev_chat.categoryId:
          self.communities[communityId].chats[prev_chat_idx].categoryId = chat.categoryId
        else:
          continue

        chatDetails.updateMissingFields(self.communities[communityId].chats[prev_chat_idx])
        self.chatService.updateOrAddChat(chatDetails) # we have to update chats stored in the chat service.
        updatedChats.add(chat)

      self.events.emit(SIGNAL_COMMUNITY_CHANNELS_REORDERED,
        CommunityChatsOrderArgs(communityId: updatedCommunity.id, chats: updatedChats))

      self.communities[communityId] = updatedCommunity
    except Exception as e:
      error "Error reordering community channel", msg = e.msg, communityId, chatId, position, procName="reorderCommunityChat"

  proc deleteCommunityChat*(self: Service, communityId: string, chatId: string) =
    try:
      let response = status_go.deleteCommunityChat(communityId, chatId)
      if not response.error.isNil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error deleting community chat: " & error.message)

      if response.result.isNil or response.result.kind == JNull:
        error "response is invalid", procName="deleteCommunityChat"

      let idx = findIndexById(chatId, self.communities[communityId].chats)
      if (idx != -1):
        self.communities[communityId].chats.delete(idx)

      self.events.emit(SIGNAL_COMMUNITY_CHANNEL_DELETED, CommunityChatIdArgs(
        communityId: communityId, chatId: chatId))
    except Exception as e:
      error "Error deleting community channel", msg = e.msg, communityId, chatId, procName="deleteCommunityChat"

  proc createCommunityCategory*(
      self: Service,
      communityId: string,
      name: string,
      channels: seq[string]) =
    try:
      let response = status_go.createCommunityCategory(communityId, name, channels)
      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error creating community category: " & error.message)

      if response.result != nil and response.result.kind != JNull:
        self.checkForCategoryPropertyUpdates(
          response.result["communityChanges"].getElems()[0]["community"].toCommunityDto,
          self.communities[communityId]
        )

        var chats: seq[ChatDto] = @[]
        for chatId, v in response.result["communityChanges"].getElems()[0]["chatsModified"].pairs():
          let fullChatId = communityId & chatId
          let idx = findIndexById(fullChatId, self.communities[communityId].chats)
          if idx > -1:
            self.communities[communityId].chats[idx].categoryId = v["CategoryModified"].getStr()
            self.communities[communityId].chats[idx].position = v["PositionModified"].getInt()
            if self.communities[communityId].chats[idx].categoryId.len > 0:
              var chatDetails = self.chatService.getChatById(fullChatId) # we are free to do this cause channel must be created before we add it to a category
              chatDetails.updateMissingFields(self.communities[communityId].chats[idx])
              self.chatService.updateOrAddChat(chatDetails) # we have to update chats stored in the chat service.
              chats.add(chatDetails)

        for k, v in response.result["communityChanges"].getElems()[0]["categoriesAdded"].pairs():
          let category = v.toCategory()
          self.communities[communityId].categories.add(category)
          self.events.emit(SIGNAL_COMMUNITY_CATEGORY_CREATED,
            CommunityCategoryArgs(communityId: communityId, category: category, chats: chats))
    except Exception as e:
      error "Error creating community category", msg = e.msg, communityId, name

  proc toggleCollapsedCommunityCategoryAsync*(self: Service, communityId: string, categoryId: string, collapsed: bool) =
    let arg = AsyncCollapseCategory(
      tptr: asyncCollapseCategoryTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCollapseCategoryDone",
      communityId: communityId,
      categoryId: categoryId,
      collapsed: collapsed,
    )
    self.threadpool.start(arg)

  proc onAsyncCollapseCategoryDone*(self: Service, rpcResponse: string) {.slot.} =
    try:
      let rpcResponseObj = rpcResponse.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj["error"].getStr)

      if rpcResponseObj["response"]{"error"}.kind != JNull:
        let error = Json.decode(rpcResponseObj["response"]["error"].getStr, RpcError)
        raise newException(RpcException, error.message)
    except Exception as e:
      error "Error toggling collapsed community category", msg = e.msg

  proc editCommunityCategory*(
      self: Service,
      communityId: string,
      categoryId: string,
      name: string,
      channels: seq[string]) =
    try:
      let response = status_go.editCommunityCategory(communityId, categoryId, name, channels)
      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error creating community category: " & error.message)

      if response.result != nil and response.result.kind != JNull:
        var chats: seq[ChatDto] = @[]
        for chatId, v in response.result["communityChanges"].getElems()[0]["chatsModified"].pairs():
          let fullChatId = communityId & chatId
          let idx = findIndexById(fullChatId, self.communities[communityId].chats)
          if idx > -1:
            self.communities[communityId].chats[idx].categoryId = v["CategoryModified"].getStr()
            self.communities[communityId].chats[idx].position = v["PositionModified"].getInt()

            var chatDetails = self.chatService.getChatById(fullChatId) # we are free to do this cause channel must be created before we add it to a category
            chatDetails.updateMissingFields(self.communities[communityId].chats[idx])
            self.chatService.updateOrAddChat(chatDetails) # we have to update chats stored in the chat service.
            chats.add(chatDetails)

        # Update communities objects
        var updatedCommunity = response.result["communities"][0].toCommunityDto
        self.checkForCategoryPropertyUpdates(
          updatedCommunity,
          self.communities[communityId]
        )

        self.saveUpdatedCommunity(updatedCommunity)

        for k, v in response.result["communityChanges"].getElems()[0]["categoriesModified"].pairs():
          let category = v.toCategory()
          self.events.emit(SIGNAL_COMMUNITY_CATEGORY_EDITED,
            CommunityCategoryArgs(communityId: communityId, category: category, chats: chats))

    except Exception as e:
      error "Error editing community category", msg = e.msg, communityId, name

  proc deleteCommunityCategory*(self: Service, communityId: string, categoryId: string) =
    try:
      let response = status_go.deleteCommunityCategory(communityId, categoryId)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error deleting community category: " & error.message)

      # Update communities objects
      var updatedCommunity = response.result["communities"][0].toCommunityDto

      self.checkForCategoryPropertyUpdates(
        updatedCommunity,
        self.communities[communityId]
      )

      self.saveUpdatedCommunity(updatedCommunity)

      self.events.emit(SIGNAL_COMMUNITY_CATEGORY_DELETED,
        CommunityCategoryArgs(
          communityId: communityId,
          category: Category(id: categoryId),
          chats: updatedCommunity.chats
        )
      )
    except Exception as e:
      error "Error deleting community category", msg = e.msg, communityId, categoryId

  proc reorderCommunityCategories*(
      self: Service,
      communityId: string,
      categoryId: string,
      position: int) =
    try:
      let response = status_go.reorderCommunityCategories(
        communityId,
        categoryId,
        position)

      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error reordering community category: " & error.message)

      let updatedCommunity = response.result["communities"][0].toCommunityDto()
      # Update community categories
      self.checkForCategoryPropertyUpdates(updatedCommunity, self.communities[communityId])
      self.communities[communityId].categories = updatedCommunity.categories
    except Exception as e:
      error "Error reordering category channel", msg = e.msg, communityId, categoryId, position

  proc asyncCommunityMetricsLoaded*(self: Service, rpcResponse: string) {.slot.} =
    let rpcResponseObj = rpcResponse.parseJson
    if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
      error "Error collecting community metrics", msg = rpcResponseObj{"error"}
      return

    let communityId = rpcResponseObj{"communityId"}.getStr()
    let metricsType = rpcResponseObj{"response"}{"result"}{"type"}.getInt()

    var metrics = rpcResponseObj{"response"}{"result"}.toCommunityMetricsDto()
    self.communityMetrics[communityId] = metrics
    self.events.emit(SIGNAL_COMMUNITY_METRICS_UPDATED, CommunityMetricsArgs(communityId: communityId, metricsType: metrics.metricsType))

  proc asyncCommunityInfoLoaded*(self: Service, communityIdAndRpcResponse: string) {.slot.} =
    let rpcResponseObj = communityIdAndRpcResponse.parseJson

    let requestedCommunityId = rpcResponseObj{"communityId"}.getStr()

    if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
      error "Error requesting community info", msg = rpcResponseObj{"error"}
      self.events.emit(SIGNAL_COMMUNITY_LOAD_DATA_FAILED, CommunityArgs(communityId: requestedCommunityId, error: "Couldn't find community info"))
      return

    var community = rpcResponseObj{"response"}{"result"}.toCommunityDto()

    if community.id == "":
      community.id = requestedCommunityId
      self.events.emit(SIGNAL_COMMUNITY_LOAD_DATA_FAILED, CommunityArgs(communityId: requestedCommunityId, community: community, error: "Couldn't find community info"))
      return

    self.communities[community.id] = community
    debug "asyncRequestCommunityInfoTask finished", communityId = requestedCommunityId, communityName = community.name

    if rpcResponseObj{"importing"}.getBool():
      self.events.emit(SIGNAL_COMMUNITY_IMPORTED, CommunityArgs(community: community))

    self.events.emit(SIGNAL_COMMUNITY_DATA_IMPORTED, CommunityArgs(community: community))
    self.events.emit(SIGNAL_COMMUNITIES_UPDATE, CommunitiesArgs(communities: @[community]))

  proc asyncCheckPermissionsToJoin*(self: Service, communityId: string, addresses: seq[string]) =
    let arg = AsyncCheckPermissionsToJoinTaskArg(
      tptr: asyncCheckPermissionsToJoinTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCheckPermissionsToJoinDone",
      communityId: communityId,
      addresses: addresses,
    )
    self.threadpool.start(arg)

  proc onAsyncCheckPermissionsToJoinDone*(self: Service, rpcResponse: string) {.slot.} =
    let rpcResponseObj = rpcResponse.parseJson
    let communityId = rpcResponseObj{"communityId"}.getStr()
    try:
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj["error"].getStr)

      let checkPermissionsToJoinResponse = rpcResponseObj["response"].toCheckPermissionsToJoinResponseDto
      self.events.emit(SIGNAL_CHECK_PERMISSIONS_TO_JOIN_RESPONSE, CheckPermissionsToJoinResponseArgs(
        communityId: communityId,
        checkPermissionsToJoinResponse: checkPermissionsToJoinResponse
      ))
    except Exception as e:
      let errMsg = e.msg
      error "Error checking permissions to join: ", errMsg
      self.events.emit(SIGNAL_CHECK_PERMISSIONS_TO_JOIN_FAILED, CheckPermissionsToJoinFailedArgs(
        communityId: communityId,
        error: errMsg,
      ))

  proc generateJoiningCommunityRequestsForSigning*(self: Service, memberPubKey: string, communityId: string,
    addressesToReveal: seq[string]): seq[SignParamsDto] =
    try:
      let response = status_go.generateJoiningCommunityRequestsForSigning(memberPubKey, communityId, addressesToReveal)
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)
      result = map(response.result.getElems(), x => x.toSignParamsDto())
    except Exception as e:
      error "Error while generating join community request", msg = e.msg
      self.events.emit(SIGNAL_COMMUNITY_MY_REQUEST_FAILED, CommunityRequestFailedArgs(
        communityId: communityId,
        error: e.msg
      ))

  proc generateEditCommunityRequestsForSigning*(self: Service, memberPubKey: string, communityId: string,
    addressesToReveal: seq[string]): seq[SignParamsDto] =
    try:
      let response = status_go.generateEditCommunityRequestsForSigning(memberPubKey, communityId, addressesToReveal)
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)
      result = map(response.result.getElems(), x => x.toSignParamsDto())
    except Exception as e:
      error "Error while generating edit community request", msg = e.msg
      self.events.emit(SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_FAILED, CommunityRequestFailedArgs(
        communityId: communityId,
        error: e.msg
      ))

  proc signCommunityRequests*(self: Service, communityId: string, signParams: seq[SignParamsDto]): seq[string] =
    try:
      var data = %* []
      for param in signParams:
        data.add(param.toJson())
      let response = status_go.signData(data)
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)
      result = map(response.result.getElems(), x => x.getStr())
    except Exception as e:
      error "Error while signing joining community request", msg = e.msg
      self.events.emit(SIGNAL_COMMUNITY_MY_REQUEST_FAILED, CommunityRequestFailedArgs(
        communityId: communityId,
        error: e.msg
      ))

  proc asyncRequestToJoinCommunity*(self: Service, communityId: string, ensName: string, addressesToShare: seq[string],
    airdropAddress: string, signatures: seq[string]) =
    try:
      let arg = AsyncRequestToJoinCommunityTaskArg(
        tptr: asyncRequestToJoinCommunityTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncRequestToJoinCommunityDone",
        communityId: communityId,
        ensName: ensName,
        addressesToShare: addressesToShare,
        signatures: signatures,
        airdropAddress: airdropAddress,
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error request to join community", msg = e.msg

  proc onAsyncRequestToJoinCommunityDone*(self: Service, communityIdAndRpcResponse: string) {.slot.} =
    let rpcResponseObj = communityIdAndRpcResponse.parseJson
    try:
      if (rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != ""):
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      let rpcResponse = Json.decode($rpcResponseObj["response"], RpcResponse[JsonNode])
      checkAndEmitACNotificationsFromResponse(self.events, rpcResponse.result{"activityCenterNotifications"})

      if not self.processRequestsToJoinCommunity(rpcResponse.result):
        raise newException(CatchableError, "no 'requestsToJoinCommunity' key in response")

    except Exception as e:
      error "Error requesting to join the community", msg = e.msg
      self.events.emit(SIGNAL_COMMUNITY_MY_REQUEST_FAILED, CommunityRequestFailedArgs(
        communityId: rpcResponseObj["communityId"].getStr,
        error: e.msg
      ))

  proc asyncEditSharedAddresses*(self: Service, communityId: string, addressesToShare: seq[string], airdropAddress: string,
    signatures: seq[string]) =
    let arg = AsyncEditSharedAddressesTaskArg(
      tptr: asyncEditSharedAddressesTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncEditSharedAddressesDone",
      communityId: communityId,
      addressesToShare: addressesToShare,
      signatures: signatures,
      airdropAddress: airdropAddress,
    )
    self.threadpool.start(arg)

  proc onAsyncEditSharedAddressesDone*(self: Service, communityIdAndRpcResponse: string) {.slot.} =
    let rpcResponseObj = communityIdAndRpcResponse.parseJson
    try:
      if (rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != ""):
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      # If we need the returned shared addresses, use the value in members.revealed_accounts of the response
      self.events.emit(SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_SUCCEEDED, CommunityIdArgs(
        communityId: rpcResponseObj["communityId"].getStr,
      ))
    except Exception as e:
      error "Error editing shared addresses", msg = e.msg
      self.events.emit(SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_FAILED, CommunityRequestFailedArgs(
        communityId: rpcResponseObj["communityId"].getStr,
        error: e.msg
      ))

  proc asyncAcceptRequestToJoinCommunity*(self: Service, communityId: string, requestId: string) =
    try:
      let userKey = self.getUserPubKeyFromPendingRequest(communityId, requestId)
      self.events.emit(SIGNAL_ACCEPT_REQUEST_TO_JOIN_LOADING, CommunityMemberArgs(communityId: communityId, pubKey: userKey))
      let arg = AsyncAcceptRequestToJoinCommunityTaskArg(
        tptr: asyncAcceptRequestToJoinCommunityTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncAcceptRequestToJoinCommunityDone",
        communityId: communityId,
        requestId: requestId
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error accepting request to join community", msg = e.msg

  proc onAsyncAcceptRequestToJoinCommunityDone*(self: Service, response: string) {.slot.} =
    var communityId: string
    var requestId: string
    var userKey: string
    try:
      let rpcResponseObj = response.parseJson
      communityId = rpcResponseObj{"communityId"}.getStr
      requestId = rpcResponseObj{"requestId"}.getStr
      userKey = self.getUserPubKeyFromPendingRequest(communityId, requestId)
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        let errorMessage = rpcResponseObj{"error"}.getStr

        if errorMessage.contains("has no permission to join"):
          self.events.emit(SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED_NO_PERMISSION,
            CommunityMemberArgs(communityId: communityId, pubKey: userKey, requestId: requestId))
        else:
          self.events.emit(SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED,
            CommunityMemberArgs(communityId: communityId, pubKey: userKey, requestId: requestId))
        return

      let updatedCommunity = rpcResponseObj["response"]["result"]["communities"][0].toCommunityDto
      let requestToJoin = rpcResponseObj["response"]["result"]["requestsToJoinCommunity"][0].toCommunityMembershipRequestDto

      self.updateMembershipRequestToNewState(communityId, requestId, updatedCommunity,
        RequestToJoinType(requestToJoin.state))

      if (userKey == ""):
        error "Did not find pubkey in the pending request"
        return

      self.events.emit(SIGNAL_COMMUNITY_EDITED, CommunityArgs(community: self.communities[communityId]))
      self.events.emit(SIGNAL_COMMUNITY_MEMBER_APPROVED,
        CommunityMemberArgs(communityId: communityId, pubKey: userKey, requestId: requestId))

      let rpcResponse = Json.decode($rpcResponseObj["response"], RpcResponse[JsonNode])
      checkAndEmitACNotificationsFromResponse(self.events, rpcResponse.result{"activityCenterNotifications"})

    except Exception as e:
      let errMsg = e.msg
      error "error accepting request to join: ", errMsg
      self.events.emit(SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED,
        CommunityMemberArgs(communityId: communityId, pubKey: userKey, requestId: requestId))

  proc asyncLoadCuratedCommunities*(self: Service) =
    self.events.emit(SIGNAL_CURATED_COMMUNITIES_LOADING, Args())
    try:
      let arg = AsyncLoadCuratedCommunitiesTaskArg(
        tptr: asyncLoadCuratedCommunitiesTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncLoadCuratedCommunitiesDone",
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error loading curated communities", msg = e.msg

  proc onAsyncLoadCuratedCommunitiesDone*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      if (rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != ""):
        error "Error loading curated communities", msg = rpcResponseObj{"error"}.getStr
        self.events.emit(SIGNAL_CURATED_COMMUNITIES_LOADING_FAILED, Args())
        return
      let curatedCommunities = parseCuratedCommunities(rpcResponseObj["response"]["result"])
      for curatedCommunity in curatedCommunities:
        self.communities[curatedCommunity.id] = curatedCommunity
      self.events.emit(SIGNAL_CURATED_COMMUNITIES_LOADED, CommunitiesArgs(communities: curatedCommunities))
    except Exception as e:
      let errMsg = e.msg
      error "error loading curated communities: ", errMsg
      self.events.emit(SIGNAL_CURATED_COMMUNITIES_LOADING_FAILED, Args())

  proc getCommunityMetrics*(self: Service, communityId: string, metricsType: CommunityMetricsType): CommunityMetricsDto =
    # NOTE: use metricsType when other metrics types added
    if self.communityMetrics.hasKey(communityId):
      return self.communityMetrics[communityId]
    return CommunityMetricsDto()

  proc collectCommunityMetricsMessagesTimestamps*(self: Service, communityId: string, intervals: string) =
    let arg = AsyncCollectCommunityMetricsTaskArg(
      tptr: asyncCollectCommunityMetricsTask,
      vptr: cast[uint](self.vptr),
      slot: "asyncCommunityMetricsLoaded",
      communityId: communityId,
      metricsType: CommunityMetricsType.MessagesTimestamps,
      intervals: parseJson(intervals)
    )
    self.threadpool.start(arg)

  proc collectCommunityMetricsMessagesCount*(self: Service, communityId: string, intervals: string) =
    let arg = AsyncCollectCommunityMetricsTaskArg(
      tptr: asyncCollectCommunityMetricsTask,
      vptr: cast[uint](self.vptr),
      slot: "asyncCommunityMetricsLoaded",
      communityId: communityId,
      metricsType: CommunityMetricsType.MessagesCount,
      intervals: parseJson(intervals)
    )
    self.threadpool.start(arg)

  proc requestCommunityInfo*(self: Service, communityId: string, importing = false, tryDatabase = true,
      requiredTimeSinceLastRequest = initDuration(0, 0)) =

    let now = now().toTime()
    if self.communityInfoRequests.hasKey(communityId):
      let lastRequestTime = self.communityInfoRequests[communityId]
      let actualTimeSincLastRequest = now - lastRequestTime
      if actualTimeSincLastRequest < requiredTimeSinceLastRequest:
        debug "requestCommunityInfo: skipping as required time has not passed yet since last request", communityId, actualTimeSincLastRequest, requiredTimeSinceLastRequest
        return

    self.communityInfoRequests[communityId] = now

    let arg = AsyncRequestCommunityInfoTaskArg(
      tptr: asyncRequestCommunityInfoTask,
      vptr: cast[uint](self.vptr),
      slot: "asyncCommunityInfoLoaded",
      communityId: communityId,
      importing: importing,
      tryDatabase: tryDatabase,
    )
    self.threadpool.start(arg)

  proc exportCommunity*(self: Service, communityId: string): string =
    try:
      let response = status_go.exportCommunity(communityId)
      if (response.result != nil):
        return response.result.getStr
    except Exception as e:
      error "Error exporting community", msg = e.msg

  proc speedupArchivesImport*() =
    try:
      let response = status_go.speedupArchivesImport()
      if (response.error != nil):
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, fmt"err: {error.message}")
    except Exception as e:
      error "Error speeding up archives import: ", msg = e.msg

  proc slowdownArchivesImport*() =
    try:
      let response = status_go.slowdownArchivesImport()
      if (response.error != nil):
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, fmt"err: {error.message}")
    except Exception as e:
      error "Error slowing down archives import: ", msg = e.msg

  proc getPendingRequestIndex(self: Service, communityId: string, requestId: string): int =
    let community = self.getCommunityById(communityId)
    var i = 0
    for pendingRequest in community.pendingRequestsToJoin:
      if (pendingRequest.id == requestId):
        return i
      i.inc()
    return -1

  proc getDeclinedRequestIndex(self: Service, communityId: string, requestId: string): int =
    let community = self.getCommunityById(communityId)
    var i = 0
    for declinedRequest in community.declinedRequestsToJoin:
      if (declinedRequest.id == requestId):
        return i
      i.inc()
    return -1

  proc getWaitingForSharedAddressesRequestIndex(self: Service, communityId: string, requestId: string): int =
    let community = self.getCommunityById(communityId)
    for i in 0 ..< len(community.waitingForSharedAddressesRequestsToJoin):
      if (community.waitingForSharedAddressesRequestsToJoin[i].id == requestId):
        return i
    return -1

  proc updateMembershipRequestToNewState*(self: Service, communityId: string, requestId: string,
      updatedCommunity: CommunityDto, newState: RequestToJoinType) =
    let indexPending = self.getPendingRequestIndex(communityId, requestId)
    let indexDeclined = self.getDeclinedRequestIndex(communityId, requestId)
    let indexAwaitingAddresses = self.getWaitingForSharedAddressesRequestIndex(communityId, requestId)

    if (indexPending == -1 and indexDeclined == -1 and indexAwaitingAddresses == -1):
      raise newException(RpcException, fmt"Community request not found: {requestId}")

    var community = self.getCommunityById(communityId)

    if (indexPending != -1):
      if @[RequestToJoinType.Declined, RequestToJoinType.Accepted, RequestToJoinType.Canceled].any(x => x == newState):
        # If the state is now declined, add to the declined requests
        if newState == RequestToJoinType.Declined:
          community.declinedRequestsToJoin.add(community.pendingRequestsToJoin[indexPending])
        elif newState == RequestToJoinType.Canceled:
          self.events.emit(SIGNAL_REQUEST_TO_JOIN_COMMUNITY_CANCELED,
            CanceledCommunityRequestArgs(
              communityId: communityId,
              requestId: requestId,
              pubKey: community.pendingRequestsToJoin[indexPending].publicKey,
            )
          )

        # If the state is no longer pending, delete the request
        community.pendingRequestsToJoin.delete(indexPending)
      else:
        community.pendingRequestsToJoin[indexPending].state = newState.int
    elif indexDeclined != -1:
      community.declinedRequestsToJoin.delete(indexDeclined)
    elif indexAwaitingAddresses != -1 and newState != RequestToJoinType.AwaitingAddress:
      if newState == RequestToJoinType.Declined:
        community.declinedRequestsToJoin.add(community.waitingForSharedAddressesRequestsToJoin[indexAwaitingAddresses])

      let myPublicKey = singletonInstance.userProfile.getPubKey()
      let awaitingRequestToJoin = community.waitingForSharedAddressesRequestsToJoin[indexAwaitingAddresses]
      community.waitingForSharedAddressesRequestsToJoin.delete(indexAwaitingAddresses)
      if awaitingRequestToJoin.publicKey == myPublicKey:
        self.events.emit(SIGNAL_WAITING_ON_NEW_COMMUNITY_OWNER_TO_CONFIRM_REQUEST_TO_REJOIN, CommunityIdArgs(communityId: communityId))

    community.members = updatedCommunity.members
    self.communities[communityId] = community

  proc cancelRequestToJoinCommunity*(self: Service, communityId: string) =
    try:
      if (not self.communities.contains(communityId)):
        error "Cancel request to join community failed: unknown community", communityId=communityId
        return

      var community = self.getCommunityById(communityId)
      let myPublicKey = singletonInstance.userProfile.getPubKey()
      var i = 0
      for myPendingRequest in community.pendingRequestsToJoin:
        if myPendingRequest.publicKey == myPublicKey:
          let response = status_go.cancelRequestToJoinCommunity(myPendingRequest.id)
          if (not response.error.isNil):
            let msg = response.error.message & " communityId=" & communityId
            error "error while cancel membership request ", msg
            return

          self.events.emit(SIGNAL_REQUEST_TO_JOIN_COMMUNITY_CANCELED,
            CanceledCommunityRequestArgs(
              communityId: communityId,
              requestId: myPendingRequest.id,
              pubKey: community.pendingRequestsToJoin[i].publicKey,
            )
          )
          community.pendingRequestsToJoin.delete(i)
          self.communities[communityId] = community
          checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
          return

        i.inc()
    except Exception as e:
      error "Error canceled request to join community", msg = e.msg

  proc declineRequestToJoinCommunity*(self: Service, communityId: string, requestId: string) =
    try:
      let response = status_go.declineRequestToJoinCommunity(requestId)
      let requestToJoin = response.result["requestsToJoinCommunity"][0].toCommunityMembershipRequestDto

      self.updateMembershipRequestToNewState(communityId, requestId, self.communities[communityId],
        RequestToJoinType(requestToJoin.state))

      self.events.emit(SIGNAL_COMMUNITY_EDITED, CommunityArgs(community: self.communities[communityId]))
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
    except Exception as e:
      error "Error declining request to join community", msg = e.msg

  proc shareCommunityToUsers*(self: Service, communityId: string, pubKeysJson: string, inviteMessage: string): string =
    try:
      let pubKeysParsed = pubKeysJson.parseJson
      var pubKeys: seq[string] = @[]
      for pubKey in pubKeysParsed:
        pubKeys.add(pubKey.getStr)
      # We no longer send invites, but merely share the community so
      # users can request access (with automatic acception)
      let response = status_go.shareCommunityToUsers(communityId, pubKeys, inviteMessage)
      discard self.chatService.processMessengerResponse(response)
    except Exception as e:
      error "Error sharing community", msg = e.msg
      result = "Error sharing community: " & e.msg

  proc muteCategory*(self: Service, communityId: string, categoryId: string, interval: int) =
    try:
      let response = status_go.muteCategory(communityId, categoryId, interval)
      if (not response.error.isNil):
        let msg = response.error.message & " categoryId=" & categoryId
        error "error while mute category ", msg
        return

      self.events.emit(SIGNAL_CATEGORY_MUTED, CategoryArgs(communityId: communityId, categoryId: categoryId))

    except Exception as e:
      error "Error muting category", msg = e.msg

  proc unmuteCategory*(self: Service, communityId: string, categoryId: string) =
    try:
      let response = status_go.unmuteCategory(communityId, categoryId)
      if (not response.error.isNil):
        let msg = response.error.message & " categoryId=" & categoryId
        error "error while unmute category ", msg
        return

      self.events.emit(SIGNAL_CATEGORY_UNMUTED, CategoryArgs(communityId: communityId, categoryId: categoryId))

    except Exception as e:
      error "Error unmuting category", msg = e.msg

  proc asyncRemoveUserFromCommunity*(self: Service, communityId, pubKey: string) =
    let arg = AsyncCommunityMemberActionTaskArg(
      tptr: asyncRemoveUserFromCommunityTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCommunityMemberActionCompleted",
      communityId: communityId,
      pubKey: pubKey,
    )
    self.threadpool.start(arg)

  proc asyncBanUserFromCommunity*(self: Service, communityId, pubKey: string, deleteAllMessages: bool) =
    let arg = AsyncCommunityMemberActionTaskArg(
      tptr: asyncBanUserFromCommunityTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCommunityMemberActionCompleted",
      communityId: communityId,
      pubKey: pubKey,
      deleteAllMessages: deleteAllMessages
    )
    self.threadpool.start(arg)

  proc asyncUnbanUserFromCommunity*(self: Service, communityId, pubKey: string) =
    let arg = AsyncCommunityMemberActionTaskArg(
      tptr: asyncUnbanUserFromCommunityTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCommunityMemberActionCompleted",
      communityId: communityId,
      pubKey: pubKey,
    )
    self.threadpool.start(arg)

  proc onAsyncCommunityMemberActionCompleted*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson

      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(RpcException, rpcResponseObj["error"].getStr)

      if rpcResponseObj["response"]{"error"}.kind != JNull:
        let error = Json.decode(rpcResponseObj["response"]["error"].getStr, RpcError)
        raise newException(RpcException, error.message)

      let memberPubkey = rpcResponseObj{"pubKey"}.getStr()

      var communityJArr: JsonNode
      if not rpcResponseObj["response"]{"result"}.getProp("communities", communityJArr):
        raise newException(RpcException, "there is no `communities` key in the response")

      if communityJArr.len == 0:
        raise newException(RpcException, "`communities` array is empty in the response")

      var community = communityJArr[0].toCommunityDto()

      var state: MembershipRequestState = MembershipRequestState.None
      if community.pendingAndBannedMembers.hasKey(memberPubkey):
        state = community.pendingAndBannedMembers[memberPubkey].toMembershipRequestState()

      if state == MembershipRequestState.None:
        let prevCommunity = self.communities[community.id]
        if prevCommunity.pendingAndBannedMembers.hasKey(memberPubkey):
          state = MembershipRequestState.Unbanned
        elif len(prevCommunity.members) > len(community.members):
          state = MembershipRequestState.Kicked

      self.events.emit(SIGNAL_COMMUNITY_MEMBER_STATUS_CHANGED, CommunityMemberStatusUpdatedArgs(
        communityId: community.id,
        memberPubkey: memberPubkey,
        state: state
      ))

    except Exception as e:
      error "error while getting the community members' revealed addressesses", msg = e.msg

  proc setCommunityMuted*(self: Service, communityId: string, mutedType: int) =
    try:
      let response = status_go.setCommunityMuted(communityId, mutedType)
      if not response.error.isNil:
        error "error muting the community", msg = response.error.message
        return

      let muted = if (MutedType(mutedType) == MutedType.Unmuted): false else: true

      self.communities[communityId].muted = muted

      self.events.emit(SIGNAL_COMMUNITY_MUTED,
        CommunityMutedArgs(communityId: communityId, muted: muted))
    except Exception as e:
      error "Error setting community un/muted", msg = e.msg

  proc isMyCommunityRequestPending*(self: Service, communityId: string): bool {.slot.} =
    if not self.communities.contains(communityId):
      error "IsMyCommunityRequestPending failed: unknown community", communityId=communityId
      return false

    let myPublicKey = singletonInstance.userProfile.getPubKey()
    var community = self.getCommunityById(communityId)
    for pendingRequest in community.pendingRequestsToJoin:
      if pendingRequest.publicKey == myPublicKey:
        return true
    return false

  proc waitingOnNewCommunityOwnerToConfirmRequestToRejoin*(self: Service, communityId: string): bool {.slot.} =
    if not self.communities.contains(communityId):
      error "waitingOnNewCommunityOwnerToConfirmRequestToRejoin failed: unknown community", communityId=communityId
      return false

    let myPublicKey = singletonInstance.userProfile.getPubKey()
    var community = self.getCommunityById(communityId)
    for request in community.waitingForSharedAddressesRequestsToJoin:
      if request.publicKey == myPublicKey:
        return true
    return false

  proc requestExtractDiscordChannelsAndCategories*(self: Service, filesToImport: seq[string]) =
    try:
      discard status_go.requestExtractDiscordChannelsAndCategories(filesToImport)
    except Exception as e:
      error "Error extracting discord channels and categories", msg = e.msg

  proc requestCancelDiscordCommunityImport*(self: Service, communityId: string) =
    try:
      discard status_go.requestCancelDiscordCommunityImport(communityId)
    except Exception as e:
      error "Error canceling discord community import", msg = e.msg

  proc requestCancelDiscordChannelImport*(self: Service, discordChannelId: string) =
    try:
      discard status_go.requestCancelDiscordChannelImport(discordChannelId)
    except Exception as e:
      error "Error canceling discord channel import", msg = e.msg

  proc createOrEditCommunityTokenPermission*(self: Service, communityId: string, tokenPermission: CommunityTokenPermissionDto) =
    try:
      let editing = tokenPermission.id != ""
      var response: RpcResponse[JsonNode]
      if editing:
        response = status_go.editCommunityTokenPermission(communityId, tokenPermission.id, int(tokenPermission.`type`), Json.encode(tokenPermission.tokenCriteria), tokenPermission.chatIDs, tokenPermission.isPrivate)
      else:
        response = status_go.createCommunityTokenPermission(communityId, int(tokenPermission.`type`), Json.encode(tokenPermission.tokenCriteria), tokenPermission.chatIDs, tokenPermission.isPrivate)

      if response.result != nil and response.result.kind != JNull:
        return

      var signal = SIGNAL_COMMUNITY_TOKEN_PERMISSION_CREATION_FAILED
      if editing:
        signal = SIGNAL_COMMUNITY_TOKEN_PERMISSION_UPDATE_FAILED

      self.events.emit(signal, CommunityTokenPermissionArgs(communityId: communityId, tokenPermission: tokenPermission))
    except Exception as e:
      error "Error creating/editing community token permission", msg = e.msg

  proc deleteCommunityTokenPermission*(self: Service, communityId: string, permissionId: string) =
    try:
      let response = status_go.deleteCommunityTokenPermission(communityId, permissionId)
      if response.result != nil and response.result.kind != JNull:
        return

      var tokenPermission = CommunityTokenPermissionDto()
      tokenPermission.id = permissionId
      self.events.emit(SIGNAL_COMMUNITY_TOKEN_PERMISSION_DELETION_FAILED,
        CommunityTokenPermissionArgs(communityId: communityId, tokenPermission: tokenPermission))
    except Exception as e:
      error "Error deleting community token permission", msg = e.msg

  proc getUserPubKeyFromPendingRequest*(self: Service, communityId: string, requestId: string): string =
    let indexPending = self.getPendingRequestIndex(communityId, requestId)
    let indexDeclined = self.getDeclinedRequestIndex(communityId, requestId)
    if (indexPending == -1 and indexDeclined == -1):
      raise newException(RpcException, fmt"Community request not found: {requestId}")

    let community = self.getCommunityById(communityId)
    if (indexPending != -1):
      return community.pendingRequestsToJoin[indexPending].publicKey
    else:
      return community.declinedRequestsToJoin[indexDeclined].publicKey

  proc shareCommunityUrlWithChatKey*(self: Service, communityId: string): string =
    try:
      let response = shared_urls.shareCommunityUrlWithChatKey(communityId)
      return response.result.getStr
    except Exception as e:
      error "error while getting community url with chat key", msg = e.msg

  proc shareCommunityUrlWithData*(self: Service, communityId: string): string =
    try:
      let response = shared_urls.shareCommunityUrlWithData(communityId)
      return response.result.getStr
    except Exception as e:
      error "error while getting community url with data", msg = e.msg

  proc shareCommunityChannelUrlWithChatKey*(self: Service, communityId: string, chatId: string): string =
    try:
      let response = shared_urls.shareCommunityChannelUrlWithChatKey(communityId, chatId)
      return response.result.getStr
    except Exception as e:
      error "error while getting community channel url with chat key ", msg = e.msg

  proc shareCommunityChannelUrlWithData*(self: Service, communityId: string, chatId: string): string =
    try:
      let response = shared_urls.shareCommunityChannelUrlWithData(communityId, chatId)
      return response.result.getStr
    except Exception as e:
      error "error while getting community channel url with data ", msg = e.msg

  proc getCommunityPublicKeyFromPrivateKey*(self: Service, communityPrivateKey: string): string =
    try:
      let response = status_go.getCommunityPublicKeyFromPrivateKey(communityPrivateKey)
      result = response.result.getStr
    except Exception as e:
      error "error while getting community public key", msg = e.msg

  proc asyncGetRevealedAccountsForMember*(self: Service, communityId, memberPubkey: string) =
    let arg = AsyncGetRevealedAccountsArg(
      tptr: asyncGetRevealedAccountsForMemberTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncGetRevealedAccountsForMemberCompleted",
      communityId: communityId,
      memberPubkey: memberPubkey,
    )
    self.threadpool.start(arg)

  proc onAsyncGetRevealedAccountsForMemberCompleted*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson

      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(RpcException, rpcResponseObj["error"].getStr)

      if rpcResponseObj["response"]{"error"}.kind != JNull:
        let error = Json.decode(rpcResponseObj["response"]["error"].getStr, RpcError)
        raise newException(RpcException, error.message)

      let revealedAccounts = rpcResponseObj["response"]["result"].toRevealedAccounts()

      self.events.emit(SIGNAL_COMMUNITY_MEMBER_REVEALED_ACCOUNTS_LOADED, CommunityMemberRevealedAccountsArgs(
        communityId: rpcResponseObj["communityId"].getStr,
        memberPubkey: rpcResponseObj["memberPubkey"].getStr,
        memberRevealedAccounts: revealedAccounts,
      ))
    except Exception as e:
      error "error while getting the community members' revealed addressesses", msg = e.msg

  proc asyncGetRevealedAccountsForAllMembers*(self: Service, communityId: string) =
    let arg = AsyncGetRevealedAccountsArg(
      tptr: asyncGetRevealedAccountsForAllMembersTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncGetRevealedAccountsForAllMembersCompleted",
      communityId: communityId,
    )
    self.threadpool.start(arg)

  proc onAsyncGetRevealedAccountsForAllMembersCompleted*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson

      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(RpcException, rpcResponseObj["error"].getStr)

      if rpcResponseObj["response"]{"error"}.kind != JNull:
        let error = Json.decode(rpcResponseObj["response"]["error"].getStr, RpcError)
        raise newException(RpcException, error.message)

      let revealedAccounts = rpcResponseObj["response"]["result"].toMembersRevealedAccounts

      self.events.emit(SIGNAL_COMMUNITY_MEMBERS_REVEALED_ACCOUNTS_LOADED, CommunityMembersRevealedAccountsArgs(
        communityId: rpcResponseObj["communityId"].getStr,
        membersRevealedAccounts: revealedAccounts
      ))
    except Exception as e:
      error "error while getting the community members' revealed addressesses", msg = e.msg

  proc asyncReevaluateCommunityMembersPermissions*(self: Service, communityId: string) =
    let arg = AsyncGetRevealedAccountsArg(
      tptr: asyncReevaluateCommunityMembersPermissionsTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncReevaluateCommunityMembersPermissionsCompleted",
      communityId: communityId,
    )
    self.threadpool.start(arg)

  proc onAsyncReevaluateCommunityMembersPermissionsCompleted*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson

      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(RpcException, rpcResponseObj["error"].getStr)

    except Exception as e:
      error "error while reevaluating community members permissions", msg = e.msg

  proc promoteSelfToControlNode*(self: Service, communityId: string) =
    try:
      let response = status_go.promoteSelfToControlNode(communityId)
      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, error.message)

      if response.result == nil or response.result.kind == JNull or response.result["communities"].kind == JNull or
          response.result["communities"].len == 0:
        error "error: ", procName="promoteSelfToControlNode", errDesription = "result is nil"
        return

      let community = response.result["communities"][0].toCommunityDto()
      self.communities[communityId] = community
      self.events.emit(SIGNAL_COMMUNITIES_UPDATE, CommunitiesArgs(communities: @[community]))
    except Exception as e:
      error "error promoting self to control node", msg = e.msg

  proc categoryHasUnreadMessages*(self: Service, communityId: string, categoryId: string): bool =
    if communityId == "" or categoryId == "":
      return false

    if not self.communities.contains(communityId):
      warn "unknown community", communityId
      return false

    for chat in self.communities[communityId].chats:
      if chat.categoryId != categoryId:
        continue
      let chatDto = self.chatService.getChatById(chat.id)
      if (not chatDto.muted and chatDto.unviewedMessagesCount > 0) or chatDto.unviewedMentionsCount > 0:
        return true
    return false

  proc markAllReadInCommunity*(self: Service, communityId: string) =
    try:
      let response = status_go.markAllReadInCommunity(communityId)
      if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, error.message)

      self.chatService.parseChatResponseAndEmit(response)
    except Exception as e:
      error "error marking all read in community", msg = e.msg
