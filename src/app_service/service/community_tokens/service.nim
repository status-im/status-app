import nimqml, tables, chronicles, json, stint, strutils, sugar, sequtils, std/strformat, times

import app/global/global_singleton
import app/core/eventemitter
import app/core/tasks/[qt, threadpool]
import app/core/signals/types

import app/modules/shared_models/currency_amount

import backend/backend
import backend/response_type
import backend/wallet
import backend/collectibles as collectibles_backend
import backend/communities as communities_backend
import backend/community_tokens as tokens_backend
from backend/collectibles_types import CollectibleOwner

import app_service/service/network/service as network_service
import app_service/service/transaction/service as transaction_service
import app_service/service/token/service as token_service
import app_service/service/settings/service as settings_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/activity_center/service as ac_service
import app_service/service/community/service as community_service
import app_service/service/currency/service as currency_service
import app_service/service/ens/utils as ens_utils
import app_service/service/eth/utils as eth_utils
import app_service/service/eth/dto/transaction
import app_service/service/community/dto/community
import app_service/service/contacts/dto/contacts
import app_service/common/activity_center
import app_service/common/types
import app_service/common/account_constants
import app_service/common/utils as common_utils

import ./community_collectible_owner
import ./dto/deployment_parameters
import ./dto/community_token
import ./dto/community_token_owner

export community_token
export deployment_parameters
export community_token_owner

include async_tasks

logScope:
  topics = "community-tokens-service"

type
  CommunityTokenDeployedStatusArgs* = ref object of Args
    communityId*: string
    contractAddress*: string
    chainId*: int
    transactionHash*: string
    deployState*: DeployState

type
  OwnerTokenDeployedStatusArgs* = ref object of Args
    communityId*: string
    chainId*: int
    ownerContractAddress*: string
    masterContractAddress*: string
    transactionHash*: string
    deployState*: DeployState

type
  CommunityTokenDeploymentArgs* = ref object of Args
    communityToken*: CommunityTokenDto
    transactionHash*: string
    error*: string

type
  OwnerTokenDeploymentArgs* = ref object of Args
    ownerToken*: CommunityTokenDto
    masterToken*: CommunityTokenDto
    error*: string

type
  CommunityTokenRemovedArgs* = ref object of Args
    communityId*: string
    contractAddress*: string
    chainId*: int

type
  OwnerTokenOwnerAddressArgs* = ref object of Args
    chainId*: int
    contractAddress*: string
    address*: string
    addressName*: string

type
  RemoteDestructArgs* = ref object of Args
    communityToken*: CommunityTokenDto
    transactionHash*: string
    status*: ContractTransactionStatus
    remoteDestructAddresses*: seq[string]

type
  AirdropArgs* = ref object of Args
    communityToken*: CommunityTokenDto
    transactionHash*: string
    status*: ContractTransactionStatus

type
  CommunityTokenOwnersArgs* =  ref object of Args
    communityId*: string
    contractAddress*: string
    chainId*: int
    owners*: seq[CommunityCollectibleOwner]
    error*: string

type
  CommunityTokensDetailsArgs* =  ref object of Args
    communityId*: string
    communityTokens*: seq[CommunityTokenDto]
    communityTokenJsonItems*: JsonNode

type
  OwnerTokenReceivedArgs* =  ref object of Args
    communityId*: string
    communityName*: string
    chainId*: int
    contractAddress*: string

type
  CommunityTokenReceivedArgs* =  ref object of Args
    name*: string
    image*: string
    address*: string
    collectibleId*: CollectibleUniqueID
    communityId*: string
    communityName*: string
    chainId*: int
    amount*: float64
    txHash*: string
    symbol*: string
    decimals*: int
    verified*: bool
    tokenListID*: string
    isFirst*: bool
    tokenType*: int
    accountAddress*: string
    accountName*: string
    isWatchOnlyAccount*: bool

proc `$`*(self: CommunityTokenReceivedArgs): string =
  return fmt"""CommunityTokenReceivedArgs(
    name: {self.name},
    image: {self.image},
    communityId: {self.communityId},
    communityName: {self.communityName},
    chainId: {self.chainId},
    amount: {self.amount},
    decimals: {self.decimals},
    verified: {self.verified},
    tokenListID: {self.tokenListID},
    txHash: {self.txHash},
    symbol: {self.symbol},
    isFirst: {self.isFirst},
    tokenType: {self.tokenType},
    accountAddress: {self.accountAddress},
    accountName: {self.accountName},
    isWatchOnlyAccount: {self.isWatchOnlyAccount}
  )"""

proc toTokenData*(self: CommunityTokenReceivedArgs): string =
  var dataNode = %* {
    "chainId": self.chainId,
    "txHash": self.txHash,
    "walletAddress": self.accountAddress,
    "isFirst": self.isFirst,
    "communityId": self.communityId,
    "amount": $self.amount,
    "name": self.name,
    "symbol": self.symbol,
    "tokenType": self.tokenType
  }
  if not self.collectibleId.isNil:
    dataNode.add("collectibleId", %self.collectibleId)
  return $dataNode

type
  FinaliseOwnershipStatusArgs* =  ref object of Args
    isPending*: bool
    communityId*: string

type ContractDetails* = object
  chainId*: int
  contractAddress*: string
  communityId*: string

proc `%`*(self: ContractDetails): JsonNode =
  result = %* {
    "chainId": self.chainId,
    "contractAddress": self.contractAddress,
    "communityId": self.communityId,
  }

proc toContractDetails*(jsonObj: JsonNode): ContractDetails =
  result = ContractDetails()
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("contractAddress", result.contractAddress)
  discard jsonObj.getProp("communityId", result.communityId)

# Signals which may be emitted by this service:
const SIGNAL_COMMUNITY_TOKEN_DEPLOY_STATUS* = "communityTokens-communityTokenDeployStatus"
const SIGNAL_COMMUNITY_TOKEN_DEPLOYMENT_STORED* = "communityTokens-communityTokenDeploymentStored"
const SIGNAL_COMMUNITY_TOKEN_OWNERS_FETCHED* = "communityTokens-communityTokenOwnersFetched"
const SIGNAL_COMMUNITY_TOKEN_OWNERS_LOADING_FAILED* = "communityTokens-communityTokenOwnersLoadingFailed"
const SIGNAL_REMOTE_DESTRUCT_STATUS* = "communityTokens-communityTokenRemoteDestructStatus"
const SIGNAL_BURN_STATUS* = "communityTokens-communityTokenBurnStatus"
const SIGNAL_BURN_ACTION_RECEIVED* = "communityTokens-communityTokenBurnActionReceived"
const SIGNAL_AIRDROP_STATUS* = "communityTokens-airdropStatus"
const SIGNAL_REMOVE_COMMUNITY_TOKEN_FAILED* = "communityTokens-removeCommunityTokenFailed"
const SIGNAL_COMMUNITY_TOKEN_REMOVED* = "communityTokens-communityTokenRemoved"
const SIGNAL_OWNER_TOKEN_DEPLOY_STATUS* = "communityTokens-ownerTokenDeployStatus"
const SIGNAL_OWNER_TOKEN_DEPLOYMENT_STORED* = "communityTokens-ownerTokenDeploymentStored"
const SIGNAL_COMMUNITY_TOKENS_DETAILS_LOADED* = "communityTokens-communityTokenDetailsLoaded"
const SIGNAL_OWNER_TOKEN_RECEIVED* = "communityTokens-ownerTokenReceived"
const SIGNAL_FINALISE_OWNERSHIP_STATUS* = "communityTokens-finaliseOwnershipStatus"
const SIGNAL_OWNER_TOKEN_OWNER_ADDRESS* = "communityTokens-ownerTokenOwnerAddress"
const SIGNAL_COMMUNITY_TOKEN_RECEIVED* = "communityTokens-communityTokenReceived"

QtObject:
  type
    Service* = ref object of QObject
      events: EventEmitter
      threadpool: ThreadPool
      networkService: network_service.Service
      transactionService: transaction_service.Service
      tokenService: token_service.Service
      settingsService: settings_service.Service
      walletAccountService: wallet_account_service.Service
      acService: ac_service.Service
      communityService: community_service.Service
      currencyService: currency_service.Service

      tokenOwnersCache: Table[ContractTuple, seq[CommunityCollectibleOwner]]

      tempFeeTable: Table[int, SuggestedFeesDto] # fees per chain, filled during gas computation, used during operation (deployment, mint, burn)
      tempGasTable: Table[ContractTuple, int] # gas per contract, filled during gas computation, used during operation (deployment, mint, burn)
      tempTokensAndAmounts: seq[CommunityTokenAndAmount]

      communityTokensCache: seq[CommunityTokenDto]

      # keep times when token holders list for contracts were updated
      tokenHoldersLastUpdateMap: Table[ContractTuple, int64]
      # timer which fetches token holders
      tokenHoldersTimer: QTimer
      # token for which token holders are fetched
      tokenHoldersToken: CommunityTokenDto
      # flag to indicate that token holders management started
      tokenHoldersManagementStarted: bool

  # Forward declaration
  proc getAllCommunityTokensAsync*(self: Service)
  proc getCommunityTokenOwners*(self: Service, communityId: string, chainId: int, contractAddress: string): seq[CommunityCollectibleOwner]
  proc getCommunityToken*(self: Service, chainId: int, address: string): CommunityTokenDto
  proc findContractByUniqueId*(self: Service, contractUniqueKey: string): CommunityTokenDto
  proc restartTokenHoldersTimer(self: Service, chainId: int, contractAddress: string)
  proc refreshTokenHolders(self: Service, token: CommunityTokenDto)

  proc delete*(self: Service) =
      delete(self.tokenHoldersTimer)
      self.QObject.delete

  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    networkService: network_service.Service,
    transactionService: transaction_service.Service,
    tokenService: token_service.Service,
    settingsService: settings_service.Service,
    walletAccountService: wallet_account_service.Service,
    acService: ac_service.Service,
    communityService: community_service.Service,
    currencyService: currency_service.Service,
  ): Service =
    result = Service()
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.networkService = networkService
    result.transactionService = transactionService
    result.tokenService = tokenService
    result.settingsService = settingsService
    result.walletAccountService = walletAccountService
    result.acService = acService
    result.communityService = communityService
    result.currencyService = currencyService

    result.tokenHoldersTimer = newQTimer()
    result.tokenHoldersTimer.setSingleShot(true)
    signalConnect(result.tokenHoldersTimer, "timeout()", result, "onTokenHoldersTimeout()", 2)

  # cache functions
  proc updateCommunityTokenCache(self: Service, chainId: int, address: string, tokenToUpdate: CommunityTokenDto) =
    for i in 0..self.communityTokensCache.len-1:
      if self.communityTokensCache[i].chainId == chainId and self.communityTokensCache[i].address == address:
        self.communityTokensCache[i] = tokenToUpdate
        return

  proc removeCommunityTokenAndUpdateCache(self: Service, chainId: int, contractAddress: string) =
    discard tokens_backend.removeCommunityToken(chainId, contractAddress)
    self.communityTokensCache = self.communityTokensCache.filter(x => ((x.chainId != chainId) or (x.address != contractAddress)))

  proc getCommunityTokenFromCache*(self: Service, chainId: int, address: string): CommunityTokenDto =
    for token in self.communityTokensCache:
      if token.chainId == chainId and cmpIgnoreCase(token.address, address) == 0:
        return token

  # end of cache functions

  proc processReceivedCollectiblesWalletEvent(self: Service, jsonMessage: string, accounts: seq[string]) =
    try:
      let dataMessageJson = parseJson(jsonMessage)
      let tokenDataPayload = fromJson(dataMessageJson, CommunityCollectiblesReceivedPayload)

      let watchOnlyAccounts = self.walletAccountService.getWatchOnlyAccounts()
      if any(watchOnlyAccounts, proc (x: WalletAccountDto): bool = x.address == accounts[0]):
        # skip events on watch-only accounts
        return

      for coll in tokenDataPayload.collectibles:
        if not coll.communityData.isSome():
          continue
        let id = coll.id
        let communityData = coll.communityData.get()

        let privilegesLevel = communityData.privilegesLevel
        let communityId = communityData.id
        let community = self.communityService.getCommunityById(communityId)
        if privilegesLevel == PrivilegesLevel.Owner and not community.isOwner():
          let communityName = communityData.name
          let chainId = id.contractID.chainID
          let contractAddress = id.contractID.address
          debug "received owner token", contractAddress=contractAddress, chainId=chainId
          let tokenReceivedArgs = OwnerTokenReceivedArgs(communityId: communityId, communityName: communityName, chainId: chainId, contractAddress: contractAddress)
          self.events.emit(SIGNAL_OWNER_TOKEN_RECEIVED, tokenReceivedArgs)
          let finaliseStatusArgs = FinaliseOwnershipStatusArgs(isPending: true, communityId: communityId)
          self.events.emit(SIGNAL_FINALISE_OWNERSHIP_STATUS, finaliseStatusArgs)

          let response = tokens_backend.registerOwnerTokenReceivedNotification(communityId)
          checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
        elif privilegesLevel == PrivilegesLevel.Community:
          var collectibleName, collectibleImage, txHash, accountName, accountAddress: string
          var isFirst = false
          var amount = float64(1.0)

          if len(accounts) > 0:
            accountAddress = accounts[0]
            let acc = self.walletAccountService.getAccountByAddress(accountAddress)
            if acc.isNil:
              error "getAccountByAddress result is nil", accountAddress=accountAddress
              continue
            accountName = acc.name

          if coll.isFirst.isSome():
            isFirst = coll.isFirst.get()
          if coll.latestTxHash.isSome():
            txHash = coll.latestTxHash.get()
          if coll.receivedAmount.isSome():
            amount = coll.receivedAmount.get()

          if coll.collectibleData.isSome():
            let collData = coll.collectibleData.get()
            collectibleName = collData.name
            if collData.imageUrl.isSome():
              collectibleImage = collData.imageUrl.get()

          let tokenReceivedArgs = CommunityTokenReceivedArgs(
            collectibleId: id,
            communityId: communityId,
            communityName: communityData.name,
            chainId: id.contractID.chainID,
            txHash: txHash,
            name: collectibleName,
            amount: amount,
            image: collectibleImage,
            isFirst: isFirst,
            tokenType: int(TokenType.ERC721),
            accountAddress: accountAddress,
            accountName: accountName
          )
          self.events.emit(SIGNAL_COMMUNITY_TOKEN_RECEIVED, tokenReceivedArgs)

          let response = tokens_backend.registerReceivedCommunityTokenNotification(communityId, isFirst, tokenReceivedArgs.toTokenData())
          checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
    except Exception as e:
      error "Error registering collectibles token received notification", msg=e.msg

  proc processReceivedCommunityTokenWalletEvent(self: Service, jsonMessage: string, accounts: seq[string]) =
    try:
      let dataMessageJson = parseJson(jsonMessage)
      let tokenDataPayload = fromJson(dataMessageJson, CommunityTokenReceivedPayload)
      if len(tokenDataPayload.communityId) == 0:
        return

      let watchOnlyAccounts = self.walletAccountService.getWatchOnlyAccounts()
      var accountName, accountAddress: string
      if len(accounts) > 0:
        accountAddress = accounts[0]
        let res = self.walletAccountService.getAccountByAddress(accountAddress)
        accountName = res.name

      let communityId = tokenDataPayload.communityId
      let tokenReceivedArgs = CommunityTokenReceivedArgs(
        communityId: communityId,
        communityName: tokenDataPayload.communityName,
        chainId: tokenDataPayload.chainId,
        txHash: tokenDataPayload.txHash,
        address: "0x" & tokenDataPayload.address.toHex(),
        name: tokenDataPayload.name,
        amount: tokenDataPayload.amount,
        decimals: tokenDataPayload.decimals,
        verified: tokenDataPayload.verified,
        tokenListID: tokenDataPayload.tokenListID,
        image: tokenDataPayload.image,
        symbol: tokenDataPayload.symbol,
        isFirst: tokenDataPayload.isFirst,
        tokenType: int(TokenType.ERC20),
        accountAddress: accountAddress,
        accountName: accountName,
        isWatchOnlyAccount: any(watchOnlyAccounts, proc (x: WalletAccountDto): bool = x.address == accounts[0])
      )
      self.events.emit(SIGNAL_COMMUNITY_TOKEN_RECEIVED, tokenReceivedArgs)

      let response = tokens_backend.registerReceivedCommunityTokenNotification(communityId, tokenDataPayload.isFirst, tokenReceivedArgs.toTokenData())
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
    except Exception as e:
      error "Error registering community token received notification", msg=e.msg

  proc processSetSignerTransactionEvent(self: Service, signalArgs: CommunityTokenTransactionStatusChangedSignal) =
    try:
      let chainId = signalArgs.communityToken.chainId
      let communityId = signalArgs.communityToken.communityId

      if signalArgs.success:
        let finaliseStatusArgs = FinaliseOwnershipStatusArgs(isPending: false, communityId: communityId)
        self.events.emit(SIGNAL_FINALISE_OWNERSHIP_STATUS, finaliseStatusArgs)
      else:
        error "Signer not set"


      # TODO move AC notifications to status-go
      let response = if signalArgs.success: tokens_backend.registerReceivedOwnershipNotification(communityId) else: tokens_backend.registerSetSignerFailedNotification(communityId)
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})

      let notificationToSetRead = self.acService.getNotificationForTypeAndCommunityId(notification.ActivityCenterNotificationType.OwnerTokenReceived, communityId)
      if notificationToSetRead != nil:
        self.acService.markActivityCenterNotificationRead(notificationToSetRead.id)
    except Exception as e:
      error "Error processing set signer transaction", msg=e.msg

  proc processAirdropTransactionEvent(self: Service, signalArgs: CommunityTokenTransactionStatusChangedSignal) =
    try:
      let transactionStatus = if signalArgs.success: ContractTransactionStatus.Completed else: ContractTransactionStatus.Failed
      let data = AirdropArgs(communityToken: signalArgs.communityToken, transactionHash: signalArgs.hash, status: transactionStatus)
      self.events.emit(SIGNAL_AIRDROP_STATUS, data)

      # update owners list if airdrop was successfull
      if signalArgs.success:
        self.refreshTokenHolders(signalArgs.communityToken)
    except Exception as e:
        error "Error processing airdrop pending transaction event", msg=e.msg

  proc processRemoteDestructEvent(self: Service, signalArgs: CommunityTokenTransactionStatusChangedSignal) =
    try:
      let transactionStatus = if signalArgs.success: ContractTransactionStatus.Completed else: ContractTransactionStatus.Failed
      let data = RemoteDestructArgs(communityToken: signalArgs.communityToken, transactionHash: signalArgs.hash, status: transactionStatus, remoteDestructAddresses: @[])
      self.events.emit(SIGNAL_REMOTE_DESTRUCT_STATUS, data)

      # update owners list if remote destruct was successfull
      if signalArgs.success:
        self.refreshTokenHolders(signalArgs.communityToken)
    except Exception as e:
      error "Error processing collectible self destruct pending transaction event", msg=e.msg

  proc processBurnEvent(self: Service, signalArgs: CommunityTokenTransactionStatusChangedSignal) =
    try:
      let transactionStatus = if signalArgs.success: ContractTransactionStatus.Completed else: ContractTransactionStatus.Failed
      if signalArgs.success:
        self.updateCommunityTokenCache(signalArgs.communityToken.chainId, signalArgs.communityToken.address, signalArgs.communityToken)
      let data = RemoteDestructArgs(communityToken: signalArgs.communityToken, transactionHash: signalArgs.hash, status: transactionStatus)
      self.events.emit(SIGNAL_BURN_STATUS, data)
    except Exception as e:
      error "Error processing collectible burn pending transaction event", msg=e.msg

  proc processDeployCommunityToken(self: Service, signalArgs: CommunityTokenTransactionStatusChangedSignal) =
    try:
      let deployState = if signalArgs.success: DeployState.Deployed else: DeployState.Failed
      let tokenDto = signalArgs.communityToken
      if not signalArgs.success:
        error "Community contract not deployed", chainId=tokenDto.chainId, address=tokenDto.address
      self.updateCommunityTokenCache(tokenDto.chainId, tokenDto.address, tokenDto)
      let data = CommunityTokenDeployedStatusArgs(communityId: tokenDto.communityId, contractAddress: tokenDto.address,
                                                  deployState: deployState, chainId: tokenDto.chainId,
                                                  transactionHash: signalArgs.hash)
      self.events.emit(SIGNAL_COMMUNITY_TOKEN_DEPLOY_STATUS, data)
    except Exception as e:
      error "Error processing community token deployment pending transaction event", msg=e.msg

  proc processDeployOwnerToken(self: Service, signalArgs: CommunityTokenTransactionStatusChangedSignal) =
    try:
      let deployState = if signalArgs.success: DeployState.Deployed else: DeployState.Failed
      let ownerToken = signalArgs.ownerToken
      let masterToken = signalArgs.masterToken
      if not signalArgs.success:
        error "Owner token contract not deployed", chainId=ownerToken.chainId, address=ownerToken.address

      let temporaryMasterContractAddress = signalArgs.hash & "-master"
      let temporaryOwnerContractAddress = signalArgs.hash & "-owner"
      self.updateCommunityTokenCache(ownerToken.chainId, temporaryOwnerContractAddress, ownerToken)
      self.updateCommunityTokenCache(ownerToken.chainId, temporaryMasterContractAddress, masterToken)

      let data = OwnerTokenDeployedStatusArgs(communityId: ownerToken.communityId, chainId: ownerToken.chainId,
                                                ownerContractAddress: ownerToken.address,
                                                masterContractAddress: masterToken.address,
                                                deployState: deployState,
                                                transactionHash: signalArgs.hash)
      self.events.emit(SIGNAL_OWNER_TOKEN_DEPLOY_STATUS, data)
    except Exception as e:
      error "Error processing owner token deployment pending transaction event", msg=e.msg

  proc processCommunityTokenAction(self: Service, signalArgs: CommunityTokenActionSignal) =
    case signalArgs.actionType
      of CommunityTokenActionType.Airdrop:
        self.refreshTokenHolders(signalArgs.communityToken)
      of CommunityTokenActionType.Burn:
        self.updateCommunityTokenCache(signalArgs.communityToken.chainId, signalArgs.communityToken.address, signalArgs.communityToken)
        let data = RemoteDestructArgs(communityToken: signalArgs.communityToken)
        self.events.emit(SIGNAL_BURN_ACTION_RECEIVED, data)
      of CommunityTokenActionType.RemoteDestruct:
        self.refreshTokenHolders(signalArgs.communityToken)
      else:
        warn "Unknown token action", actionType=signalArgs.actionType

  proc init*(self: Service) =
    self.getAllCommunityTokensAsync()

    self.events.on(SignalType.Wallet.event) do(e:Args):
      var data = WalletSignal(e)
      if data.eventType == collectibles_backend.eventCommunityCollectiblesReceived:
        self.processReceivedCollectiblesWalletEvent(data.message, data.accounts)
      elif data.eventType == tokens_backend.eventCommunityTokenReceived:
        self.processReceivedCommunityTokenWalletEvent(data.message, data.accounts)

    self.events.on(SignalType.CommunityTokenAction.event) do(e:Args):
      let receivedData = CommunityTokenActionSignal(e)
      self.processCommunityTokenAction(receivedData)

    self.events.on(SignalType.CommunityTokenTransactionStatusChanged.event) do(e: Args):
      let receivedData = CommunityTokenTransactionStatusChangedSignal(e)
      if receivedData.errorString != "":
        error "Community token transaction has finished but the system error occured. Probably state of the token in database is broken.",
              errorString=receivedData.errorString, transactionHash=receivedData.hash, transactionSuccess=receivedData.success
      if receivedData.sendType == int(SendType.CommunitySetSignerPubKey):
        self.processSetSignerTransactionEvent(receivedData)
      elif receivedData.sendType == int(SendType.CommunityMintTokens):
        self.processAirdropTransactionEvent(receivedData)
      elif receivedData.sendType == int(SendType.CommunityRemoteBurn):
        self.processRemoteDestructEvent(receivedData)
      elif receivedData.sendType == int(SendType.CommunityBurn):
        self.processBurnEvent(receivedData)
      elif receivedData.sendType == int(SendType.CommunityDeployAssets) or receivedData.sendType == int(SendType.CommunityDeployCollectibles):
        self.processDeployCommunityToken(receivedData)
      elif receivedData.sendType == int(SendType.CommunityDeployOwnerToken):
        self.processDeployOwnerToken(receivedData)

  proc buildTransactionDataDto(self: Service, addressFrom: string, chainId: int, contractAddress: string): TransactionDataDto =
    let gasUnits = self.tempGasTable.getOrDefault((chainId, contractAddress), 0)
    let suggestedFees = self.tempFeeTable.getOrDefault(chainId, nil)
    if suggestedFees == nil:
      error "Can't find suggested fees for chainId", chainId=chainId
      return
    return ens_utils.buildTransactionDataDto(gasUnits, suggestedFees, addressFrom, chainId, contractAddress)

  proc temporaryMasterContractAddress*(ownerContractTransactionHash: string): string =
    return ownerContractTransactionHash & "-master"

  proc temporaryOwnerContractAddress*(ownerContractTransactionHash: string): string =
    return ownerContractTransactionHash & "-owner"

  proc storeDeployedOwnerContract*(self: Service, addressFrom: string, chainId: int, txHash: string,
    ownerDeploymentParams: DeploymentParameters, masterDeploymentParams: DeploymentParameters) =
    var data = OwnerTokenDeploymentArgs(
      ownerToken: CommunityTokenDto(
        communityId: ownerDeploymentParams.communityId,
        name: ownerDeploymentParams.name,
        symbol: ownerDeploymentParams.symbol,
        tokenType: ownerDeploymentParams.tokenType,
      ),
      masterToken: CommunityTokenDto(
        communityId: masterDeploymentParams.communityId,
        name: masterDeploymentParams.name,
        symbol: masterDeploymentParams.symbol,
        tokenType: masterDeploymentParams.tokenType,
      ),
    )
    try:

      let response = tokens_backend.storeDeployedOwnerToken(addressFrom, chainId, txHash, %ownerDeploymentParams, %masterDeploymentParams)
      if not response.error.isNil:
        raise newException(CatchableError, response.error.message)

      let deployedOwnerToken = toCommunityTokenDto(response.result["ownerToken"])
      let deployedMasterToken = toCommunityTokenDto(response.result["masterToken"])
      self.communityTokensCache.add(deployedOwnerToken)
      self.communityTokensCache.add(deployedMasterToken)
      data.ownerToken = deployedOwnerToken
      data.masterToken = deployedMasterToken
    except Exception as e:
      data.error = e.msg
      error "Error storing deployed owner contract", msg = e.msg
    self.events.emit(SIGNAL_OWNER_TOKEN_DEPLOYMENT_STORED, data)

  proc storeDeployedContract*(self: Service, sendType: SendType, addressFrom: string, addressTo: string, chainId: int,
    txHash: string, deploymentParams: DeploymentParameters) =
    var data = CommunityTokenDeploymentArgs(
      transactionHash: txHash
    )
    try:
      var response: RpcResponse[JsonNode]
      case sendType
      of SendType.CommunityDeployAssets:
        response = tokens_backend.storeDeployedAssets(addressFrom, addressTo, chainId, txHash, %deploymentParams)
      of SendType.CommunityDeployCollectibles:
        response = tokens_backend.storeDeployedCollectibles(addressFrom, addressTo, chainId, txHash, %deploymentParams)
      else:
        let err = "unexpected send type " & $sendType
        raise newException(CatchableError, err)

      let deployedCommunityToken = toCommunityTokenDto(response.result["communityToken"])
      self.communityTokensCache.add(deployedCommunityToken)
      data.communityToken = deployedCommunityToken
    except Exception as e:
      data.error = e.msg
      error "Error storing deployed contract", msg = e.msg
    self.events.emit(SIGNAL_COMMUNITY_TOKEN_DEPLOYMENT_STORED, data)

  proc getCommunityTokens*(self: Service, communityId: string): seq[CommunityTokenDto] =
    return self.communityTokensCache.filter(x => (x.communityId == communityId))

  proc getAllCommunityTokens*(self: Service): seq[CommunityTokenDto] =
    return self.communityTokensCache

  proc getCommunityTokensDetailsAsync*(self: Service, communityId: string) =
    let arg = GetCommunityTokensDetailsArg(
      tptr: getCommunityTokensDetailsTaskArg,
      vptr: cast[uint](self.vptr),
      slot: "onCommunityTokensDetailsLoaded",
      communityId: communityId
    )
    self.threadpool.start(arg)

  proc onCommunityTokensDetailsLoaded*(self:Service, response: string) {.slot.} =
    try:
      let responseJson = response.parseJson()

      if responseJson["error"].getStr != "":
        raise newException(ValueError, responseJson["error"].getStr)

      let communityTokens = parseCommunityTokens(responseJson["communityTokensResponse"]["result"])
      let communityTokenJsonItems = responseJson["communityTokenJsonItems"]

      self.events.emit(SIGNAL_COMMUNITY_TOKENS_DETAILS_LOADED,
        CommunityTokensDetailsArgs(
          communityId: responseJson["communityId"].getStr,
          communityTokens: communityTokens,
          communityTokenJsonItems: communityTokenJsonItems,
        ))
    except Exception as e:
      error "Error getting community tokens details", message = e.msg

  proc getAllCommunityTokensAsync*(self: Service) =
    let arg = GetAllCommunityTokensArg(
      tptr: getAllCommunityTokensTaskArg,
      vptr: cast[uint](self.vptr),
      slot: "onGotAllCommunityTokens",
    )
    self.threadpool.start(arg)

  proc onGotAllCommunityTokens*(self:Service, response: string) {.slot.} =
    try:
      let responseJson = parseJson(response)
      self.communityTokensCache = map(responseJson["response"]["result"].getElems(),
        proc(x: JsonNode): CommunityTokenDto = x.toCommunityTokenDto())

    except RpcException as e:
      error "Error getting all community tokens async", message = e.msg

  proc removeCommunityToken*(self: Service, communityId: string, chainId: int, address: string) =
    try:
      self.removeCommunityTokenAndUpdateCache(chainId, address)
      self.events.emit(SIGNAL_COMMUNITY_TOKEN_REMOVED, CommunityTokenRemovedArgs(communityId: communityId, contractAddress: address, chainId: chainId))
    except Exception as e:
      error "Error removing community token", message = e.msg
      self.events.emit(SIGNAL_REMOVE_COMMUNITY_TOKEN_FAILED, Args())

  proc getCommunityTokenBySymbol*(self: Service, communityId: string, symbol: string): CommunityTokenDto =
    let communityTokens = self.getCommunityTokens(communityId)
    for token in communityTokens:
      if token.symbol == symbol:
        return token

  proc getCommunityToken*(self: Service, chainId: int, address: string): CommunityTokenDto =
    let communityTokens = self.getAllCommunityTokens()
    for token in communityTokens:
      if token.chainId == chainId and token.address == address:
        return token

  proc getCommunityTokenDescription*(self: Service, chainId: int, address: string): string =
    let communityTokens = self.getAllCommunityTokens()
    for token in communityTokens:
      if token.chainId == chainId and cmpIgnoreCase(token.address, address) == 0:
        return token.description
    return ""

  proc getCommunityTokenBurnState*(self: Service, chainId: int, contractAddress: string): ContractTransactionStatus =
    let burnTransactions = self.transactionService.getPendingTransactionsForType(PendingTransactionTypeDto.BurnCommunityToken)
    for transaction in burnTransactions:
      try:
        if transaction.chainId == chainId and transaction.to.toLower == contractAddress.toLower:
          return ContractTransactionStatus.InProgress
      except Exception:
        discard
    return ContractTransactionStatus.Completed

  proc getRemoteDestructedAddresses*(self: Service, chainId: int, contractAddress: string): seq[string] =
    try:
      let remoteDestructTransactions = self.transactionService.getPendingTransactionsForType(PendingTransactionTypeDto.RemoteDestructCollectible)
      for transaction in remoteDestructTransactions:
        if transaction.chainId == chainId and transaction.to == contractAddress:
          let burntAddresses = to(transaction.additionalData.parseJson(), seq[string])
          return burntAddresses
    except Exception:
      error "Error getting contract owner", message = getCurrentExceptionMsg()

  proc contractOwnerName*(self: Service, contractOwnerAddress: string): string =
    try:
      let res = self.walletAccountService.getAccountByAddress(contractOwnerAddress)
      if res == nil:
        error "getAccountByAddress result is nil"
        return ""
      return res.name
    except RpcException:
      error "Error getting contract owner name", message = getCurrentExceptionMsg()

  proc getRemainingSupply*(self: Service, chainId: int, contractAddress: string): Uint256 =
    let token = self.getCommunityToken(chainId, contractAddress)
    if token.deployState != DeployState.Deployed:
      return token.supply
    try:
      let response = tokens_backend.remainingSupply(chainId, contractAddress)
      return stint.parse(response.result.getStr(), Uint256)
    except RpcException:
      error "Error getting remaining supply", message = getCurrentExceptionMsg()
    # if there is an exception probably community token is not minted yet
    return token.supply

  proc getRemoteDestructedAmount*(self: Service, chainId: int, contractAddress: string): Uint256 =
    try:
      let token = self.getCommunityToken(chainId, contractAddress)
      let tokenType = token.tokenType
      let tokenState = token.deployState
      if tokenType != TokenType.ERC721 or tokenState != DeployState.Deployed:
        return stint.parse("0", Uint256)
      let response = tokens_backend.remoteDestructedAmount(chainId, contractAddress)
      return stint.parse(response.result.getStr(), Uint256)
    except RpcException:
      error "Error getting remote destructed amount", message = getCurrentExceptionMsg()

  proc computeAirdropFee*(self: Service, uuid: string, collectiblesAndAmounts: seq[CommunityTokenAndAmount], walletAddresses: seq[string], addressFrom: string) =
    let sendType = SendType.CommunityMintTokens
    try:
      if collectiblesAndAmounts.len == 0:
        raise newException(CatchableError, "no collectibles to airdrop")
      let chainId = collectiblesAndAmounts[0].communityToken.chainId
      let communityId = collectiblesAndAmounts[0].communityToken.communityId
      var transferDetails: seq[JsonNode]
      for collectibleAndAmount in collectiblesAndAmounts:
        let amountHex = "0x" & eth_utils.stripLeadingZeros(collectibleAndAmount.amount.toHex)
        transferDetails.add(%* {
          "tokenContractAddress": collectibleAndAmount.communityToken.address,
          "amount": amountHex,
        })
      self.transactionService.suggestedCommunityRoutes(
        uuid,
        sendType,
        chainId,
        addressFrom,
        communityId,
        signerPubKey = "",
        tokenIds = @[],
        walletAddresses,
        transferDetails
      )
    except Exception as e:
      error "Error loading deploy owner fees", msg = e.msg
      self.transactionService.emitSuggestedRoutesReadySignal(
        SuggestedRoutesArgs(
          uuid: uuid,
          sendType: sendType,
          errCode: $InternalErrorCode,
          errDescription: e.msg
        )
      )

  proc getFiatValue(self: Service, cryptoBalance: float, tokenKey: string): float =
    if (tokenKey == ""):
      return 0.0
    let price = self.tokenService.getPriceForToken(tokenKey)
    return cryptoBalance * price

  proc findContractByUniqueId*(self: Service, contractUniqueKey: string): CommunityTokenDto =
    let allTokens = self.getAllCommunityTokens()
    for token in allTokens:
      if common_utils.contractUniqueKey(token.chainId, token.address) == contractUniqueKey:
        return token
    raise newException(CatchableError, "Contract not found")

  proc computeDeployTokenFee*(self: Service, uuid: string, chainId: int, accountFrom: string, communityId: string, deploymentParams: DeploymentParameters) =
    var sendType = SendType.CommunityDeployAssets
    if deploymentParams.tokenType == TokenType.ERC721:
      sendType = SendType.CommunityDeployCollectibles
    try:
      self.transactionService.suggestedCommunityRoutes(
        uuid,
        sendType,
        chainId,
        accountFrom,
        communityId,
        signerPubKey = "",
        tokenIds = @[],
        walletAddresses = @[],
        transferDetails = @[],
        signature = "",
        ownerTokenParameters = JsonNode(),
        masterTokenParameters = JsonNode(),
        %deploymentParams
      )
    except Exception as e:
      error "Error loading deploy owner fees", msg = e.msg
      self.transactionService.emitSuggestedRoutesReadySignal(
        SuggestedRoutesArgs(
          uuid: uuid,
          sendType: sendType,
          errCode: $InternalErrorCode,
          errDescription: e.msg
        )
      )

  proc computeSetSignerFee*(self: Service, uuid: string, communityId: string, chainId: int, contractAddress: string, addressFrom: string) =
    let sendType = SendType.CommunitySetSignerPubKey
    try:
      var transferDetails: seq[JsonNode]
      transferDetails.add(%* {
        "tokenContractAddress": contractAddress,
      })

      self.transactionService.suggestedCommunityRoutes(
        uuid,
        sendType,
        chainId,
        addressFrom,
        communityId,
        signerPubKey = singletonInstance.userProfile.getPubKey(),
        tokenIds = @[],
        walletAddresses = @[],
        transferDetails
      )
    except Exception as e:
      error "Error loading burn fees", msg = e.msg
      self.transactionService.emitSuggestedRoutesReadySignal(
        SuggestedRoutesArgs(
          uuid: uuid,
          sendType: sendType,
          errCode: $InternalErrorCode,
          errDescription: e.msg
        )
      )

  proc computeDeployOwnerContractsFee*(self: Service, uuid: string, chainId: int, accountFrom: string, communityId: string,
    ownerDeploymentParams: DeploymentParameters, masterDeploymentParams: DeploymentParameters) =
    try:
      var signatureResult: JsonNode
      let err = tokens_backend.createCommunityTokenDeploymentSignature(signatureResult, chainId, accountFrom, communityId)
      if err.len > 0:
        raise newException(CatchableError, "createCommunityTokenDeploymentSignature failed " & err)
      let signature = signatureResult.getStr

      self.transactionService.suggestedCommunityRoutes(
        uuid,
        SendType.CommunityDeployOwnerToken,
        chainId,
        accountFrom,
        communityId,
        signerPubKey = singletonInstance.userProfile.getPubKey(),
        tokenIds = @[],
        walletAddresses = @[],
        transferDetails = @[],
        signature,
        %ownerDeploymentParams,
        %masterDeploymentParams
      )
    except Exception as e:
      error "Error loading deploy owner fees", msg = e.msg
      self.transactionService.emitSuggestedRoutesReadySignal(
        SuggestedRoutesArgs(
          uuid: uuid,
          sendType: SendType.CommunityDeployOwnerToken,
          errCode: $InternalErrorCode,
          errDescription: e.msg
        )
      )

  proc getOwnerBalances(self: Service, contractOwners: seq[CommunityCollectibleOwner], ownerAddress: string): seq[CollectibleBalance] =
    for owner in contractOwners:
      if owner.collectibleOwner.address == ownerAddress:
        return owner.collectibleOwner.balances

  proc collectTokensToBurn(self: Service, walletAndAmountList: seq[WalletAndAmount], contractOwners: seq[CommunityCollectibleOwner]): seq[UInt256] =
    if len(walletAndAmountList) == 0 or len(contractOwners) == 0:
      return
    for walletAndAmount in walletAndAmountList:
      let ownerBalances = self.getOwnerBalances(contractOwners, walletAndAmount.walletAddress)
      let amount = walletAndAmount.amount
      if amount > len(ownerBalances):
        error "amount to burn is higher than the number of tokens", amount=amount, balance=len(ownerBalances), owner=walletAndAmount.walletAddress
        return
      for i in 0..amount-1: # add the amount of tokens
        result.add(ownerBalances[i].tokenId)

  proc getTokensToBurn(self: Service, walletAndAmountList: seq[WalletAndAmount], contract: CommunityTokenDto): seq[Uint256] =
    if contract.address == "":
      raise newException(CatchableError, "contract address is empty")
    let tokenOwners = self.getCommunityTokenOwners(contract.communityId, contract.chainId, contract.address)
    let tokenIds = self.collectTokensToBurn(walletAndAmountList, tokenOwners)
    if len(tokenIds) == 0:
      raise newException(CatchableError, "cannot resolve token ids to burn")
    return tokenIds

  proc computeSelfDestructFee*(self: Service, uuid: string, walletAndAmountList: seq[WalletAndAmount], contractUniqueKey: string, addressFrom: string) =

    let sendType = SendType.CommunityRemoteBurn
    try:
      if walletAndAmountList.len == 0:
        raise newException(CatchableError, "no amounts to burn for addresses")
      let contract = self.findContractByUniqueId(contractUniqueKey)
      let tokenIds = self.getTokensToBurn(walletAndAmountList, contract)
      let tokensCount = len(tokenIds)
      if tokensCount == 0:
        raise newException(CatchableError, "token list is empty")

      let
        bigTokensCount = common_utils.stringToUint256($tokensCount)
        hexTokensCount = "0x" & eth_utils.stripLeadingZeros(bigTokensCount.toHex)

      var transferDetails: seq[JsonNode]
      transferDetails.add(%* {
        "tokenContractAddress": contract.address,
        "amount": hexTokensCount,
      })

      self.transactionService.suggestedCommunityRoutes(
        uuid,
        sendType,
        contract.chainId,
        addressFrom,
        contract.communityId,
        signerPubKey = "",
        tokenIds.map(x => "0x" & eth_utils.stripLeadingZeros(x.toHex)),
        walletAddresses = walletAndAmountList.map(x => x.walletAddress),
        transferDetails
      )
    except Exception as e:
      error "Error loading self destruct fees", msg = e.msg
      self.transactionService.emitSuggestedRoutesReadySignal(
        SuggestedRoutesArgs(
          uuid: uuid,
          sendType: sendType,
          errCode: $InternalErrorCode,
          errDescription: e.msg
        )
      )

  proc getErrorCodeFromMessage(self: Service, errorMessage: string): ComputeFeeErrorCode =
    var errorCode = ComputeFeeErrorCode.Other
    if errorMessage.contains("403 Forbidden") or errorMessage.contains("exceed"):
      errorCode = ComputeFeeErrorCode.Infura
    if errorMessage.contains("execution reverted"):
      errorCode = ComputeFeeErrorCode.Revert
    return errorCode

  proc computeBurnFee*(self: Service, uuid: string, contractUniqueKey: string, amount: string, addressFrom: string) =
    let sendType = SendType.CommunityBurn
    try:
      let contract = self.findContractByUniqueId(contractUniqueKey)

      let
        bigAmount = common_utils.stringToUint256(amount)
        hexAmount = "0x" & eth_utils.stripLeadingZeros(bigAmount.toHex)

      var transferDetails: seq[JsonNode]
      transferDetails.add(%* {
        "tokenContractAddress": contract.address,
        "amount": hexAmount,
      })

      self.transactionService.suggestedCommunityRoutes(
        uuid,
        sendType,
        contract.chainId,
        addressFrom,
        contract.communityId,
        signerPubKey = "",
        tokenIds = @[],
        walletAddresses = @[],
        transferDetails
      )
    except Exception as e:
      error "Error loading burn fees", msg = e.msg
      self.transactionService.emitSuggestedRoutesReadySignal(
        SuggestedRoutesArgs(
          uuid: uuid,
          sendType: sendType,
          errCode: $InternalErrorCode,
          errDescription: e.msg
        )
      )

  # convert json returned from async task into gas table
  proc toGasTable(json: JsonNode): Table[ContractTuple, int] =
    try:
      if json.kind != JArray:
        return
      for i in json:
        result[i["key"].toContractTuple] = i["value"].getInt
    except Exception:
      error "Error converting to gas table", message = getCurrentExceptionMsg()

  # convert json returned from async task into fee table
  proc toFeeTable(json: JsonNode): Table[int, SuggestedFeesDto] =
    try:
      if json.kind != JArray:
        return
      for i in json:
        result[i["key"].getInt] = decodeSuggestedFeesDto(i["value"])
    except Exception:
      error "Error converting to fee table", message = getCurrentExceptionMsg()

  proc isTokenDeployed(self: Service, token: CommunityTokenDto): bool =
    return token.deployState == DeployState.Deployed

  proc fetchCommunityOwners(self: Service,  communityToken: CommunityTokenDto) =
    if not self.isTokenDeployed(communityToken):
      return

    if communityToken.tokenType == TokenType.ERC20:
      let arg = FetchAssetOwnersArg(
        tptr: fetchAssetOwnersTaskArg,
        vptr: cast[uint](self.vptr),
        slot: "onCommunityTokenOwnersFetched",
        chainId: communityToken.chainId,
        contractAddress: communityToken.address,
        communityId: communityToken.communityId
      )
      self.threadpool.start(arg)
      return
    elif communityToken.tokenType == TokenType.ERC721:
      let arg = FetchCollectibleOwnersArg(
        tptr: fetchCollectibleOwnersTaskArg,
        vptr: cast[uint](self.vptr),
        slot: "onCommunityTokenOwnersFetched",
        chainId: communityToken.chainId,
        contractAddress: communityToken.address,
        communityId: communityToken.communityId
      )
      self.threadpool.start(arg)
      return
    else:
      debug "Unable to fetch token hodlers for token type ", token=communityToken.tokenType

  proc onCommunityTokenOwnersFetched*(self:Service, response: string) {.slot.} =
    let responseJson = response.parseJson()
    let chainId = responseJson{"chainId"}.getInt
    let contractAddress = responseJson{"contractAddress"}.getStr
    let communityId = responseJson{"communityId"}.getStr

    try:
      if responseJson{"error"}.kind != JNull and responseJson{"error"}.getStr != "":
        raise newException(ValueError, responseJson["error"].getStr)

      let communityTokenOwners = toCommunityCollectibleOwners(responseJson{"result"})
      self.tokenOwnersCache[(chainId, contractAddress)] = communityTokenOwners
      let data = CommunityTokenOwnersArgs(chainId: chainId, contractAddress: contractAddress, communityId: communityId, owners: communityTokenOwners)
      self.events.emit(SIGNAL_COMMUNITY_TOKEN_OWNERS_FETCHED, data)
    except Exception as e:
      error "Can't fetch community token owners", chainId=responseJson{"chainId"}, contractAddress=responseJson{"contractAddress"}, errorMsg=e.msg

      let data = CommunityTokenOwnersArgs(
        chainId: chainId,
        contractAddress: contractAddress,
        communityId: communityId,
        error: e.msg,
      )
      self.events.emit(SIGNAL_COMMUNITY_TOKEN_OWNERS_LOADING_FAILED, data)

    # restart token holders timer
    self.restartTokenHoldersTimer(chainId, contractAddress)

  # get owners from cache
  proc getCommunityTokenOwners*(self: Service, communityId: string, chainId: int, contractAddress: string): seq[CommunityCollectibleOwner] =
    return self.tokenOwnersCache.getOrDefault((chainId: chainId, address: contractAddress))

  proc iAmCommunityPrivilegedUser(self:Service, communityId: string): bool =
    let community = self.communityService.getCommunityById(communityId)
    return community.isPrivilegedUser()

  proc getOwnerToken*(self: Service, communityId: string): CommunityTokenDto =
    let communityTokens = self.getCommunityTokens(communityId)
    for token in communityTokens:
      if token.privilegesLevel == PrivilegesLevel.Owner:
        return token

  proc getTokenMasterToken*(self: Service, communityId: string): CommunityTokenDto =
    let communityTokens = self.getCommunityTokens(communityId)
    for token in communityTokens:
      if token.privilegesLevel == PrivilegesLevel.Master:
        return token

  proc declineOwnership*(self: Service, communityId: string) =
    let notification = self.acService.getNotificationForTypeAndCommunityId(notification.ActivityCenterNotificationType.OwnerTokenReceived, communityId)
    if notification != nil:
      discard self.acService.deleteActivityCenterNotifications(@[notification.id])
    try:
      let response = tokens_backend.registerSetSignerDeclinedNotification(communityId)
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
    except Exception as e:
      error "Error registering decline set signer notification", msg=e.msg
    let finaliseStatusArgs = FinaliseOwnershipStatusArgs(isPending: false, communityId: communityId)
    self.events.emit(SIGNAL_FINALISE_OWNERSHIP_STATUS, finaliseStatusArgs)

  proc asyncGetOwnerTokenOwnerAddress*(self: Service, chainId: int, contractAddress: string) =
    let arg = GetOwnerTokenOwnerAddressArgs(
      tptr: getOwnerTokenOwnerAddressTask,
      vptr: cast[uint](self.vptr),
      slot: "onGetOwnerTokenOwner",
      chainId: chainId,
      contractAddress: contractAddress
    )
    self.threadpool.start(arg)

  proc onGetOwnerTokenOwner*(self:Service, response: string) {.slot.} =
    var ownerTokenArgs = OwnerTokenOwnerAddressArgs()
    try:
      let responseJson = response.parseJson()
      ownerTokenArgs.chainId = responseJson{"chainId"}.getInt
      ownerTokenArgs.contractAddress = responseJson{"contractAddress"}.getStr
      let errorMsg = responseJson["error"].getStr
      if errorMsg != "":
        error "can't get owner token owner address", errorMsg
      else:
        ownerTokenArgs.address = responseJson{"address"}.getStr
        let acc = self.walletAccountService.getAccountByAddress(ownerTokenArgs.address)
        if acc == nil:
          error "getAccountByAddress result is nil"
        else:
          ownerTokenArgs.addressName = acc.name
    except Exception:
      error "can't get owner token owner address", message = getCurrentExceptionMsg()
    self.events.emit(SIGNAL_OWNER_TOKEN_OWNER_ADDRESS, ownerTokenArgs)

  proc refreshCommunityToken*(self: Service, chainId: int, contractAddress: string) =
    try:
      discard tokens_backend.reTrackOwnerTokenDeploymentTransaction(chainId, contractAddress)
    except Exception:
      error "can't retrack token transaction", message = getCurrentExceptionMsg()

  # ran also when holders are fetched
  proc restartTokenHoldersTimer(self: Service, chainId: int, contractAddress: string) =
    if not self.tokenHoldersManagementStarted:
      return
    self.tokenHoldersTimer.stop()

    let tokenTupleKey = (chainId: chainId, address: contractAddress)
    var nextTimerShotInSeconds = int64(0)
    if self.tokenHoldersLastUpdateMap.hasKey(tokenTupleKey):
      let lastUpdateTime = self.tokenHoldersLastUpdateMap[tokenTupleKey]
      const intervalInSecs = int64(5*60)
      let nowInSeconds = now().toTime().toUnix()
      nextTimerShotInSeconds = intervalInSecs - (nowInSeconds - lastUpdateTime)
      if nextTimerShotInSeconds < 0:
        nextTimerShotInSeconds = 0

    self.tokenHoldersTimer.setInterval(int(nextTimerShotInSeconds * 1000))
    self.tokenHoldersTimer.start()

  # executed when Token page with holders is opened
  proc startTokenHoldersManagement*(self: Service, chainId: int, contractAddress: string) =
    let communityToken = self.getCommunityToken(chainId, contractAddress)
    if not self.iAmCommunityPrivilegedUser(communityToken.communityId):
      warn "can't get token holders - not privileged user"
      return

    self.tokenHoldersToken = communityToken
    self.tokenHoldersManagementStarted = true
    self.restartTokenHoldersTimer(chainId, contractAddress)

  # executed when Token page with holders is closed
  proc stopTokenHoldersManagement*(self: Service) =
    self.tokenHoldersManagementStarted = false
    self.tokenHoldersTimer.stop()

  proc onTokenHoldersTimeout(self: Service) {.slot.} =
    # update last fetch time
    let tokenTupleKey = (chainId: self.tokenHoldersToken.chainId, address: self.tokenHoldersToken.address)
    let nowInSeconds = now().toTime().toUnix()
    self.tokenHoldersLastUpdateMap[tokenTupleKey] = nowInSeconds
    # run async calls to fetch holders
    self.fetchCommunityOwners(self.tokenHoldersToken)

  # executed when there was some change and holders needs to be fetched again
  proc refreshTokenHolders(self: Service, token: CommunityTokenDto) =
    let tokenTupleKey = (chainId: token.chainId, address: token.address)
    self.tokenHoldersLastUpdateMap.del(tokenTupleKey)
    if not self.tokenHoldersManagementStarted:
      # not need to get holders now
      return
    let holdersTokenTuple = (chainId: self.tokenHoldersToken.chainId, address: self.tokenHoldersToken.address)
    if (tokenTupleKey != holdersTokenTuple):
      # different token is opened now
      return
    self.restartTokenHoldersTimer(token.chainId, token.address)

  proc stopSuggestedRoutesAsyncCalculation*(self: Service) =
    self.transactionService.stopSuggestedRoutesAsyncCalculation()

  proc buildTransactionsFromRoute*(self: Service, uuid: string): string =
    return self.transactionService.buildTransactionsFromRoute(uuid)

  proc sendRouterTransactionsWithSignatures*(self: Service, uuid: string, signatures: TransactionsSignatures): string =
    return self.transactionService.sendRouterTransactionsWithSignatures(uuid, signatures)

  proc signMessage*(self: Service, address: string, hashedPassword: string, hashedMessage: string): tuple[res: string, err: string] =
    return self.transactionService.signMessage(address, hashedPassword, hashedMessage)