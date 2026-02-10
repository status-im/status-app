import nimqml
import std/[strformat, strutils, tables, json, sequtils, marshal, times], chronicles, stint

import io_interface, view, controller
import ephemeral_notification_item, ephemeral_notification_model
import app/modules/shared_models/[user_item, member_item, member_model, section_item, section_model, section_details, contacts_utils]
import app/modules/shared_modules/keycard_popup/module as keycard_shared_module
import app/global/app_sections_config
import app/global/app_signals
import app/global/[global_singleton, feature_flags]
import app/global/utils as utils
import constants

import chat_section/model as chat_model
import chat_section/item as chat_item
import chat_section/module as chat_section_module
import wallet_section/module as wallet_section_module
import browser_section/module as browser_section_module
import profile_section/module as profile_section_module
import app_search/module as app_search_module
import stickers/module as stickers_module
import gifs/module as gifs_module
import activity_center/module as activity_center_module
import communities/module as communities_module
import node_section/module as node_section_module
import communities/tokens/models/token_item
import communities/tokens/models/token_model
import network_connection/module as network_connection_module
import shared_urls/module as shared_urls_module
import market_section/module as market_module

import app_service/service/contacts/dto/contacts
import app_service/service/community_tokens/community_collectible_owner

import app_service/service/chat/service as chat_service
import app_service/service/community/service as community_service
import app_service/service/message/service as message_service
import app_service/service/token/service as token_service
import app_service/service/collectible/service as collectible_service
import app_service/service/currency/service as currency_service
import app_service/service/ramp/service as ramp_service
import app_service/service/transaction/service as transaction_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/bookmarks/service as bookmark_service
import app_service/service/dapp_permissions/service as dapp_permissions_service
import app_service/service/profile/service as profile_service
import app_service/service/accounts/service as accounts_service
import app_service/service/accounts/utils as accounts_utils
import app_service/service/settings/service as settings_service
import app_service/service/contacts/service as contacts_service
import app_service/service/about/service as about_service
import app_service/service/privacy/service as privacy_service
import app_service/service/stickers/service as stickers_service
import app_service/service/activity_center/service as activity_center_service
import app_service/service/saved_address/service as saved_address_service
import app_service/service/following_address/service as following_address_service
import app_service/service/node/service as node_service
import app_service/service/node_configuration/service as node_configuration_service
import app_service/service/devices/service as devices_service
import app_service/service/mailservers/service as mailservers_service
import app_service/service/gif/service as gif_service
import app_service/service/ens/service as ens_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/network/service as network_service
import app_service/service/general/service as general_service
import app_service/service/keycard/service as keycard_service
import app_service/service/shared_urls/service as urls_service
import app_service/service/network_connection/service as network_connection_service
import app_service/common/types
import app_service/common/utils as common_utils
import app_service/service/network/network_item
import app_service/service/market/service as market_service

import app/core/notifications/details
import app/core/eventemitter
import app/core/custom_urls/urls_manager

export io_interface

import app/core/tasks/threadpool

const TOAST_MESSAGE_VISIBILITY_DURATION_IN_MS = 5000 # 5 seconds
const STATUS_URL_ENS_RESOLVE_REASON = "StatusUrl"

type
  SpectateRequest = object
    communityId*: string
    channelUuid*: string

  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller
    chatSectionModules: OrderedTable[string, chat_section_module.AccessInterface]
    events: EventEmitter
    urlsManager: UrlsManager
    keycardService: keycard_service.Service
    settingsService: settings_service.Service
    networkService: network_service.Service
    privacyService: privacy_service.Service
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    savedAddressService: saved_address_service.Service
    followingAddressService: following_address_service.Service
    networkConnectionService: network_connection_service.Service
    stickersService: stickers_service.Service
    communityTokensService: community_tokens_service.Service
    walletSectionModule: wallet_section_module.AccessInterface
    browserSectionModule: browser_section_module.AccessInterface
    profileSectionModule: profile_section_module.AccessInterface
    stickersModule: stickers_module.AccessInterface
    gifsModule: gifs_module.AccessInterface
    activityCenterModule: activity_center_module.AccessInterface
    communitiesModule: communities_module.AccessInterface
    appSearchModule: app_search_module.AccessInterface
    nodeSectionModule: node_section_module.AccessInterface
    keycardSharedModuleForAuthenticationOrSigning: keycard_shared_module.AccessInterface
    keycardSharedModuleKeycardSyncPurpose: keycard_shared_module.AccessInterface
    keycardSharedModule: keycard_shared_module.AccessInterface
    networkConnectionModule: network_connection_module.AccessInterface
    sharedUrlsModule: shared_urls_module.AccessInterface
    marketModule: market_module.AccessInterface
    moduleLoaded: bool
    chatsLoaded: bool
    communityDataLoaded: bool
    contactsLoaded: bool
    pendingSpectateRequest: SpectateRequest
    statusDeepLinkToActivate: string

{.push warning[Deprecated]: off.}

# Forward declaration
proc switchToContactOrDisplayUserProfile[T](self: Module[T], publicKey: string)
method activateStatusDeepLink*[T](self: Module[T], statusDeepLink: string)
proc checkIfWeHaveNotifications[T](self: Module[T])
proc createMemberItem[T](self: Module[T], memberId: string, requestId: string, state: MembershipRequestState, role: MemberRole, airdropAddress: string = ""): MemberItem
proc getAllCommunityMemberItems[T](self: Module[T], community: CommunityDto): seq[MemberItem]


proc newModule*[T](
  delegate: T,
  events: EventEmitter,
  urlsManager: UrlsManager,
  accountsService: accounts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  tokenService: token_service.Service,
  collectibleService: collectible_service.Service,
  currencyService: currency_service.Service,
  rampService: ramp_service.Service,
  transactionService: transaction_service.Service,
  walletAccountService: wallet_account_service.Service,
  bookmarkService: bookmark_service.Service,
  profileService: profile_service.Service,
  settingsService: settings_service.Service,
  contactsService: contacts_service.Service,
  aboutService: about_service.Service,
  dappPermissionsService: dapp_permissions_service.Service,
  privacyService: privacy_service.Service,
  stickersService: stickers_service.Service,
  activityCenterService: activity_center_service.Service,
  savedAddressService: saved_address_service.Service,
  followingAddressService: following_address_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  devicesService: devices_service.Service,
  mailserversService: mailservers_service.Service,
  nodeService: node_service.Service,
  gifService: gif_service.Service,
  ensService: ens_service.Service,
  communityTokensService: community_tokens_service.Service,
  networkService: network_service.Service,
  generalService: general_service.Service,
  keycardService: keycard_service.Service,
  networkConnectionService: network_connection_service.Service,
  sharedUrlsService: urls_service.Service,
  marketService: market_service.Service,
  threadpool: ThreadPool
): Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(
    result,
    events,
    settingsService,
    nodeConfigurationService,
    accountsService,
    chatService,
    communityService,
    contactsService,
    messageService,
    gifService,
    privacyService,
    mailserversService,
    nodeService,
    communityTokensService,
    walletAccountService,
    tokenService,
    networkService,
    sharedUrlsService,
  )
  result.moduleLoaded = false
  result.chatsLoaded = false
  result.communityDataLoaded = false
  result.contactsLoaded = false

  result.events = events
  result.urlsManager = urlsManager
  result.keycardService = keycardService
  result.settingsService = settingsService
  result.networkService = networkService
  result.privacyService = privacyService
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.savedAddressService = savedAddressService
  result.followingAddressService = followingAddressService
  result.stickersService = stickersService
  result.communityTokensService = communityTokensService

  # Submodules
  result.chatSectionModules = initOrderedTable[string, chat_section_module.AccessInterface]()
  result.walletSectionModule = wallet_section_module.newModule(
    result, events, tokenService, collectibleService, currencyService,
    rampService, transactionService, walletAccountService,
    settingsService, savedAddressService, followingAddressService, networkService, accountsService,
    keycardService, nodeService, networkConnectionService, devicesService,
    communityTokensService, threadpool
  )
  result.browserSectionModule = browser_section_module.newModule(
    result, events, bookmarkService, settingsService, networkService,
    dappPermissionsService, walletAccountService,
    tokenService, currencyService, savedAddressService
  )
  result.profileSectionModule = profile_section_module.newModule(
    result, events, accountsService, settingsService, stickersService,
    profileService, contactsService, aboutService, privacyService, nodeConfigurationService,
    devicesService, mailserversService, chatService, ensService, walletAccountService, generalService, communityService,
    networkService, keycardService, tokenService, nodeService
  )
  result.stickersModule = stickers_module.newModule(result, events, stickersService, settingsService, walletAccountService,
    networkService, tokenService)
  result.gifsModule = gifs_module.newModule(result, events, gifService)
  result.activityCenterModule = activity_center_module.newModule(result, events, activityCenterService, contactsService,
  messageService, chatService, communityService, devicesService, generalService)
  result.communitiesModule = communities_module.newModule(result, events, communityService, communityTokensService,
    networkService, transactionService, tokenService, chatService, walletAccountService, keycardService)
  result.appSearchModule = app_search_module.newModule(result, events, contactsService, chatService, communityService,
  messageService)
  result.nodeSectionModule = node_section_module.newModule(result, events, settingsService, nodeService, nodeConfigurationService)
  result.networkConnectionModule = network_connection_module.newModule(result, events, networkConnectionService)
  result.sharedUrlsModule = shared_urls_module.newModule(result, events, sharedUrlsService)
  result.marketModule = market_module.newModule(result, events, marketService)

method delete*[T](self: Module[T]) =
  self.controller.delete
  self.profileSectionModule.delete
  self.stickersModule.delete
  self.gifsModule.delete
  self.activityCenterModule.delete
  self.communitiesModule.delete
  for cModule in self.chatSectionModules.values:
    cModule.delete
  self.chatSectionModules.clear
  self.walletSectionModule.delete
  self.browserSectionModule.delete
  self.appSearchModule.delete
  self.nodeSectionModule.delete
  if not self.keycardSharedModuleForAuthenticationOrSigning.isNil:
    self.keycardSharedModuleForAuthenticationOrSigning.delete
  if not self.keycardSharedModuleKeycardSyncPurpose.isNil:
    self.keycardSharedModuleKeycardSyncPurpose.delete
  if not self.keycardSharedModule.isNil:
    self.keycardSharedModule.delete
  self.networkConnectionModule.delete
  self.sharedUrlsModule.delete
  self.view.delete
  self.viewVariant.delete

method getAppNetwork*[T](self: Module[T]): NetworkItem =
  return self.controller.getAppNetwork()

method onAppNetworkChanged*[T](self: Module[T]) =
  self.view.emitAppNetworkChangedSignal()

proc createTokenItem[T](self: Module[T], tokenDto: CommunityTokenDto) : token_item.TokenItem =
  let network = self.controller.getNetworkByChainId(tokenDto.chainId)
  let tokenOwners = self.controller.getCommunityTokenOwners(tokenDto.communityId, tokenDto.chainId, tokenDto.address)
  let ownerAddressName = if len(tokenDto.deployer) > 0: self.controller.getCommunityTokenOwnerName(tokenDto.deployer) else: ""
  let remainingSupply = if tokenDto.infiniteSupply: stint.parse("0", Uint256) else: self.controller.getRemainingSupply(tokenDto.chainId, tokenDto.address)
  let burnState = self.controller.getCommunityTokenBurnState(tokenDto.chainId, tokenDto.address)
  let remoteDestructedAddresses = self.controller.getRemoteDestructedAddresses(tokenDto.chainId, tokenDto.address)
  let destructedAmount = self.controller.getRemoteDestructedAmount(tokenDto.chainId, tokenDto.address)
  result = initTokenItem(tokenDto, network, tokenOwners, ownerAddressName, burnState, remoteDestructedAddresses, remainingSupply, destructedAmount)

proc createTokenItemImproved[T](self: Module[T], tokenDto: CommunityTokenDto, communityTokenJsonItems: JsonNode) : token_item.TokenItem =
  # These 3 values come from local caches so they can be done sync
  let network = self.controller.getNetworkByChainId(tokenDto.chainId)
  let tokenOwners = self.controller.getCommunityTokenOwners(tokenDto.communityId, tokenDto.chainId, tokenDto.address)
  let ownerAddressName = if len(tokenDto.deployer) > 0: self.controller.getCommunityTokenOwnerName(tokenDto.deployer) else: ""

  var tokenDetails: JsonNode

  for details in communityTokenJsonItems.items:
    if details["address"].getStr ==  tokenDto.address:
      tokenDetails = details
      break

  if tokenDetails.kind == JNull:
    error "Token details not found for token", name = tokenDto.name, address = tokenDto.address
    return

  let remainingSupply = tokenDetails["remainingSupply"].getStr
  let burnState = tokenDetails["burnState"].getInt
  let remoteDestructedAddresses = map(tokenDetails["remoteDestructedAddresses"].getElems(),
    proc(remoteDestructAddress: JsonNode): string = remoteDestructAddress.getStr)
  let destructedAmount = tokenDetails["destructedAmount"].getStr

  result = initTokenItem(
    tokenDto,
    network,
    tokenOwners,
    ownerAddressName,
    ContractTransactionStatus(burnState),
    remoteDestructedAddresses,
    stint.parse(remainingSupply, Uint256),
    stint.parse(destructedAmount, Uint256),
  )

method onCommunityTokensDetailsLoaded[T](self: Module[T], communityId: string,
    communityTokens: seq[CommunityTokenDto], communityTokenJsonItems: JsonNode) =
  let communityTokensItems = communityTokens.map(proc(tokenDto: CommunityTokenDto): token_item.TokenItem =
    result = self.createTokenItemImproved(tokenDto, communityTokenJsonItems)
  )
  self.view.model().setTokenItems(communityId, communityTokensItems)
  self.view.model().setTokensLoading(communityId, false)

proc createCommunitySectionItem[T](self: Module[T], communityDetails: CommunityDto): SectionItem =
  var communityTokensItems: seq[token_item.TokenItem]
  var communityMembersAirdropAddress: Table[string, string]

  let existingCommunity = self.view.model().getItemById(communityDetails.id)

  # Members will be lazy loaded when the user goes to the Members panel in the Admin section
  var members: seq[MemberItem] = @[]

  if not existingCommunity.isEmpty() and
      (communityDetails.memberRole == MemberRole.Owner or communityDetails.memberRole == MemberRole.TokenMaster):
    if existingCommunity.joinedMembersCount != communityDetails.members.len:
      # If the number of joined members has changed, we need to update the members list
      # There is the slight chance that the number stays the same if someone left at the same tme as someone joined,
      # but it's not a big deal, it will correct itself on the next community update
      members = self.getAllCommunityMemberItems(communityDetails)
    else:
      # If the number of joined members is the same, we can use the existing members
      members = existingCommunity.members.getItems()

    # If there are tokens already in the model, we should keep the existing community tokens, until
    # getCommunityTokensDetailsAsync will trigger onCommunityTokensDetailsLoaded
    if not existingCommunity.communityTokens.isNil:
      communityTokensItems = existingCommunity.communityTokens.items

  let (unviewedCount, notificationsCount) = self.controller.sectionUnreadMessagesAndMentionsCount(
    communityDetails.id,
    communityDetails.muted,
  )

  let hasNotification = unviewedCount > 0 or notificationsCount > 0
  let active = self.getActiveSectionId() == communityDetails.id # We must pass on if the current item section is currently active to keep that property as it is

  var isBanned = false
  if communityDetails.pendingAndBannedMembers.contains(singletonInstance.userProfile.getPubKey()):
    isBanned = communityDetails.pendingAndBannedMembers[singletonInstance.userProfile.getPubKey()].toMembershipRequestState() == MembershipRequestState.Banned

  result = initSectionItem(
    communityDetails.id,
    sectionType = SectionType.Community,
    communityDetails.name,
    communityDetails.memberRole,
    communityDetails.isControlNode,
    communityDetails.description,
    communityDetails.introMessage,
    communityDetails.outroMessage,
    communityDetails.images.thumbnail,
    communityDetails.images.banner,
    icon = "",
    communityDetails.color,
    communityDetails.tags,
    hasNotification,
    notificationsCount,
    active,
    enabled = true,
    communityDetails.joined,
    communityDetails.canJoin,
    communityDetails.spectated,
    communityDetails.canManageUsers,
    communityDetails.canRequestAccess,
    communityDetails.isMember,
    isBanned,
    communityDetails.permissions.access,
    communityDetails.permissions.ensOnly,
    communityDetails.muted,
    members,
    communityDetails.members.len,
    communityDetails.settings.historyArchiveSupportEnabled,
    communityDetails.adminSettings.pinMessageAllMembersEnabled,
    communityDetails.encrypted,
    communityTokensItems,
    activeMembersCount = int(communityDetails.activeMembersCount),
  )

proc sendNotification[T](self: Module[T], status: string, sendDetails: SendDetailsDto, sentTransaction: RouterSentTransaction) =
    var
      finalStatus = status
      addressFrom = sendDetails.fromAddress
      addressTo = sendDetails.toAddress
      txTo = "" # txFrom is always the same as addressFrom, but txTo is different from addressTo when the app performs any sending flow via certain contract
      fromChain = sendDetails.fromChain
      toChain = sendDetails.toChain
      fromAmount = sendDetails.fromAmount.toString(10)
      toAmount = sendDetails.toAmount.toString(10)
      fromAsset = sendDetails.fromToken
      toAsset = sendDetails.toToken
      error = ""
      txHash = ""
      isApprovalTx = false
      #community specific details
      # main community details
      communityId = ""
      communityName = ""
      communityInvolvedTokens = 0
      communityTotalAmount = ""
      # community token 1 details
      communityAmount1 = ""
      communityAmountInfinite1 = false
      communityAssetName1 = ""
      communityAssetDecimals1 = 0
      # community token 2 details
      communityAmount2 = ""
      communityAmountInfinite2 = false
      communityAssetName2 = ""
      communityAssetDecimals2 = 0
      # other community details
      communityInvolvedAddress = ""
      communityNubmerOfInvolvedAddresses = 0
      communityOwnerTokenName = ""
      communityMasterTokenName = ""
      communityDeployedTokenName = ""

    if not sendDetails.errorResponse.isNil:
      error = sendDetails.errorResponse.details

    if not sentTransaction.isNil and sentTransaction.hash.len > 0:
      txTo = sentTransaction.toAddress
      if sentTransaction.fromChain > 0:
        fromChain = sentTransaction.fromChain
      if sentTransaction.toChain > 0:
        toChain = sentTransaction.toChain
      let
        txAmountIn = sentTransaction.amountIn.toString(10)
        txAmountOut = sentTransaction.amountOut.toString(10)
      if txAmountIn != "0":
        fromAmount = txAmountIn
      if txAmountOut != "0":
        toAmount = txAmountOut
      if sentTransaction.fromToken.len > 0:
        fromAsset = sentTransaction.fromToken
      if sentTransaction.toToken.len > 0:
        toAsset = sentTransaction.toToken
      txHash = sentTransaction.hash
      isApprovalTx = sentTransaction.approvalTx

    var accFromName = ""
    var accDto = self.walletAccountService.getAccountByAddress(addressFrom)
    if not accDto.isNil:
      accFromName = accDto.name

    var accToName = ""
    accDto = self.walletAccountService.getAccountByAddress(addressTo)
    if not accDto.isNil:
      accToName = accDto.name
    else:
      let savedAddress = self.savedAddressService.getSavedAddress(address = addressTo, ignoreNetworkMode = false)
      if not savedAddress.isNil:
        accToName = savedAddress.name

    var txToName = ""
    let txType = SendType(sendDetails.sendType)
    if txType == SendType.Bridge:
      txToName = "Hop" # no translations, currently we hardcode providers here, when we add more, this info should come from the status-go side.
    elif txType == SendType.Swap:
      txToName = "Velora" # no translations, currently we hardcode providers here, when we add more, this info should come from the status-go side.
    else:
      accDto = self.walletAccountService.getAccountByAddress(txTo)
      if not accDto.isNil:
        txToName = accDto.name

    # check for community details
    if not sendDetails.communityParams.isNil:
      let getTokenContractAddressAtIndex = proc(transferDetails: seq[TansferDetails], index: int): string =
        if transferDetails.len == 0 or index >= transferDetails.len:
          return ""
        return transferDetails[index].tokenContractAddress

      let getCommunityAmount = proc(transferDetails: seq[TansferDetails]): string =
        var total: UInt256 = stint.u256(0)
        for td in transferDetails:
          total += td.amount
        return total.toString(10)

      communityId = sendDetails.communityParams.communityId
      let item = self.view.model().getItemById(communityId)
      if item.id == "":
        error = "cannot_resolve_community"
      else:
        communityName = item.name

      communityInvolvedTokens = sendDetails.communityParams.transferDetails.len
      communityTotalAmount = getCommunityAmount(sendDetails.communityParams.transferDetails)

      for i in 0 ..< sendDetails.communityParams.transferDetails.len:
        let tokenContractAddress = getTokenContractAddressAtIndex(sendDetails.communityParams.transferDetails, i)
        if tokenContractAddress.len == 0:
          error = "cannot_resolve_token_contract_address"
        else:
          let communityToken = self.communityTokensService.getCommunityTokenFromCache(fromChain, tokenContractAddress)
          if communityToken.name.len == 0:
            error = "cannot_resolve_community_token"
          else:
            if i == 0:
              communityAssetName1 = communityToken.name
              communityAssetDecimals1 = communityToken.decimals
              communityAmount1 = sendDetails.communityParams.transferDetails[i].amount.toString(10)
            elif i == 1:
              communityAssetName2 = communityToken.name
              communityAssetDecimals2 = communityToken.decimals
              communityAmount2 = sendDetails.communityParams.transferDetails[i].amount.toString(10)

      if txType == SendType.CommunityDeployOwnerToken:
        communityOwnerTokenName = sendDetails.communityParams.ownerTokenParameters.name
        communityMasterTokenName = sendDetails.communityParams.masterTokenParameters.name

      if txType == SendType.CommunityDeployAssets or
        txType == SendType.CommunityDeployCollectibles:
          communityDeployedTokenName = sendDetails.communityParams.deploymentParameters.name
          communityAmountInfinite1 = sendDetails.communityParams.deploymentParameters.infiniteSupply
          if not communityAmountInfinite1:
            communityAmount1 = sendDetails.communityParams.deploymentParameters.supply.toString(10)

      if txType == SendType.CommunityRemoteBurn or
        txType == SendType.CommunityBurn:
        communityNubmerOfInvolvedAddresses = sendDetails.communityParams.walletAddresses.len
        if communityNubmerOfInvolvedAddresses == 1: # set address only if all tokens are from the same address
          communityInvolvedAddress = sendDetails.communityParams.walletAddresses[0]

    if finalStatus.len == 0 and error.len > 0:
      finalStatus = TxStatusFailed
    self.view.showTransactionToast(
      sendDetails.uuid,
      sendDetails.sendType,
      fromChain,
      toChain,
      addressFrom,
      accFromName,
      addressTo,
      accToName,
      txTo,
      txToName,
      txHash,
      isApprovalTx,
      fromAmount,
      toAmount,
      fromAsset,
      toAsset,
      sendDetails.username,
      sendDetails.publicKey,
      sendDetails.packId,
      communityId,
      communityName,
      communityInvolvedTokens,
      communityTotalAmount,
      communityAmount1,
      communityAmountInfinite1,
      communityAssetName1,
      communityAssetDecimals1,
      communityAmount2,
      communityAmountInfinite2,
      communityAssetName2,
      communityAssetDecimals2,
      communityInvolvedAddress,
      communityNubmerOfInvolvedAddresses,
      communityOwnerTokenName,
      communityMasterTokenName,
      communityDeployedTokenName,
      finalStatus,
      error,
    )

proc connectForNotificationsOnly[T](self: Module[T]) =
  self.events.on(SIGNAL_WALLET_ACCOUNT_SAVED) do(e:Args):
    let args = AccountArgs(e)
    self.view.showToastAccountAdded(args.account.name)

  self.events.on(SIGNAL_WALLET_ACCOUNT_DELETED) do(e:Args):
    let args = AccountArgs(e)
    self.view.showToastAccountRemoved(args.account.name)

  self.events.on(SIGNAL_KEYPAIR_NAME_CHANGED) do(e: Args):
    let args = KeypairArgs(e)
    self.view.showToastKeypairRenamed(args.oldKeypairName, args.keypair.name)

  self.events.on(SIGNAL_NETWORK_ENDPOINT_UPDATED) do(e: Args):
    let args = NetworkEndpointUpdatedArgs(e)
    self.view.showNetworkEndpointUpdated(args.networkName, args.isTest)

  self.events.on(SIGNAL_KEYPAIR_DELETED) do(e: Args):
    let args = KeypairArgs(e)
    self.view.showToastKeypairRemoved(args.keyPairName)

  self.events.on(SIGNAL_IMPORTED_KEYPAIRS) do(e:Args):
    let args = KeypairsArgs(e)
    var kpName: string
    if args.keypairs.len > 0:
      kpName = args.keypairs[0].name
    self.view.showToastKeypairsImported(kpName, args.keypairs.len, args.error)

  self.events.on(SIGNAL_SENDING_TRANSACTIONS_STARTED) do(e:Args):
    let args = TransactionArgs(e)
    # we allow this notification only if an error occurs, otherwise skip it and display notification after the tx gets submitted to the network
    if args.sendDetails.errorResponse.isNil:
      return
    self.sendNotification(args.status, args.sendDetails, args.sentTransaction)

  self.events.on(SIGNAL_TRANSACTION_SENT) do(e:Args):
    let args = TransactionArgs(e)
    self.sendNotification(args.status, args.sendDetails, args.sentTransaction)

  self.events.on(SIGNAL_TRANSACTION_STATUS_CHANGED) do(e:Args):
    let args = TransactionArgs(e)
    self.sendNotification(args.status, args.sendDetails, args.sentTransaction)

  self.events.on(MARK_WALLET_ADDRESSES_AS_SHOWN) do(e:Args):
    let args = WalletAddressesArgs(e)
    for address in args.addresses:
      self.addressWasShown(address)

  self.events.on(SIGNAL_PAIRING_FALLBACK_COMPLETED) do(e:Args):
    self.view.showToastPairingFallbackCompleted()

  self.events.on(SIGNAL_KEYCHAIN_GET_CREDENTIAL) do(e:Args):
    self.view.requestGetCredentialFromKeychain(singletonInstance.userProfile.getKeyUid())

  self.events.on(SIGNAL_KEYCHAIN_STORE_CREDENTIAL) do(e:Args):
    let args = AuthenticationArgs(e)
    self.view.requestStoreCredentialToKeychain(singletonInstance.userProfile.getKeyUid(), args.password)

method load*[T](
  self: Module[T],
  events: EventEmitter,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  mailserversService: mailservers_service.Service,
) =
  singletonInstance.engine.setRootContextProperty("mainModule", self.viewVariant)
  self.controller.init()
  self.view.load()
  self.connectForNotificationsOnly()

  let homePageEnabled = singletonInstance.featureFlags().getHomePageEnabled()

  var activeSection: SectionItem
  var activeSectionId = singletonInstance.localAccountSensitiveSettings.getActiveSection()

  # Default to Wallet section if no active section is set or if the active section is the settings section
  # or if the active section is the home page section but home page is not enabled
  if activeSectionId == "" or activeSectionId == SETTINGS_SECTION_ID or activeSectionId == ACTIVITYCENTER_SECTION_ID or
    (activeSectionId == HOMEPAGE_SECTION_ID and not homePageEnabled):
    activeSectionId = WALLET_SECTION_ID

  var homePageSectionItem: SectionItem

  # Home Page Section
  if homePageEnabled:
    homePageSectionItem = initSectionItem(
      HOMEPAGE_SECTION_ID,
      SectionType.HomePage,
      HOMEPAGE_SECTION_NAME,
      memberRole = MemberRole.Owner,
      description = "",
      image = "",
      icon = HOMEPAGE_SECTION_ICON,
      color = "",
      hasNotification = false,
      notificationsCount = 0,
      active = true,
      enabled = true,
    )
    self.view.model().addItem(homePageSectionItem)
    if activeSectionId == homePageSectionItem.id:
      activeSection = homePageSectionItem

  # Communities Portal Section
  let communitiesPortalSectionItem = initSectionItem(
    COMMUNITIESPORTAL_SECTION_ID,
    SectionType.CommunitiesPortal,
    COMMUNITIESPORTAL_SECTION_NAME,
    memberRole = MemberRole.Owner,
    description = "",
    image = "",
    icon = COMMUNITIESPORTAL_SECTION_ICON,
    color = "",
    hasNotification = false,
    notificationsCount = 0,
    active = false,
    enabled = true,
  )
  self.view.model().addItem(communitiesPortalSectionItem)
  if activeSectionId == communitiesPortalSectionItem.id:
    activeSection = communitiesPortalSectionItem

  # Wallet Section
  let walletSectionItem = initSectionItem(
    WALLET_SECTION_ID,
    SectionType.Wallet,
    WALLET_SECTION_NAME,
    memberRole = MemberRole.Owner,
    description = "",
    introMessage = "",
    outroMessage = "",
    image = "",
    icon = WALLET_SECTION_ICON,
    color = "",
    hasNotification = false,
    notificationsCount = 0,
    active = false,
    enabled = WALLET_ENABLED,
  )
  self.view.model().addItem(walletSectionItem)
  if activeSectionId == walletSectionItem.id:
    activeSection = walletSectionItem

  # Browser Section
  let browserSectionItem = initSectionItem(
    BROWSER_SECTION_ID,
    SectionType.Browser,
    BROWSER_SECTION_NAME,
    memberRole = MemberRole.Owner,
    description = "",
    introMessage = "",
    outroMessage = "",
    image = "",
    icon = BROWSER_SECTION_ICON,
    color = "",
    hasNotification = false,
    notificationsCount = 0,
    active = false,
    enabled = singletonInstance.localAccountSensitiveSettings.getIsBrowserEnabled(),
  )
  self.view.model().addItem(browserSectionItem)
  if activeSectionId == browserSectionItem.id:
    activeSection = browserSectionItem

  # Node Management Section
  let nodeManagementSectionItem = initSectionItem(
    NODEMANAGEMENT_SECTION_ID,
    SectionType.NodeManagement,
    NODEMANAGEMENT_SECTION_NAME,
    memberRole = MemberRole.Owner,
    description = "",
    introMessage = "",
    outroMessage = "",
    image = "",
    icon = NODEMANAGEMENT_SECTION_ICON,
    color = "",
    hasNotification = false,
    notificationsCount = 0,
    active = false,
    enabled = singletonInstance.localAccountSensitiveSettings.getNodeManagementEnabled(),
  )
  self.view.model().addItem(nodeManagementSectionItem)
  if activeSectionId == nodeManagementSectionItem.id:
    activeSection = nodeManagementSectionItem

  # Activity Center Section
  let activityCenterSectionItem = initSectionItem(
    ACTIVITYCENTER_SECTION_ID,
    SectionType.ActivityCenter,
    ACTIVITYCENTER_SECTION_NAME,
    memberRole = MemberRole.Owner,
    description = "",
    image = "",
    icon = ACTIVITYCENTER_SECTION_ICON,
    color = "",
    hasNotification = false,
    notificationsCount = 0,
    active = false,
    enabled = true,
  )
  self.view.model().addItem(activityCenterSectionItem)
  if activeSectionId == activityCenterSectionItem.id:
    activeSection = activityCenterSectionItem

  # Profile Section
  let profileSettingsSectionItem = initSectionItem(
    SETTINGS_SECTION_ID,
    SectionType.ProfileSettings,
    SETTINGS_SECTION_NAME,
    memberRole = MemberRole.Owner,
    description = "",
    introMessage = "",
    outroMessage = "",
    image = "",
    icon = SETTINGS_SECTION_ICON,
    color = "",
    hasNotification = false, # deferred to QML
    notificationsCount = 0,
    active = false,
    enabled = true,
  )
  self.view.model().addItem(profileSettingsSectionItem)
  if activeSectionId == profileSettingsSectionItem.id:
    activeSection = profileSettingsSectionItem

  if singletonInstance.featureFlags().getMarketEnabled():
    # Market Section
    let marketItem = initSectionItem(
      MARKET_SECTION_ID,
      SectionType.Market,
      MARKET_SECTION_NAME,
      memberRole = MemberRole.Owner,
      description = "",
      introMessage = "",
      outroMessage = "",
      image = "",
      icon = MARKET_SECTION_ICON,
      color = "",
      hasNotification = false,
      notificationsCount = 0,
      active = false,
      enabled = WALLET_ENABLED,
    )
    self.view.model().addItem(marketItem)
    if activeSectionId == marketItem.id:
      activeSection = marketItem
  else:
    # Swap Section
    let swapSectionItem = initSectionItem(
      SWAP_SECTION_ID,
      SectionType.Swap,
      SWAP_SECTION_NAME,
      memberRole = MemberRole.Owner,
      description = "",
      introMessage = "",
      outroMessage = "",
      image = "",
      icon = SWAP_SECTION_ICON,
      color = "",
      hasNotification = false,
      notificationsCount = 0,
      active = false,
      enabled = WALLET_ENABLED,
    )
    self.view.model().addItem(swapSectionItem)
    if activeSectionId == swapSectionItem.id:
      activeSection = swapSectionItem

  self.browserSectionModule.load()
  self.profileSectionModule.load()
  self.stickersModule.load()
  self.gifsModule.load()
  self.activityCenterModule.load()
  self.communitiesModule.load()
  self.appSearchModule.load()
  self.nodeSectionModule.load()
  # Load wallet last as it triggers events that are listened by other modules
  self.walletSectionModule.load()
  self.networkConnectionModule.load()
  self.sharedUrlsModule.load()
  self.marketModule.load()

  # If the home page is enabled, we default to it as the opening section
  # (disabled for 2.35 as per https://github.com/status-im/status-app/issues/18664, revisit after)
  #if homePageEnabled:
  #  activeSection = homePageSectionItem

  # Set active section on app start
  # If section is empty wait until chats are loaded
  if not activeSection.isEmpty():
    self.setActiveSection(activeSection)

proc isEverythingLoaded[T](self: Module[T]): bool =
  return self.communityDataLoaded and self.chatsLoaded and self.contactsLoaded

method onChatsLoaded*[T](
  self: Module[T],
  events: EventEmitter,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  mailserversService: mailservers_service.Service,
  walletAccountService: wallet_account_service.Service,
  tokenService: token_service.Service,
  communityTokensService: community_tokens_service.Service,
  sharedUrlsService: urls_service.Service,
  networkService: network_service.Service,
) =
  self.chatsLoaded = true
  if not self.isEverythingLoaded:
    return
  let myPubKey = singletonInstance.userProfile.getPubKey()
  var activeSection: SectionItem
  var activeSectionId = singletonInstance.localAccountSensitiveSettings.getActiveSection()

  # Create personal chat section
  self.chatSectionModules[myPubKey] = chat_section_module.newModule(
    self,
    events,
    sectionId = myPubKey,
    isCommunity = false,
    settingsService,
    nodeConfigurationService,
    contactsService,
    chatService,
    communityService,
    messageService,
    mailserversService,
    walletAccountService,
    tokenService,
    communityTokensService,
    sharedUrlsService,
    networkService
  )
  let (unviewedMessagesCount, unviewedMentionsCount) = self.controller.sectionUnreadMessagesAndMentionsCount(
    myPubKey,
    sectionIsMuted = false
  )
  var items: seq[SectionItem] = @[]

  let personalChatSectionItem = initSectionItem(
    myPubKey,
    sectionType = SectionType.Chat,
    name = CHAT_SECTION_NAME,
    icon = CHAT_SECTION_ICON,
    hasNotification = unviewedMessagesCount > 0 or unviewedMentionsCount > 0,
    notificationsCount = unviewedMentionsCount,
    active = self.getActiveSectionId() == myPubKey,
    enabled = true,
    joined = true,
    canJoin = true,
    canRequestAccess = true,
    isMember = true,
    isBanned = false,
    muted = false,
  )
  items.add(personalChatSectionItem)
  if activeSectionId == personalChatSectionItem.id:
    activeSection = personalChatSectionItem

  # For the personal chat section we load the chats immediately
  self.chatSectionModules[myPubKey].load(buildChats = true)

  let communities = self.controller.getJoinedAndSpectatedCommunities()
  # Create Community sections
  for community in communities:
    self.chatSectionModules[community.id] = chat_section_module.newModule(
      self,
      events,
      community.id,
      isCommunity = true,
      settingsService,
      nodeConfigurationService,
      contactsService,
      chatService,
      communityService,
      messageService,
      mailserversService,
      walletAccountService,
      tokenService,
      communityTokensService,
      sharedUrlsService,
      networkService
    )
    let communitySectionItem = self.createCommunitySectionItem(community)
    items.add(communitySectionItem)
    if activeSectionId == communitySectionItem.id:
      activeSection = communitySectionItem

    self.chatSectionModules[community.id].load()

  self.view.model().addItems(items)

  self.checkIfWeHaveNotifications()

  self.events.emit(SIGNAL_MAIN_LOADED, Args())

  # Set active section if it is one of the channel sections
  if not activeSection.isEmpty():
    self.setActiveSection(activeSection)

  self.view.sectionsLoaded()
  if self.statusDeepLinkToActivate != "":
    self.activateStatusDeepLink(self.statusDeepLinkToActivate)

method onCommunityDataLoaded*[T](
  self: Module[T],
  events: EventEmitter,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  mailserversService: mailservers_service.Service,
  walletAccountService: wallet_account_service.Service,
  tokenService: token_service.Service,
  communityTokensService: community_tokens_service.Service,
  sharedUrlsService: urls_service.Service,
  networkService: network_service.Service,
) =
  self.communityDataLoaded = true
  if not self.isEverythingLoaded:
    return

  self.onChatsLoaded(
    events,
    settingsService,
    nodeConfigurationService,
    contactsService,
    chatService,
    communityService,
    messageService,
    mailserversService,
    walletAccountService,
    tokenService,
    communityTokensService,
    sharedUrlsService,
    networkService,
  )

method onContactsLoaded*[T](
  self: Module[T],
  events: EventEmitter,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  mailserversService: mailservers_service.Service,
  walletAccountService: wallet_account_service.Service,
  tokenService: token_service.Service,
  communityTokensService: community_tokens_service.Service,
  sharedUrlsService: urls_service.Service,
  networkService: network_service.Service,
) =
  self.contactsLoaded = true
  if not self.isEverythingLoaded:
    return

  self.onChatsLoaded(
    events,
    settingsService,
    nodeConfigurationService,
    contactsService,
    chatService,
    communityService,
    messageService,
    mailserversService,
    walletAccountService,
    tokenService,
    communityTokensService,
    sharedUrlsService,
    networkService,
  )

method onChatsLoadingFailed*[T](self: Module[T]) =
  self.view.chatsLoadingFailed()

proc checkIfModuleDidLoad [T](self: Module[T]) =
  if self.moduleLoaded:
    return

  for cModule in self.chatSectionModules.values:
    if(not cModule.isLoaded()):
      return

#  if (not self.communitiesPortalSectionModule.isLoaded()):
#    return

  if (not self.walletSectionModule.isLoaded()):
    return

  if(not self.browserSectionModule.isLoaded()):
    return

  if(not self.nodeSectionModule.isLoaded()):
    return

  if(not self.profileSectionModule.isLoaded()):
    return

  if(not self.stickersModule.isLoaded()):
    return

  if not self.gifsModule.isLoaded():
    return

  if(not self.activityCenterModule.isLoaded()):
    return

  if(not self.communitiesModule.isLoaded()):
    return

  if(not self.appSearchModule.isLoaded()):
    return

  if(not self.networkConnectionModule.isLoaded()):
    return

  self.moduleLoaded = true
  self.delegate.mainDidLoad()

method chatSectionDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method communitySectionDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method appSearchDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method stickersDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method gifsDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method activityCenterDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method communitiesModuleDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

#method communitiesPortalSectionDidLoad*[T](self: Module[T]) =
#  self.checkIfModuleDidLoad()

method walletSectionDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method browserSectionDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method profileSectionDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method nodeSectionDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method networkConnectionModuleDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method viewDidLoad*[T](self: Module[T]) =
  self.checkIfModuleDidLoad()

method emitMailserverWorking*[T](self: Module[T]) =
  self.view.emitMailserverWorking()

method emitMailserverNotWorking*[T](self: Module[T]) =
  self.view.emitMailserverNotWorking()

method setCommunityIdToSpectate*[T](self: Module[T], communityId: string) =
  self.pendingSpectateRequest.communityId = communityId
  self.pendingSpectateRequest.channelUuid = ""

method getActiveSectionId*[T](self: Module[T]): string =
  return self.controller.getActiveSectionId()

method setActiveSection*[T](self: Module[T], item: SectionItem, skipSavingInSettings: bool = false) =
  if(item.isEmpty()):
    warn "section is empty and cannot be made as active one"
    return
  self.controller.setActiveSectionId(item.id)
  self.activeSectionSet(item.id, skipSavingInSettings)

method setActiveSectionById*[T](self: Module[T], id: string) =
  let item = self.view.model().getItemById(id)
  if item.isEmpty():
    discard self.communitiesModule.spectateCommunity(id)
  else:
    self.setActiveSection(item)

proc notifySubModulesAboutChange[T](self: Module[T], sectionId: string) =
  for cModule in self.chatSectionModules.values:
    cModule.onActiveSectionChange(sectionId)

  # If there is a need other section may be notified the same way from here...

method activeSectionSet*[T](self: Module[T], sectionId: string, skipSavingInSettings: bool = false) =
  if self.view.activeSection.getId() == sectionId:
    return
  let item = self.view.model().getItemById(sectionId)

  if item.isEmpty():
    # should never be here
    warn "main-module, incorrect section id", sectionId
    return

  case sectionId:
    of COMMUNITIESPORTAL_SECTION_ID:
      self.communitiesModule.onActivated()
    of BROWSER_SECTION_ID:
      self.browserSectionModule.onActivated()

  # If metrics are enabled, send a navigation event
  var sectionIdToSend = sectionId
  if sectionId == singletonInstance.userProfile.getPubKey():
    sectionIdToSend = CHAT_SECTION_NAME
  elif sectionId.startsWith("0x"):
    # This is a community
    sectionIdToSend = "community"
  singletonInstance.globalEvents.addCentralizedMetricIfEnabled("navigation", $(%*{"viewId": sectionIdToSend}))

  self.view.model().setActiveSection(sectionId)
  self.view.activeSectionSet(item)

  if not skipSavingInSettings:
    singletonInstance.localAccountSensitiveSettings.setActiveSection(sectionId)

  self.notifySubModulesAboutChange(sectionId)

proc setSectionAvailability[T](self: Module[T], sectionType: SectionType, available: bool) =
  if(available):
    self.view.model().enableSection(sectionType)
  else:
    self.view.model().disableSection(sectionType)

method toggleSection*[T](self: Module[T], sectionType: SectionType) =
  if (sectionType == SectionType.Browser):
    let enabled = singletonInstance.localAccountSensitiveSettings.getIsBrowserEnabled()
    self.setSectionAvailability(sectionType, not enabled)
    singletonInstance.localAccountSensitiveSettings.setIsBrowserEnabled(not enabled)
  elif (sectionType == SectionType.NodeManagement):
    let enabled = singletonInstance.localAccountSensitiveSettings.getNodeManagementEnabled()
    self.setSectionAvailability(sectionType, not enabled)
    singletonInstance.localAccountSensitiveSettings.setNodeManagementEnabled(not enabled)

method setCurrentUserStatus*[T](self: Module[T], status: StatusType) =
  self.controller.setCurrentUserStatus(status)

proc getChatSectionModule*[T](self: Module[T]): chat_section_module.AccessInterface =
  return self.chatSectionModules[singletonInstance.userProfile.getPubKey()]

method getChatSectionModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.getChatSectionModule().getModuleAsVariant()

method getCommunitySectionModule*[T](self: Module[T], communityId: string): QVariant =
  if(not self.chatSectionModules.contains(communityId)):
    warn "main-module, unexisting community key", communityId
    return

  return self.chatSectionModules[communityId].getModuleAsVariant()

method switchTo*[T](self: Module[T], sectionId, chatId: string) =
  self.controller.switchTo(sectionId, chatId, "")

method onActiveChatChange*[T](self: Module[T], sectionId: string, chatId: string) =
  self.appSearchModule.onActiveChatChange(sectionId, chatId)

method onChatLeft*[T](self: Module[T], chatId: string) =
  self.appSearchModule.updateSearchLocationIfPointToChatWithId(chatId)

proc checkIfWeHaveNotifications[T](self: Module[T]) =
  let sectionWithUnread = self.view.model().isThereASectionWithUnreadMessages()
  let activtyCenterNotifications = self.activityCenterModule.unreadActivityCenterNotificationsCountFromView() > 0
  self.view.setNotificationAvailable(sectionWithUnread or activtyCenterNotifications)

  # Update Activity Center section item related notifications properties
  let activityCenterNotificationsCount = self.activityCenterModule.unreadActivityCenterNotificationsCount()
  self.view.model().updateNotifications(
    ACTIVITYCENTER_SECTION_ID,
    hasNotification = activtyCenterNotifications,
    notificationsCount = activityCenterNotificationsCount)

method onActivityNotificationsUpdated[T](self: Module[T]) =
  self.checkIfWeHaveNotifications()

method onNotificationsUpdated[T](self: Module[T], sectionId: string, sectionHasUnreadMessages: bool,
    sectionNotificationCount: int) =
  self.view.model().updateNotifications(sectionId, sectionHasUnreadMessages, sectionNotificationCount)
  self.checkIfWeHaveNotifications()

method onPlayNotificationSound[T](self: Module[T]) =
  self.view.playNotificationSound()

method onNetworkConnected[T](self: Module[T]) =
  self.view.setConnected(true)

method onNetworkDisconnected[T](self: Module[T]) =
  self.view.setConnected(false)

method isConnected[T](self: Module[T]): bool =
  self.controller.isConnected()

method getAppSearchModule*[T](self: Module[T]): QVariant =
  self.appSearchModule.getModuleAsVariant()

method communitySpectated*[T](self: Module[T], communityId: string) =
  if self.pendingSpectateRequest.communityId != communityId:
    return
  self.pendingSpectateRequest.communityId = ""
  if self.pendingSpectateRequest.channelUuid == "":
    return
  let chatId = communityId & self.pendingSpectateRequest.channelUuid
  self.pendingSpectateRequest.channelUuid = ""
  self.controller.switchTo(communityId, chatId, "")

method communityJoined*[T](
  self: Module[T],
  community: CommunityDto,
  events: EventEmitter,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  contactsService: contacts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  messageService: message_service.Service,
  mailserversService: mailservers_service.Service,
  walletAccountService: wallet_account_service.Service,
  tokenService: token_service.Service,
  communityTokensService: community_tokens_service.Service,
  sharedUrlsService: urls_service.Service,
  networkService: network_service.Service,
  setActive: bool = false,
) =
  if self.chatSectionModules.contains(community.id):
    # The community is already spectated
    return
  var firstCommunityJoined = false
  if (self.chatSectionModules.len == 1): # First one is personal chat section
    firstCommunityJoined = true
  self.chatSectionModules[community.id] = chat_section_module.newModule(
      self,
      events,
      community.id,
      isCommunity = true,
      settingsService,
      nodeConfigurationService,
      contactsService,
      chatService,
      communityService,
      messageService,
      mailserversService,
      walletAccountService,
      tokenService,
      communityTokensService,
      sharedUrlsService,
      networkService
    )
  self.chatSectionModules[community.id].load()

  let communitySectionItem = self.createCommunitySectionItem(community)
  if (firstCommunityJoined):
    # If there are no other communities, add the first community after the Chat section in the model so that the order is respected
    self.view.model().addItem(communitySectionItem,
      self.view.model().getItemIndex(singletonInstance.userProfile.getPubKey()) + 1)
  else:
    self.view.model().addItem(communitySectionItem)

  if setActive:
    self.setActiveSection(communitySectionItem)
    if(community.chats.len > 0):
      let chatId = community.chats[0].id
      self.chatSectionModules[community.id].setActiveItem(chatId)

method communityLeft*[T](self: Module[T], communityId: string) =
  if(not self.chatSectionModules.contains(communityId)):
    warn "main-module, unexisting community key to leave", communityId
    return

  self.view.model().removeItem(communityId)

  singletonInstance.localAccountSensitiveSettings.removeSectionChatRecord(communityId)

  if (self.controller.getActiveSectionId() == communityId):
    let item = self.view.model().getItemById(singletonInstance.userProfile.getPubKey())
    self.setActiveSection(item)

  var moduleToDelete: chat_section_module.AccessInterface
  discard self.chatSectionModules.pop(communityId, moduleToDelete)
  moduleToDelete.delete
  moduleToDelete = nil

method communityEdited*[T](
    self: Module[T],
    community: CommunityDto) =
  if not self.chatSectionModules.contains(community.id):
    return
  var communitySectionItem = self.createCommunitySectionItem(community)
  # We need to calculate the unread counts because the community update doesn't come with it
  let (unviewedMessagesCount, unviewedMentionsCount) = self.controller.sectionUnreadMessagesAndMentionsCount(
    communitySectionItem.id,
    communitySectionItem.muted,
  )
  communitySectionItem.setHasNotification(unviewedMessagesCount > 0)
  communitySectionItem.setNotificationsCount(unviewedMentionsCount)
  self.view.editItem(communitySectionItem)

method onCommunityMuted*[T](
    self: Module[T],
    communityId: string,
    muted: bool) =
  self.view.model.setMuted(communityId, muted)

# used in FinaliseOwnershipPopup in UI
method getOwnerTokenAsJson*[T](self: Module[T], communityId: string): string =
  let item = self.view.model().getItemById(communityId)
  if item.id == "":
    return
  let tokensModel = item.communityTokens()
  let ownerToken = tokensModel.getOwnerToken()
  let jsonObj = %* {
    "symbol": ownerToken.tokenDto.symbol,
    "chainName": ownerToken.chainName,
    "accountName": ownerToken.accountName,
    "accountAddress": ownerToken.tokenDto.deployer,
    "contractUniqueKey": common_utils.contractUniqueKey(ownerToken.tokenDto.chainId, ownerToken.tokenDto.address)
  }
  return $jsonObj

method isEnsVerified*[T](self: Module[T], publicKey: string): bool =
  return self.controller.getContact(publicKey).ensVerified

method communityDataImported*[T](self: Module[T], community: CommunityDto) =
  if community.id == self.pendingSpectateRequest.communityId:
    discard self.communitiesModule.spectateCommunity(community.id)

method resolveENS*[T](self: Module[T], ensName: string, uuid: string, reason: string = "") =
  if ensName.len == 0:
    error "error: cannot do a lookup for empty ens name"
    return
  self.controller.resolveENS(ensName, uuid, reason)

method resolvedENS*[T](self: Module[T], publicKey: string, address: string, uuid: string, reason: string) =
  if reason.len > 0 and publicKey.len == 0:
    self.displayEphemeralNotification(
      title = "Unexisting contact",
      subTitle = "Wrong public key or ens name",
      image = "",
      icon = "",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Default.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
    )
    return

  if reason == STATUS_URL_ENS_RESOLVE_REASON & $StatusUrlAction.DisplayUserProfile:
    self.switchToContactOrDisplayUserProfile(publicKey)
  else:
    self.view.emitResolvedENSSignal(publicKey, address, uuid)

method onCommunityTokenDeploymentStored*[T](self: Module[T], communityToken: CommunityTokenDto, error: string) =
  if error != "":
    error "Cannot update section model, due to error storing community token: ", error
    return
  let item = self.view.model().getItemById(communityToken.communityId)
  if item.id == "":
    error "Cannot update section model, due to missing community with id: ", communityId=communityToken.communityId
    return
  item.appendCommunityToken(self.createTokenItem(communityToken))

method onOwnerTokensDeploymentStored*[T](self: Module[T], ownerToken: CommunityTokenDto, masterToken: CommunityTokenDto, error: string) =
  if error != "":
    error "Cannot update section model, due to error storing owner tokens: ", error
    return
  let item = self.view.model().getItemById(ownerToken.communityId)
  if item.id == "":
    error "Cannot update section model, due to missing community with id: ", communityId=ownerToken.communityId
    return
  item.appendCommunityToken(self.createTokenItem(ownerToken))
  item.appendCommunityToken(self.createTokenItem(masterToken))

method onCommunityTokenRemoved*[T](self: Module[T], communityId: string, chainId: int, address: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.removeCommunityToken(chainId, address)

method startTokenHoldersManagement*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string) =
  self.controller.startTokenHoldersManagement(chainId, contractAddress)
  let item = self.view.model().getItemById(communityId)
  if item.id != "" and not item.communityTokens.hasTokenHolders(chainId, contractAddress):
    item.setCommunityTokenHoldersLoading(chainId, contractAddress, value = true)

method stopTokenHoldersManagement*[T](self: Module[T]) =
  self.controller.stopTokenHoldersManagement()

method errorLoadingTokenHolders*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string, error: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.setCommunityTokenHoldersLoading(chainId, contractAddress, value = false)

method onCommunityTokenOwnersFetched*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string, owners: seq[CommunityCollectibleOwner]) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.setCommunityTokenOwners(chainId, contractAddress, owners, item.memberRole == MemberRole.Owner)

method onCommunityTokenDeployStateChanged*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string, deployState: DeployState) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updateCommunityTokenDeployState(chainId, contractAddress, deployState)

method onFinaliseOwnershipStatusChanged*[T](self: Module[T], isPending: bool, communityId: string) =
  self.view.model().updateIsPendingOwnershipRequest(communityId, isPending)

method onOwnerTokenDeployStateChanged*[T](self: Module[T], communityId: string, chainId: int, ownerContractAddress: string, masterContractAddress: string, deployState: DeployState, transactionHash: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    # update temporary master contract address first
    if transactionHash != "":
      item.updateCommunityTokenAddress(chainId, temporaryMasterContractAddress(transactionHash), masterContractAddress)
      item.updateCommunityTokenAddress(chainId, temporaryOwnerContractAddress(transactionHash), ownerContractAddress)
    # then update states
    item.updateCommunityTokenDeployState(chainId, ownerContractAddress, deployState)
    item.updateCommunityTokenDeployState(chainId, masterContractAddress, deployState)

method onCommunityTokenSupplyChanged*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string, supply: Uint256, remainingSupply: Uint256, destructedAmount: Uint256) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updateCommunityTokenSupply(chainId, contractAddress, supply, destructedAmount)
    item.updateCommunityRemainingSupply(chainId, contractAddress, remainingSupply)

method onBurnStateChanged*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string, burnState: ContractTransactionStatus) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updateBurnState(chainId, contractAddress, burnState)

method onRemoteDestructed*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string, addresses: seq[string]) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updateRemoteDestructedAddresses(chainId, contractAddress, addresses)

method onRequestReevaluateMembersPermissionsIfRequired*[T](self: Module[T], communityId: string, chainId: int, contractAddress: string) =
  let communityDto = self.controller.getCommunityById(communityId)
  for _, tokenPermission in communityDto.tokenPermissions.pairs:
    if tokenPermission.type != TokenPermissionType.BecomeTokenOwner:
      for tokenCriteria in tokenPermission.tokenCriteria:
        if tokenCriteria.contractAddresses.hasKey(chainId):
          let actualAddress = tokenCriteria.contractAddresses[chainId]
          if actualAddress == contractAddress:
            self.controller.asyncReevaluateCommunityMembersPermissions(communityId)
            return

method onAcceptRequestToJoinLoading*[T](self: Module[T], communityId: string, memberKey: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updatePendingRequestLoadingState(memberKey, true)

method onAcceptRequestToJoinFailed*[T](self: Module[T], communityId: string, memberKey: string, requestId: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updatePendingRequestLoadingState(memberKey, false)

method onAcceptRequestToJoinFailedNoPermission*[T](self: Module[T], communityId: string, memberKey: string, requestId: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updatePendingRequestLoadingState(memberKey, false)

method onAcceptRequestToJoinSuccess*[T](self: Module[T], communityId: string, memberKey: string, requestId: string) =
  let item = self.view.model().getItemById(communityId)
  if item.id != "":
    item.updatePendingRequestLoadingState(memberKey, false)

method onMembershipStateUpdated*[T](self: Module[T], communityId: string, memberPubkey: string, state: MembershipRequestState) =
  let myPublicKey = singletonInstance.userProfile.getPubKey()
  let communityDto = self.controller.getCommunityById(communityId)

  if myPublicKey == memberPubkey:
    case state:
      of MembershipRequestState.Banned, MembershipRequestState.BannedWithAllMessagesDelete:
        self.view.model().setIsBanned(communityId, true)
        singletonInstance.globalEvents.showCommunityMemberBannedNotification(fmt "You've been banned from {communityDto.name}", "", communityId)
      of MembershipRequestState.Kicked:
        singletonInstance.globalEvents.showCommunityMemberKickedNotification(fmt "You were kicked from {communityDto.name}", "", communityId)
      of MembershipRequestState.Unbanned:
        self.view.model().setIsBanned(communityId, false)
        singletonInstance.globalEvents.showCommunityMemberUnbannedNotification(fmt "You were unbanned from {communityDto.name}", "", communityId)
      else:
        discard
  elif communityDto.isControlNode:
    let (contactName, _, _) = self.controller.getContactNameAndImage(memberPubkey)
    let item = self.view.model().getItemById(communityId)
    if item.id != "":
      item.updateMembershipStatus(memberPubkey, state)
    case state:
      of MembershipRequestState.Banned, MembershipRequestState.Kicked,
          MembershipRequestState.Unbanned, MembershipRequestState.BannedWithAllMessagesDelete:
        self.view.emitCommunityMemberStatusEphemeralNotification(communityDto.name, contactName, state.int)
      else:
        discard

method displayWindowsOsNotification*[T](self: Module[T], title: string,
    message: string) =
  self.view.displayWindowsOsNotification(title, message)

method osNotificationClicked*[T](self: Module[T], details: NotificationDetails) =
  if(details.notificationType == NotificationType.NewContactRequest):
    self.controller.switchTo(details.sectionId, "", "")
    self.view.emitOpenActivityCenterSignal()
  elif(details.notificationType == NotificationType.JoinCommunityRequest):
    self.controller.switchTo(details.sectionId, "", "")
    self.view.emitOpenCommunityMembershipRequestsViewSignal(details.sectionId)
  elif(details.notificationType == NotificationType.MyRequestToJoinCommunityAccepted):
    self.controller.switchTo(details.sectionId, "", "")
  elif(details.notificationType == NotificationType.MyRequestToJoinCommunityRejected):
    warn "There is no particular action clicking on a notification informing you about rejection to join community"

method newCommunityMembershipRequestReceived*[T](self: Module[T], membershipRequest: CommunityMembershipRequestDto) =
  let (contactName, _, _) = self.controller.getContactNameAndImage(membershipRequest.publicKey)
  let community =  self.controller.getCommunityById(membershipRequest.communityId)
  singletonInstance.globalEvents.newCommunityMembershipRequestNotification("New membership request",
    fmt "{contactName} asks to join {community.name}", community.id)

  self.view.model().addMember(membershipRequest.communityId, self.createMemberItem(
    membershipRequest.publicKey,
    membershipRequest.id,
    MembershipRequestState(membershipRequest.state),
    MemberRole.None,
  ))

method communityMembershipRequestCanceled*[T](self: Module[T], communityId: string, requestId: string, pubKey: string) =
  self.view.model().removeMember(communityId, pubKey)

method meMentionedCountChanged*[T](self: Module[T], allMentions: int) =
  singletonInstance.globalEvents.meMentionedIconBadgeNotification(allMentions)

method displayEphemeralNotification*[T](
    self: Module[T],
    title: string,
    subTitle: string,
    image: string,
    icon: string,
    iconColor: string,
    loading: bool,
    ephNotifType: int,
    actionType: int,
    actionData: string,
    url: string,
    details = NotificationDetails()
  ) =
  let now = getTime()
  let id = now.toUnix * 1000000000 + now.nanosecond
  var finalEphNotifType = EphemeralNotificationType.Default
  if ephNotifType == EphemeralNotificationType.Success.int:
    finalEphNotifType = EphemeralNotificationType.Success
  elif ephNotifType == EphemeralNotificationType.Danger.int:
    finalEphNotifType = EphemeralNotificationType.Danger

  let item = ephemeral_notification_item.initItem(
    id,
    title,
    TOAST_MESSAGE_VISIBILITY_DURATION_IN_MS,
    subTitle,
    image,
    icon,
    iconColor,
    loading,
    finalEphNotifType,
    url,
    EphemeralActionType(actionType),
    actionData,
    details
  )
  self.view.ephemeralNotificationModel().addItem(item)

method displayEphemeralNotification*[T](self: Module[T], title: string, subTitle: string, details: NotificationDetails) =
  if details.notificationType == NotificationType.NewMessage or
      details.notificationType == NotificationType.NewMessageWithPersonalMention or
      details.notificationType == NotificationType.CommunityTokenPermissionCreated or
      details.notificationType == NotificationType.CommunityTokenPermissionUpdated or
      details.notificationType == NotificationType.CommunityTokenPermissionDeleted or
      details.notificationType == NotificationType.CommunityTokenPermissionCreationFailed or
      details.notificationType == NotificationType.CommunityTokenPermissionUpdateFailed or
      details.notificationType == NotificationType.CommunityTokenPermissionDeletionFailed or
      details.notificationType == NotificationType.NewMessageWithGlobalMention:
    self.displayEphemeralNotification(
      title,
      subTitle,
      image = "",
      icon = "",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Default.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
      details,
    )

  elif details.notificationType == NotificationType.NewContactRequest or
      details.notificationType == NotificationType.IdentityVerificationRequest or
      details.notificationType == NotificationType.ContactRemoved:
    self.displayEphemeralNotification(
      title,
      subTitle,
      image = "",
      icon = "contact",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Default.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
      details,
    )

  elif details.notificationType == NotificationType.AcceptedContactRequest:
    self.displayEphemeralNotification(
      title,
      subTitle,
      image = "",
      icon = "checkmark-circle",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Success.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
      details,
    )

  elif details.notificationType == NotificationType.CommunityMemberKicked:
    self.displayEphemeralNotification(
      title,
      subTitle,
      image = "",
      icon = "communities",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Danger.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
      details,
    )

  elif details.notificationType == NotificationType.CommunityMemberBanned:
    self.displayEphemeralNotification(
      title,
      subTitle,
      image = "",
      icon = "communities",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Danger.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
      details,
    )

  elif details.notificationType == NotificationType.CommunityMemberUnbanned:
    self.displayEphemeralNotification(
      title,
      subTitle = "Visit community",
      image = "",
      icon = "communities",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Success.int,
      actionType = EphemeralActionType.NavigateToCommunityAdmin.int,
      actionData = details.sectionId,
      url = "",
      details,
    )

  elif details.notificationType == NotificationType.NewsFeedMessage:
    self.view.newsFeedEphemeralNotification(title, details.notificationId)

  else:
    self.displayEphemeralNotification(
      title,
      subTitle,
      image = "",
      icon = "",
      iconColor = "",
      loading = false,
      ephNotifType = EphemeralNotificationType.Default.int,
      actionType = EphemeralActionType.None.int,
      actionData = "",
      url = "",
      details,
    )

method removeEphemeralNotification*[T](self: Module[T], id: int64) =
  self.view.ephemeralNotificationModel().removeItemWithId(id)

method ephemeralNotificationClicked*[T](self: Module[T], id: int64) =
  let item = self.view.ephemeralNotificationModel().getItemWithId(id)
  if(item.details.isEmpty()):
    return
  if(item.details.notificationType == NotificationType.NewMessage or
    item.details.notificationType == NotificationType.NewMessageWithPersonalMention or
    item.details.notificationType == NotificationType.NewMessageWithGlobalMention):
    self.controller.switchTo(item.details.sectionId, item.details.chatId, item.details.messageId)
  else:
    self.osNotificationClicked(item.details)

method onMyRequestAdded*[T](self: Module[T]) =
  self.displayEphemeralNotification(
    title = "Your Request has been submitted",
    subTitle = "",
    image = "",
    icon = "checkmark-circle",
    iconColor = "",
    loading = false,
    ephNotifType = EphemeralNotificationType.Success.int,
    actionType = EphemeralActionType.None.int,
    actionData = "",
    url = "",
  )

proc switchToContactOrDisplayUserProfile[T](self: Module[T], publicKey: string) =
  let contact = self.controller.getContact(publicKey)
  if contact.isContact:
    self.getChatSectionModule().switchToOrCreateOneToOneChat(publicKey)
  else:
    self.view.emitDisplayUserProfileSignal(publicKey)

method onStatusUrlRequested*[T](self: Module[T], action: StatusUrlAction, communityId: string, channelId: string,
    url: string, userId: string) =

  case action:
    of StatusUrlAction.DisplayUserProfile:
      if singletonInstance.utils().isCompressedPubKey(userId):
        let contactPk = singletonInstance.utils().getDecompressedPk(userId)
        self.switchToContactOrDisplayUserProfile(contactPk)
      else:
        self.resolveENS(userId, "", STATUS_URL_ENS_RESOLVE_REASON & $StatusUrlAction.DisplayUserProfile)

    of StatusUrlAction.OpenCommunity:
      let item = self.view.model().getItemById(communityId)
      if item.isEmpty():
        if self.controller.getCommunityById(communityId).id != "":
          self.controller.spectateCommunity(communityId)
          return
        # request community info and then spectate
        self.pendingSpectateRequest.communityId = communityId
        self.pendingSpectateRequest.channelUuid = ""
        self.communitiesModule.requestCommunityInfo(communityId, importing = false)
        return

      self.controller.switchTo(communityId, "", "")

    of StatusUrlAction.OpenCommunityChannel:
      let chatId = communityId & channelId
      let item = self.view.model().getItemById(communityId)

      if item.isEmpty():
        self.pendingSpectateRequest.communityId = communityId
        self.pendingSpectateRequest.channelUuid = channelId
        self.communitiesModule.requestCommunityInfo(communityId, importing = false)
        return

      self.controller.switchTo(communityId, chatId, "")

    elif action == StatusUrlAction.OpenLinkInBrowser and singletonInstance.localAccountSensitiveSettings.getIsBrowserEnabled():
      let item = self.view.model().getItemById(BROWSER_SECTION_ID)
      self.setActiveSection(item)
      self.browserSectionModule.openUrl(url)

    else:
      return



################################################################################
## keycard shared module - authentication/sign purpose
################################################################################
proc isSharedKeycardModuleForAuthenticationOrSigningRunning[T](self: Module[T]): bool =
  return not self.keycardSharedModuleForAuthenticationOrSigning.isNil

method getKeycardSharedModuleForAuthenticationOrSigning*[T](self: Module[T]): QVariant =
  if self.isSharedKeycardModuleForAuthenticationOrSigningRunning():
    return self.keycardSharedModuleForAuthenticationOrSigning.getModuleAsVariant()

proc createSharedKeycardModuleForAuthenticationOrSigning[T](self: Module[T], identifier: string) =
  self.keycardSharedModuleForAuthenticationOrSigning = keycard_shared_module.newModule[Module[T]](self, identifier,
    self.events, self.keycardService, self.settingsService, self.networkService, self.privacyService, self.accountsService,
    self.walletAccountService)

method onSharedKeycarModuleForAuthenticationOrSigningTerminated*[T](self: Module[T], lastStepInTheCurrentFlow: bool) =
  if self.isSharedKeycardModuleForAuthenticationOrSigningRunning():
    self.view.emitDestroyKeycardSharedModuleForAuthenticationOrSigning()
    self.keycardSharedModuleForAuthenticationOrSigning.delete
    self.keycardSharedModuleForAuthenticationOrSigning = nil

method runAuthenticationOrSigningPopup*[T](self: Module[T], flow: keycard_shared_module.FlowType, keyUid: string,
  bip44Paths: seq[string] = @[], dataToSign = "") =
  var identifier = UNIQUE_MAIN_MODULE_AUTHENTICATE_KEYPAIR_IDENTIFIER
  if flow == keycard_shared_module.FlowType.Sign:
    identifier = UNIQUE_MAIN_MODULE_SIGNING_DATA_IDENTIFIER
  self.createSharedKeycardModuleForAuthenticationOrSigning(identifier)
  if self.keycardSharedModuleForAuthenticationOrSigning.isNil:
    return
  self.keycardSharedModuleForAuthenticationOrSigning.runFlow(flow, keyUid, bip44Paths, dataToSign)

method onDisplayKeycardSharedModuleForAuthenticationOrSigning*[T](self: Module[T]) =
  self.view.emitDisplayKeycardSharedModuleForAuthenticationOrSigning()
################################################################################

################################################################################
## keycard shared module - keycard syncing purpose
################################################################################
method onSharedKeycarModuleKeycardSyncPurposeTerminated*[T](self: Module[T], lastStepInTheCurrentFlow: bool) =
  if not self.keycardSharedModuleKeycardSyncPurpose.isNil:
    self.keycardSharedModuleKeycardSyncPurpose.delete
    self.keycardSharedModuleKeycardSyncPurpose = nil

method tryKeycardSync*[T](self: Module[T], keyUid: string, pin: string) =
  self.keycardSharedModuleKeycardSyncPurpose = keycard_shared_module.newModule[Module[T]](self, UNIQUE_MAIN_MODULE_KEYCARD_SYNC_IDENTIFIER,
    self.events, self.keycardService, self.settingsService, self.networkService, self.privacyService, self.accountsService,
    self.walletAccountService)
  if self.keycardSharedModuleKeycardSyncPurpose.isNil:
    return
  self.keycardSharedModuleKeycardSyncPurpose.syncKeycardBasedOnAppState(keyUid, pin)
################################################################################

################################################################################
## keycard shared module - general purpose
################################################################################
method getKeycardSharedModule*[T](self: Module[T]): QVariant =
  if not self.keycardSharedModule.isNil:
    return self.keycardSharedModule.getModuleAsVariant()

method onSharedKeycarModuleFlowTerminated*[T](self: Module[T], lastStepInTheCurrentFlow: bool, nextFlow: keycard_shared_module.FlowType,
  forceFlow: bool, nextKeyUid: string, returnToFlow: keycard_shared_module.FlowType) =
  if not self.keycardSharedModule.isNil:
    if nextFlow == keycard_shared_module.FlowType.General:
      self.view.emitDestroyKeycardSharedModuleFlow()
      self.keycardSharedModule.delete
      self.keycardSharedModule = nil
      return
    self.keycardSharedModule.runFlow(nextFlow, nextKeyUid, bip44Paths = @[], txHash = "", forceFlow, returnToFlow)

method onDisplayKeycardSharedModuleFlow*[T](self: Module[T]) =
  self.view.emitDisplayKeycardSharedModuleFlow()

proc runStopUsingKeycardForProfilePopup[T](self: Module[T]) =
  if not self.keycardSharedModule.isNil:
    info "shared keycard module is already running, cannot run stop using keycard flow"
    return
  self.keycardSharedModule = keycard_shared_module.newModule[Module[T]](self, UNIQUE_MAIN_MODULE_SHARED_KEYCARD_MODULE_IDENTIFIER,
    self.events, self.keycardService, self.settingsService, self.networkService, self.privacyService, self.accountsService,
    self.walletAccountService)
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.MigrateFromKeycardToApp,
    singletonInstance.userProfile.getKeyUid(), bip44Paths = @[], txHash = "", forceFlow = true)

proc runStartUsingKeycardForProfilePopup[T](self: Module[T]) =
  if not self.keycardSharedModule.isNil:
    info "shared keycard module is already running, cannot run start using keycard flow"
    return
  self.keycardSharedModule = keycard_shared_module.newModule[Module[T]](self, UNIQUE_MAIN_MODULE_SHARED_KEYCARD_MODULE_IDENTIFIER,
    self.events, self.keycardService, self.settingsService, self.networkService, self.privacyService, self.accountsService,
    self.walletAccountService)
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.MigrateFromAppToKeycard,
    singletonInstance.userProfile.getKeyUid(), bip44Paths = @[], txHash = "", forceFlow = true)
################################################################################

method checkAndPerformProfileMigrationIfNeeded*[T](self: Module[T]) =
  let keyUid = singletonInstance.userProfile.getKeyUid()
  let migrationNeeded = self.settingsService.getProfileMigrationNeeded()
  let profileKeypair = self.walletAccountService.getKeypairByKeyUid(keyUid)
  if profileKeypair.isNil:
    info "quit the app because of unresolved profile keypair", keyUid
    quit() # quit the app
  if not migrationNeeded:
    if not self.keycardSharedModule.isNil:
      let currentFlow = self.keycardSharedModule.getCurrentFlowType()
      if currentFlow == FlowType.MigrateFromKeycardToApp or
        currentFlow == FlowType.MigrateFromAppToKeycard:
          self.keycardSharedModule.onCancelActionClicked()
    return
  if profileKeypair.migratedToKeycard():
    if not self.keycardSharedModule.isNil:
      let currentFlow = self.keycardSharedModule.getCurrentFlowType()
      if currentFlow == FlowType.MigrateFromKeycardToApp:
        return
      self.keycardSharedModule.onCancelActionClicked()
    info "run stop using keycard flow for the profile, cause profile was migrated on paired device"
    self.runStopUsingKeycardForProfilePopup()
    return
  if not self.keycardSharedModule.isNil:
    let currentFlow = self.keycardSharedModule.getCurrentFlowType()
    if currentFlow == FlowType.MigrateFromAppToKeycard:
      return
    self.keycardSharedModule.onCancelActionClicked()
  info "run migrate to a Keycard flow for the profile, cause profile was migrated on paired device"
  self.runStartUsingKeycardForProfilePopup()


method activateStatusDeepLink*[T](self: Module[T], statusDeepLink: string) =
  if not self.chatsLoaded:
    self.statusDeepLinkToActivate = statusDeepLink
    return
  let urlData = self.sharedUrlsModule.parseSharedUrl(statusDeepLink)
  if urlData.notASupportedStatusLink:
    # Just open it in the browser
    self.view.emitOpenUrlSignal(statusDeepLink)
    return
  if urlData.channel.uuid != "":
    self.onStatusUrlRequested(StatusUrlAction.OpenCommunityChannel, urlData.community.communityId, urlData.channel.uuid,
      url="", userId="")
    return
  if urlData.community.communityId != "":
    self.onStatusUrlRequested(StatusUrlAction.OpenCommunity, urlData.community.communityId, channelId="", url="", userId="")
    return
  if urlData.contact.publicKey != "":
    self.onStatusUrlRequested(StatusUrlAction.DisplayUserProfile, communityId="", channelId="", url="",
      urlData.contact.publicKey)
    return

method onDeactivateChatLoader*[T](self: Module[T], sectionId: string, chatId: string) =
  if (sectionId.len > 0 and self.chatSectionModules.contains(sectionId)):
    self.chatSectionModules[sectionId].onDeactivateChatLoader(chatId)

method windowActivated*[T](self: Module[T]) =
  self.controller.slowdownArchivesImport()

method windowDeactivated*[T](self: Module[T]) =
  self.controller.speedupArchivesImport()

method communityMembersRevealedAccountsLoaded*[T](self: Module[T], communityId: string, membersRevealedAccounts: MembersRevealedAccounts) =
  var  communityMembersAirdropAddress: Table[string, string]
  for pubkey, revealedAccounts in membersRevealedAccounts.pairs:
    for revealedAccount in revealedAccounts:
      if revealedAccount.isAirdropAddress:
        communityMembersAirdropAddress[pubkey] = revealedAccount.address
        discard

  self.view.model.setMembersAirdropAddress(communityId, communityMembersAirdropAddress)

method communityMemberRevealedAccountsAdded*[T](self: Module[T], request: CommunityMembershipRequestDto) =
  var airdropAddress = ""
  for revealedAccount in request.revealedAccounts:
    if revealedAccount.isAirdropAddress:
      airdropAddress = revealedAccount.address
      discard

  if airdropAddress == "":
    warn "Request to join doesn't have an airdrop address", requestId = request.id, communityId = request.communityId
    return

  let communityMembersAirdropAddress = {request.publicKey: airdropAddress}.toTable
  self.view.model.setMembersAirdropAddress(request.communityId, communityMembersAirdropAddress)

## Used in test env only, for testing keycard flows
method registerMockedKeycard*[T](self: Module[T], cardIndex: int, readerState: int, keycardState: int,
  mockedKeycard: string, mockedKeycardHelper: string) =
  self.keycardService.registerMockedKeycard(cardIndex, readerState, keycardState, mockedKeycard, mockedKeycardHelper)

method pluginMockedReaderAction*[T](self: Module[T]) =
  self.keycardService.pluginMockedReaderAction()

method unplugMockedReaderAction*[T](self: Module[T]) =
  self.keycardService.unplugMockedReaderAction()

method insertMockedKeycardAction*[T](self: Module[T], cardIndex: int) =
  self.keycardService.insertMockedKeycardAction(cardIndex)

method removeMockedKeycardAction*[T](self: Module[T]) =
  self.keycardService.removeMockedKeycardAction()

method addressWasShown*[T](self: Module[T], address: string) =
  if address.len == 0:
    return
  self.walletAccountService.addressWasShown(address)

method openSectionChatAndMessage*[T](self: Module[T], sectionId: string, chatId: string, messageId: string) =
  if sectionId in self.chatSectionModules:
    self.chatSectionModules[sectionId].openCommunityChatAndScrollToMessage(chatId, messageId)

method updateRequestToJoinState*[T](self: Module[T], sectionId: string, requestToJoinState: RequestToJoinState) =
  if sectionId in self.chatSectionModules:
    self.chatSectionModules[sectionId].updateRequestToJoinState(requestToJoinState)

proc createMemberItem[T](
    self: Module[T],
    memberId: string,
    requestId: string,
    state: MembershipRequestState,
    role: MemberRole,
    airdropAddress: string = "",
    ): MemberItem =
  let contactDetails = self.controller.getContactDetails(memberId)
  let status = self.controller.getStatusForContactWithId(memberId)
  return createMemberItemFromDtos(
    contactDetails,
    toOnlineStatus(status.statusType),
    state,
    requestId,
    role,
    airdropAddress,
  )

method contactUpdated*[T](self: Module[T], contactId: string) =
  let contactDetails = self.controller.getContactDetails(contactId)
  self.view.model().updateMemberItemInSections(
    pubKey = contactId,
    displayName = contactDetails.dto.displayName,
    ensName = contactDetails.dto.name,
    isEnsVerified = contactDetails.dto.ensVerified,
    localNickname = contactDetails.dto.localNickname,
    alias = contactDetails.dto.alias,
    icon = contactDetails.icon,
    isContact = contactDetails.dto.isContact,
    isBlocked = contactDetails.dto.isBlocked,
    trustStatus = contactDetails.dto.trustStatus,
    contactRequest = toContactStatus(contactDetails.dto.contactRequestState),
  )

proc getAllCommunityMemberItems[T](self: Module[T], community: CommunityDto): seq[MemberItem] =
  # Add members who were kicked from the community after the ownership change for auto-rejoin after they share addresses
  var members = community.members
  for requestForAutoRejoin in community.waitingForSharedAddressesRequestsToJoin:
    var chatMember = ChatMember()
    chatMember.id = requestForAutoRejoin.publicKey
    chatMember.joined = false
    chatMember.role = MemberRole.None
    members.add(chatMember)

  var bannedMembers = newSeq[MemberItem]()
  for memberId, memberState in community.pendingAndBannedMembers.pairs:
    let state = memberState.toMembershipRequestState()
    case state:
      of MembershipRequestState.Banned, MembershipRequestState.BannedWithAllMessagesDelete, MembershipRequestState.UnbannedPending:
        bannedMembers.add(self.createMemberItem(memberId, "", state, MemberRole.None))
      else:
        discard

  var memberItems = members.map(proc(member: ChatMember): MemberItem =
      var state = MembershipRequestState.Accepted
      if member.id in community.pendingAndBannedMembers:
        let memberState = community.pendingAndBannedMembers[member.id].toMembershipRequestState()
        if memberState == MembershipRequestState.BannedPending or memberState == MembershipRequestState.KickedPending:
          state = memberState
      elif not member.joined:
        state = MembershipRequestState.AwaitingAddress
      result = self.createMemberItem(
        member.id,
        requestId = "",
        state,
        member.role,
        airdropAddress = "",
      )
    )

  let pendingMembers = community.pendingRequestsToJoin.map(proc(requestDto: CommunityMembershipRequestDto): MemberItem =
      result = self.createMemberItem(requestDto.publicKey, requestDto.id, MembershipRequestState(requestDto.state), MemberRole.None)
    )

  let declinedMemberItems = community.declinedRequestsToJoin.map(proc(requestDto: CommunityMembershipRequestDto): MemberItem =
      result = self.createMemberItem(requestDto.publicKey, requestDto.id, MembershipRequestState(requestDto.state), MemberRole.None)
    )

  memberItems = concat(memberItems, pendingMembers, declinedMemberItems, bannedMembers)

  # Remove duplicates, this can happen when the requests to join have not updated in time
  var finalMembers: Table[string, MemberItem]
  for memberItem in memberItems:
    if not finalMembers.contains(memberItem.pubKey):
      finalMembers[memberItem.pubKey] = memberItem

  return finalMembers.values.toSeq()

method loadMembersForSectionId*[T](self: Module[T], sectionId: string) =
  let existingCommunity = self.view.model().getItemById(sectionId)
  if existingCommunity.isEmpty():
    error "Cannot load members for section", sectionId
    return

  let community = self.controller.getCommunityById(sectionId)

  if community.memberRole == MemberRole.Owner or community.memberRole == MemberRole.TokenMaster:
    self.controller.getCommunityTokensDetailsAsync(community.id)
    self.controller.asyncGetRevealedAccountsForAllMembers(community.id)
    self.view.model.setTokensLoading(sectionId, true)

  let memberItems = self.getAllCommunityMemberItems(community)

  self.view.model.setMembersItems(sectionId, memberItems)

method getSectionId*[T](self: Module[T], sectionType: SectionType): string =
  return self.view.model().getItemBySectionType(sectionType).id()

method getSectionName*[T](self: Module[T], sectionId: string): string =
  return self.view.model().getItemById(sectionId).name()

method authenticateLoggedInUser*[T](self: Module[T], requestedBy: string) =
  self.controller.authenticateLoggedInUser(requestedBy)

method onLoggedInUserAuthenticated*[T](self: Module[T], requestedBy: string, password: string, pin: string, keyUid: string,
  keycardUid: string) =
  self.view.emitLoggedInUserAuthenticated(requestedBy, password, pin, keyUid, keycardUid)

method requestGetCredentialFromKeychainResult*[T](self: Module[T], success: bool, secret: string) =
  if success:
    self.events.emit(SIGNAL_KEYCHAIN_SERVICE_SUCCESS, AuthenticationArgs(password: secret))
  else:
    self.events.emit(SIGNAL_KEYCHAIN_SERVICE_ERROR, AuthenticationErrorArgs())

method credentialStoredToKeychainResult*[T](self: Module[T], success: bool) =
  if success:
    self.events.emit(SIGNAL_KEYCHAIN_SERVICE_SUCCESS, AuthenticationArgs())
  else:
    self.events.emit(SIGNAL_KEYCHAIN_SERVICE_ERROR, AuthenticationErrorArgs())

{.pop.}
