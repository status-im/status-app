## Tests that the provider-reported route execution duration (e.g. LI.FI
## bridging time) is parsed from the router's path payload and included in
## the estimated-time bucket shown by the UI, on top of the gas-based
## source-chain inclusion estimate.

import unittest, json, strutils

import app_service/service/transaction/dto
import app_service/service/transaction/dtoV2
import app_service/service/transaction/dto_conversion

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

# Mirrors the wallet.suggested.routes event payload (trimmed to the fields the
# parser reads). routeExecutionDurationJson is spliced in whole so the
# field-absent case can be exercised too.
proc makePathJson(txEstimatedTime, approvalEstimatedTime: int, routeExecutionDurationJson: string): string =
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
    "SuggestedApprovalTxNonce": "0x0", "SuggestedApprovalGasAmount": 0,
    "UsedContractAddress": "0x1231deb6f5749ef6ce6943a275a1d3e7486f4eae",
    "TxNonce": "0x80", "TxGasPrice": "0x0", "TxGasFeeMode": 0,
    "TxMaxFeesPerGas": "0x1391e33", "TxBaseFee": "0x1317b20", "TxPriorityFee": "0x0",
    "TxGasAmount": 228990, "TxBonderFees": "0x0", "TxTokenFees": "0x0",
    "TxEstimatedTime": $3,$5
    "TxFee": "0x4461192f71a", "TxL1Fee": "0x0",
    "ApprovalRequired": false, "ApprovalAmountRequired": "0x0",
    "ApprovalContractAddress": "0x1231deb6f5749ef6ce6943a275a1d3e7486f4eae",
    "ApprovalTxNonce": "0x0", "ApprovalGasPrice": "0x0", "ApprovalGasFeeMode": 0,
    "ApprovalMaxFeesPerGas": "0x0", "ApprovalBaseFee": "0x0", "ApprovalPriorityFee": "0x0",
    "ApprovalGasAmount": 0, "ApprovalEstimatedTime": $4,
    "ApprovalFee": "0x0", "ApprovalL1Fee": "0x0", "TxTotalFee": "0x4461192f71a"
  }""" % [networkJson, tokenJson, $txEstimatedTime, $approvalEstimatedTime, routeExecutionDurationJson]

proc parsePath(txEstimatedTime, approvalEstimatedTime, routeExecutionDuration: int): TransactionPathDtoV2 =
  makePathJson(txEstimatedTime, approvalEstimatedTime,
               " \"RouteExecutionDuration\": " & $routeExecutionDuration & ",").parseJson.toTransactionPathDtoV2()

proc timeBucket(txEstimatedTime, approvalEstimatedTime, routeExecutionDuration: int): EstimatedTime =
  let converted = convertToOldRoute(@[parsePath(txEstimatedTime, approvalEstimatedTime, routeExecutionDuration)])
  check converted.len == 1
  return EstimatedTime(converted[0].estimatedTime)

suite "route estimated time bucketing":

  test "RouteExecutionDuration is parsed from the payload":
    check parsePath(72, 0, 420).routeExecutionDuration == 420

  test "missing RouteExecutionDuration defaults to 0":
    let path = makePathJson(72, 0, "").parseJson.toTransactionPathDtoV2()
    check path.routeExecutionDuration == 0

  test "no route duration keeps the inclusion-only bucket":
    # 72s inclusion estimate alone (typical mainnet medium-fee case)
    check timeBucket(72, 0, 0) == EstimatedTime.LessThanTwoMins

  test "route duration extends the bucket":
    # same inclusion estimate, but a 7-minute bridge on top
    check timeBucket(72, 0, 420) == EstimatedTime.MoreThanFiveMins

  test "all three components are summed":
    # 50 + 40 + 100 = 190s; each alone would bucket lower
    check timeBucket(50, 40, 100) == EstimatedTime.LessThanFourMins

  test "short route duration can keep a low bucket":
    check timeBucket(20, 0, 30) == EstimatedTime.LessThanOneMin # 50s in total

  test "bucket boundaries":
    check timeBucket(29, 0, 0) == EstimatedTime.LessThanThirtySecs
    check timeBucket(30, 0, 0) == EstimatedTime.LessThanOneMin
    check timeBucket(119, 0, 0) == EstimatedTime.LessThanTwoMins
    check timeBucket(120, 0, 0) == EstimatedTime.LessThanThreeMins
    check timeBucket(239, 0, 0) == EstimatedTime.LessThanFourMins
    check timeBucket(240, 0, 0) == EstimatedTime.LessThanFiveMins
    check timeBucket(300, 0, 0) == EstimatedTime.LessThanFiveMins # inclusive upper bound
    check timeBucket(301, 0, 0) == EstimatedTime.MoreThanFiveMins

  test "zero everything stays unknown":
    check timeBucket(0, 0, 0) == EstimatedTime.Unknown
