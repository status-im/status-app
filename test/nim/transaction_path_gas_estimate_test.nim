## The router reports the node's raw gas estimates next to its buffered
## suggestions; the send modal uses them as the minimum custom gas amount.
## A route whose gas estimate expired before signing comes back as WT-005,
## which the send modal handles by fetching the route again.

import unittest, json, strutils

import app_service/service/transaction/dtoV2
import app_service/service/transaction/router_transactions_dto

const networkJson = """{
  "chainId": 42161, "chainName": "Arbitrum", "blockExplorerUrl": "https://arbiscan.io/",
  "iconUrl": "network/arbitrum", "nativeCurrencyName": "Ether", "nativeCurrencySymbol": "ETH",
  "nativeCurrencyDecimals": 18, "isTest": false, "layer": 2, "enabled": true,
  "chainColor": "#51D0F0", "shortName": "arb1", "relatedChainId": 421614,
  "isActive": true, "isDeactivatable": true, "eip1559Enabled": true
}"""

const tokenJson = """{
  "crossChainId": "eth-native", "chainId": 42161,
  "address": "0x0000000000000000000000000000000000000000", "decimals": 18,
  "name": "Ethereum", "symbol": "ETH", "logoUri": "", "custom": false
}"""

# A trimmed wallet.suggested.routes path; estimatesJson is spliced in, so it can be absent.
proc makePathJson(estimatesJson: string): string =
  result = """{
    "RouterInputParamsUuid": "test-uuid", "ProcessorName": "LiFi", "Tool": "across",
    "FromChain": $1, "ToChain": $1, "FromToken": $2, "ToToken": $2,
    "AmountIn": "0x1bf5b92a61e000", "AmountInLocked": false, "AmountOut": "0x1bae0c8d37c8d9",
    "SuggestedNonEIP1559Fees": null,
    "SuggestedLevelsForMaxFeesPerGas": {
      "low": "0x1391e33", "lowPriority": "0x0", "lowEstimatedTime": 0,
      "medium": "0x4e478cf", "mediumPriority": "0x0", "mediumEstimatedTime": 0,
      "high": "0xc3b2e08", "highPriority": "0x0", "highEstimatedTime": 0
    },
    "MaxFeesPerGas": "0x0", "SuggestedMinPriorityFee": "0x0", "SuggestedMaxPriorityFee": "0x0",
    "CurrentBaseFee": "0x1317b20", "SuggestedTxNonce": "0x80", "SuggestedTxGasAmount": 228990,
    "SuggestedApprovalTxNonce": "0x0", "SuggestedApprovalGasAmount": 48300,$3
    "UsedContractAddress": "0x1231deb6f5749ef6ce6943a275a1d3e7486f4eae",
    "TxNonce": "0x80", "TxGasPrice": "0x0", "TxGasFeeMode": 0,
    "TxMaxFeesPerGas": "0x1391e33", "TxBaseFee": "0x1317b20", "TxPriorityFee": "0x0",
    "TxGasAmount": 228990, "TxBonderFees": "0x0", "TxTokenFees": "0x0",
    "TxEstimatedTime": 72,
    "TxFee": "0x4461192f71a", "TxL1Fee": "0x0",
    "ApprovalRequired": false, "ApprovalAmountRequired": "0x0",
    "ApprovalContractAddress": "0x1231deb6f5749ef6ce6943a275a1d3e7486f4eae",
    "ApprovalTxNonce": "0x0", "ApprovalGasPrice": "0x0", "ApprovalGasFeeMode": 0,
    "ApprovalMaxFeesPerGas": "0x0", "ApprovalBaseFee": "0x0", "ApprovalPriorityFee": "0x0",
    "ApprovalGasAmount": 0, "ApprovalEstimatedTime": 0,
    "ApprovalFee": "0x0", "ApprovalL1Fee": "0x0", "TxTotalFee": "0x4461192f71a"
  }""" % [networkJson, tokenJson, estimatesJson]

suite "route path gas estimates":

  test "raw estimates are parsed next to the suggestions":
    let path = makePathJson("""
      "EstimatedTxGasAmount": 218085, "EstimatedApprovalGasAmount": 46000,""").parseJson.toTransactionPathDtoV2()
    check path.suggestedTxGasAmount == 228990'u64
    check path.estimatedTxGasAmount == 218085'u64
    check path.suggestedApprovalGasAmount == 48300'u64
    check path.estimatedApprovalGasAmount == 46000'u64

  test "values beyond int32 survive":
    let path = makePathJson("""
      "EstimatedTxGasAmount": 4294967295, "EstimatedApprovalGasAmount": 0,""").parseJson.toTransactionPathDtoV2()
    check path.estimatedTxGasAmount == 4_294_967_295'u64

  test "missing estimates (older status-go) default to 0, i.e. no minimum":
    let path = makePathJson("").parseJson.toTransactionPathDtoV2()
    check path.estimatedTxGasAmount == 0'u64
    check path.estimatedApprovalGasAmount == 0'u64

suite "route gas estimate expired error":

  test "WT-005 is recognised":
    check ErrorResponse(code: ErrCodeRouteGasEstimateExpired, details: "out of date").isRouteGasEstimateExpired()

  test "other errors are not":
    check not ErrorResponse(code: "WT-001", details: "no generated route").isRouteGasEstimateExpired()
    check not ErrorResponse(nil).isRouteGasEstimateExpired()
