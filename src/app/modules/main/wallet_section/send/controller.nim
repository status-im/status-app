import tables
import uuids, chronicles
import io_interface
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service
import app_service/service/transaction/service as transaction_service
import app_service/service/currency/service as currency_service
import app_service/service/currency/dto as currency_dto
import app_service/service/keycard/service as keycard_service
import app_service/service/network/network_item

import app/modules/shared/wallet_utils
import app/modules/shared_models/currency_amount

import app/core/eventemitter

logScope:
  topics = "wallet-send-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    walletAccountService: wallet_account_service.Service
    networkService: network_service.Service
    currencyService: currency_service.Service
    transactionService: transaction_service.Service
    keycardService: keycard_service.Service
    tokenService: token_service.Service
    connectionKeycardResponse: UUID

proc newController*(
  delegate: io_interface.AccessInterface,
  events: EventEmitter,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  currencyService: currency_service.Service,
  transactionService: transaction_service.Service,
  keycardService: keycard_service.Service
): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.tokenService = tokenService
  result.walletAccountService = walletAccountService
  result.networkService = networkService
  result.currencyService = currencyService
  result.transactionService = transactionService
  result.keycardService = keycardService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_TRANSACTION_SENT) do(e:Args):
    let args = TransactionArgs(e)
    var
      txHash = ""
      isApprovalTx = false
    if not args.sentTransaction.isNil:
      txHash = args.sentTransaction.hash
      isApprovalTx = args.sentTransaction.approvalTx
    self.delegate.transactionWasSent(
      args.sendDetails.uuid,
      args.sendDetails.fromChain,
      isApprovalTx,
      txHash,
      if not args.sendDetails.errorResponse.isNil: args.sendDetails.errorResponse.details else: ""
    )



  self.events.on(SIGNAL_SUGGESTED_ROUTES_READY) do(e:Args):
    let args = SuggestedRoutesArgs(e)
    if args.sendType == SendType.CommunityBurn or
      args.sendType == SendType.CommunityDeployAssets or
      args.sendType == SendType.CommunityDeployCollectibles or
      args.sendType == SendType.CommunityDeployOwnerToken or
      args.sendType == SendType.CommunityMintTokens or
      args.sendType == SendType.CommunityRemoteBurn or
      args.sendType == SendType.CommunitySetSignerPubKey:
        return
    self.delegate.suggestedRoutesReady(args.uuid, args.suggestedRoutes, args.errCode, args.errDescription)

  self.events.on(SIGNAL_SIGN_ROUTER_TRANSACTIONS) do(e:Args):
    var data = RouterTransactionsForSigningArgs(e)
    self.delegate.prepareSignaturesForTransactions(data.data)

  self.events.on(SIGNAL_TRANSACTION_STATUS_CHANGED) do(e:Args):
    let args = TransactionArgs(e)
    self.delegate.transactionSendingComplete(args.sentTransaction.hash, args.status)

proc getTokensByGroupKey*(self: Controller, groupKey: string): seq[token_service.TokenItem] =
  return self.tokenService.getTokensByGroupKey(groupKey)

proc getTokenByGroupKeyAndChainId*(self: Controller, groupKey: string, chainId: int): token_service.TokenItem =
  return self.tokenService.getTokenByGroupKeyAndChainId(groupKey, chainId)

proc getWalletAccounts*(self: Controller): seq[wallet_account_service.WalletAccountDto] =
  return self.walletAccountService.getWalletAccounts()

proc getChainIds*(self: Controller): seq[int] =
  return self.networkService.getCurrentNetworksChainIds()

proc getCurrentCurrency*(self: Controller): string =
  return self.walletAccountService.getCurrency()

proc getCurrencyFormat*(self: Controller, key: string): CurrencyFormatDto =
  return self.currencyService.getCurrencyFormat(key)

proc getKeycardsWithSameKeyUid*(self: Controller, keyUid: string): seq[KeycardDto] =
  # TODO: re-implement when integrating new keycard approach
  return @[]

proc getAccountByAddress*(self: Controller, address: string): WalletAccountDto =
  return self.walletAccountService.getAccountByAddress(address)

proc getWalletAccountByIndex*(self: Controller, accountIndex: int): WalletAccountDto =
  return self.walletAccountService.getWalletAccount(accountIndex)

proc getTokenBalance*(self: Controller, walletAccount: string, tokenKey: string): CurrencyAmount =
  return currencyAmountToItem(self.walletAccountService.getTokenBalance(walletAccount, tokenKey), self.walletAccountService.getCurrencyFormat(tokenKey))

proc authenticate*(self: Controller, keyUid = "") =
  discard

proc suggestedRoutes*(self: Controller,
    uuid: string,
    sendType: SendType,
    accountFrom: string,
    accountTo: string,
    token: string,
    tokenIsOwnerToken: bool,
    amountIn: string,
    toToken: string = "",
    amountOut: string = "",
    fromChainID: int = 0,
    toChainID: int = 0,
    slippagePercentage: float = 0.0,
    extraParamsTable: Table[string, string] = initTable[string, string]()) =
  self.transactionService.suggestedRoutes(uuid, sendType, accountFrom, accountTo, token, tokenIsOwnerToken, amountIn, toToken, amountOut,
    fromChainID, toChainID, slippagePercentage, extraParamsTable)

proc stopSuggestedRoutesAsyncCalculation*(self: Controller) =
  self.transactionService.stopSuggestedRoutesAsyncCalculation()

proc buildTransactionsFromRoute*(self: Controller, uuid: string): string =
  return self.transactionService.buildTransactionsFromRoute(uuid)

proc signMessage*(self: Controller, address: string, hashedPassword: string, hashedMessage: string): tuple[res: string, err: string] =
  return self.transactionService.signMessage(address, hashedPassword, hashedMessage)

proc sendRouterTransactionsWithSignatures*(self: Controller, uuid: string, signatures: TransactionsSignatures): string =
  return self.transactionService.sendRouterTransactionsWithSignatures(uuid, signatures)

proc areTestNetworksEnabled*(self: Controller): bool =
  return self.walletAccountService.areTestNetworksEnabled()

proc getCurrentNetworks*(self: Controller): seq[NetworkItem] =
  return self.networkService.getCurrentNetworks()

proc getKeypairByAccountAddress*(self: Controller, address: string): KeypairDto =
  return self.walletAccountService.getKeypairByAccountAddress(address)

proc disconnectKeycardReponseSignal(self: Controller) =
  self.events.disconnect(self.connectionKeycardResponse)

proc connectKeycardReponseSignal(self: Controller) =
  self.connectionKeycardResponse = self.events.onWithUUID(SIGNAL_KEYCARD_RESPONSE) do(e: Args):
    let args = KeycardLibArgs(e)
    self.disconnectKeycardReponseSignal()
    let currentFlow = self.keycardService.getCurrentFlow()
    if currentFlow != KCSFlowType.Sign:
      error "trying to use keycard in the other than the signing a transaction flow"
      self.delegate.transactionWasSent(uuid = "", chainId = 0, approvalTx = false, txHash = "", error = "trying to use keycard in the other than the signing a transaction flow")
      return
    self.delegate.onTransactionSigned(args.flowType, args.flowEvent)

proc cancelCurrentFlow*(self: Controller) =
  self.keycardService.cancelCurrentFlow()

proc runSignFlow*(self: Controller, pin, bip44Path, txHash: string) =
  self.cancelCurrentFlow()
  self.connectKeycardReponseSignal()
  self.keycardService.startSignFlow(bip44Path, txHash, pin)

proc getChainsWithNoGasFromError*(self: Controller, errCode: string, errDescription: string): Table[int, string] =
  return self.walletAccountService.getChainsWithNoGasFromError(errCode, errDescription)

proc reevaluateRouterPath*(self: Controller, uuid: string, pathName: string, chainId: int, isApprovalTx: bool): string =
  return self.transactionService.reevaluateRouterPath(uuid, pathName, chainId, isApprovalTx)
