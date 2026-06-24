import tables
import ../../../../app_service/service/community/service as community_service
import ../../../../app_service/service/chat/service as chat_service
import ../../shared_models/section_item

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method cleanJoinEditCommunityData*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onActivated*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityDataLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method setCommunityTags*(self: AccessInterface, communityTags: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method setAllCommunities*(self: AccessInterface, communities: seq[CommunityDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method setCuratedCommunities*(self: AccessInterface, curatedCommunities: seq[CommunityDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getCommunityItem*(self: AccessInterface, community: CommunityDto): SectionItem {.base.} =
  raise newException(ValueError, "No implementation available")

method isDisplayNameDupeOfCommunityMember*(self: AccessInterface, displayName: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method navigateToCommunity*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method spectateCommunity*(self: AccessInterface, communityId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method createCommunity*(self: AccessInterface, name: string, description, introMessage, outroMessage: string, access: int,
                        color: string, tags: string, imagePath: string, aX: int, aY: int, bX: int, bY: int,
                        historyArchiveSupportEnabled: bool, pinMessageAllMembersEnabled: bool, bannerJsonStr: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestImportDiscordCommunity*(self: AccessInterface, name: string, description, introMessage, outroMessage: string, access: int,
                        color: string, tags: string, imagePath: string, aX: int, aY: int, bX: int, bY: int,
                        historyArchiveSupportEnabled: bool, pinMessageAllMembersEnabled: bool, filesToImport: seq[string],
                        fromTimestamp: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestImportDiscordChannel*(self: AccessInterface, name: string, discordChannelId: string, communityId: string, description: string,
                        color: string, emoji: string, filesToImport: seq[string],
                        fromTimestamp: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method isUserMemberOfCommunity*(self: AccessInterface, communityId: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method isMyCommunityRequestPending*(self: AccessInterface, communityId: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method cancelRequestToJoinCommunity*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestCommunityInfo*(self: AccessInterface, communityId: string, importing: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method myRequestAdded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityLeft*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityChannelReordered*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityChannelDeleted*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityCategoryCreated*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityCategoryEdited*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityCategoryDeleted*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityEdited*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityAdded*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method curatedCommunityAdded*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method curatedCommunityEdited*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityImported*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityDataImported*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityInfoRequestFailed*(self: AccessInterface, communityId: string, errorMsg: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onImportCommunityErrorOccured*(self: AccessInterface, communityId: string, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onImportCommunityCancelled*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityMuted*(self: AccessInterface, communityId: string, muted: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityAccessRequested*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityAccessFailed*(self: AccessInterface, communityId: string, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityEditSharedAddressesSucceeded*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityEditSharedAddressesFailed*(self: AccessInterface, communityId: string, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestExtractDiscordChannelsAndCategories*(self: AccessInterface, filesToImport: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method discordCategoriesAndChannelsExtracted*(self: AccessInterface, categories: seq[DiscordCategoryDto], channels: seq[DiscordChannelDto], oldestMessageTimestamp: int, errors: Table[string, DiscordImportError], errorsCount: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method discordImportProgressUpdated*(self: AccessInterface, communityId: string, communityName: string, communityImage: string, tasks: seq[DiscordImportTaskProgress], progress: float, errorsCount: int, warningsCount: int, stopped: bool, totalChunksCount: int, currentChunk: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method discordImportChannelProgressUpdated*(
    self: AccessInterface,
    channelId: string,
    channelName: string,
    tasks: seq[DiscordImportTaskProgress],
    progress: float,
    errorsCount: int,
    warningsCount: int,
    stopped: bool,
    totalChunksCount: int,
    currentChunk: int
  ) {.base.} =
    raise newException(ValueError, "No implementation available")

method discordImportChannelFinished*(self: AccessInterface, communityId: string, channelId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method discordImportChannelCanceled*(self: AccessInterface, channelId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestCancelDiscordCommunityImport*(self: AccessInterface, id: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestCancelDiscordChannelImport*(self: AccessInterface, discordChannelId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityHistoryArchivesDownloadStarted*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityHistoryArchivesDownloadFinished*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method curatedCommunitiesLoading*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method curatedCommunitiesLoadingFailed*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method curatedCommunitiesLoaded*(self: AccessInterface, curatedCommunities: seq[CommunityDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityTokenMetadataAdded*(self: AccessInterface, communityId: string, tokenMetadata: CommunityTokensMetadataDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onWalletAccountTokensRebuilt*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onAllTokenGroupsLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTokenList*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method shareCommunityUrlWithChatKey*(self: AccessInterface, communityId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method shareCommunityUrlWithData*(self: AccessInterface, communityId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method shareCommunityChannelUrlWithChatKey*(self: AccessInterface, communityId: string, chatId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method shareCommunityChannelUrlWithData*(self: AccessInterface, communityId: string, chatId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method onSigningResult*(self: AccessInterface, signature: string, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method prepareKeypairsForSigning*(self: AccessInterface, communityId: string, ensName: string, addresses: string,
  airdropAddress: string, editMode: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method signSharedAddressesForKeypair*(self: AccessInterface, keyUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method joinCommunityOrEditSharedAddresses*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method prepareTokenModelForCommunity*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method prepareTokenModelForCommunityChat*(self: AccessInterface, communityId: string, chatId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getCommunityPublicKeyFromPrivateKey*(self: AccessInterface, communityPrivateKey: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method checkPermissions*(self: AccessInterface, communityId: string, sharedAddresses: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityCheckPermissionsToJoinResponse*(self: AccessInterface, communityId: string, checkPermissionsToJoinResponse: CheckPermissionsToJoinResponseDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityCheckAllChannelsPermissionsResponse*(self: AccessInterface, communityId: string,
    checkChannelPermissionsResponse: CheckAllChannelsPermissionsResponseDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityCheckPermissionsToJoinFailed*(self: AccessInterface, communityId: string, ValueErrorerror: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityCheckAllChannelPermissionsFailed*(self: AccessInterface, communityId: string, ValueErrorerror: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityMemberRevealedAccountsLoaded*(self: AccessInterface, communityId: string, memberPubkey: string,
    revealedAccounts: seq[RevealedAccount]) {.base.} =
  raise newException(ValueError, "No implementation available")

method removeCommunityChat*(self: AccessInterface, communityId: string, channelId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method promoteSelfToControlNode*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getCheckingPermissionToJoinInProgress*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")
