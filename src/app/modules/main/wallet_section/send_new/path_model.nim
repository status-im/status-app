import nimqml, tables, strutils, std/strformat

import ./path_item

export path_item

type
  ModelRole {.pure.} = enum
    Index = UserRole + 1,
    ProcessorName,
    FromChain,
    FromChainEIP1559Compliant,
    FromChainNoBaseFee,
    FromChainNoPriorityFee,
    ToChain,
    FromToken,
    ToToken,
    AmountIn,
    AmountInLocked,
    AmountOut,
    SuggestedNonEIP1559GasPrice,
    SuggestedNonEIP1559EstimatedTime,
    SuggestedMaxFeesPerGasLowLevel,
    SuggestedPriorityFeePerGasLowLevel,
    SuggestedEstimatedTimeLowLevel,
    SuggestedMaxFeesPerGasMediumLevel,
    SuggestedPriorityFeePerGasMediumLevel,
    SuggestedEstimatedTimeMediumLevel,
    SuggestedMaxFeesPerGasHighLevel,
    SuggestedPriorityFeePerGasHighLevel,
    SuggestedEstimatedTimeHighLevel,
    SuggestedMinPriorityFee,
    SuggestedMaxPriorityFee,
    CurrentBaseFee,
    SuggestedTxNonce,
    SuggestedTxGasAmount,
    SuggestedApprovalTxNonce,
    SuggestedApprovalGasAmount,
    TxNonce,
    TxGasPrice,
    TxGasFeeMode,
    TxMaxFeesPerGas,
    TxBaseFee,
    TxPriorityFee,
    TxGasAmount,
    TxBonderFees,
    TxTokenFees,
    TxEstimatedTime,
    TxFee,
    TxL1Fee,
    TxTotalFee,
    ApprovalRequired,
    ApprovalAmountRequired,
    ApprovalContractAddress,
    ApprovalTxNonce,
    ApprovalGasPrice,
    ApprovalGasFeeMode,
    ApprovalMaxFeesPerGas,
    ApprovalBaseFee,
    ApprovalPriorityFee,
    ApprovalGasAmount,
    ApprovalEstimatedTime,
    ApprovalFee,
    ApprovalL1Fee,
    EstimatedTime

QtObject:
  type
    PathModel* = ref object of QAbstractListModel
      items*: seq[PathItem]

  proc delete(self: PathModel)
  proc setup(self: PathModel)
  proc newPathModel*(): PathModel =
    new(result, delete)
    result.setup

  proc `$`*(self: PathModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  method rowCount(self: PathModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: PathModel): Table[int, string] =
    {
      ModelRole.Index.int: "index",
      ModelRole.ProcessorName.int: "processorName",
      ModelRole.FromChain.int: "fromChain",
      ModelRole.FromChainEIP1559Compliant.int: "fromChainEIP1559Compliant",
      ModelRole.FromChainNoBaseFee.int: "fromChainNoBaseFee",
      ModelRole.FromChainNoPriorityFee.int: "fromChainNoPriorityFee",
      ModelRole.ToChain.int: "toChain",
      ModelRole.FromToken.int: "fromToken",
      ModelRole.ToToken.int: "toToken",
      ModelRole.AmountIn.int: "amountIn",
      ModelRole.AmountInLocked.int: "amountInLocked",
      ModelRole.AmountOut.int: "amountOut",
      ModelRole.SuggestedNonEIP1559GasPrice.int: "suggestedNonEIP1559GasPrice",
      ModelRole.SuggestedNonEIP1559EstimatedTime.int: "suggestedNonEIP1559EstimatedTime",
      ModelRole.SuggestedMaxFeesPerGasLowLevel.int: "suggestedMaxFeesPerGasLowLevel",
      ModelRole.SuggestedPriorityFeePerGasLowLevel.int: "suggestedPriorityFeePerGasLowLevel",
      ModelRole.SuggestedEstimatedTimeLowLevel.int: "suggestedEstimatedTimeLowLevel",
      ModelRole.SuggestedMaxFeesPerGasMediumLevel.int: "suggestedMaxFeesPerGasMediumLevel",
      ModelRole.SuggestedPriorityFeePerGasMediumLevel.int: "suggestedPriorityFeePerGasMediumLevel",
      ModelRole.SuggestedEstimatedTimeMediumLevel.int: "suggestedEstimatedTimeMediumLevel",
      ModelRole.SuggestedMaxFeesPerGasHighLevel.int: "suggestedMaxFeesPerGasHighLevel",
      ModelRole.SuggestedPriorityFeePerGasHighLevel.int: "suggestedPriorityFeePerGasHighLevel",
      ModelRole.SuggestedEstimatedTimeHighLevel.int: "suggestedEstimatedTimeHighLevel",
      ModelRole.SuggestedMinPriorityFee.int: "suggestedMinPriorityFee",
      ModelRole.SuggestedMaxPriorityFee.int: "suggestedMaxPriorityFee",
      ModelRole.CurrentBaseFee.int: "currentBaseFee",
      ModelRole.SuggestedTxNonce.int: "suggestedTxNonce",
      ModelRole.SuggestedTxGasAmount.int: "suggestedTxGasAmount",
      ModelRole.SuggestedApprovalTxNonce.int: "suggestedApprovalTxNonce",
      ModelRole.SuggestedApprovalGasAmount.int: "suggestedApprovalGasAmount",
      ModelRole.TxNonce.int: "txNonce",
      ModelRole.TxGasPrice.int: "txGasPrice",
      ModelRole.TxGasFeeMode.int: "txGasFeeMode",
      ModelRole.TxMaxFeesPerGas.int: "txMaxFeesPerGas",
      ModelRole.TxBaseFee.int: "txBaseFee",
      ModelRole.TxPriorityFee.int: "txPriorityFee",
      ModelRole.TxGasAmount.int: "txGasAmount",
      ModelRole.TxBonderFees.int: "txBonderFees",
      ModelRole.TxTokenFees.int: "txTokenFees",
      ModelRole.TxEstimatedTime.int: "txEstimatedTime",
      ModelRole.TxFee.int: "txFee",
      ModelRole.TxL1Fee.int: "txL1Fee",
      ModelRole.TxTotalFee.int: "txTotalFee",
      ModelRole.ApprovalRequired.int: "approvalRequired",
      ModelRole.ApprovalAmountRequired.int: "approvalAmountRequired",
      ModelRole.ApprovalContractAddress.int: "approvalContractAddress",
      ModelRole.ApprovalTxNonce.int: "approvalTxNonce",
      ModelRole.ApprovalGasPrice.int: "approvalGasPrice",
      ModelRole.ApprovalGasFeeMode.int: "approvalGasFeeMode",
      ModelRole.ApprovalMaxFeesPerGas.int: "approvalMaxFeesPerGas",
      ModelRole.ApprovalBaseFee.int: "approvalBaseFee",
      ModelRole.ApprovalPriorityFee.int: "approvalPriorityFee",
      ModelRole.ApprovalGasAmount.int: "approvalGasAmount",
      ModelRole.ApprovalEstimatedTime.int: "approvalEstimatedTime",
      ModelRole.ApprovalFee.int: "approvalFee",
      ModelRole.ApprovalL1Fee.int: "approvalL1Fee",
      ModelRole.EstimatedTime.int: "estimatedTime"
    }.toTable

  proc setItems*(self: PathModel, items: seq[PathItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  method data(self: PathModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Index:
      result = newQVariant(index.row)
    of ModelRole.ProcessorName:
      result = newQVariant(item.processorName)
    of ModelRole.FromChain:
      result = newQVariant(item.fromChain)
    of ModelRole.FromChainEIP1559Compliant:
      result = newQVariant(item.fromChainEIP1559Compliant)
    of ModelRole.FromChainNoBaseFee:
      result = newQVariant(item.fromChainNoBaseFee)
    of ModelRole.FromChainNoPriorityFee:
      result = newQVariant(item.fromChainNoPriorityFee)
    of ModelRole.ToChain:
      result = newQVariant(item.toChain)
    of ModelRole.FromToken:
      result = newQVariant(item.fromToken)
    of ModelRole.ToToken:
      result = newQVariant(item.toToken)
    of ModelRole.AmountIn:
      result = newQVariant(item.amountIn)
    of ModelRole.AmountInLocked:
      result = newQVariant(item.amountInLocked)
    of ModelRole.AmountOut:
      result = newQVariant(item.amountOut)
    of ModelRole.SuggestedNonEIP1559GasPrice:
      result = newQVariant(item.suggestedNonEIP1559GasPrice)
    of ModelRole.SuggestedNonEIP1559EstimatedTime:
      result = newQVariant(item.suggestedNonEIP1559EstimatedTime)
    of ModelRole.SuggestedMaxFeesPerGasLowLevel:
      result = newQVariant(item.suggestedMaxFeesPerGasLowLevel)
    of ModelRole.SuggestedPriorityFeePerGasLowLevel:
      result = newQVariant(item.suggestedPriorityFeePerGasLowLevel)
    of ModelRole.SuggestedEstimatedTimeLowLevel:
      result = newQVariant(item.suggestedEstimatedTimeLowLevel)
    of ModelRole.SuggestedMaxFeesPerGasMediumLevel:
      result = newQVariant(item.suggestedMaxFeesPerGasMediumLevel)
    of ModelRole.SuggestedPriorityFeePerGasMediumLevel:
      result = newQVariant(item.suggestedPriorityFeePerGasMediumLevel)
    of ModelRole.SuggestedEstimatedTimeMediumLevel:
      result = newQVariant(item.suggestedEstimatedTimeMediumLevel)
    of ModelRole.SuggestedMaxFeesPerGasHighLevel:
      result = newQVariant(item.suggestedMaxFeesPerGasHighLevel)
    of ModelRole.SuggestedPriorityFeePerGasHighLevel:
      result = newQVariant(item.suggestedPriorityFeePerGasHighLevel)
    of ModelRole.SuggestedEstimatedTimeHighLevel:
      result = newQVariant(item.suggestedEstimatedTimeHighLevel)
    of ModelRole.SuggestedMinPriorityFee:
      result = newQVariant(item.suggestedMinPriorityFee)
    of ModelRole.SuggestedMaxPriorityFee:
      result = newQVariant(item.suggestedMaxPriorityFee)
    of ModelRole.CurrentBaseFee:
      result = newQVariant(item.currentBaseFee)
    of ModelRole.SuggestedTxNonce:
      result = newQVariant(item.suggestedTxNonce)
    of ModelRole.SuggestedTxGasAmount:
      result = newQVariant(item.suggestedTxGasAmount)
    of ModelRole.SuggestedApprovalTxNonce:
      result = newQVariant(item.suggestedApprovalTxNonce)
    of ModelRole.SuggestedApprovalGasAmount:
      result = newQVariant(item.suggestedApprovalGasAmount)
    of ModelRole.TxNonce:
      result = newQVariant(item.txNonce)
    of ModelRole.TxGasPrice:
      result = newQVariant(item.txGasPrice)
    of ModelRole.TxGasFeeMode:
      result = newQVariant(item.txGasFeeMode)
    of ModelRole.TxMaxFeesPerGas:
      result = newQVariant(item.txMaxFeesPerGas)
    of ModelRole.TxBaseFee:
      result = newQVariant(item.txBaseFee)
    of ModelRole.TxPriorityFee:
      result = newQVariant(item.txPriorityFee)
    of ModelRole.TxGasAmount:
      result = newQVariant(item.txGasAmount)
    of ModelRole.TxBonderFees:
      result = newQVariant(item.txBonderFees)
    of ModelRole.TxTokenFees:
      result = newQVariant(item.txTokenFees)
    of ModelRole.TxEstimatedTime:
      result = newQVariant(item.txEstimatedTime)
    of ModelRole.TxFee:
      result = newQVariant(item.txFee)
    of ModelRole.TxL1Fee:
      result = newQVariant(item.txL1Fee)
    of ModelRole.TxTotalFee:
      result = newQVariant(item.txTotalFee)
    of ModelRole.ApprovalRequired:
      result = newQVariant(item.approvalRequired)
    of ModelRole.ApprovalAmountRequired:
      result = newQVariant(item.approvalAmountRequired)
    of ModelRole.ApprovalContractAddress:
      result = newQVariant(item.approvalContractAddress)
    of ModelRole.ApprovalTxNonce:
      result = newQVariant(item.approvalTxNonce)
    of ModelRole.ApprovalGasPrice:
      result = newQVariant(item.approvalGasPrice)
    of ModelRole.ApprovalGasFeeMode:
      result = newQVariant(item.approvalGasFeeMode)
    of ModelRole.ApprovalMaxFeesPerGas:
      result = newQVariant(item.approvalMaxFeesPerGas)
    of ModelRole.ApprovalBaseFee:
      result = newQVariant(item.approvalBaseFee)
    of ModelRole.ApprovalPriorityFee:
      result = newQVariant(item.approvalPriorityFee)
    of ModelRole.ApprovalGasAmount:
      result = newQVariant(item.approvalGasAmount)
    of ModelRole.ApprovalEstimatedTime:
      result = newQVariant(item.approvalEstimatedTime)
    of ModelRole.ApprovalFee:
      result = newQVariant(item.approvalFee)
    of ModelRole.ApprovalL1Fee:
      result = newQVariant(item.approvalL1Fee)
    of ModelRole.EstimatedTime:
      result = newQVariant(item.estimatedTime)
    else:
      discard

  proc delete(self: PathModel) =
    self.QAbstractListModel.delete

  proc setup(self: PathModel) =
    self.QAbstractListModel.setup

