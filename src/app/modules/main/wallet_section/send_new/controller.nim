import tables
import uuids, chronicles

import io_interface

import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service
import app_service/service/transaction/service as transaction_service
import app_service/service/keycard/service as keycard_service
import app_service/service/network/network_item

import app/core/eventemitter

logScope:
  topics = "wallet-send-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    walletAccountService: wallet_account_service.Service
    networkService: network_service.Service
    transactionService: transaction_service.Service
    keycardService: keycard_service.Service
    connectionKeycardResponse: UUID

proc newController*(
  delegate: io_interface.AccessInterface,
  events: EventEmitter,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  transactionService: transaction_service.Service,
  keycardService: keycard_service.Service
): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.walletAccountService = walletAccountService
  result.networkService = networkService
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
    self.delegate.suggestedRoutesReady(args.uuid, args.routes, args.errCode, args.errDescription)

  self.events.on(SIGNAL_SIGN_ROUTER_TRANSACTIONS) do(e:Args):
    var data = RouterTransactionsForSigningArgs(e)
    self.delegate.prepareSignaturesForTransactions(data.data)

  self.events.on(SIGNAL_TRANSACTION_STATUS_CHANGED) do(e:Args):
    let args = TransactionArgs(e)
    self.delegate.transactionSendingComplete(args.sentTransaction.hash, args.status)

proc authenticate*(self: Controller, keyUid = "") =
  discard

proc suggestedRoutes*(self: Controller,
    uuid: string,
    sendType: SendType,
    accountFrom: string,
    accountTo: string,
    tokenGroupKey: string,
    tokenIsOwnerToken: bool,
    amountIn: string,
    toTokenGroupKey: string = "",
    amountOut: string = "",
    fromChainID: int = 0,
    toChainID: int = 0,
    slippagePercentage: float = 0.0,
    extraParamsTable: Table[string, string] = initTable[string, string]()) =
  self.transactionService.suggestedRoutes(uuid, sendType, accountFrom, accountTo, tokenGroupKey, tokenIsOwnerToken, amountIn,
    toTokenGroupKey, amountOut, fromChainID, toChainID, slippagePercentage, extraParamsTable)

proc stopSuggestedRoutesAsyncCalculation*(self: Controller) =
  self.transactionService.stopSuggestedRoutesAsyncCalculation()

proc setFeeMode*(self: Controller, feeMode: int, routerInputParamsUuid: string, pathName: string, chainId: int,
  isApprovalTx: bool, communityId: string): string =
    return self.transactionService.setFeeMode(feeMode, routerInputParamsUuid, pathName, chainId, isApprovalTx, communityId)

proc setCustomTxDetails*(self: Controller, nonce: int, gasAmount: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string,
  routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool, communityId: string): string =
    return self.transactionService.setCustomTxDetails(nonce, gasAmount, gasPrice, maxFeesPerGas, priorityFee, routerInputParamsUuid,
    pathName, chainId, isApprovalTx, communityId)

proc getEstimatedTime*(self: Controller, chainId: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string): int =
    self.transactionService.getEstimatedTimeV2(chainId, gasPrice, maxFeesPerGas, priorityFee)

proc getCurrentNetworks*(self: Controller): seq[NetworkItem] =
  return self.networkService.getCurrentNetworks()

proc buildTransactionsFromRoute*(self: Controller, uuid: string): string =
  return self.transactionService.buildTransactionsFromRoute(uuid)

proc signMessage*(self: Controller, address: string, hashedPassword: string, hashedMessage: string): tuple[res: string, err: string] =
  return self.transactionService.signMessage(address, hashedPassword, hashedMessage)

proc sendRouterTransactionsWithSignatures*(self: Controller, uuid: string, signatures: TransactionsSignatures): string =
  return self.transactionService.sendRouterTransactionsWithSignatures(uuid, signatures)

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
