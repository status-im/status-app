import chronicles, stint, strutils
import app/global/global_singleton
import app/global/app_signals
import app/core/signals/types as signal_types
import app/core/eventemitter
import app/core/notifications/notifications_manager
import app_service/common/types
import app_service/service/general/service as general_service
import app_service/service/settings/service as settings_service
import app_service/service/node_configuration/service as node_configuration_service
import app_service/service/accounts/service as accounts_service
import app_service/service/chat/service as chat_service
import app_service/service/community/service as community_service
import app_service/service/contacts/service as contacts_service
import app_service/service/message/service as message_service
import app_service/service/gif/service as gif_service
import app_service/service/mailservers/service as mailservers_service
import app_service/service/privacy/service as privacy_service
import app_service/service/node/service as node_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/token/service as token_service
import app_service/service/network/service as networks_service
import app_service/service/shared_urls/service as urls_service
import app_service/service/network/network_item

import app_service/service/community_tokens/community_collectible_owner

import io_interface
import ../shared_modules/keycard_popup/io_interface as keycard_shared_module

logScope:
  topics = "main-module-controller"

const UNIQUE_MAIN_MODULE_AUTHENTICATE_INTERNAL_IDENTIFIER* = "MainModule-Internal-"
const UNIQUE_MAIN_MODULE_AUTHENTICATE_KEYPAIR_IDENTIFIER* = "MainModule-AuthenticateKeypair"
const UNIQUE_MAIN_MODULE_SIGNING_DATA_IDENTIFIER* = "MainModule-SigningData"
const UNIQUE_MAIN_MODULE_KEYCARD_SYNC_IDENTIFIER* = "MainModule-KeycardSyncPurpose"
const UNIQUE_MAIN_MODULE_SHARED_KEYCARD_MODULE_IDENTIFIER* = "MainModule-SharedKeycardModule"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    generalService: general_service.Service
    settingsService: settings_service.Service
    nodeConfigurationService: node_configuration_service.Service
    accountsService: accounts_service.Service
    chatService: chat_service.Service
    communityService: community_service.Service
    messageService: message_service.Service
    contactsService: contacts_service.Service
    gifService: gif_service.Service
    privacyService: privacy_service.Service
    mailserversService: mailservers_service.Service
    nodeService: node_service.Service
    communityTokensService: community_tokens_service.Service
    activeSectionId: string
    authenticateUserFlowRequestedBy: string
    keycardSigningFlowRequestedBy: string
    walletAccountService: wallet_account_service.Service
    tokenService: token_service.Service
    networksService: networks_service.Service
    sharedUrlsService: urls_service.Service

# Forward declaration
proc getRemainingSupply*(self: Controller, chainId: int, contractAddress: string): Uint256
proc getRemoteDestructedAmount*(self: Controller, chainId: int, contractAddress: string): Uint256

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  generalService: general_service.Service,
  settingsService: settings_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  accountsService: accounts_service.Service,
  chatService: chat_service.Service,
  communityService: community_service.Service,
  contactsService: contacts_service.Service,
  messageService: message_service.Service,
  gifService: gif_service.Service,
  privacyService: privacy_service.Service,
  mailserversService: mailservers_service.Service,
  nodeService: node_service.Service,
  communityTokensService: community_tokens_service.Service,
  walletAccountService: wallet_account_service.Service,
  tokenService: token_service.Service,
  networksService: networks_service.Service,
  sharedUrlsService: urls_service.Service
):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.generalService = generalService
  result.settingsService = settingsService
  result.nodeConfigurationService = nodeConfigurationService
  result.accountsService = accountsService
  result.chatService = chatService
  result.communityService = communityService
  result.contactsService = contactsService
  result.messageService = messageService
  result.gifService = gifService
  result.privacyService = privacyService
  result.nodeService = nodeService
  result.mailserversService = mailserversService
  result.communityTokensService = communityTokensService
  result.walletAccountService = walletAccountService
  result.tokenService = tokenService
  result.networksService = networksService
  result.sharedUrlsService = sharedUrlsService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_ACTIVE_CHATS_LOADED) do(e:Args):
    self.delegate.onChatsLoaded(
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
    )

  self.events.on(SIGNAL_COMMUNITY_DATA_LOADED) do(e:Args):
    self.delegate.onCommunityDataLoaded(
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
    )

  self.events.on(SIGNAL_CONTACTS_LOADED) do(e:Args):
    self.delegate.onContactsLoaded(
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
    )

  self.events.on(SIGNAL_ACTIVE_MAILSERVER_CHANGED) do(e:Args):
    let args = ActiveMailserverChangedArgs(e)
    if args.nodeAddress == "":
      return
    self.delegate.emitMailserverWorking()
    echo "ACTIVE MAILSERVER CHANGED: ", repr(e)
    # We need to take some actions here. This is the only place where "activeMailserverChanged" signal should be handled.
    # Do the following, if we really need that.
    # requestAllHistoricMessagesResult
    # requestMissingCommunityInfos

  self.events.on(SIGNAL_MAILSERVER_NOT_WORKING) do(e: Args):
    self.delegate.emitMailserverNotWorking()

  self.events.on(SIGNAL_COMMUNITY_JOINED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityJoined(
      args.community,
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
      setActive = args.fromUserAction
    )

  self.events.on(SIGNAL_COMMUNITY_SPECTATED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityJoined(
      args.community,
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
      setActive = args.fromUserAction
    )
    self.delegate.onFinaliseOwnershipStatusChanged(args.isPendingOwnershipRequest, args.community.id)
    self.delegate.communitySpectated(args.community.id)

  self.events.on(TOGGLE_SECTION) do(e:Args):
    let args = ToggleSectionArgs(e)
    self.delegate.toggleSection(args.sectionType)

  self.events.on(SIGNAL_COMMUNITY_CREATED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityJoined(
      args.community,
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
      setActive = true
    )

  self.events.on(SIGNAL_COMMUNITY_IMPORTED) do(e:Args):
    let args = CommunityArgs(e)
    if(args.error.len > 0):
      return
    self.delegate.communityJoined(
      args.community,
      self.events,
      self.settingsService,
      self.nodeConfigurationService,
      self.contactsService,
      self.chatService,
      self.communityService,
      self.messageService,
      self.mailserversService,
      self.walletAccountService,
      self.tokenService,
      self.communityTokensService,
      self.sharedUrlsService,
      self.networksService,
      setActive = false
    )

  self.events.on(SIGNAL_COMMUNITY_DATA_IMPORTED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityDataImported(args.community)

  self.events.on(SIGNAL_COMMUNITY_LEFT) do(e:Args):
    let args = CommunityIdArgs(e)
    self.delegate.communityLeft(args.communityId)

  self.events.on(SIGNAL_COMMUNITY_EDITED) do(e:Args):
    let args = CommunityArgs(e)
    self.delegate.communityEdited(args.community)

  self.events.on(SIGNAL_COMMUNITY_MEMBERS_REVEALED_ACCOUNTS_LOADED) do(e:Args):
    let args = CommunityMembersRevealedAccountsArgs(e)
    self.delegate.communityMembersRevealedAccountsLoaded(args.communityId, args.membersRevealedAccounts)

  self.events.on(SIGNAL_COMMUNITIES_UPDATE) do(e:Args):
    let args = CommunitiesArgs(e)
    for community in args.communities:
      self.delegate.communityEdited(community)

  self.events.on(SIGNAL_COMMUNITY_MUTED) do(e:Args):
    let args = CommunityMutedArgs(e)
    self.delegate.onCommunityMuted(args.communityId, args.muted)

  self.events.on(SIGNAL_ENS_RESOLVED) do(e: Args):
    var args = ResolvedContactArgs(e)
    self.delegate.resolvedENS(args.pubkey, args.address, args.uuid, args.reason)

  self.events.on(SIGNAL_MAKE_SECTION_CHAT_ACTIVE) do(e: Args):
    var args = ActiveSectionChatArgs(e)
    self.activeSectionId = args.sectionId
    self.delegate.activeSectionSet(self.activeSectionId)

    if args.chatId != "":
      self.delegate.openSectionChatAndMessage(args.sectionId, args.chatId, args.messageId)

  self.events.on(SIGNAL_STATUS_URL_ACTIVATED) do(e: Args):
    var args = StatusUrlArgs(e)
    self.delegate.activateStatusDeepLink(args.url)

  self.events.on(SIGNAL_OS_NOTIFICATION_CLICKED) do(e: Args):
    var args = ClickedNotificationArgs(e)
    self.delegate.osNotificationClicked(args.details)

  if defined(windows):
    self.events.on(SIGNAL_DISPLAY_WINDOWS_OS_NOTIFICATION) do(e: Args):
      var args = NotificationArgs(e)
      self.delegate.displayWindowsOsNotification(args.title, args.message)

  self.events.on(SIGNAL_DISPLAY_APP_NOTIFICATION) do(e: Args):
    var args = NotificationArgs(e)
    self.delegate.displayEphemeralNotification(args.title, args.message, args.details)

  self.events.on(SIGNAL_PLAY_NOTIFICATION_SOUND) do (e: Args):
     self.delegate.onPlayNotificationSound()

  self.events.on(SIGNAL_NEW_REQUEST_TO_JOIN_COMMUNITY) do(e: Args):
    var args = CommunityRequestArgs(e)
    self.delegate.newCommunityMembershipRequestReceived(args.communityRequest)

  self.events.on(SIGNAL_REQUEST_TO_JOIN_COMMUNITY_CANCELED) do(e:Args):
    let args = community_service.CanceledCommunityRequestArgs(e)
    self.delegate.communityMembershipRequestCanceled(args.communityId, args.requestId, args.pubKey)

  self.events.on(SIGNAL_NEW_REQUEST_TO_JOIN_COMMUNITY_ACCEPTED) do(e: Args):
    var args = CommunityRequestArgs(e)
    self.delegate.communityMemberRevealedAccountsAdded(args.communityRequest)

  self.events.on(SIGNAL_NETWORK_CONNECTED) do(e: Args):
    self.delegate.onNetworkConnected()

  self.events.on(SIGNAL_NETWORK_DISCONNECTED) do(e: Args):
    self.delegate.onNetworkDisconnected()

  self.events.on(SIGNAL_CURRENT_USER_STATUS_UPDATED) do (e: Args):
    var args = CurrentUserStatusArgs(e)
    singletonInstance.userProfile.setCurrentUserStatus(args.statusType.int)

  self.events.on(chat_service.SIGNAL_CHAT_LEFT) do(e: Args):
    let args = chat_service.ChatArgs(e)
    self.delegate.onChatLeft(args.chatId)

  self.events.on(SIGNAL_COMMUNITY_MY_REQUEST_ADDED) do(e: Args):
    self.delegate.onMyRequestAdded();

  self.events.on(SIGNAL_COMMUNITY_TOKEN_DEPLOYMENT_STORED) do(e: Args):
    let args = CommunityTokenDeploymentArgs(e)
    self.delegate.onCommunityTokenDeploymentStored(args.communityToken, args.error)

  self.events.on(SIGNAL_OWNER_TOKEN_DEPLOYMENT_STORED) do(e: Args):
    let args = OwnerTokenDeploymentArgs(e)
    self.delegate.onOwnerTokensDeploymentStored(args.ownerToken, args.masterToken, args.error)

  self.events.on(SIGNAL_COMMUNITY_TOKEN_DEPLOY_STATUS) do(e: Args):
    let args = CommunityTokenDeployedStatusArgs(e)
    self.delegate.onCommunityTokenDeployStateChanged(args.communityId, args.chainId, args.contractAddress, args.deployState)

  self.events.on(SIGNAL_OWNER_TOKEN_DEPLOY_STATUS) do(e: Args):
    let args = OwnerTokenDeployedStatusArgs(e)
    self.delegate.onOwnerTokenDeployStateChanged(args.communityId, args.chainId, args.ownerContractAddress, args.masterContractAddress, args.deployState, args.transactionHash)

  self.events.on(SIGNAL_COMMUNITY_TOKEN_REMOVED) do(e: Args):
    let args = CommunityTokenRemovedArgs(e)
    self.delegate.onCommunityTokenRemoved(args.communityId, args.chainId, args.contractAddress)

  self.events.on(SIGNAL_BURN_STATUS) do(e: Args):
    let args = RemoteDestructArgs(e)
    let communityToken = args.communityToken
    self.delegate.onCommunityTokenSupplyChanged(communityToken.communityId, communityToken.chainId,
      communityToken.address, communityToken.supply,
      self.getRemainingSupply(communityToken.chainId, communityToken.address),
      self.getRemoteDestructedAmount(communityToken.chainId, communityToken.address))
    self.delegate.onBurnStateChanged(communityToken.communityId, communityToken.chainId, communityToken.address, args.status)

  self.events.on(SIGNAL_BURN_ACTION_RECEIVED) do(e: Args):
    let args = RemoteDestructArgs(e)
    let communityToken = args.communityToken
    self.delegate.onCommunityTokenSupplyChanged(communityToken.communityId, communityToken.chainId,
      communityToken.address, communityToken.supply,
      self.getRemainingSupply(communityToken.chainId, communityToken.address),
      self.getRemoteDestructedAmount(communityToken.chainId, communityToken.address))

  self.events.on(SIGNAL_FINALISE_OWNERSHIP_STATUS) do(e: Args):
    let args = FinaliseOwnershipStatusArgs(e)
    self.delegate.onFinaliseOwnershipStatusChanged(args.isPending, args.communityId)

  self.events.on(SIGNAL_REMOTE_DESTRUCT_STATUS) do(e: Args):
    let args = RemoteDestructArgs(e)
    let communityToken = args.communityToken
    self.delegate.onCommunityTokenSupplyChanged(communityToken.communityId, communityToken.chainId,
      communityToken.address, communityToken.supply,
      self.getRemainingSupply(communityToken.chainId, communityToken.address),
      self.getRemoteDestructedAmount(communityToken.chainId, communityToken.address))
    self.delegate.onRemoteDestructed(communityToken.communityId, communityToken.chainId, communityToken.address, args.remoteDestructAddresses)
    if args.status == ContractTransactionStatus.Completed:
      self.delegate.onRequestReevaluateMembersPermissionsIfRequired(communityToken.communityId, communityToken.chainId, communityToken.address)

  self.events.on(SIGNAL_AIRDROP_STATUS) do(e: Args):
    let args = AirdropArgs(e)
    let communityToken = args.communityToken
    self.delegate.onCommunityTokenSupplyChanged(communityToken.communityId, communityToken.chainId,
      communityToken.address, communityToken.supply,
      self.getRemainingSupply(communityToken.chainId, communityToken.address),
      self.getRemoteDestructedAmount(communityToken.chainId, communityToken.address))
    if args.status == ContractTransactionStatus.Completed:
      self.delegate.onRequestReevaluateMembersPermissionsIfRequired(communityToken.communityId, communityToken.chainId, communityToken.address)

  self.events.on(SIGNAL_COMMUNITY_TOKEN_OWNERS_FETCHED) do(e: Args):
    let args = CommunityTokenOwnersArgs(e)
    self.delegate.onCommunityTokenOwnersFetched(args.communityId, args.chainId, args.contractAddress, args.owners)

  self.events.on(SIGNAL_COMMUNITY_TOKEN_OWNERS_LOADING_FAILED) do(e: Args):
    let args = CommunityTokenOwnersArgs(e)
    self.delegate.errorLoadingTokenHolders(args.communityId, args.chainId, args.contractAddress, args.error)

  self.events.on(SIGNAL_ACCEPT_REQUEST_TO_JOIN_LOADING) do(e: Args):
    var args = CommunityMemberArgs(e)
    self.delegate.onAcceptRequestToJoinLoading(args.communityId, args.pubKey)

  self.events.on(SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED) do(e: Args):
    var args = CommunityMemberArgs(e)
    self.delegate.onAcceptRequestToJoinFailed(args.communityId, args.pubKey, args.requestId)

  self.events.on(SIGNAL_ACCEPT_REQUEST_TO_JOIN_FAILED_NO_PERMISSION) do(e: Args):
    var args = CommunityMemberArgs(e)
    self.delegate.onAcceptRequestToJoinFailedNoPermission(args.communityId, args.pubKey, args.requestId)

  self.events.on(SIGNAL_COMMUNITY_MEMBER_APPROVED) do(e: Args):
    var args = CommunityMemberArgs(e)
    self.delegate.onAcceptRequestToJoinSuccess(args.communityId, args.pubKey, args.requestId)

  self.events.on(SIGNAL_COMMUNITY_MEMBER_STATUS_CHANGED) do(e: Args):
    let args = CommunityMemberStatusUpdatedArgs(e)
    self.delegate.onMembershipStateUpdated(args.communityId, args.memberPubkey, args.state)

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_FLOW_TERMINATED) do(e: Args):
    let args = SharedKeycarModuleFlowTerminatedArgs(e)
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_KEYCARD_SYNC_IDENTIFIER:
      self.delegate.onSharedKeycarModuleKeycardSyncPurposeTerminated(args.lastStepInTheCurrentFlow)
      self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_KEYCARD_SYNC_TERMINATED, Args())
      return
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_SHARED_KEYCARD_MODULE_IDENTIFIER:
      self.delegate.onSharedKeycarModuleFlowTerminated(args.lastStepInTheCurrentFlow, args.continueWithNextFlow,
        args.forceFlow, args.continueWithKeyUid, args.returnToFlow)
      return
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_SIGNING_DATA_IDENTIFIER and
      self.keycardSigningFlowRequestedBy.len > 0:
        self.delegate.onSharedKeycarModuleForAuthenticationOrSigningTerminated(args.lastStepInTheCurrentFlow)
        let data = SharedKeycarModuleArgs(uniqueIdentifier: self.keycardSigningFlowRequestedBy,
          pin: args.pin,
          keyUid: args.keyUid,
          keycardUid: args.keycardUid,
          path: args.path,
          r: args.r,
          s: args.s,
          v: args.v)
        self.keycardSigningFlowRequestedBy = ""
        self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_DATA_SIGNED, data)
        return
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_AUTHENTICATE_KEYPAIR_IDENTIFIER and
      self.authenticateUserFlowRequestedBy.len > 0:
        var requestedBy = self.authenticateUserFlowRequestedBy
        self.authenticateUserFlowRequestedBy = ""
        self.delegate.onSharedKeycarModuleForAuthenticationOrSigningTerminated(args.lastStepInTheCurrentFlow)
        let data = SharedKeycarModuleArgs(uniqueIdentifier: requestedBy,
          password: args.password,
          pin: args.pin,
          keyUid: args.keyUid,
          keycardUid: args.keycardUid,
          additinalPathsDetails: args.additinalPathsDetails)
        ## Whenever user provides a password/pin we need to make some global checks.
        self.events.emit(SIGNAL_PASSWORD_PROVIDED, AuthenticationArgs(keyUid: data.keyUid, password: data.password))
        self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_USER_AUTHENTICATED, data)
        if requestedBy.startsWith(UNIQUE_MAIN_MODULE_AUTHENTICATE_INTERNAL_IDENTIFIER):
          requestedBy = requestedBy.split(UNIQUE_MAIN_MODULE_AUTHENTICATE_INTERNAL_IDENTIFIER)[1]
          self.delegate.onLoggedInUserAuthenticated(requestedBy, args.password, args.pin, args.keyUid, args.keycardUid)
          return
        return

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_DISPLAY_POPUP) do(e: Args):
    let args = SharedKeycarModuleBaseArgs(e)
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_SHARED_KEYCARD_MODULE_IDENTIFIER:
      self.delegate.onDisplayKeycardSharedModuleFlow()
      return
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_SIGNING_DATA_IDENTIFIER and
      self.keycardSigningFlowRequestedBy.len > 0:
        self.delegate.onDisplayKeycardSharedModuleForAuthenticationOrSigning()
        return
    if args.uniqueIdentifier == UNIQUE_MAIN_MODULE_AUTHENTICATE_KEYPAIR_IDENTIFIER and
      self.authenticateUserFlowRequestedBy.len > 0:
        self.delegate.onDisplayKeycardSharedModuleForAuthenticationOrSigning()
        return

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_SIGN_DATA) do(e: Args):
    let args = SharedKeycarModuleSigningArgs(e)
    self.keycardSigningFlowRequestedBy = args.uniqueIdentifier
    self.delegate.runAuthenticationOrSigningPopup(keycard_shared_module.FlowType.Sign, args.keyUid, @[args.path], args.dataToSign)

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_AUTHENTICATE_USER) do(e: Args):
    let args = SharedKeycarModuleAuthenticationArgs(e)
    self.authenticateUserFlowRequestedBy = args.uniqueIdentifier
    self.delegate.runAuthenticationOrSigningPopup(keycard_shared_module.FlowType.Authentication, args.keyUid, args.additionalBip44Paths)

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_TRY_KEYCARD_SYNC) do(e: Args):
    let args = SharedKeycarModuleArgs(e)
    self.delegate.tryKeycardSync(args.keyUid, args.pin)

  self.events.on(SIGNAL_PROFILE_MIGRATION_NEEDED_UPDATED) do(e: Args):
    self.delegate.checkAndPerformProfileMigrationIfNeeded()

  self.events.on(SIGNAL_COMMUNITY_TOKENS_DETAILS_LOADED) do(e: Args):
    let args = CommunityTokensDetailsArgs(e)
    self.delegate.onCommunityTokensDetailsLoaded(args.communityId, args.communityTokens, args.communityTokenJsonItems)

  self.events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e: Args):
    self.delegate.onAppNetworkChanged()

  self.events.on(SIGNAL_CONTACT_UPDATED) do(e: Args):
    let args = ContactArgs(e)
    self.delegate.contactUpdated(args.contactId)

  self.events.on(SIGNAL_CONTACT_NICKNAME_CHANGED) do(e: Args):
    var args = ContactArgs(e)
    self.delegate.contactUpdated(args.contactId)

  self.events.on(SIGNAL_CONTACT_BLOCKED) do(e: Args):
    let args = ContactArgs(e)
    self.delegate.contactUpdated(args.contactId)

  self.events.on(SIGNAL_CONTACT_UNBLOCKED) do(e: Args):
    let args = ContactArgs(e)
    self.delegate.contactUpdated(args.contactId)

  self.events.on(SIGNAL_LOGGEDIN_USER_NAME_CHANGED) do(e: Args):
    self.delegate.contactUpdated(singletonInstance.userProfile.getPubKey())

proc authenticateLoggedInUser*(self: Controller, requestedBy: string) =
    let loggedInUserKeyUid = singletonInstance.userProfile.getKeyUid()
    self.authenticateUserFlowRequestedBy = UNIQUE_MAIN_MODULE_AUTHENTICATE_INTERNAL_IDENTIFIER & requestedBy
    self.delegate.runAuthenticationOrSigningPopup(keycard_shared_module.FlowType.Authentication, loggedInUserKeyUid, @[])

proc isConnected*(self: Controller): bool =
  return self.nodeService.isConnected()

proc getActiveSectionId*(self: Controller): string =
  result = self.activeSectionId

proc setActiveSectionId*(self: Controller, sectionId: string) =
  self.activeSectionId = sectionId

proc sectionUnreadMessagesAndMentionsCount*(self: Controller, communityId: string, sectionIsMuted: bool):
    tuple[unviewedMessagesCount: int, unviewedMentionsCount: int] =
  return self.chatService.sectionUnreadMessagesAndMentionsCount(communityId, sectionIsMuted)

proc setCurrentUserStatus*(self: Controller, status: StatusType) =
  if(self.settingsService.saveSendStatusUpdates(status)):
    singletonInstance.userProfile.setCurrentUserStatus(status.int)
    self.contactsService.emitCurrentUserStatusChanged(self.settingsService.getCurrentUserStatus())
  else:
    error "error updating user status"

proc getContact*(self: Controller, id: string): ContactsDto =
  return self.contactsService.getContactById(id)

proc getContactNameAndImage*(self: Controller, contactId: string):
    tuple[name: string, image: string, largeImage: string] =
  return self.contactsService.getContactNameAndImage(contactId)

proc getContactDetails*(self: Controller, contactId: string): ContactDetails =
  return self.contactsService.getContactDetails(contactId)

proc resolveENS*(self: Controller, ensName: string, uuid: string = "", reason: string = "") =
  self.contactsService.resolveENS(ensName, uuid, reason)

proc isMnemonicBackedUp*(self: Controller): bool =
  result = self.privacyService.isMnemonicBackedUp()

proc switchTo*(self: Controller, sectionId, chatId, messageId: string) =
  let data = ActiveSectionChatArgs(sectionId: sectionId, chatId: chatId, messageId: messageId)
  self.events.emit(SIGNAL_MAKE_SECTION_CHAT_ACTIVE, data)

proc getJoinedAndSpectatedCommunities*(self: Controller): seq[CommunityDto] =
  return self.communityService.getJoinedAndSpectatedCommunities()

proc getCommunityById*(self: Controller, communityId: string): CommunityDto =
  return self.communityService.getCommunityById(communityId)

proc spectateCommunity*(self: Controller, communityId: string) =
  discard self.communityService.spectateCommunity(communityId)

proc getStatusForContactWithId*(self: Controller, publicKey: string): StatusUpdateDto =
  return self.contactsService.getStatusForContactWithId(publicKey)

proc getCommunityTokensDetailsAsync*(self: Controller, communityId: string) =
  self.communityTokensService.getCommunityTokensDetailsAsync(communityId)

proc getCommunityTokenOwners*(self: Controller, communityId: string, chainId: int, contractAddress: string): seq[CommunityCollectibleOwner] =
  return self.communityTokensService.getCommunityTokenOwners(communityId, chainId, contractAddress)

proc getCommunityTokenOwnerName*(self: Controller, contractOwnerAddress: string): string =
  return self.communityTokensService.contractOwnerName(contractOwnerAddress)

proc getCommunityTokenBurnState*(self: Controller, chainId: int, contractAddress: string): ContractTransactionStatus =
  return self.communityTokensService.getCommunityTokenBurnState(chainId, contractAddress)

proc getRemoteDestructedAddresses*(self: Controller, chainId: int, contractAddress: string): seq[string] =
  return self.communityTokensService.getRemoteDestructedAddresses(chainId, contractAddress)

proc getRemainingSupply*(self: Controller, chainId: int, contractAddress: string): Uint256 =
  return self.communityTokensService.getRemainingSupply(chainId, contractAddress)

proc getRemoteDestructedAmount*(self: Controller, chainId: int, contractAddress: string): Uint256 =
  return self.communityTokensService.getRemoteDestructedAmount(chainId, contractAddress)

proc getNetworkByChainId*(self:Controller, chainId: int): NetworkItem =
  self.networksService.getNetworkByChainId(chainId)

proc getAppNetwork*(self:Controller): NetworkItem =
  self.networksService.getAppNetwork()

proc slowdownArchivesImport*(self:Controller) =
  communityService.slowdownArchivesImport()

proc speedupArchivesImport*(self:Controller) =
  communityService.speedupArchivesImport()

proc asyncGetRevealedAccountsForAllMembers*(self: Controller, communityId: string) =
  self.communityService.asyncGetRevealedAccountsForAllMembers(communityId)

proc asyncGetRevealedAccountsForMember*(self: Controller, communityId, memberPubkey: string) =
  self.communityService.asyncGetRevealedAccountsForMember(communityId, memberPubkey)

proc asyncReevaluateCommunityMembersPermissions*(self: Controller, communityId: string) =
  self.communityService.asyncReevaluateCommunityMembersPermissions(communityId)

proc startTokenHoldersManagement*(self: Controller, chainId: int, contractAddress: string) =
  self.communityTokensService.startTokenHoldersManagement(chainId, contractAddress)

proc stopTokenHoldersManagement*(self: Controller) =
  self.communityTokensService.stopTokenHoldersManagement()

proc connectionChange*(self: Controller, connectionType: string, isExpensive: bool) =
  self.generalService.connectionChange(connectionType, isExpensive)
