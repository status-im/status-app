import tables, nimqml, sequtils, sugar, chronicles, stint

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface

import app/global/global_singleton
import app/core/eventemitter
import app/core/notifications/notifications_manager

import app_service/common/utils
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service
import app_service/service/transaction/service as transaction_service
import app_service/service/transaction/dto
import app_service/service/transaction/dtoV2

export io_interface

logScope:
  topics = "wallet-send-module"

const authenticationCanceled* = "authenticationCanceled"

# Shouldn't be public ever, use only within this module.
type TmpSendTransactionDetails = object
  uuid: string
  keyUid: string
  fromAddr: string
  fromAddrPath: string
  txHashBeingProcessed: string
  resolvedSignatures: TransactionsSignatures

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: controller.Controller
    moduleLoaded: bool
    tmpSendTransactionDetails: TmpSendTransactionDetails
    tmpClearLocalDataLater: bool

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  transactionService: transaction_service.Service
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.controller = controller.newController(result, events, walletAccountService,
    networkService, transactionService)
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)

  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete
  self.controller.delete

proc clearTmpData(self: Module, keepUuid = false) =
  if keepUuid:
    self.tmpSendTransactionDetails = TmpSendTransactionDetails(
      uuid: self.tmpSendTransactionDetails.uuid
    )
    return
  self.tmpSendTransactionDetails = TmpSendTransactionDetails()

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionSendNew", self.viewVariant)

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.sendModuleDidLoad()

proc convertTransactionPathDtoV2ToPathItem(self: Module, txPath: TransactionPathDtoV2): PathItem =
  var fromChainId = 0
  var toChainid = 0
  var fromTokenSymbol = ""
  var toTokenSymbol = ""
  if txPath.fromChain.chainId > 0:
    fromChainId = txPath.fromChain.chainId
  if txPath.toChain.chainId > 0:
    toChainId = txPath.toChain.chainId
  # if not txPath.fromToken.isNil:
    # fromTokenSymbol = txPath.fromToken.bySymbolModelKey()
  # if not txPath.toToken.isNil:
  #   toTokenSymbol = txPath.toToken.bySymbolModelKey()

  result = newPathItem(
    processorName = txPath.processorName,
    fromChain = fromChainId,
    fromChainEIP1559Compliant = txPath.fromChain.eip1559Enabled,
    fromChainNoBaseFee = txPath.fromChain.noBaseFee,
    fromChainNoPriorityFee = txPath.fromChain.noPriorityFee,
    toChain = toChainId,
    fromToken = fromTokenSymbol,
    toToken = toTokenSymbol,
    amountIn = $txPath.amountIn,
    amountInLocked = txPath.amountInLocked,
    amountOut = $txPath.amountOut,
    suggestedNonEIP1559GasPrice = $txPath.suggestedNonEIP1559Fees.gasPrice,
    suggestedNonEIP1559EstimatedTime = txPath.suggestedNonEIP1559Fees.estimatedTime,
    suggestedMaxFeesPerGasLowLevel = $txPath.suggestedLevelsForMaxFeesPerGas.low,
    suggestedPriorityFeePerGasLowLevel = $txPath.suggestedLevelsForMaxFeesPerGas.lowPriority,
    suggestedEstimatedTimeLowLevel = txPath.suggestedLevelsForMaxFeesPerGas.lowEstimatedTime,
    suggestedMaxFeesPerGasMediumLevel = $txPath.suggestedLevelsForMaxFeesPerGas.medium,
    suggestedPriorityFeePerGasMediumLevel = $txPath.suggestedLevelsForMaxFeesPerGas.mediumPriority,
    suggestedEstimatedTimeMediumLevel = txPath.suggestedLevelsForMaxFeesPerGas.mediumEstimatedTime,
    suggestedMaxFeesPerGasHighLevel = $txPath.suggestedLevelsForMaxFeesPerGas.high,
    suggestedPriorityFeePerGasHighLevel = $txPath.suggestedLevelsForMaxFeesPerGas.highPriority,
    suggestedEstimatedTimeHighLevel = txPath.suggestedLevelsForMaxFeesPerGas.highEstimatedTime,
    suggestedMinPriorityFee = $txPath.suggestedMinPriorityFee,
    suggestedMaxPriorityFee = $txPath.suggestedMaxPriorityFee,
    currentBaseFee = $txPath.currentBaseFee,
    suggestedTxNonce = $txPath.suggestedTxNonce,
    suggestedTxGasAmount = $txPath.suggestedTxGasAmount,
    suggestedApprovalTxNonce = $txPath.suggestedApprovalTxNonce,
    suggestedApprovalGasAmount = $txPath.suggestedApprovalGasAmount,
    txNonce = $txPath.txNonce,
    txGasPrice = $txPath.txGasPrice,
    txGasFeeMode = txPath.txGasFeeMode,
    txMaxFeesPerGas = $txPath.txMaxFeesPerGas,
    txBaseFee = $txPath.txBaseFee,
    txPriorityFee = $txPath.txPriorityFee,
    txGasAmount = $txPath.txGasAmount,
    txBonderFees = $txPath.txBonderFees,
    txTokenFees = $txPath.txTokenFees,
    txEstimatedTime = txPath.txEstimatedTime,
    txFee = $txPath.txFee,
    txL1Fee = $txPath.txL1Fee,
    approvalRequired = txPath.approvalRequired,
    approvalAmountRequired = $txPath.approvalAmountRequired,
    approvalContractAddress = txPath.approvalContractAddress,
    approvalTxNonce = $txPath.approvalTxNonce,
    approvalGasPrice = $txPath.approvalGasPrice,
    approvalGasFeeMode = txPath.approvalGasFeeMode,
    approvalMaxFeesPerGas = $txPath.approvalMaxFeesPerGas,
    approvalBaseFee = $txPath.approvalBaseFee,
    approvalPriorityFee = $txPath.approvalPriorityFee,
    approvalGasAmount = $txPath.approvalGasAmount,
    approvalEstimatedTime = txPath.approvalEstimatedTime,
    approvalFee = $txPath.approvalFee,
    approvalL1Fee = $txPath.approvalL1Fee,
    txTotalFee = $txPath.txTotalFee
    )

proc buildTransactionsFromRoute(self: Module) =
  let err = self.controller.buildTransactionsFromRoute(self.tmpSendTransactionDetails.uuid)
  if err.len > 0:
    self.transactionWasSent(uuid = self.tmpSendTransactionDetails.uuid, chainId = 0, approvalTx = false, txHash = "", error = err)
    self.clearTmpData()

method authenticateAndTransfer*(self: Module, uuid: string, fromAddr: string) =
  self.tmpSendTransactionDetails.uuid = uuid
  self.tmpSendTransactionDetails.fromAddr = fromAddr
  self.tmpSendTransactionDetails.resolvedSignatures.clear()
  self.tmpClearLocalDataLater = true # means there are still some tx to be sent
  self.buildTransactionsFromRoute()

proc sendSignedTransactions*(self: Module) =
  try:
    # check if all transactions are signed
    for _, (r, s, v) in self.tmpSendTransactionDetails.resolvedSignatures.pairs:
      if r.len == 0 or s.len == 0 or v.len == 0:
        raise newException(CatchableError, "not all transactions are signed")

    let err = self.controller.sendRouterTransactionsWithSignatures(self.tmpSendTransactionDetails.uuid, self.tmpSendTransactionDetails.resolvedSignatures)
    if err.len > 0:
      raise newException(CatchableError, "sending transaction failed: " & err)
  except Exception as e:
    error "sendSignedTransactions failed: ", msg=e.msg
    self.transactionWasSent(uuid = self.tmpSendTransactionDetails.uuid, chainId = 0, approvalTx = false, txHash = "", error = e.msg)
    self.clearTmpData()

proc requestNextSignature(self: Module) =
  for h, (r, s, v) in self.tmpSendTransactionDetails.resolvedSignatures.pairs:
    if r.len != 0 and s.len != 0 and v.len != 0:
      continue
    self.tmpSendTransactionDetails.txHashBeingProcessed = h
    self.view.emitSigningRequested(self.tmpSendTransactionDetails.keyUid, h,
      self.tmpSendTransactionDetails.fromAddrPath, self.tmpSendTransactionDetails.fromAddr)
    return
  self.tmpSendTransactionDetails.txHashBeingProcessed = ""
  self.view.sendSuccessfullyAuthenticatedSignal(self.tmpSendTransactionDetails.uuid)
  self.sendSignedTransactions()

method onSigningResult*(self: Module, signature: string) =
  if signature.len == 0:
    # signing was cancelled or failed
    self.transactionWasSent(uuid = self.tmpSendTransactionDetails.uuid, chainId = 0, approvalTx = false, txHash = "", error = authenticationCanceled)
    self.clearTmpData()
    return
  if self.tmpSendTransactionDetails.txHashBeingProcessed.len == 0:
    return
  self.tmpSendTransactionDetails.resolvedSignatures[self.tmpSendTransactionDetails.txHashBeingProcessed] = utils.getRSVFromSignature(signature)
  self.requestNextSignature()

method prepareSignaturesForTransactions*(self:Module, txForSigning: RouterTransactionsForSigningDto) =
  if txForSigning.sendDetails.uuid != self.tmpSendTransactionDetails.uuid:
    return
  try:
    if txForSigning.signingDetails.hashes.len == 0:
      raise newException(CatchableError, "no transaction hashes to be signed")
    if txForSigning.signingDetails.keyUid == "" or txForSigning.signingDetails.address == "" or txForSigning.signingDetails.addressPath == "":
      raise newException(CatchableError, "preparing signatures for transactions failed")

    self.tmpSendTransactionDetails.keyUid = txForSigning.signingDetails.keyUid
    self.tmpSendTransactionDetails.fromAddr = txForSigning.signingDetails.address
    self.tmpSendTransactionDetails.fromAddrPath = txForSigning.signingDetails.addressPath
    for h in txForSigning.signingDetails.hashes:
      self.tmpSendTransactionDetails.resolvedSignatures[h] = ("", "", "")
    self.requestNextSignature()
  except Exception as e:
    error "prepareSignaturesForTransactions failed: ", msg=e.msg
    self.transactionWasSent(uuid = txForSigning.sendDetails.uuid, chainId = 0, approvalTx = false, txHash = "", error = e.msg)
    self.clearTmpData()


method transactionWasSent*(self: Module, uuid: string, chainId: int = 0, approvalTx: bool = false, txHash: string = "", error: string = "") =
  self.tmpClearLocalDataLater = false
  defer:
    self.clearTmpData(approvalTx)
  if txHash.len == 0:
    self.view.sendTransactionSentSignal(uuid = self.tmpSendTransactionDetails.uuid, chainId = 0, approvalTx = false, txHash = "", error)
    return
  self.view.sendTransactionSentSignal(uuid, chainId, approvalTx, txHash, error)

method suggestedRoutesReady*(self: Module, uuid: string, routes: seq[TransactionPathDtoV2], errCode: string, errDescription: string) =
  let paths = routes.map(x => self.convertTransactionPathDtoV2ToPathItem(x))
  self.view.getPathModel().setItems(paths)
  self.view.sendSuggestedRoutesReadySignal(uuid, errCode, errDescription)

method suggestedRoutes*(self: Module,
  uuid: string,
  sendType: SendType,
  chainId: int,
  accountFrom: string,
  accountTo: string,
  tokenGroupKey: string,
  tokenIsOwnerToken: bool,
  amountIn: string,
  toTokenGroupKey: string = "",
  amountOut: string = "",
  slippagePercentage: float = 0.0,
  extraParamsTable: Table[string, string] = initTable[string, string]()) =
  self.clearTmpData()
  self.controller.suggestedRoutes(
    uuid,
    sendType,
    accountFrom,
    accountTo,
    tokenGroupKey,
    tokenIsOwnerToken,
    amountIn,
    toTokenGroupKey,
    amountOut,
    chainId,
    chainId,
    slippagePercentage,
    extraParamsTable
  )

method resetData*(self: Module) =
  self.controller.stopSuggestedRoutesAsyncCalculation()
  self.clearTmpData(keepUuid = self.tmpClearLocalDataLater)

method transactionSendingComplete*(self: Module, txHash: string, status: string) =
  self.view.sendtransactionSendingCompleteSignal(txHash, status)

method setFeeMode*(self: Module, feeMode: int, routerInputParamsUuid: string, pathName: string, chainId: int,
  isApprovalTx: bool, communityId: string) =
  let err = self.controller.setFeeMode(feeMode, routerInputParamsUuid, pathName, chainId, isApprovalTx, communityId)
  if err.len > 0:
    # TODO: translate this, or find a better way to display error at this step (maybe within the popup)
    var data = NotificationArgs(title: "Setting fee mode", message: err)
    self.events.emit(SIGNAL_DISPLAY_APP_NOTIFICATION, data)

method setCustomTxDetails*(self: Module, nonce: int, gasAmount: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string,
  routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool, communityId: string) =
  let err = self.controller.setCustomTxDetails(nonce, gasAmount, gasPrice, maxFeesPerGas, priorityFee, routerInputParamsUuid, pathName,
    chainId, isApprovalTx, communityId)
  if err.len > 0:
    # TODO: translate this, or find a better way to display error at this step (maybe within the popup)
    var data = NotificationArgs(title: "Setting custom fee", message: err)
    self.events.emit(SIGNAL_DISPLAY_APP_NOTIFICATION, data)

method getEstimatedTime*(self: Module, chainId: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string): int =
  return self.controller.getEstimatedTime(chainId, gasPrice, maxFeesPerGas, priorityFee)
