# import json, json_serialization, stint

# import ../network/dto, ../token/dto

# include  app_service/common/json_utils

import json, strutils, stint, json_serialization, chronicles
import sequtils, sugar

import
  web3/eth_api_types

include  ../../common/json_utils
import backend/network_types, ../token/dto/token

type
  SuggestedNonEIP1559Fees* = ref object
    gasPrice*: UInt256
    estimatedTime*: int

type
  SuggestedLevelsForMaxFeesPerGasDto* = ref object
    low*: UInt256
    lowPriority*: UInt256
    lowEstimatedTime*: int
    medium*: UInt256
    mediumPriority*: UInt256
    mediumEstimatedTime*: int
    high*: UInt256
    highPriority*: UInt256
    highEstimatedTime*: int

type
  TransactionPathDtoV2* = ref object
    routerInputParamsUuid*: string
    processorName*: string
    tool*: string
    fromChain*: NetworkDto
    toChain*: NetworkDto
    fromToken*: TokenDto
    toToken*: TokenDto
    amountIn*: UInt256
    amountInLocked*: bool
    amountOut*: UInt256

    suggestedNonEIP1559Fees*: SuggestedNonEIP1559Fees
    suggestedLevelsForMaxFeesPerGas*: SuggestedLevelsForMaxFeesPerGasDto
    maxFeesPerGas*: UInt256
    suggestedMinPriorityFee*: UInt256
    suggestedMaxPriorityFee*: UInt256
    currentBaseFee*: UInt256
    suggestedTxNonce*: UInt256
    suggestedTxGasAmount*: uint64
    suggestedApprovalTxNonce*: UInt256
    suggestedApprovalGasAmount*: uint64
    usedContractAddress*: string

    txNonce*: UInt256
    txGasPrice*: UInt256
    txGasFeeMode*: int
    txMaxFeesPerGas*: UInt256
    txBaseFee*: UInt256
    txPriorityFee*: UInt256
    txGasAmount*: uint64
    txBonderFees*: UInt256
    txTokenFees*: UInt256
    txEstimatedTime*: int

    txFee*: UInt256
    txL1Fee*: UInt256

    approvalRequired*: bool
    approvalAmountRequired*: UInt256
    approvalContractAddress*: string
    approvalTxNonce*: UInt256
    approvalGasPrice*: UInt256
    approvalGasFeeMode*: int
    approvalMaxFeesPerGas*: UInt256
    approvalBaseFee*: UInt256
    approvalPriorityFee*: UInt256
    approvalGasAmount*: uint64
    approvalEstimatedTime*: int

    approvalFee*: UInt256
    approvalL1Fee*: UInt256

    txTotalFee*: UInt256

proc toSuggestedNonEIP1559Fees*(jsonObj: JsonNode): SuggestedNonEIP1559Fees =
  result = SuggestedNonEIP1559Fees()
  var value: string
  if jsonObj.getProp("gasPrice", value):
    result.gasPrice = stint.fromHex(UInt256, $value)
  discard jsonObj.getProp("estimatedTime", result.estimatedTime)

proc toSuggestedLevelsForMaxFeesPerGasDto*(jsonObj: JsonNode): SuggestedLevelsForMaxFeesPerGasDto =
  result = SuggestedLevelsForMaxFeesPerGasDto()
  var value: string
  if jsonObj.getProp("low", value):
    result.low = stint.fromHex(UInt256, $value)
  if jsonObj.getProp("lowPriority", value):
    result.lowPriority = stint.fromHex(UInt256, $value)
  discard jsonObj.getProp("lowEstimatedTime", result.lowEstimatedTime)
  if jsonObj.getProp("medium", value):
    result.medium = stint.fromHex(UInt256, $value)
  if jsonObj.getProp("mediumPriority", value):
    result.mediumPriority = stint.fromHex(UInt256, $value)
  discard jsonObj.getProp("mediumEstimatedTime", result.mediumEstimatedTime)
  if jsonObj.getProp("high", value):
    result.high = stint.fromHex(UInt256, $value)
  if jsonObj.getProp("highPriority", value):
    result.highPriority = stint.fromHex(UInt256, $value)
  discard jsonObj.getProp("highEstimatedTime", result.highEstimatedTime)

proc toTransactionPathDtoV2*(jsonObj: JsonNode): TransactionPathDtoV2 =
  result = TransactionPathDtoV2()
  discard jsonObj.getProp("RouterInputParamsUuid", result.routerInputParamsUuid)
  discard jsonObj.getProp("ProcessorName", result.processorName)
  discard jsonObj.getProp("Tool", result.tool)
  result.fromChain = Json.decode($jsonObj["FromChain"], NetworkDto, allowUnknownFields = true)
  result.toChain = Json.decode($jsonObj["ToChain"], NetworkDto, allowUnknownFields = true)
  result.fromToken = Json.decode($jsonObj["FromToken"], TokenDto, allowUnknownFields = true)
  result.toToken = Json.decode($jsonObj["ToToken"], TokenDto, allowUnknownFields = true)
  result.amountIn = stint.fromHex(UInt256, jsonObj{"AmountIn"}.getStr)
  discard jsonObj.getProp("AmountInLocked", result.amountInLocked)
  result.amountOut = stint.fromHex(UInt256, jsonObj{"AmountOut"}.getStr)
  result.suggestedNonEIP1559Fees = jsonObj["SuggestedNonEIP1559Fees"].toSuggestedNonEIP1559Fees()
  result.suggestedLevelsForMaxFeesPerGas = jsonObj["SuggestedLevelsForMaxFeesPerGas"].toSuggestedLevelsForMaxFeesPerGasDto()
  result.maxFeesPerGas = stint.fromHex(UInt256, jsonObj{"MaxFeesPerGas"}.getStr)
  result.suggestedMinPriorityFee = stint.fromHex(UInt256, jsonObj{"SuggestedMinPriorityFee"}.getStr)
  result.suggestedMaxPriorityFee = stint.fromHex(UInt256, jsonObj{"SuggestedMaxPriorityFee"}.getStr)
  result.currentBaseFee = stint.fromHex(UInt256, jsonObj{"CurrentBaseFee"}.getStr)
  result.suggestedTxNonce = stint.fromHex(UInt256, jsonObj{"SuggestedTxNonce"}.getStr)
  discard jsonObj.getProp("SuggestedTxGasAmount", result.suggestedTxGasAmount)
  result.suggestedApprovalTxNonce = stint.fromHex(UInt256, jsonObj{"SuggestedApprovalTxNonce"}.getStr)
  discard jsonObj.getProp("SuggestedApprovalGasAmount", result.suggestedApprovalGasAmount)
  discard jsonObj.getProp("UsedContractAddress", result.usedContractAddress)
  result.txNonce = stint.fromHex(UInt256, jsonObj{"TxNonce"}.getStr)
  result.txGasPrice = stint.fromHex(UInt256, jsonObj{"TxGasPrice"}.getStr)
  discard jsonObj.getProp("TxGasFeeMode", result.txGasFeeMode)
  result.txMaxFeesPerGas = stint.fromHex(UInt256, jsonObj{"TxMaxFeesPerGas"}.getStr)
  result.txBaseFee = stint.fromHex(UInt256, jsonObj{"TxBaseFee"}.getStr)
  result.txPriorityFee = stint.fromHex(UInt256, jsonObj{"TxPriorityFee"}.getStr)
  discard jsonObj.getProp("TxGasAmount", result.txGasAmount)
  result.txBonderFees = stint.fromHex(UInt256, jsonObj{"TxBonderFees"}.getStr)
  result.txTokenFees = stint.fromHex(UInt256, jsonObj{"TxTokenFees"}.getStr)
  discard jsonObj.getProp("TxEstimatedTime", result.txEstimatedTime)
  result.txFee = stint.fromHex(UInt256, jsonObj{"TxFee"}.getStr)
  result.txL1Fee = stint.fromHex(UInt256, jsonObj{"TxL1Fee"}.getStr)
  discard jsonObj.getProp("ApprovalRequired", result.approvalRequired)
  result.approvalAmountRequired = stint.fromHex(UInt256, jsonObj{"ApprovalAmountRequired"}.getStr)
  discard jsonObj.getProp("ApprovalContractAddress", result.approvalContractAddress)
  result.approvalTxNonce = stint.fromHex(UInt256, jsonObj{"ApprovalTxNonce"}.getStr)
  result.approvalGasPrice = stint.fromHex(UInt256, jsonObj{"ApprovalGasPrice"}.getStr)
  discard jsonObj.getProp("ApprovalGasFeeMode", result.approvalGasFeeMode)
  result.approvalMaxFeesPerGas = stint.fromHex(UInt256, jsonObj{"ApprovalMaxFeesPerGas"}.getStr)
  result.approvalBaseFee = stint.fromHex(UInt256, jsonObj{"ApprovalBaseFee"}.getStr)
  result.approvalPriorityFee = stint.fromHex(UInt256, jsonObj{"ApprovalPriorityFee"}.getStr)
  discard jsonObj.getProp("ApprovalGasAmount", result.approvalGasAmount)
  discard jsonObj.getProp("ApprovalEstimatedTime", result.approvalEstimatedTime)
  result.approvalFee = stint.fromHex(UInt256, jsonObj{"ApprovalFee"}.getStr)
  result.approvalL1Fee = stint.fromHex(UInt256, jsonObj{"ApprovalL1Fee"}.getStr)
  result.txTotalFee = stint.fromHex(UInt256, jsonObj{"TxTotalFee"}.getStr)

proc toTransactionPathsDtoV2*(jsonObj: JsonNode): seq[TransactionPathDtoV2] =
  return jsonObj.getElems().map(x => x.toTransactionPathDtoV2())

proc toTransactionPathsDtoV2*(rawPaths: string): seq[TransactionPathDtoV2] =
  return rawPaths.parseJson.toTransactionPathsDtoV2()
