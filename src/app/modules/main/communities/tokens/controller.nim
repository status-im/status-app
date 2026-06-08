import uuids, chronicles
import ./io_interface as community_tokens_module_interface

import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/transaction/service as transaction_service
import app_service/service/network/service as networks_service
import app_service/service/community/service as community_service
import app_service/service/keycard/service as keycard_service
import app_service/service/network/network_item
import app/core/signals/types
import app/core/eventemitter

type
  Controller* = ref object of RootObj
    delegate: community_tokens_module_interface.AccessInterface
    events: EventEmitter
    walletAccountService: wallet_account_service.Service
    communityTokensService: community_tokens_service.Service
    transactionService: transaction_service.Service
    networksService: networks_service.Service
    communityService: community_service.Service
    keycardService: keycard_service.Service
    connectionKeycardResponse: UUID

proc newCommunityTokensController*(
    delegate: community_tokens_module_interface.AccessInterface,
    events: EventEmitter,
    walletAccountService: wallet_account_service.Service,
    communityTokensService: community_tokens_service.Service,
    transactionService: transaction_service.Service,
    networksService: networks_service.Service,
    communityService: community_service.Service,
    keycardService: keycard_service.Service
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.walletAccountService = walletAccountService
  result.communityTokensService = communityTokensService
  result.transactionService = transactionService
  result.networksService = networksService
  result.communityService = communityService
  result.keycardService = keycardService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_OWNER_TOKEN_RECEIVED) do(e: Args):
    let args = OwnerTokenReceivedArgs(e)
    self.delegate.onOwnerTokenReceived(args.communityId, args.communityName, args.chainId, args.contractAddress)
  self.events.on(SIGNAL_COMMUNITY_TOKEN_RECEIVED) do(e: Args):
    let args = CommunityTokenReceivedArgs(e)
    if args.isWatchOnlyAccount:
      return
    self.delegate.onCommunityTokenReceived(args.name, args.symbol, args.image, args.communityId, args.communityName, $args.amount, args.chainId, args.txHash, args.isFirst, args.tokenType, args.accountName, args.accountAddress)
  self.events.on(SIGNAL_COMMUNITY_LOST_OWNERSHIP) do(e: Args):
    let args = CommunityIdArgs(e)
    self.delegate.onLostOwnership(args.communityId)
  self.events.on(SIGNAL_OWNER_TOKEN_OWNER_ADDRESS) do(e: Args):
    let args = OwnerTokenOwnerAddressArgs(e)
    self.delegate.onOwnerTokenOwnerAddress(args.chainId, args.contractAddress, args.address, args.addressName)
  self.events.on(SIGNAL_COMMUNITY_TOKENS_CHANGED) do(e:Args):
    self.communityTokensService.getAllCommunityTokensAsync()
  self.events.on(SIGNAL_SUGGESTED_ROUTES_READY) do(e:Args):
    let args = SuggestedRoutesArgs(e)
    self.delegate.suggestedRoutesReady(args.uuid, args.sendType, args.totalCostNativeCryptoCurrency, args.totalCostFiatCurrency,
      args.costPerPath, args.errCode, args.errDescription)
  self.events.on(SIGNAL_SIGN_ROUTER_TRANSACTIONS) do(e:Args):
    let args = RouterTransactionsForSigningArgs(e)
    self.delegate.prepareSignaturesForTransactions(args.data)
  self.events.on(SIGNAL_TRANSACTION_SENT) do(e:Args):
    let args = TransactionArgs(e)
    var
      txHash = ""
      isApprovalTx = false
      toAddress = ""
    if not args.sentTransaction.isNil:
      txHash = args.sentTransaction.hash
      isApprovalTx = args.sentTransaction.approvalTx
      toAddress = args.sentTransaction.toAddress
    self.delegate.onTransactionSent(
      args.sendDetails.uuid,
      SendType(args.sendDetails.sendType),
      args.sendDetails.fromChain,
      isApprovalTx,
      txHash,
      toAddress,
      if not args.sendDetails.errorResponse.isNil: args.sendDetails.errorResponse.details else: ""
    )

proc storeDeployedContract*(self: Controller, sendType: SendType, addressFrom: string, addressTo: string, chainId: int,
  txHash: string, deploymentParams: DeploymentParameters) =
  self.communityTokensService.storeDeployedContract(sendType, addressFrom, addressTo, chainId, txHash, deploymentParams)

proc storeDeployedOwnerContract*(self: Controller, addressFrom: string, chainId: int, txHash: string,
  ownerDeploymentParams: DeploymentParameters, masterDeploymentParams: DeploymentParameters) =
  self.communityTokensService.storeDeployedOwnerContract(addressFrom, chainId, txHash, ownerDeploymentParams, masterDeploymentParams)

proc removeCommunityToken*(self: Controller, communityId: string, chainId: int, address: string) =
  self.communityTokensService.removeCommunityToken(communityId, chainId, address)

proc refreshCommunityToken*(self: Controller, chainId: int, address: string) =
  self.communityTokensService.refreshCommunityToken(chainId, address)

proc computeAirdropFee*(self: Controller, uuid: string, tokensAndAmounts: seq[CommunityTokenAndAmount], walletAddresses: seq[string], addressFrom: string) =
  self.communityTokensService.computeAirdropFee(uuid, tokensAndAmounts, walletAddresses, addressFrom)

proc authenticate*(self: Controller, keyUid = "") =
  discard

proc getCommunityTokens*(self: Controller, communityId: string): seq[CommunityTokenDto] =
  return self.communityTokensService.getCommunityTokens(communityId)

proc computeDeployTokenFee*(self: Controller, uuid: string, chainId: int, accountAddress: string, communityId: string, deploymentParams: DeploymentParameters) =
  self.communityTokensService.computeDeployTokenFee(uuid, chainId, accountAddress, communityId, deploymentParams)

proc computeSetSignerFee*(self: Controller, uuid: string, communityId: string, chainId: int, contractAddress: string, addressFrom: string) =
  self.communityTokensService.computeSetSignerFee(uuid, communityId, chainId, contractAddress, addressFrom)

proc computeDeployOwnerContractsFee*(self: Controller, uuid: string, chainId: int, accountAddress: string, communityId: string,
ownerDeploymentParams: DeploymentParameters, masterDeploymentParams: DeploymentParameters) =
  self.communityTokensService.computeDeployOwnerContractsFee(uuid, chainId, accountAddress, communityId, ownerDeploymentParams, masterDeploymentParams)

proc computeSelfDestructFee*(self: Controller, uuid: string, walletAndAmountList: seq[WalletAndAmount], contractUniqueKey: string, addressFrom: string) =
  self.communityTokensService.computeSelfDestructFee(uuid, walletAndAmountList, contractUniqueKey, addressFrom)

proc findContractByUniqueId*(self: Controller, contractUniqueKey: string): CommunityTokenDto =
  return self.communityTokensService.findContractByUniqueId(contractUniqueKey)

proc computeBurnFee*(self: Controller, uuid: string, contractUniqueKey: string, amount: string, addressFrom: string) =
  self.communityTokensService.computeBurnFee(uuid, contractUniqueKey, amount, addressFrom)

proc getNetworkByChainId*(self:Controller, chainId: int): NetworkItem =
  self.networksService.getNetworkByChainId(chainId)

proc getOwnerToken*(self: Controller, communityId: string): CommunityTokenDto =
  return self.communityTokensService.getOwnerToken(communityId)

proc getTokenMasterToken*(self: Controller, communityId: string): CommunityTokenDto =
  return self.communityTokensService.getTokenMasterToken(communityId)

proc getCommunityById*(self: Controller, communityId: string): lent CommunityDto =
  return self.communityService.getCommunityById(communityId)

proc declineOwnership*(self: Controller, communityId: string) =
  self.communityTokensService.declineOwnership(communityId)

proc asyncGetOwnerTokenOwnerAddress*(self: Controller, chainId: int, contractAddress: string) =
  self.communityTokensService.asyncGetOwnerTokenOwnerAddress(chainId, contractAddress)

proc stopSuggestedRoutesAsyncCalculation*(self: Controller) =
  self.communityTokensService.stopSuggestedRoutesAsyncCalculation()

proc getKeypairByAccountAddress*(self: Controller, address: string): KeypairDto =
  return self.walletAccountService.getKeypairByAccountAddress(address)

proc buildTransactionsFromRoute*(self: Controller, uuid: string): string =
  return self.communityTokensService.buildTransactionsFromRoute(uuid)

proc sendRouterTransactionsWithSignatures*(self: Controller, uuid: string, signatures: TransactionsSignatures): string =
  return self.communityTokensService.sendRouterTransactionsWithSignatures(uuid, signatures)

proc signMessage*(self: Controller, address: string, hashedPassword: string, hashedMessage: string): tuple[res: string, err: string] =
  return self.communityTokensService.signMessage(address, hashedPassword, hashedMessage)

proc disconnectKeycardReponseSignal(self: Controller) =
  self.events.disconnect(self.connectionKeycardResponse)

proc connectKeycardReponseSignal(self: Controller) =
  self.connectionKeycardResponse = self.events.onWithUUID(SIGNAL_KEYCARD_RESPONSE) do(e: Args):
    let args = KeycardLibArgs(e)
    self.disconnectKeycardReponseSignal()
    let currentFlow = self.keycardService.getCurrentFlow()
    if currentFlow != KCSFlowType.Sign:
      error "trying to use keycard in other than the signing a community related transaction flow"
      #TODO: notifify about error
      # self.delegate.transactionWasSent(uuid = "", chainId = 0, approvalTx = false, txHash = "", error = "trying to use keycard in the other than the signing a transaction flow")
      return
    self.delegate.onTransactionSigned(args.flowType, args.flowEvent)

proc cancelCurrentFlow*(self: Controller) =
  self.keycardService.cancelCurrentFlow()

proc runSignFlow*(self: Controller, pin, bip44Path, txHash: string) =
  self.cancelCurrentFlow()
  self.connectKeycardReponseSignal()
  self.keycardService.startSignFlow(bip44Path, txHash, pin)