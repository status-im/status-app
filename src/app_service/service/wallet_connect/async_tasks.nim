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

  AsyncTxWorkArgs = ref object of QObjectTaskArg
    key: string
    kind: string
    chainId: int
    txJson: string
    signature: string

proc buildTransaction(chainId: int, txJson: string): tuple[txToSign: string, txData: JsonNode] =
  var buildTxResponse: JsonNode
  let err = wallet.buildTransaction(buildTxResponse, chainId, txJson)
  if err.len > 0:
    error "status-go - wallet_buildTransaction failed", err=err
    return
  if buildTxResponse.isNil or buildTxResponse.kind != JsonNodeKind.JObject or
    not buildTxResponse.hasKey("txArgs") or not buildTxResponse.hasKey("messageToSign"):
      error "unexpected wallet_buildTransaction response"
      return
  let txToSign = buildTxResponse["messageToSign"].getStr
  if txToSign.len != wallet_constants.TX_HASH_LEN_WITH_PREFIX:
    error "unexpected tx hash length"
    return
  return (txToSign, buildTxResponse["txArgs"])

proc buildRawTransaction(chainId: int, txData: string, signature: string): string =
  var txResponse: JsonNode
  let err = wallet.buildRawTransaction(txResponse, chainId, txData, signature)
  if err.len > 0:
    error "status-go - wallet_buildRawTransaction failed", err=err
    return
  if txResponse.isNil or txResponse.kind != JsonNodeKind.JObject or not txResponse.hasKey("rawTx"):
    error "unexpected wallet_buildRawTransaction response"
    return
  return txResponse["rawTx"].getStr

proc sendTransactionWithSignature(chainId: int, txData: string, signature: string): string =
  var txResponse: JsonNode
  let err = wallet.sendTransactionWithSignature(txResponse,
    chainId,
    $PendingTransactionTypeDto.WalletConnectTransfer,
    txData,
    if signature.startsWith("0x"): signature[2..^1] else: signature)
  if err.len > 0:
    error "status-go - sendTransactionWithSignature failed", err=err
    return ""
  if txResponse.isNil or txResponse.kind != JsonNodeKind.JString:
    error "unexpected sendTransactionWithSignature response"
    return ""
  return txResponse.getStr

proc asyncTxWorkTask(argsEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncTxWorkArgs](argsEncoded)
  let result = %*{
    "key": arg.key,
    "kind": arg.kind,
    "txToSign": "",
    "txData": newJNull(),
    "data": "",
    "error": "",
  }
  try:
    case arg.kind
    of "build":
      let (txToSign, txData) = buildTransaction(arg.chainId, arg.txJson)
      if txToSign.len == 0 or txData.isNil:
        result["error"] = %"building transaction failed"
      else:
        result["txToSign"] = %txToSign
        result["txData"] = txData
    of "buildRaw":
      result["data"] = %buildRawTransaction(arg.chainId, arg.txJson, arg.signature)
    of "send":
      result["data"] = %sendTransactionWithSignature(arg.chainId, arg.txJson, arg.signature)
    else:
      result["error"] = %("unknown tx work kind: " & arg.kind)
  except Exception as e:
    error "asyncTxWorkTask failed: ", kind=arg.kind, msg=e.msg
    result["error"] = %e.msg
  arg.finish(result)

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