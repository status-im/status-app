import json, tables, json_serialization, chronicles
import core, response_type
from ./gen import rpc

import status_go
from app_service/common/account_constants import ZERO_ADDRESS

include common

export response_type

const
    GasFeeLow* = 0
    GasFeeMedium* = 1
    GasFeeHigh* = 2
    GasFeeCustom* = 3

const
  ExtraKeyUsername* = "username"
  ExtraKeyPublicKey* = "publicKey"
  ExtraKeyPackId* = "packID"

  ExtraKeys = @[ExtraKeyUsername, ExtraKeyPublicKey, ExtraKeyPackId]

rpc(signMessage, "wallet"):
  message: string
  address: string
  hashedPassword: string

rpc(buildTransaction, "wallet"):
  chainId: int
  sendTxArgsJson: string

rpc(buildRawTransaction, "wallet"):
  chainId: int
  sendTxArgsJson: string
  signature: string

rpc(sendTransactionWithSignature, "wallet"):
  chainId: int
  txType: string
  sendTxArgsJson: string
  signature: string


## Signs the provided message with the provided account using the provided hashed password, performs `crypto.Sign`
## `resultOut` represents a json object that contains the signature if the call was successful, or `nil`
## `message` is the message to sign
## `address` is the address to sign with
## `hashedPassword` is the hashed password to sign with
## returns the error message if any, or an empty string
proc signMessage*(resultOut: var JsonNode, message: string, address: string, hashedPassword: string): string =
  try:
    let response = signMessage(message, address, hashedPassword)
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error signing message", err = e.msg
    return e.msg


## Builds the tx with the provided tx args and chain id
## `resultOut` represents a json object that corresponds to the status go `transfer.TxResponse` type, or `nil` if the call was unsuccessful
## `chainId` is the chain id of the network
## `txArgsJSON` is the json string of the tx, corresponds to the status go `transactions.SendTxArgs` type
## returns the error message if any, or an empty string
proc buildTransaction*(resultOut: var JsonNode, chainId: int, sendTxArgsJson: string): string =
  try:
    let response = buildTransaction(chainId, sendTxArgsJson)
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error building transaction", err = e.msg
    return e.msg


## Builds the raw tx with the provided tx args, chain id and signature
## `resultOut` represents a json object that corresponds to the status go `transfer.TxResponse` type, or `nil` if the call was unsuccessful
## `chainId` is the chain id of the network
## `txArgsJSON` is the json string of the tx, corresponds to the status go `transactions.SendTxArgs` type
## `signature` is the signature of the tx
## returns the error message if any, or an empty string
proc buildRawTransaction*(resultOut: var JsonNode, chainId: int, sendTxArgsJson: string, signature: string): string =
  try:
    let response = buildRawTransaction(chainId, sendTxArgsJson, signature)
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error building raw transaction", err = e.msg
    return e.msg

## Sends the tx with signature on provided chain, setting tx type
## `resultOut` represents a json object that contains the tx hash if the call was successful, or `nil`
## `chainId` is the chain id of the network
## `txType` is the type of the tx, corresponds to the status go `transactions.PendingTrxType` type
## `txArgsJSON` is the json string of the tx, corresponding to the status go `transactions.SendTxArgs` type
## `signature` is the signature of the tx
## returns the error message if any, or an empty string
proc sendTransactionWithSignature*(resultOut: var JsonNode, chainId: int, txType: string, sendTxArgsJson: string,
  signature: string): string =
  try:
    let response = sendTransactionWithSignature(chainId, txType, sendTxArgsJson, signature)
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error sending transaction", err =  e.msg
    return e.msg

proc hashTypedData*(resultOut: var JsonNode, data: string): string =
  try:
    let rawResponse = status_go.hashTypedData(data)
    var response = Json.decode(rawResponse, RpcResponse[JsonNode])
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error hashing data", err = e.msg
    return e.msg

proc hashTypedDataV4*(resultOut: var JsonNode, data: string): string =
  try:
    let rawResponse = status_go.hashTypedDataV4(data)
    var response = Json.decode(rawResponse, RpcResponse[JsonNode])
    return prepareResponse(resultOut, response)
  except Exception as e:
    warn "error hashing data v4", err = e.msg
    return e.msg

proc prepareDataForSuggestedRoutes(
  uuid: string,
  sendType: int,
  accountFrom: string,
  accountTo: string,
  amountIn: string,
  amountOut: string,
  tokenKey: string,
  tokenIsOwnerToken: bool,
  toTokenKey: string,
  fromChainID: int,
  toChainID: int,
  slippagePercentage: float,
  extraParamsTable: Table[string, string],
  communityRouteInputParameters: JsonNode = JsonNode(),
  ): JsonNode =

  let data = %* {
    "uuid": uuid,
    "sendType": sendType,
    "addrFrom": accountFrom,
    "addrTo": accountTo,
    "amountIn": amountIn,
    "amountOut": amountOut,
    "tokenKey": tokenKey,
    "tokenIDIsOwnerToken": tokenIsOwnerToken,
    "toTokenKey": toTokenKey,
    "fromChainID": fromChainID,
    "toChainID": toChainID,
    "gasFeeMode": GasFeeLow,
    "slippagePercentage": slippagePercentage,
    "communityRouteInputParams": communityRouteInputParameters,
  }

  # `extraParamsTable` is used for send types like EnsRegister, EnsRelease, EnsSetPubKey, StickersBuy
  # keys that can be used in `extraParamsTable` are:
  # "username", "publicKey", "packID"
  for key, value in extraParamsTable:
    if key in ExtraKeys:
      data[key] = %* value
    else:
      return nil

  return %* [data]

proc suggestedRoutesAsync*(uuid: string, sendType: int, accountFrom: string, accountTo: string, amountIn: string, amountOut: string, tokenKey: string,
  tokenIsOwnerToken: bool, toTokenKey: string, fromChainID, toChainID: int, slippagePercentage: float, extraParamsTable: Table[string, string]):
  string {.raises: [RpcException].} =
  let payload = prepareDataForSuggestedRoutes(uuid, sendType, accountFrom, accountTo, amountIn, amountOut, tokenKey, tokenIsOwnerToken,  toTokenKey,
    fromChainID, toChainID, slippagePercentage, extraParamsTable)
  if payload.isNil:
    raise newException(RpcException, "Invalid key in extraParamsTable")
  let rpcResponse = core.callPrivateRPC("wallet_getSuggestedRoutesAsync", payload)
  if isErrorResponse(rpcResponse):
    return rpcResponse.error.message

proc suggestedRoutesAsyncForCommunities*(uuid: string, sendType: int, accountFrom: string, fromChainID: int,
  toChainID: int, communityId: string, feeTokenKey: string, signerPubKey: string = "0x0", tokenIds: seq[string] = @[],
  walletAddresses: seq[string] = @[], tokenDeploymentSignature: string = "", ownerTokenParameters: JsonNode = JsonNode(),
  masterTokenParameters: JsonNode = JsonNode(), deploymentParameters: JsonNode = JsonNode(),
  transferDetails: seq[JsonNode] = @[]): string {.raises: [RpcException].} =

  let data = %* {
    "communityID": communityId,
    "signerPubKey": signerPubKey,
    "tokenIds": tokenIds,
    "walletAddresses": walletAddresses,
    "tokenDeploymentSignature": tokenDeploymentSignature,
    "ownerTokenParameters": ownerTokenParameters,
    "masterTokenParameters": masterTokenParameters,
    "deploymentParameters": deploymentParameters,
    "transferDetails": transferDetails,
  }

  let payload = prepareDataForSuggestedRoutes(uuid, sendType, accountFrom, accountTo=ZERO_ADDRESS, amountIn="0x0", amountOut="0x0", tokenKey=feeTokenKey,
    tokenIsOwnerToken=false, toTokenKey=feeTokenKey, fromChainID, toChainID, slippagePercentage=0.0, extraParamsTable=initTable[string, string](),
    communityRouteInputParameters=data)
  let rpcResponse = core.callPrivateRPC("wallet_getSuggestedRoutesAsync", payload)
  if isErrorResponse(rpcResponse):
    return rpcResponse.error.message

proc stopSuggestedRoutesAsyncCalculation*(): string {.raises: [RpcException].} =
  let rpcResponse = core.callPrivateRPC("wallet_stopSuggestedRoutesAsyncCalculation")
  if isErrorResponse(rpcResponse):
    return rpcResponse.error.message

## Sets the fee mode for the provided path (should not be user for custom fee mode)
## `feeMode` is the fee mode to set for the path, corresponds to the status go `fees.GasFeeMode` type (0: GasFeeLow, 1: GasFeeMedium, 2: GasFeeHigh and 3: GasFeeCustom)
## `routerInputParamsUuid` is the uuid of the router input params
## `pathName` is the name of the path
## `chainId` is the chain id of the network
## `isApprovalTx` is a flag that indicates if the tx is an approval tx - optional
## `communityId` is the id of the community - optional
## returns the error message if any, or an empty string
proc setFeeMode*(feeMode: int, routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool = false,
  communityId: string = ""): string {.raises: [RpcException].} =
    var pathTxIdentity = %* {
      "routerInputParamsUuid": routerInputParamsUuid,
      "pathName": pathName,
      "chainID": chainId,
    }
    if isApprovalTx:
      pathTxIdentity["isApprovalTx"] = %* true
    if communityId != "":
      pathTxIdentity["communityID"] = %* communityId

    let payload = %* [pathTxIdentity, feeMode]
    let rpcResponse = core.callPrivateRPC("wallet_setFeeMode", payload)
    if isErrorResponse(rpcResponse):
      return rpcResponse.error.message

## Sets the fee mode for the provided path (should not be user for any but the custom fee mode)
## `nonce` is the nonce of the tx
## `gasAmount` is the gas amount of the tx
## `maxFeesPerGas` is the max fees per gas of the tx
## `priorityFee` is the priority fee of the tx
## `routerInputParamsUuid` is the uuid of the router input params
## `pathName` is the name of the path
## `chainId` is the chain id of the network
## `isApprovalTx` is a flag that indicates if the tx is an approval tx - optional
## `communityId` is the id of the community - optional
## returns the error message if any, or an empty string
proc setCustomTxDetails*(nonce: int, gasAmount: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string,
  routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool = false,
  communityId: string = ""): string {.raises: [RpcException].} =

  let pathTxCustomParams = %* {
    "gasFeeMode": GasFeeCustom,
    "nonce": nonce,
    "gasAmount": gasAmount,
    "gasPrice": gasPrice,
    "maxFeesPerGas": maxFeesPerGas,
    "priorityFee": priorityFee,
  }

  var pathTxIdentity = %* {
      "routerInputParamsUuid": routerInputParamsUuid,
      "pathName": pathName,
      "chainID": chainId,
    }
  if isApprovalTx:
    pathTxIdentity["isApprovalTx"] = %* true
  if communityId != "":
    pathTxIdentity["communityID"] = %* communityId

  let payload = %* [pathTxIdentity, pathTxCustomParams]
  let rpcResponse = core.callPrivateRPC("wallet_setCustomTxDetails", payload)
  if isErrorResponse(rpcResponse):
    return rpcResponse.error.message


## Reevaluates reevaluates the tx-fields from the router path that matches the provided pathTxIdentity and sends signal.SuggestedRoutes.
## `uuid` is the uuid of the router input params
## `routerInputParamsUuid` is the uuid of the router input params
## `pathName` is the name of the path
## `chainId` is the chain id of the network
## `isApprovalTx` is a flag that indicates if the tx is an approval tx - optional
proc reevaluateRouterPath*(routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool = false): string {.raises: [RpcException].} =
  var pathTxIdentity = %* {
      "routerInputParamsUuid": routerInputParamsUuid,
      "pathName": pathName,
      "chainID": chainId,
    }
  if isApprovalTx:
    pathTxIdentity["isApprovalTx"] = %* true

  let payload = %* [pathTxIdentity]
  let rpcResponse = core.callPrivateRPC("wallet_reevaluateRouterPath", payload)
  if isErrorResponse(rpcResponse):
    return rpcResponse.error.message

rpc(refetchTxHistory, "wallet"):
  discard

rpc(getUnsupportedCollectibleChainIds, "wallet"):
  discard