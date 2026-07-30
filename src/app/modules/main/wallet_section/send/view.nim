import nimqml, tables, json, sequtils, strutils, stint, chronicles
import app/global/html_utils

import ./io_interface, ./network_route_model, ./network_route_item, ./suggested_route_item, ./transaction_routes
import app_service/service/network/service as network_service
import app_service/service/transaction/dto as transaction_dto

import app_service/common/utils as common_utils
import app_service/service/eth/utils as eth_utils
from backend/wallet import ExtraKeyPackId

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      # for send modal
      fromNetworksRouteModel: NetworkRouteModel
      toNetworksRouteModel: NetworkRouteModel
      transactionRoutes: TransactionRoutes
      errCode: string
      errDescription: string
      selectedAssetKey: string
      showUnPreferredChains: bool
      sendType: transaction_dto.SendType
      selectedTokenIsOwnerToken: bool
      selectedTokenName: string
      selectedRecipient: string
      selectedSenderAccountAddress: string
      # for receive modal
      selectedReceiveAccountAddress: string

  # Forward declaration
  proc updateNetworksDisabledChains(self: View)
  proc updateNetworksTokenBalance(self: View)

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.fromNetworksRouteModel = newNetworkRouteModel()
    result.toNetworksRouteModel = newNetworkRouteModel()
    result.transactionRoutes = newTransactionRoutes()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc selectedSenderAccountAddressChanged*(self: View) {.signal.}
  proc getSelectedSenderAccountAddress*(self: View): string {.slot.} =
    return self.selectedSenderAccountAddress
  proc setSelectedSenderAccountAddress*(self: View, address: string) {.slot.} =
    self.selectedSenderAccountAddress = address
    self.updateNetworksTokenBalance()
    self.selectedSenderAccountAddressChanged()
  QtProperty[string] selectedSenderAccountAddress:
    read = getSelectedSenderAccountAddress
    notify = selectedSenderAccountAddressChanged

  proc selectedReceiveAccountAddressChanged*(self: View) {.signal.}
  proc getSelectedReceiveAccountAddress*(self: View): string {.slot.} =
    return self.selectedReceiveAccountAddress
  proc setSelectedReceiveAccountAddress*(self: View, address: string) {.slot.} =
    self.selectedReceiveAccountAddress = address
    self.selectedReceiveAccountAddressChanged()
  QtProperty[string] selectedReceiveAccountAddress:
    read = getSelectedReceiveAccountAddress
    notify = selectedReceiveAccountAddressChanged

  proc fromNetworksRouteModelChanged*(self: View) {.signal.}
  proc getfromNetworksRouteModel(self: View): QVariant {.slot.} =
    return newQVariant(self.fromNetworksRouteModel)
  QtProperty[QVariant] fromNetworksRouteModel:
    read = getfromNetworksRouteModel
    notify = fromNetworksRouteModelChanged

  proc toNetworksRouteModelChanged*(self: View) {.signal.}
  proc gettoNetworksRouteModel(self: View): QVariant {.slot.} =
    return newQVariant(self.toNetworksRouteModel)
  QtProperty[QVariant] toNetworksRouteModel:
    read = gettoNetworksRouteModel
    notify = toNetworksRouteModelChanged

  proc selectedAssetKeyChanged*(self: View) {.signal.}
  proc getSelectedAssetKey*(self: View): string {.slot.} =
    return self.selectedAssetKey
  proc setSelectedAssetKey(self: View, assetKey: string) {.slot.} =
    self.selectedAssetKey = assetKey
    self.updateNetworksTokenBalance()
    self.selectedAssetKeyChanged()
  QtProperty[string] selectedAssetKey:
    write = setSelectedAssetKey
    read = getSelectedAssetKey
    notify = selectedAssetKeyChanged

  proc showUnPreferredChainsChanged*(self: View) {.signal.}
  proc getShowUnPreferredChains(self: View): bool {.slot.} =
    return self.showUnPreferredChains
  proc toggleShowUnPreferredChains*(self: View) {.slot.} =
    self.showUnPreferredChains = not self.showUnPreferredChains
    self.updateNetworksDisabledChains()
    self.showUnPreferredChainsChanged()
  QtProperty[bool] showUnPreferredChains:
    read = getShowUnPreferredChains
    notify = showUnPreferredChainsChanged

  proc sendTypeChanged*(self: View) {.signal.}
  proc getSendType(self: View): int {.slot.} =
    return ord(self.sendType)
  proc setSendType(self: View, sendType: int) {.slot.} =
    self.sendType = (SendType)sendType
    self.sendTypeChanged()
  QtProperty[int] sendType:
    write = setSendType
    read = getSendType
    notify = sendTypeChanged

  proc selectedRecipientChanged*(self: View) {.signal.}
  proc getSelectedRecipient(self: View): string {.slot.} =
    return self.selectedRecipient
  proc setSelectedRecipient(self: View, selectedRecipient: string) {.slot.} =
    self.selectedRecipient = selectedRecipient
    self.selectedRecipientChanged()
  QtProperty[string] selectedRecipient:
    read = getSelectedRecipient
    write = setSelectedRecipient
    notify = selectedRecipientChanged

  proc setSelectedTokenIsOwnerToken(self: View, isOwnerToken: bool) {.slot.} =
    self.selectedTokenIsOwnerToken = isOwnerToken

  proc setSelectedTokenName(self: View, tokenName: string) {.slot.} =
    self.selectedTokenName = tokenName

  proc updateNetworksDisabledChains(self: View) =
    # if the setting to show unpreferred chains is toggled, add all unpreferred chains to disabled chains list
    if not self.showUnPreferredChains:
      self.toNetworksRouteModel.disableRouteUnpreferredChains()
    else:
      self.toNetworksRouteModel.enableRouteUnpreferredChains()

  proc updateNetworksTokenBalance(self: View) =
    for chainId in self.toNetworksRouteModel.getAllNetworksChainIds():
      let tokenBalance = self.delegate.getTokenBalanceForChainId(chainId)
      self.fromNetworksRouteModel.updateTokenBalanceForSymbol(chainId, tokenBalance)
      self.toNetworksRouteModel.updateTokenBalanceForSymbol(chainId, tokenBalance)

  proc setNetworkItems*(self: View, fromNetworks: seq[NetworkRouteItem], toNetworks: seq[NetworkRouteItem]) =
    self.fromNetworksRouteModel.setItems(fromNetworks)
    self.toNetworksRouteModel.setItems(toNetworks)

  proc transactionSent*(self: View, uuid: string, chainId: int, approvalTx: bool, txHash: string, error: string) {.signal.}
  proc sendTransactionSentSignal*(self: View, uuid: string, chainId: int, approvalTx: bool, txHash: string, error: string) =
    self.transactionSent(uuid, chainId, approvalTx, txHash, error)

  proc authenticateAndTransfer*(self: View, uuid: string) {.slot.} =
    self.delegate.authenticateAndTransfer(self.selectedSenderAccountAddress, uuid)

  proc signingRequested*(self: View, keyUid: string, txHash: string, path: string, address: string) {.signal.}
  proc emitSigningRequested*(self: View, keyUid: string, txHash: string, path: string, address: string) =
    self.signingRequested(keyUid, txHash, path, address)

  proc onSigningResult*(self: View, signature: string) {.slot.} =
    self.delegate.onSigningResult(signature)

  proc reevaluateSwap*(self: View, uuid: string, chainId: int, isApprovalTx: bool) {.slot.} =
    self.delegate.reevaluateSwap(uuid, chainId, isApprovalTx)

  proc suggestedRoutesReady*(self: View, suggestedRoutes: QVariant, errCode: string, errDescription: string) {.signal.}
  proc setTransactionRoute*(self: View, routes: TransactionRoutes, errCode: string, errDescription: string) =
    self.transactionRoutes = routes
    self.errCode = errCode
    self.errDescription = errDescription
    self.suggestedRoutesReady(newQVariant(self.transactionRoutes), errCode, errDescription)

  proc suggestedRoutes*(self: View, uuid: string, amountIn: string, amountOut: string, slippagePercentageString: string, extraParamsJson: string) {.slot.} =
    var extraParamsTable: Table[string, string]
    try:
      if extraParamsJson.len > 0:
        for key, value in parseJson(extraParamsJson):
          if key == ExtraKeyPackId:
            let bigPackId = common_utils.stringToUint256(value.getStr())
            let packIdHex = "0x" & eth_utils.stripLeadingZeros(bigPackId.toHex)
            extraParamsTable[key] = packIdHex
          else:
            extraParamsTable[key] = value.getStr()
    except Exception as e:
      error "Error parsing extraParamsJson: ", msg=e.msg

    var slippagePercentage: float
    if self.sendType == transaction_dto.SendType.Swap:
      try:
        slippagePercentage = slippagePercentageString.parseFloat()
      except:
        error "parsing slippage failed", slippage=slippagePercentageString

    let selectedFromChain = self.fromNetworksRouteModel.getSelectedChain()
    let selectedToChain = self.toNetworksRouteModel.getSelectedChain()

    self.delegate.suggestedRoutes(
      uuid,
      self.sendType,
      self.selectedSenderAccountAddress,
      self.selectedRecipient,
      self.selectedAssetKey,
      self.selectedTokenIsOwnerToken,
      amountIn,
      "",
      amountOut,
      selectedFromChain,
      selectedToChain,
      slippagePercentage,
      extraParamsTable
    )

  proc updateRoutePreferredChains*(self: View, chainIds: string) {.slot.} =
    self.toNetworksRouteModel.updateRoutePreferredChains(chainIds)

  proc updatedNetworksWithRoutes*(self: View, paths: seq[SuggestedRouteItem], chainsWithNoGas: Table[int, string]) =
    self.fromNetworksRouteModel.resetPathData()
    self.toNetworksRouteModel.resetPathData()
    for path in paths:
      let fromChainId = path.getfromNetwork()
      self.fromNetworksRouteModel.updateFromNetworks(path, not chainsWithNoGas.hasKey(fromChainId))
      self.toNetworksRouteModel.updateToNetworks(path)

  proc resetData*(self: View) {.slot.} =
    self.delegate.resetData()
    self.sendType = transaction_dto.SendType.Transfer
    self.selectedRecipient = ""
    self.fromNetworksRouteModel.reset()
    self.toNetworksRouteModel.reset()
    self.transactionRoutes = newTransactionRoutes()
    self.selectedAssetKey = ""
    self.showUnPreferredChains = false

  proc splitAndFormatAddressPrefix(self: View, text : string, updateInStore: bool): string {.slot.} =
    return self.delegate.splitAndFormatAddressPrefix(text, updateInStore)

  proc getAddressFromFormattedString(self: View, text : string): string {.slot.} =
    var splitWords = html_utils.plain_text(text).split(':')
    for i in countdown(splitWords.len-1, 0):
      if splitWords[i].startsWith("0x"):
        return splitWords[i]
    return ""

# "Stateless" methods
  proc fetchSuggestedRoutesWithParameters*(self: View,
    uuid: string,
    accountFrom: string,
    accountTo: string,
    amountIn: string,
    amountOut: string,
    token: string,
    toToken: string,
    fromChainID: int,
    toChainID: int,
    sendType: int,
    slippagePercentageString: string) {.slot.} =

    var slippagePercentage: float
    if sendType == ord(transaction_dto.SendType.Swap):
      try:
        slippagePercentage = slippagePercentageString.parseFloat()
      except:
        error "parsing slippage failed", slippage=slippagePercentageString

    self.delegate.suggestedRoutes(
      uuid,
      SendType(sendType),
      accountFrom,
      accountTo,
      token,
      self.selectedTokenIsOwnerToken,
      amountIn,
      toToken,
      amountOut,
      fromChainID,
      toChainID,
      slippagePercentage
    )

  proc transactionSendingComplete*(self: View, txHash: string, status: string) {.signal.}
  proc sendtransactionSendingCompleteSignal*(self: View, txHash: string, status: string) =
    self.transactionSendingComplete(txHash, status)

  proc setSenderAccount*(self: View, address: string) {.slot.} =
    self.setSelectedSenderAccountAddress(address)

  proc setReceiverAccount*(self: View, address: string) {.slot.} =
    self.setSelectedReceiveAccountAddress(address)

  proc delete*(self: View) =
    self.QObject.delete

