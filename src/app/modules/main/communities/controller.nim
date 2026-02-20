import std/strutils, uuids
import ./io_interface

import app/core/signals/types
import app/core/eventemitter
import app_service/service/chat/dto/chat
import app_service/service/community/service as community_service
import app_service/service/chat/service as chat_service
import app_service/service/network/service as networks_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/keycard/service as keycard_service
import app/modules/shared_modules/keycard_popup/io_interface as keycard_shared_module
import app_service/service/network/network_item
import ../../../../backend/general as status_general

const UNIQUE_COMMUNITIES_MODULE_AUTH_IDENTIFIER* = "CommunitiesModule-Authentication"
const UNIQUE_COMMUNITIES_MODULE_SIGNING_IDENTIFIER* = "CommunitiesModule-Signing"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    communityService: community_service.Service
    communityTokensService: community_tokens_service.Service
    networksService: networks_service.Service
    tokenService: token_service.Service
    chatService: chat_service.Service
    walletAccountService: wallet_account_service.Service
    keycardService: keycard_service.Service
    connectionKeycardResponse: UUID
    ## the following are used for silent signing in case there are more then a single address for the same keypair
    silentSigningPath: string
    silentSigningKeyUid: string
    silentSigningPin: string

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    communityService: community_service.Service,
    communityTokensService: community_tokens_service.Service,
    networksService: networks_service.Service,
    tokenService: token_service.Service,
    chatService: chat_service.Service,
    walletAccountService: wallet_account_service.Service,
    keycardService: keycard_service.Service
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.communityService = communityService
  result.communityTokensService = communityTokensService
  result.networksService = networksService
  result.tokenService = tokenService
  result.chatService = chatService
  result.walletAccountService = walletAccountService
  result.keycardService = keycardService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.once(SIGNAL_COMMUNITY_DATA_LOADED) do(e:Args):
    self.delegate.communityDataLoaded()

  self.events.on(SIGNAL_COMMUNITY_CREATED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityAdded(args.community)

  self.events.on(SIGNAL_COMMUNITY_DATA_IMPORTED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityDataImported(args.community)

  self.events.on(SIGNAL_COMMUNITY_LOAD_DATA_FAILED) do(e: Args):
    let args = CommunityArgs(e)
    self.delegate.communityInfoRequestFailed(args.communityId, args.error)

  self.events.on(SIGNAL_CURATED_COMMUNITY_FOUND) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.curatedCommunityAdded(args.community)

  self.events.on(SIGNAL_COMMUNITY_ADDED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityAdded(args.community)

  self.events.on(SIGNAL_COMMUNITY_IMPORTED) do(e:Args):
    let args = CommunityArgs(e)
    if(args.error.len > 0):
      self.delegate.onImportCommunityErrorOccured(args.community.id, args.error)
    else:
      self.delegate.communityImported(args.community)

  self.events.on(SIGNAL_COMMUNITIES_UPDATE) do(e:Args):
    let args = CommunitiesArgs(e)
    for community in args.communities:
      self.delegate.communityEdited(community)
      self.delegate.curatedCommunityEdited(community)

  self.events.on(SIGNAL_CURATED_COMMUNITIES_UPDATED) do(e:Args):
    let args = CommunitiesArgs(e)
    for community in args.communities:
      self.delegate.curatedCommunityEdited(community)

  self.events.on(SIGNAL_COMMUNITY_MUTED) do(e:Args):
    let args = CommunityMutedArgs(e)
    self.delegate.communityMuted(args.communityId, args.muted)

  self.events.on(SIGNAL_COMMUNITY_MY_REQUEST_ADDED) do(e:Args):
    let args = CommunityRequestArgs(e)
    self.delegate.communityAccessRequested(args.communityRequest.communityId)

  self.events.on(SIGNAL_COMMUNITY_MY_REQUEST_FAILED) do(e:Args):
    let args = CommunityRequestFailedArgs(e)
    self.delegate.communityAccessFailed(args.communityId, args.error)

  self.events.on(SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_SUCCEEDED) do(e:Args):
    let args = CommunityIdArgs(e)
    self.delegate.communityEditSharedAddressesSucceeded(args.communityId)

  self.events.on(SIGNAL_COMMUNITY_EDIT_SHARED_ADDRESSES_FAILED) do(e:Args):
    let args = CommunityRequestFailedArgs(e)
    self.delegate.communityEditSharedAddressesFailed(args.communityId, args.error)

  self.events.on(SIGNAL_DISCORD_CATEGORIES_AND_CHANNELS_EXTRACTED) do(e:Args):
    let args = DiscordCategoriesAndChannelsArgs(e)
    self.delegate.discordCategoriesAndChannelsExtracted(args.categories, args.channels, args.oldestMessageTimestamp, args.errors, args.errorsCount)

  self.events.on(SIGNAL_DISCORD_COMMUNITY_IMPORT_PROGRESS) do(e:Args):
    let args = DiscordImportProgressArgs(e)
    self.delegate.discordImportProgressUpdated(args.communityId, args.communityName, args.communityImage, args.tasks, args.progress, args.errorsCount, args.warningsCount, args.stopped, args.totalChunksCount, args.currentChunk)

  self.events.on(SIGNAL_DISCORD_CHANNEL_IMPORT_PROGRESS) do(e:Args):
    let args = DiscordImportChannelProgressArgs(e)
    self.delegate.discordImportChannelProgressUpdated(args.channelId, args.channelName, args.tasks, args.progress, args.errorsCount, args.warningsCount, args.stopped, args.totalChunksCount, args.currentChunk)

  self.events.on(SIGNAL_DISCORD_CHANNEL_IMPORT_FINISHED) do(e:Args):
    let args = CommunityChatIdArgs(e)
    self.delegate.discordImportChannelFinished(args.communityId, args.chatId)

  self.events.on(SIGNAL_DISCORD_CHANNEL_IMPORT_CANCELED) do(e:Args):
    let args = ChannelIdArgs(e)
    self.delegate.discordImportChannelCanceled(args.channelId)

  self.events.on(SIGNAL_COMMUNITY_HISTORY_ARCHIVES_DOWNLOAD_STARTED) do(e:Args):
    let args = CommunityIdArgs(e)
    self.delegate.communityHistoryArchivesDownloadStarted(args.communityId)

  self.events.on(SIGNAL_COMMUNITY_HISTORY_ARCHIVES_DOWNLOAD_FINISHED) do(e:Args):
    let args = CommunityIdArgs(e)
    self.delegate.communityHistoryArchivesDownloadFinished(args.communityId)

  self.events.on(SIGNAL_CURATED_COMMUNITIES_LOADING) do(e:Args):
    self.delegate.curatedCommunitiesLoading()

  self.events.on(SIGNAL_CURATED_COMMUNITIES_LOADING_FAILED) do(e:Args):
    self.delegate.curatedCommunitiesLoadingFailed()

  self.events.on(SIGNAL_CURATED_COMMUNITIES_LOADED) do(e:Args):
    let args = CommunitiesArgs(e)
    self.delegate.curatedCommunitiesLoaded(args.communities)

  self.events.on(SIGNAL_COMMUNITY_TOKEN_METADATA_ADDED) do(e: Args):
    let args = CommunityTokenMetadataArgs(e)
    self.delegate.onCommunityTokenMetadataAdded(args.communityId, args.tokenMetadata)

  self.events.on(SIGNAL_CHECK_PERMISSIONS_TO_JOIN_RESPONSE) do(e: Args):
    let args = CheckPermissionsToJoinResponseArgs(e)
    self.delegate.onCommunityCheckPermissionsToJoinResponse(args.communityId, args.checkPermissionsToJoinResponse)

  self.events.on(SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_RESPONSE) do(e: Args):
    let args = CheckAllChannelsPermissionsResponseArgs(e)
    self.delegate.onCommunityCheckAllChannelsPermissionsResponse(
      args.communityId,
      args.checkAllChannelsPermissionsResponse,
    )

  self.events.on(SIGNAL_COMMUNITY_MEMBER_REVEALED_ACCOUNTS_LOADED) do(e: Args):
    let args = CommunityMemberRevealedAccountsArgs(e)
    self.delegate.onCommunityMemberRevealedAccountsLoaded(
      args.communityId,
      args.memberPubkey,
      args.memberRevealedAccounts,
    )

  self.events.on(SIGNAL_TOKENS_LIST_UPDATED) do(e: Args):
    self.delegate.onWalletAccountTokensRebuilt()

  self.events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e: Args):
    self.delegate.onWalletAccountTokensRebuilt()

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_USER_AUTHENTICATED) do(e: Args):
    let args = SharedKeycarModuleArgs(e)
    if args.uniqueIdentifier != UNIQUE_COMMUNITIES_MODULE_AUTH_IDENTIFIER:
      return
    self.delegate.onUserAuthenticated(args.pin, args.password, args.keyUid)

  self.events.on(SIGNAL_CHECK_PERMISSIONS_TO_JOIN_FAILED) do(e: Args):
    let args = CheckPermissionsToJoinFailedArgs(e)
    self.delegate.onCommunityCheckPermissionsToJoinFailed(args.communityId, args.error)

  self.events.on(SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_FAILED) do(e: Args):
    let args = CheckChannelsPermissionsErrorArgs(e)
    self.delegate.onCommunityCheckAllChannelPermissionsFailed(args.communityId, args.error)

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_DATA_SIGNED) do(e: Args):
    let args = SharedKeycarModuleArgs(e)
    if args.uniqueIdentifier != UNIQUE_COMMUNITIES_MODULE_SIGNING_IDENTIFIER:
      return
    self.delegate.onDataSigned(args.keyUid, args.path, args.r, args.s, args.v, args.pin)

proc getCommunityTags*(self: Controller): string =
  result = self.communityService.getCommunityTags()

proc getAllCommunities*(self: Controller): seq[CommunityDto] =
  result = self.communityService.getAllCommunities()

proc isDisplayNameDupeOfCommunityMember*(self: Controller, displayName: string): bool =
  result = self.communityService.isDisplayNameDupeOfCommunityMember(displayName)

proc getCommunityById*(self: Controller, communityId: string): CommunityDto =
  result = self.communityService.getCommunityById(communityId)

proc spectateCommunity*(self: Controller, communityId: string): string =
  self.communityService.spectateCommunity(communityId)

proc cancelRequestToJoinCommunity*(self: Controller, communityId: string) =
  self.communityService.cancelRequestToJoinCommunity(communityId)

proc createCommunity*(
    self: Controller,
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
  self.communityService.createCommunity(
    name,
    description,
    introMessage,
    outroMessage,
    access,
    color,
    tags,
    imageUrl,
    aX, aY, bX, bY,
    historyArchiveSupportEnabled,
    pinMessageAllMembersEnabled,
    bannerJsonStr)

proc requestImportDiscordCommunity*(
    self: Controller,
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
  self.communityService.requestImportDiscordCommunity(
    name,
    description,
    introMessage,
    outroMessage,
    access,
    color,
    tags,
    imageUrl,
    aX, aY, bX, bY,
    historyArchiveSupportEnabled,
    pinMessageAllMembersEnabled,
    filesToImport,
    fromTimestamp)

proc requestImportDiscordChannel*(
    self: Controller,
    name: string,
    discordChannelId: string,
    communityId: string,
    description: string,
    color: string,
    emoji: string,
    filesToImport: seq[string],
    fromTimestamp: int) =
  self.communityService.requestImportDiscordChannel(
    name,
    discordChannelId,
    communityId,
    description,
    color,
    emoji,
    filesToImport,
    fromTimestamp)

proc reorderCommunityChat*(
    self: Controller,
    communityId: string,
    categoryId: string,
    chatId: string,
    position: int) =
  self.communityService.reorderCommunityChat(
    communityId,
    categoryId,
    chatId,
    position)

proc getChatDetailsByIds*(self: Controller, chatIds: seq[string]): seq[ChatDto] =
  return self.chatService.getChatsByIds(chatIds)

proc requestCommunityInfo*(self: Controller, communityId: string, importing: bool) =
  self.communityService.requestCommunityInfo(communityId, importing)

proc setCommunityMuted*(self: Controller, communityId: string, mutedType: int) =
  self.communityService.setCommunityMuted(communityId, mutedType)

proc isUserMemberOfCommunity*(self: Controller, communityId: string): bool =
  return self.communityService.isUserMemberOfCommunity(communityId)

proc isMyCommunityRequestPending*(self: Controller, communityId: string): bool =
  return self.communityService.isMyCommunityRequestPending(communityId)

proc asyncLoadCuratedCommunities*(self: Controller) =
  self.communityService.asyncLoadCuratedCommunities()

proc requestExtractDiscordChannelsAndCategories*(self: Controller, filesToImport: seq[string]) =
  self.communityService.requestExtractDiscordChannelsAndCategories(filesToImport)

proc requestCancelDiscordCommunityImport*(self: Controller, id: string) =
  self.communityService.requestCancelDiscordCommunityImport(id)

proc requestCancelDiscordChannelImport*(self: Controller, discordChannelId: string) =
  self.communityService.requestCancelDiscordChannelImport(discordChannelId)

proc getAllTokenGroupsForActiveNetworksMode*(self: Controller): seq[TokenGroupItem] =
  return self.tokenService.getAllTokenGroupsForActiveNetworksMode()

proc getCommunityTokens*(self: Controller, communityId: string): seq[CommunityTokenDto] =
  self.communityTokensService.getCommunityTokens(communityId)

proc getAllCommunityTokens*(self: Controller): seq[CommunityTokenDto] =
  self.communityTokensService.getAllCommunityTokens()

proc getNetworkByChainId*(self:Controller, chainId: int): NetworkItem =
  self.networksService.getNetworkByChainId(chainId)

proc shareCommunityUrlWithChatKey*(self: Controller, communityId: string): string =
  return self.communityService.shareCommunityUrlWithChatKey(communityId)

proc shareCommunityUrlWithData*(self: Controller, communityId: string): string =
  return self.communityService.shareCommunityUrlWithData(communityId)

proc shareCommunityChannelUrlWithChatKey*(self: Controller, communityId: string, chatId: string): string =
  return self.communityService.shareCommunityChannelUrlWithChatKey(communityId, chatId)

proc shareCommunityChannelUrlWithData*(self: Controller, communityId: string, chatId: string): string =
  return self.communityService.shareCommunityChannelUrlWithData(communityId, chatId)

proc asyncRequestToJoinCommunity*(self: Controller, communityId: string, ensName: string, addressesToShare: seq[string],
  airdropAddress: string, signatures: seq[string]) =
  self.communityService.asyncRequestToJoinCommunity(communityId, ensName, addressesToShare, airdropAddress,
    signatures)

proc asyncEditSharedAddresses*(self: Controller, communityId: string, addressesToShare: seq[string],
  airdropAddress: string, signatures: seq[string]) =
  self.communityService.asyncEditSharedAddresses(communityId, addressesToShare, airdropAddress, signatures)

proc authenticate*(self: Controller) =
  let data = SharedKeycarModuleAuthenticationArgs(uniqueIdentifier: UNIQUE_COMMUNITIES_MODULE_AUTH_IDENTIFIER)
  self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_AUTHENTICATE_USER, data)

proc getCommunityPublicKeyFromPrivateKey*(self: Controller, communityPrivateKey: string): string =
  result = self.communityService.getCommunityPublicKeyFromPrivateKey(communityPrivateKey)

proc asyncCheckPermissionsToJoin*(self: Controller, communityId: string, addressesToShare: seq[string]) =
  self.communityService.asyncCheckPermissionsToJoin(communityId, addressesToShare)

proc asyncCheckAllChannelsPermissions*(self: Controller, communityId: string, sharedAddresses: seq[string]) =
  self.chatService.asyncCheckAllChannelsPermissions(communityId, sharedAddresses)

proc asyncGetRevealedAccountsForMember*(self: Controller, communityId, memberPubkey: string) =
  self.communityService.asyncGetRevealedAccountsForMember(communityId, memberPubkey)

proc generateJoiningCommunityRequestsForSigning*(self: Controller, memberPubKey: string, communityId: string,
  addressesToReveal: seq[string]): seq[SignParamsDto] =
  return self.communityService.generateJoiningCommunityRequestsForSigning(memberPubKey, communityId, addressesToReveal)

proc generateEditCommunityRequestsForSigning*(self: Controller, memberPubKey: string, communityId: string,
  addressesToReveal: seq[string]): seq[SignParamsDto] =
  return self.communityService.generateEditCommunityRequestsForSigning(memberPubKey, communityId, addressesToReveal)

proc signCommunityRequests*(self: Controller, communityId: string, signParams: seq[SignParamsDto]): seq[string] =
  return self.communityService.signCommunityRequests(communityId, signParams)

proc getKeypairByAccountAddress*(self: Controller, address: string): KeypairDto =
  return self.walletAccountService.getKeypairByAccountAddress(address)

proc getKeypairByKeyUid*(self: Controller, keyUid: string): KeypairDto =
  return self.walletAccountService.getKeypairByKeyUid(keyUid)

proc getKeypairs*(self: Controller): seq[KeypairDto] =
  return self.walletAccountService.getKeypairs()

proc getWalletAccounts*(self: Controller): seq[wallet_account_service.WalletAccountDto] =
  return self.walletAccountService.getWalletAccounts()

proc getEnabledChainIds*(self: Controller): seq[int] =
  return self.walletAccountService.getEnabledChainIds()

proc disconnectKeycardReponseSignal(self: Controller) =
  self.events.disconnect(self.connectionKeycardResponse)

proc connectKeycardReponseSignal(self: Controller) =
  self.connectionKeycardResponse = self.events.onWithUUID(SIGNAL_KEYCARD_RESPONSE) do(e: Args):
    let args = KeycardLibArgs(e)
    self.disconnectKeycardReponseSignal()
    let currentFlow = self.keycardService.getCurrentFlow()
    if currentFlow != KCSFlowType.Sign:
      return
    self.delegate.onDataSigned(self.silentSigningKeyUid, self.silentSigningPath, args.flowEvent.txSignature.r, args.flowEvent.txSignature.s, args.flowEvent.txSignature.v, self.silentSigningPin)
    self.silentSigningKeyUid = ""
    self.silentSigningPath = ""
    self.silentSigningPin = ""

proc cancelCurrentFlow*(self: Controller) =
  self.keycardService.cancelCurrentFlow()

proc runSignFlow(self: Controller, pin, path, dataToSign: string) =
  self.cancelCurrentFlow()
  self.connectKeycardReponseSignal()
  self.keycardService.startSignFlow(path, dataToSign, pin)

proc runSigningOnKeycard*(self: Controller, keyUid: string, path: string, dataToSign: string, pin: string) =
  var finalDataToSign = status_general.hashMessageForSigning(dataToSign)
  if finalDataToSign.startsWith("0x"):
    finalDataToSign = finalDataToSign[2..^1]

  if pin.len == 0:
    let data = SharedKeycarModuleSigningArgs(uniqueIdentifier: UNIQUE_COMMUNITIES_MODULE_SIGNING_IDENTIFIER,
      keyUid: keyUid,
      path: path,
      dataToSign: finalDataToSign)
    self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_SIGN_DATA, data)
    return
  self.silentSigningKeyUid = keyUid
  self.silentSigningPath = path
  self.silentSigningPin = pin
  self.runSignFlow(pin, path, finalDataToSign)

proc removeCommunityChat*(self: Controller, communityId: string, channelId: string) =
  self.communityService.deleteCommunityChat(communityId, channelId)

proc getCurrentNetworksChainIds*(self: Controller): seq[int] =
  return self.networksService.getCurrentNetworksChainIds()

proc promoteSelfToControlNode*(self: Controller, communityId: string) =
  self.communityService.promoteSelfToControlNode(communityId)
