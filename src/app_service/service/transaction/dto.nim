import json, strutils, stint, json_serialization, std/strformat
import tables, sequtils

import
  web3/eth_api_types

import dtoV2
import backend/network_types
import backend/transactions
import app_service/common/conversion as service_conversion
import app_service/service/token/dto/token
import app/modules/shared_models/currency_amount

include  app_service/common/json_utils

type
  SendType* {.pure.} = enum
    Transfer
    ENSRegister
    ENSRelease
    ENSSetPubKey
    StickersBuy
    Bridge
    ERC721Transfer
    ERC1155Transfer
    Swap
    CommunityBurn
    CommunityDeployAssets
    CommunityDeployCollectibles
    CommunityDeployOwnerToken
    CommunityMintTokens
    CommunityRemoteBurn
    CommunitySetSignerPubKey
    Approve

type
  PendingTransactionTypeDto* {.pure.} = enum
    Unknown = "Unknown"
    RegisterENS = "RegisterENS",
    SetPubKey = "SetPubKey",
    ReleaseENS = "ReleaseENS",
    BuyStickerPack = "BuyStickerPack"
    WalletTransfer = "WalletTransfer"
    DeployCommunityToken = "DeployCommunityToken"
    AirdropCommunityToken = "AirdropCommunityToken"
    RemoteDestructCollectible = "RemoteDestructCollectible"
    BurnCommunityToken = "BurnCommunityToken"
    DeployOwnerToken = "DeployOwnerToken"
    SetSignerPublicKey = "SetSignerPublicKey"
    WalletConnectTransfer = "WalletConnectTransfer"

proc event*(self:PendingTransactionTypeDto):string =
  result = "transaction:" & $self

type
  TransactionDto* = ref object of RootObj
    id*: string
    typeValue*: string
    address*: string
    blockNumber*: string # TODO remove, fetched separately in details
    blockHash*: string
    contract*: string
    timestamp*: UInt256
    gasPrice*: string
    gasLimit*: string # TODO remove, fetched separately in details
    gasUsed*: string
    nonce*: string # TODO remove, fetched separately in details
    txStatus*: string
    value*: string
    tokenId*: UInt256
    fromAddress*: string
    to*: string
    chainId*: int
    maxFeePerGas*: string # TODO remove, fetched separately in details
    maxPriorityFeePerGas*: string
    input*: string # TODO remove, fetched separately in details
    txHash*: string # TODO remove, fetched separately in details
    multiTransactionID*: int
    baseGasFees*: string
    totalFees*: string
    maxTotalFees*: string # TODO remove, fetched separately in details
    additionalData*: string
    symbol*: string

proc getTotalFees(tip: string, baseFee: string, gasUsed: string, maxFee: string): string =
  var maxFees = stint.fromHex(Uint256, maxFee)
  var totalGasUsed = stint.fromHex(Uint256, tip) + stint.fromHex(Uint256, baseFee)
  if totalGasUsed >  maxFees:
    totalGasUsed = maxFees
  var totalGasUsedInHex = (totalGasUsed * stint.fromHex(Uint256, gasUsed)).toHex
  return totalGasUsedInHex

proc getMaxTotalFees(maxFee: string, gasLimit: string): string =
  return (stint.fromHex(Uint256, maxFee) * stint.fromHex(Uint256, gasLimit)).toHex

proc toTransactionDto*(jsonObj: JsonNode): TransactionDto =
  result = TransactionDto()
  result.timestamp = stint.fromHex(UInt256, jsonObj{"timestamp"}.getStr)
  result.tokenId = stint.fromHex(UInt256, jsonObj{"tokenId"}.getStr)
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("type", result.typeValue)
  discard jsonObj.getProp("address", result.address)
  discard jsonObj.getProp("contract", result.contract)
  discard jsonObj.getProp("blockNumber", result.blockNumber)
  discard jsonObj.getProp("blockHash", result.blockHash)
  discard jsonObj.getProp("gasPrice", result.gasPrice)
  discard jsonObj.getProp("gasLimit", result.gasLimit)
  discard jsonObj.getProp("gasUsed", result.gasUsed)
  discard jsonObj.getProp("nonce", result.nonce)
  discard jsonObj.getProp("txStatus", result.txStatus)
  discard jsonObj.getProp("value", result.value)
  discard jsonObj.getProp("from", result.fromAddress)
  discard jsonObj.getProp("to", result.to)
  discard jsonObj.getProp("networkId", result.chainId)
  discard jsonObj.getProp("maxFeePerGas", result.maxFeePerGas)
  discard jsonObj.getProp("maxPriorityFeePerGas", result.maxPriorityFeePerGas)
  discard jsonObj.getProp("input", result.input)
  discard jsonObj.getProp("txHash", result.txHash)
  discard jsonObj.getProp("multiTransactionID", result.multiTransactionID)
  discard jsonObj.getProp("base_gas_fee", result.baseGasFees)
  result.totalFees = getTotalFees(result.maxPriorityFeePerGas, result.baseGasFees, result.gasUsed, result.maxFeePerGas)
  result.maxTotalFees = getMaxTotalFees(result.maxFeePerGas, result.gasLimit)

proc `$`*(self: TransactionDto): string =
  return fmt"""TransactionDto(
    id:{self.id},
    typeValue:{self.typeValue},
    address:{self.address},
    blockNumber:{self.blockNumber},
    blockHash:{self.blockHash},
    contract:{self.contract},
    timestamp:{self.timestamp},
    gasPrice:{self.gasPrice},
    gasLimit:{self.gasLimit},
    gasUsed:{self.gasUsed},
    nonce:{self.nonce},
    txStatus:{self.txStatus},
    value:{self.value},
    tokenId:{self.tokenId},
    fromAddress:{self.fromAddress},
    to:{self.to},
    chainId:{self.chainId},
    maxFeePerGas:{self.maxFeePerGas},
    maxPriorityFeePerGas:{self.maxPriorityFeePerGas},
    input:{self.input},
    txHash:{self.txHash},
    multiTransactionID:{self.multiTransactionID},
    baseGasFees:{self.baseGasFees},
    totalFees:{self.totalFees},
    maxTotalFees:{self.maxTotalFees},
    additionalData:{self.additionalData},
    symbol:{self.symbol}
  )"""

proc toPendingTransactionDto*(jsonObj: JsonNode): TransactionDto =
  result = TransactionDto()
  result.value = "0x" & toHex(toUInt256(parseFloat(jsonObj{"value"}.getStr)))
  result.timestamp = u256(jsonObj{"timestamp"}.getInt)
  result.tokenId = stint.fromHex(UInt256, jsonObj{"tokenId"}.getStr)
  discard jsonObj.getProp("hash", result.txHash)
  discard jsonObj.getProp("from", result.fromAddress)
  discard jsonObj.getProp("to", result.to)
  discard jsonObj.getProp("gasPrice", result.gasPrice)
  discard jsonObj.getProp("gasLimit", result.gasLimit)
  discard jsonObj.getProp("type", result.typeValue)
  discard jsonObj.getProp("network_id", result.chainId)
  discard jsonObj.getProp("multi_transaction_id", result.multiTransactionID)
  discard jsonObj.getProp("additionalData", result.additionalData)
  discard jsonObj.getProp("data", result.input)
  discard jsonObj.getProp("symbol", result.symbol)

proc toMultiTransactionDto*(jsonObj: JsonNode): MultiTransactionDto =
  result = MultiTransactionDto()

  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("timestamp", result.timestamp)
  discard jsonObj.getProp("fromAddress", result.fromAddress)
  discard jsonObj.getProp("toAddress", result.toAddress)
  discard jsonObj.getProp("fromAsset", result.fromAsset)
  discard jsonObj.getProp("toAsset", result.toAsset)
  discard jsonObj.getProp("fromAmount", result.fromAmount)
  discard jsonObj.getProp("toAmount", result.toAmount)
  var multiTxType: int
  discard jsonObj.getProp("type", multiTxType)
  result.multiTxType = cast[MultiTransactionType](multiTxType)

proc cmpTransactions*(x, y: TransactionDto): int =
  # Sort proc to compare transactions from a single account.
  # Compares first by block number, then by nonce
  result = cmp(x.blockNumber.parseHexInt, y.blockNumber.parseHexInt)
  if result == 0:
    result = cmp(x.nonce, y.nonce)

type
  SuggestedFeesDto* = ref object
    gasPrice*: float64
    baseFee*: float64
    maxPriorityFeePerGas*: float64
    maxFeePerGasL*: float64
    maxFeePerGasM*: float64
    maxFeePerGasH*: float64
    l1GasFee*: float64
    eip1559Enabled*: bool

proc decodeSuggestedFeesDto*(jsonObj: JsonNode): SuggestedFeesDto =
  result = SuggestedFeesDto()
  result.gasPrice = jsonObj{"gasPrice"}.getFloat
  result.baseFee = jsonObj{"baseFee"}.getFloat
  result.maxPriorityFeePerGas = jsonObj{"maxPriorityFeePerGas"}.getFloat
  result.maxFeePerGasL = jsonObj{"maxFeePerGasL"}.getFloat
  result.maxFeePerGasM = jsonObj{"maxFeePerGasM"}.getFloat
  result.maxFeePerGasH = jsonObj{"maxFeePerGasH"}.getFloat
  if jsonObj.hasKey("l1GasFee"):
    result.l1GasFee = jsonObj{"l1GasFee"}.getFloat
  result.eip1559Enabled = jsonObj{"eip1559Enabled"}.getbool

proc toSuggestedFeesDto*(jsonObj: JsonNode): SuggestedFeesDto =
  result = SuggestedFeesDto()
  var stringValue: string
  if jsonObj.getProp("gasPrice", stringValue) and stringValue.len > 0:
    result.gasPrice = parseFloat(stringValue)
  if jsonObj.getProp("baseFee", stringValue) and stringValue.len > 0:
    result.baseFee = parseFloat(stringValue)
  if jsonObj.getProp("maxPriorityFeePerGas", stringValue) and stringValue.len > 0:
    result.maxPriorityFeePerGas = parseFloat(stringValue)
  if jsonObj.getProp("maxFeePerGasLow", stringValue) and stringValue.len > 0:
    result.maxFeePerGasL = parseFloat(stringValue)
  if jsonObj.getProp("maxFeePerGasMedium", stringValue) and stringValue.len > 0:
    result.maxFeePerGasM = parseFloat(stringValue)
  if jsonObj.getProp("maxFeePerGasHigh", stringValue) and stringValue.len > 0:
    result.maxFeePerGasH = parseFloat(stringValue)
  if jsonObj.getProp("l1GasFee", stringValue) and stringValue.len > 0:
    result.l1GasFee = parseFloat(stringValue)
  result.eip1559Enabled = jsonObj{"eip1559Enabled"}.getbool

proc `$`*(self: SuggestedFeesDto): string =
  return fmt"""SuggestedFees(
    gasPrice:{self.gasPrice},
    baseFee:{self.baseFee},
    maxPriorityFeePerGas:{self.maxPriorityFeePerGas},
    maxFeePerGasL:{self.maxFeePerGasL},
    maxFeePerGasM:{self.maxFeePerGasM},
    maxFeePerGasH:{self.maxFeePerGasH},
    l1GasFee:{self.l1GasFee},
    eip1559Enabled:{self.eip1559Enabled}
  )"""

type
  TransactionPathDto* = ref object
    bridgeName*: string
    fromNetwork*: NetworkDto
    toNetwork*: NetworkDto
    fromToken*: TokenDto  # Only populated when converting from V2
    toToken*: TokenDto  # Only populated when converting from V2
    maxAmountIn* : UInt256
    amountIn*: UInt256
    amountOut*: UInt256
    gasAmount*: uint64
    gasFees*: SuggestedFeesDto
    tokenFees*: float
    bonderFees*: string
    txBonderFees*: UInt256 # Unchanged value from Path V2
    cost*: float
    estimatedTime*: int
    amountInLocked*: bool
    isFirstSimpleTx*: bool
    isFirstBridgeTx*: bool
    approvalRequired*: bool
    approvalGasFees*: float
    approvalAmountRequired*: UInt256
    approvalContractAddress*: string
    slippagePercentage*: float

proc `$`*(self: TransactionPathDto): string =
  return fmt"""TransactionPath(
    bridgeName:{self.bridgeName},
    fromNetwork:{self.fromNetwork},
    toNetwork:{self.toNetwork},
    fromToken:{self.fromToken},
    toToken:{self.toToken},
    maxAmountIn:{self.maxAmountIn},
    amountIn:{self.amountIn},
    amountOut:{self.amountOut},
    gasAmount:{self.gasAmount},
    tokenFees:{self.tokenFees},
    bonderFees:{self.bonderFees},
    cost:{self.cost},
    estimatedTime:{self.estimatedTime},
    amountInLocked:{self.amountInLocked},
    isFirstSimpleTx:{self.isFirstSimpleTx},
    isFirstBridgeTx:{self.isFirstBridgeTx}
    approvalRequired:{self.approvalRequired},
    approvalGasFees:{self.approvalGasFees},
    approvalAmountRequired:{self.approvalAmountRequired},
    approvalContractAddress:{self.approvalContractAddress},
    slippagePercentage:{self.slippagePercentage},
    gasFees:{$self.gasFees}
  )"""

proc convertToTransactionPathDto*(jsonObj: JsonNode): TransactionPathDto =
  result = TransactionPathDto()
  discard jsonObj.getProp("bridgeName", result.bridgeName)
  result.fromNetwork = Json.decode($jsonObj["fromNetwork"], NetworkDto, allowUnknownFields = true)
  result.toNetwork = Json.decode($jsonObj["toNetwork"], NetworkDto, allowUnknownFields = true)
  result.gasFees = decodeSuggestedFeesDto(jsonObj["gasFees"])
  discard jsonObj.getProp("cost", result.cost)
  discard jsonObj.getProp("tokenFees", result.tokenFees)
  discard jsonObj.getProp("bonderFees", result.bonderFees)
  result.maxAmountIn = stint.u256(jsonObj{"maxAmountIn"}.getStr)
  result.amountIn = stint.u256(jsonObj{"amountIn"}.getStr)
  result.amountOut = stint.u256(jsonObj{"amountOut"}.getStr)
  result.estimatedTime = jsonObj{"estimatedTime"}.getInt
  result.amountInLocked = jsonObj{"amountInLocked"}.getBool
  result.isFirstSimpleTx = jsonObj{"isFirstSimpleTx"}.getBool
  result.isFirstBridgeTx = jsonObj{"isFirstBridgeTx"}.getBool
  discard jsonObj.getProp("gasAmount", result.gasAmount)
  discard jsonObj.getProp("approvalRequired", result.approvalRequired)
  result.approvalAmountRequired = stint.u256(jsonObj{"approvalAmountRequired"}.getStr)
  discard jsonObj.getProp("approvalGasFees", result.approvalGasFees)
  discard jsonObj.getProp("approvalContractAddress", result.approvalContractAddress)
  discard jsonObj.getProp("slippagePercentage", result.slippagePercentage)

type
  FeesDto* = ref object
    totalFeesInNativeCrypto*: float
    totalTokenFees*: float
    totalTime*: int

proc `$`*(self: FeesDto): string =
  return fmt"""FeesDto(
    totalFeesInNativeCrypto:{self.totalFeesInNativeCrypto},
    totalTokenFees:{self.totalTokenFees},
    totalTime:{self.totalTime},
  )"""

proc convertToFeesDto*(jsonObj: JsonNode): FeesDto =
  result = FeesDto()
  discard jsonObj.getProp("totalFeesInEth", result.totalFeesInNativeCrypto)
  discard jsonObj.getProp("totalTokenFees", result.totalTokenFees)
  discard jsonObj.getProp("totalTime", result.totalTime)

type
  SendToNetwork* = ref object
    chainId*: int
    chainName*: string
    iconUrl*: string
    amountOut*: UInt256

proc `$`*(self: SendToNetwork): string =
  return fmt"""SendToNetwork(
    chainId:{self.chainId},
    chainName:{self.chainName},
    iconUrl:{self.iconUrl},
    amountOut:{self.amountOut},
  )"""

proc convertSendToNetwork*(jsonObj: JsonNode): SendToNetwork =
  result = SendToNetwork()
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("chainName", result.chainName)
  discard jsonObj.getProp("iconUrl", result.iconUrl)
  result.amountOut = stint.u256(jsonObj{"amountOut"}.getStr)

type
  SuggestedRoutesDto* = ref object
    best*: seq[TransactionPathDto]
    bestRoute*: seq[TransactionPathDtoV2]
    rawBest*: string # serialized seq[TransactionPathDtoV2]
    gasTimeEstimate*: FeesDto
    amountToReceive*: UInt256
    toNetworks*: seq[SendToNetwork]

type
  CostPerPath* = object
    contractUniqueKey*: string
    costNativeCryptoCurrency*: CurrencyAmount
    costFiatCurrency*: CurrencyAmount

proc `%`*(self: CostPerPath): JsonNode =
  result = %* {
    "nativeCryptoFee": if self.costNativeCryptoCurrency == nil: newCurrencyAmount().toJsonNode() else: self.costNativeCryptoCurrency.toJsonNode(),
    "fiatFee": if self.costFiatCurrency == nil: newCurrencyAmount().toJsonNode() else: self.costFiatCurrency.toJsonNode(),
    "contractUniqueKey": self.contractUniqueKey,
  }

# TODO: Generalize for non-ETH gas fees
# Not needed for now since the only other option is BNB which has
# the same decimals as ETH
proc getGasNativeCryptoValue*(gweiValue: float, gasLimit: uint64): float =
  let weiValue = service_conversion.gwei2Wei(gweiValue) * u256(gasLimit)
  let nativeCryptoValue = parseFloat(service_conversion.wei2Eth(weiValue))
  return nativeCryptoValue

proc getFeesTotal*(paths: seq[TransactionPathDto]): FeesDto =
  var fees: FeesDto = FeesDto()
  if(paths.len == 0):
    return fees

  for path in paths:
    var optimalPrice = path.gasFees.gasPrice
    if path.gasFees.eip1559Enabled:
      optimalPrice = path.gasFees.maxFeePerGasM

    fees.totalFeesInNativeCrypto += getGasNativeCryptoValue(optimalPrice, path.gasAmount)
    fees.totalFeesInNativeCrypto += parseFloat(service_conversion.wei2Eth(service_conversion.gwei2Wei(path.gasFees.l1GasFee)))
    fees.totalFeesInNativeCrypto += path.approvalGasFees
    fees.totalTokenFees += path.tokenFees
    fees.totalTime += path.estimatedTime
  return fees

proc getTotalAmountToReceive*(paths: seq[TransactionPathDto]): UInt256 =
  var totalAmountToReceive: UInt256 = stint.u256(0)
  for path in paths:
    totalAmountToReceive += path.amountOut

  return totalAmountToReceive

proc getToNetworksList*(paths: seq[TransactionPathDto]): seq[SendToNetwork] =
  var networkMap: Table[int, SendToNetwork] = initTable[int, SendToNetwork]()
  for path in paths:
    if(networkMap.hasKey(path.toNetwork.chainId)):
      networkMap[path.toNetwork.chainId].amountOut = networkMap[path.toNetwork.chainId].amountOut + path.amountOut
    else:
      networkMap[path.toNetwork.chainId] = SendToNetwork(chainId: path.toNetwork.chainId, chainName: path.toNetwork.chainName, iconUrl: path.toNetwork.iconURL, amountOut: path.amountOut)
  return toSeq(networkMap.values)

proc addFirstSimpleBridgeTxFlag*(paths: seq[TransactionPathDto]) : seq[TransactionPathDto] =
  let txPaths = paths
  var firstSimplePath: bool = false
  var firstBridgePath: bool = false

  for path in txPaths:
    if not firstSimplePath:
      firstSimplePath = true
      path.isFirstSimpleTx = true
    if path.bridgeName != "Transfer":
      if not firstBridgePath:
        firstBridgePath = false
        path.isFirstBridgeTx = true

  return txPaths
