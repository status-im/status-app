import stint

import backend/backend
import backend/eth

import app_service/service/eth/utils as eth_utils
import app_service/service/transaction/dto_conversion

type
  AsyncGetEstimatedTimeArgs = ref object of QObjectTaskArg
    topic: string
    chainId: int
    maxFeePerGasHex: string

  AsyncSuggestedFeesArgs = ref object of QObjectTaskArg
    topic: string
    chainId: int

  AsyncEstimateGasArgs = ref object of QObjectTaskArg
    topic: string
    chainId: int
    txJson: JsonNode

proc asyncGetEstimatedTimeTask(argsEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncGetEstimatedTimeArgs](argsEncoded)
  let result = %*{
    "topic": arg.topic,
    "chainId": arg.chainId,
    "estimatedTime": EstimatedTime.Unknown.int,
  }
  try:
    var maxFeePerGasWeiHex: string
    if arg.maxFeePerGasHex.isEmptyOrWhitespace:
      let chainFeesResult = eth.suggestedFees(arg.chainId).result
      let chainFees = chainFeesResult.toSuggestedFeesDto()
      if chainFees.isNil:
        raise newException(Exception, "chainFees is nil")

      # For non-EIP-1559 chains, we use the high fee
      let maxFeePerGasGwei = if chainFees.eip1559Enabled: chainFees.maxFeePerGasM
                             else: chainFees.maxFeePerGasL
      maxFeePerGasWeiHex = eth_utils.gweiToWeiHexValue(maxFeePerGasGwei)
    else:
      try:
        maxFeePerGasWeiHex = eth_utils.normalizedWeiHexValue(arg.maxFeePerGasHex)
      except ValueError:
        raise newException(Exception, "failed to parse maxFeePerGasHex " & arg.maxFeePerGasHex)

    let seconds = backend.getTransactionEstimatedTimeV2(arg.chainId, "0x0", maxFeePerGasWeiHex, "0x0").result.getInt
    result["estimatedTime"] = %estimatedTimeFlagFromSeconds(seconds).int
  except Exception as e:
    error "asyncGetEstimatedTime failed: ", msg=e.msg
  arg.finish(result)

proc asyncSuggestedFeesTask(argsEncoded: string) {.gcsafe, nimcall.} =
    let arg = decode[AsyncSuggestedFeesArgs](argsEncoded)
    let result = %*{
        "topic": arg.topic,
        "chainId": arg.chainId,
        "suggestedFees": %*{},
    }
    try:
        let response = eth.suggestedFees(arg.chainId)
        result["suggestedFees"] = response.result
        arg.finish(result)
    except Exception as e:
        error "asyncSuggestedFees failed: ", msg=e.msg
        arg.finish(result)

proc asyncEstimateGasTask(argsEncoded: string) {.gcsafe, nimcall.} =
    let arg = decode[AsyncEstimateGasArgs](argsEncoded)
    let result = %*{
        "topic": arg.topic,
        "chainId": arg.chainId,
        "estimatedGas": "",
    }
    try:
        let tx = arg.txJson
        let transaction = %*{
            "from": tx["from"].getStr,
            "to": tx["to"].getStr
        }
        if tx.hasKey("data"):
            transaction["data"] = tx["data"]
        if tx.hasKey("value"):
            transaction["value"] = tx["value"]

        let response = eth.estimateGas(arg.chainId, transaction)
        result["estimatedGas"] = response.result
        arg.finish(result)
    except Exception as e:
        error "asyncGasLimit failed: ", msg=e.msg
        arg.finish(result)