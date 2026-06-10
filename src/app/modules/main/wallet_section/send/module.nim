import tables, nimqml, sequtils, sugar, stint, strutils, chronicles
import dotherside_ext

import ./io_interface, ./view, ./controller, ./network_route_item, ./transaction_routes, ./suggested_route_item, ./suggested_route_model, ./gas_estimate_item, ./gas_fees_item, ./network_route_model
import ../io_interface as delegate_interface
import app/global/global_singleton
import app/core/eventemitter
import app_service/common/utils
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service
import app_service/service/currency/service as currency_service
import app_service/service/transaction/service as transaction_service
import app_service/service/transaction/[dto, dtoV2]
import app/modules/shared_models/currency_amount
import app_service/service/network/network_item as network_service_item

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
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  currencyService: currency_service.Service,
  transactionService: transaction_service.Service
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.controller = controller.newController(result, events, tokenService, walletAccountService, networkService, currencyService,
    transactionService)
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

proc convertSendToNetworkToNetworkItem(self: Module, network: SendToNetwork): NetworkRouteItem =
  result = initNetworkRouteItem(
      network.chainId,
      layer = 0,
      true,
      true,
      true,
      newCurrencyAmount(),
      amountIn = "",
      $network.amountOut)

proc convertNetworkDtoToNetworkRouteItem(self: Module, network: network_service_item.NetworkItem, tokenBalance: CurrencyAmount): NetworkRouteItem =
  result = initNetworkRouteItem(
      network.chainId,
      network.layer,
      true,
      false,
      true,
      tokenBalance
      )

proc convertSuggestedFeesDtoToGasFeesItem(self: Module, gasFees: SuggestedFeesDto): GasFeesItem =
  result = newGasFeesItem(
    gasPrice = gasFees.gasPrice,
    baseFee = gasFees.baseFee,
    maxPriorityFeePerGas = gasFees.maxPriorityFeePerGas,
    maxFeePerGasL = gasFees.maxFeePerGasL,
    maxFeePerGasM = gasFees.maxFeePerGasM,
    maxFeePerGasH = gasFees.maxFeePerGasH,
    l1GasFee = gasFees.l1GasFee,
    eip1559Enabled = gasFees.eip1559Enabled
    )

proc convertFeesDtoToGasEstimateItem(self: Module, fees: FeesDto): GasEstimateItem =
  result = newGasEstimateItem(
    totalFeesInNativeCrypto = fees.totalFeesInNativeCrypto,
    totalTokenFees = fees.totalTokenFees,
    totalTime = fees.totalTime
    )

proc convertTransactionPathDtoToSuggestedRouteItem(self: Module, pathOld: TransactionPathDto, pathNew: TransactionPathDtoV2): SuggestedRouteItem =
  result = newSuggestedRouteItem(
    bridgeName = pathOld.bridgeName,
    fromNetwork = pathOld.fromNetwork.chainId,
    toNetwork = pathOld.toNetwork.chainId,
    maxAmountIn = $pathOld.maxAmountIn,
    amountIn = $pathOld.amountIn,
    amountOut = $pathOld.amountOut,
    gasAmount = $pathOld.gasAmount,
    gasFees = self.convertSuggestedFeesDtoToGasFeesItem(pathOld.gasFees),
    tokenFees = pathOld.tokenFees,
    cost = pathOld.cost,
    estimatedTime = pathOld.estimatedTime,
    amountInLocked = pathOld.amountInLocked,
    isFirstSimpleTx = pathOld.isFirstSimpleTx,
    isFirstBridgeTx = pathOld.isFirstBridgeTx,
    approvalRequired = pathOld.approvalRequired,
    approvalGasFees = pathOld.approvalGasFees,
    approvalAmountRequired = $pathOld.approvalAmountRequired,
    approvalContractAddress = pathOld.approvalContractAddress,
    slippagePercentage = pathOld.slippagePercentage,
    txFeeInWei = pathNew.txFee.toString(),
    txL1FeeInWei = pathNew.txL1Fee.toString(),
    approvalFeeInWei = pathNew.approvalFee.toString(),
    approvalL1FeeInWei = pathNew.approvalL1Fee.toString(),
  )

method getTokenBalanceForChainId*(self: Module, chainId: int): CurrencyAmount =
  let assetKey = self.view.getSelectedAssetKey()
  if assetKey.len == 0:
    return self.controller.getTokenBalance(self.view.getSelectedSenderAccountAddress(), "")

  let tokenItem = self.controller.getTokenByGroupKeyAndChainId(assetKey, chainId)
  if tokenItem.isNil:
    error "no token found for group key and chain id", groupKey=assetKey, chainId=chainId
    return newCurrencyAmount()
  return self.controller.getTokenBalance(self.view.getSelectedSenderAccountAddress(), tokenItem.key)

proc refreshNetworks*(self: Module) =
  let networks = self.controller.getCurrentNetworks()
  let assetKey = self.view.getSelectedAssetKey()
  if assetKey.len == 0:
    let tokenBalance = self.controller.getTokenBalance(self.view.getSelectedSenderAccountAddress(), "")
    let fromNetworks = networks.map(x => self.convertNetworkDtoToNetworkRouteItem(x, tokenBalance))
    let toNetworks = networks.map(x => self.convertNetworkDtoToNetworkRouteItem(x, tokenBalance))
    self.view.setNetworkItems(fromNetworks, toNetworks)
    return

  let tokens = self.controller.getTokensByGroupKey(assetKey)
  if tokens.len == 0:
    error "no tokens found for group key", groupKey=assetKey
    return

  if tokens.len < 2:
    error "cannot bridge - only one token found for group key", groupKey=assetKey
    return

  var
    fromNetworks: seq[NetworkRouteItem]
    toNetworks: seq[NetworkRouteItem]
  for token in tokens:
    var network: network_service_item.NetworkItem
    for i in 0..<networks.len:
      if networks[i].chainId == token.chainId:
        network = networks[i]
        break

    if network.isNil:
      error "network not found for token", tokenKey=token.key
      continue

    let tokenBalance = self.controller.getTokenBalance(self.view.getSelectedSenderAccountAddress(), token.key)
    fromNetworks.add(self.convertNetworkDtoToNetworkRouteItem(network, tokenBalance))
    toNetworks.add(self.convertNetworkDtoToNetworkRouteItem(network, tokenBalance))

  self.view.setNetworkItems(fromNetworks, toNetworks)

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionSend", self.viewVariant)

  # these connections should be part of the controller's init method
  self.events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e:Args):
    self.refreshNetworks()

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.refreshNetworks()
  self.moduleLoaded = true
  self.delegate.sendModuleDidLoad()

proc buildTransactionsFromRoute(self: Module) =
  let err = self.controller.buildTransactionsFromRoute(self.tmpSendTransactionDetails.uuid)
  if err.len > 0:
    self.transactionWasSent(uuid = self.tmpSendTransactionDetails.uuid, chainId = 0, approvalTx = false, txHash = "", error = err)
    self.clearTmpData()

method authenticateAndTransfer*(self: Module, fromAddr: string, uuid: string) =
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

method suggestedRoutesReady*(self: Module, uuid: string, suggestedRoutes: SuggestedRoutesDto, errCode: string, errDescription: string) =
  if suggestedRoutes.best.len != suggestedRoutes.bestRoute.len:
    error "suggestedRoutes.best and suggestedRoutes.bestRoute have different lengths"
    return
  var paths: seq[SuggestedRouteItem]
  for i in 0..<suggestedRoutes.best.len:
    let p = self.convertTransactionPathDtoToSuggestedRouteItem(suggestedRoutes.best[i], suggestedRoutes.bestRoute[i])
    paths.add(p)

  let suggestedRouteModel = newSuggestedRouteModel()
  suggestedRouteModel.setItems(paths)
  let gasTimeEstimate = self.convertFeesDtoToGasEstimateItem(suggestedRoutes.gasTimeEstimate)
  let networks = suggestedRoutes.toNetworks.map(x => self.convertSendToNetworkToNetworkItem(x))
  let toNetworksRouteModel = newNetworkRouteModel()
  toNetworksRouteModel.setItems(networks)
  self.view.updatedNetworksWithRoutes(paths, self.controller.getChainsWithNoGasFromError(errCode, errDescription))
  let transactionRoutes = newTransactionRoutes(
    uuid = uuid,
    suggestedRoutes = suggestedRouteModel,
    gasTimeEstimate = gasTimeEstimate,
    amountToReceive = suggestedRoutes.amountToReceive,
    toNetworksRouteModel = toNetworksRouteModel,
    rawPaths = suggestedRoutes.rawBest)
  self.view.setTransactionRoute(transactionRoutes, errCode, errDescription)

method suggestedRoutes*(self: Module,
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
  self.clearTmpData()
  self.controller.suggestedRoutes(
    uuid,
    sendType,
    accountFrom,
    accountTo,
    token,
    tokenIsOwnerToken,
    amountIn,
    toToken,
    amountOut,
    fromChainID,
    toChainID,
    slippagePercentage,
    extraParamsTable
  )

method resetData*(self: Module) =
  self.controller.stopSuggestedRoutesAsyncCalculation()
  # Don't clear tmp data here (may be needed for swap (approve+swap)) the data will be cleared when the signing completes, is cancelled, or error occurs.
  if self.tmpSendTransactionDetails.txHashBeingProcessed.len > 0:
    return
  self.clearTmpData(keepUuid = self.tmpClearLocalDataLater)

method filterChanged*(self: Module, addresses: seq[string], chainIds: seq[int], isDirty: bool) =
  if not isDirty or addresses.len == 0:
    return
  self.view.setSenderAccount(addresses[0])
  self.view.setReceiverAccount(addresses[0])

proc getNetworkColor(self: Module, shortName: string): string =
  let networks = self.controller.getCurrentNetworks()
  for network in networks:
    if cmpIgnoreCase(network.shortName, shortName) == 0:
      return network.chainColor
  return ""

proc getLayer1NetworkChainId*(self: Module): int =
  let networks = self.controller.getCurrentNetworks()
  for network in networks:
    if network.layer == NETWORK_LAYER_1:
      return network.chainId
  return 0

method getNetworkChainId*(self: Module, shortName: string): int =
  let networks = self.controller.getCurrentNetworks()
  for network in networks:
    if cmpIgnoreCase(network.shortName, shortName) == 0:
      return network.chainId
  return 0

method splitAndFormatAddressPrefix*(self: Module, text : string, updateInStore: bool): string {.slot.} =
  var tempPreferredChains: seq[int]
  var chainFound = false
  var editedText = ""

  for word in plainText(text).split(':'):
    if word.startsWith("0x"):
      editedText = editedText & word
    else:
      let chainColor = self.getNetworkColor(word)
      if not chainColor.isEmptyOrWhitespace():
        chainFound = true
        tempPreferredChains.add(self.getNetworkChainId(word))
        editedText = editedText & "<span style='color: " & chainColor & "'>" & word & "</span>" & ":"

  if updateInStore:
    if not chainFound:
      self.view.updateRoutePreferredChains($self.getLayer1NetworkChainId())
    else:
      self.view.updateRoutePreferredChains(tempPreferredChains.join(":"))

  editedText = "<a><p>" & editedText & "</a></p>"
  return editedText

method transactionSendingComplete*(self: Module, txHash: string, status: string) =
  self.view.sendtransactionSendingCompleteSignal(txHash, status)

method reevaluateSwap*(self: Module, uuid: string, chainId: int, isApprovalTx: bool) =
  const pathName = "Paraswap"
  let err = self.controller.reevaluateRouterPath(uuid, pathName, chainId, isApprovalTx)
  if err.len > 0:
    error "reevaluateRouterPath failed: ", err=err