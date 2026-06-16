import nimqml, tables, json, sequtils, strutils, stint, chronicles

import ./io_interface, ./path_model, ./path_item
import app_service/common/utils as common_utils
import app_service/service/eth/utils as eth_utils
import app_service/service/transaction/dto as transaction_dto
from backend/wallet import ExtraKeyPackId

export path_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      pathModel: PathModel

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.pathModel = newPathModel()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc getPathModel*(self: View): PathModel {.inline.} =
    return self.pathModel

  proc fetchSuggestedRoutes*(self: View,
    uuid: string,
    sendType: int,
    chainId: int,
    accountFrom: string,
    accountTo: string,
    amountIn: string,
    tokenGroupKey: string,
    amountOut: string,
    toTokenGroupKey: string,
    slippagePercentageString: string,
    extraParamsJson: string) {.slot.} =

    var extraParamsTable: Table[string, string]
    self.pathModel.setItems(@[])
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
    if sendType == ord(transaction_dto.SendType.Swap):
      try:
        slippagePercentage = slippagePercentageString.parseFloat()
      except:
        error "parsing slippage failed", slippage=slippagePercentageString

    self.delegate.suggestedRoutes(
        uuid,
        SendType(sendType),
        chainId,
        accountFrom,
        accountTo,
        tokenGroupKey,
        false, #tokenIsOwnerToken
        amountIn,
        toTokenGroupKey,
        amountOut,
        slippagePercentage,
        extraParamsTable)

  proc resetData*(self: View) {.slot.} =
    self.delegate.resetData()

  proc authenticateAndTransfer*(self: View, uuid: string, fromAddr: string) {.slot.} =
    self.delegate.authenticateAndTransfer(uuid, fromAddr)

  proc signingRequested*(self: View, keyUid: string, txHash: string, path: string, address: string) {.signal.}
  proc emitSigningRequested*(self: View, keyUid: string, txHash: string, path: string, address: string) =
    self.signingRequested(keyUid, txHash, path, address)

  proc onSigningResult*(self: View, signature: string) {.slot.} =
    self.delegate.onSigningResult(signature)

  proc suggestedRoutesReady(self: View, uuid: string, pathModel: QVariant, errCode: string, errDescription: string) {.signal.}
  proc sendSuggestedRoutesReadySignal*(self: View, uuid: string, errCode: string, errDescription: string) =
    self.suggestedRoutesReady(uuid, newQVariant(self.pathModel), errCode, errDescription)

  proc transactionSendingComplete(self: View, txHash: string, status: string) {.signal.}
  proc sendtransactionSendingCompleteSignal*(self: View, txHash: string, status: string) =
    self.transactionSendingComplete(txHash, status)

  proc transactionSent(self: View, uuid: string, chainId: int, approvalTx: bool, txHash: string, error: string) {.signal.}
  proc sendTransactionSentSignal*(self: View, uuid: string, chainId: int, approvalTx: bool, txHash: string, error: string) =
    self.transactionSent(uuid, chainId, approvalTx, txHash, error)

  proc successfullyAuthenticated(self: View, uuid: string) {.signal.}
  proc sendSuccessfullyAuthenticatedSignal*(self: View, uuid: string) =
    self.successfullyAuthenticated(uuid)

  proc setFeeMode*(self: View, feeMode: int, routerInputParamsUuid: string, pathName: string, chainId: int,
    isApprovalTx: bool, communityId: string) {.slot.} =
      self.delegate.setFeeMode(feeMode, routerInputParamsUuid, pathName, chainId, isApprovalTx, communityId)

  proc setCustomTxDetails*(self: View, nonce: int, gasAmount: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string,
    routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool, communityId: string) {.slot.} =
      self.delegate.setCustomTxDetails(nonce, gasAmount, gasPrice, maxFeesPerGas, priorityFee, routerInputParamsUuid, pathName,
        chainId, isApprovalTx, communityId)

  proc getEstimatedTime*(self: View, chainId: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string): int {.slot.} =
    return self.delegate.getEstimatedTime(chainId, gasPrice, maxFeesPerGas, priorityFee)

  proc delete*(self: View) =
    self.QObject.delete

