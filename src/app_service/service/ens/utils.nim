import std/[json, options, strutils]
import std/strformat
import chronicles
import nimcrypto, stint
import ../../common/conversion as common_conversion
import ../eth/dto/transaction as eth_transaction_dto
import ../../../backend/ens as status_ens
import ../../common/account_constants
import ../../common/utils
import ../../service/transaction/dto

logScope:
  topics = "ens-utils"

include ../../common/json_utils

const ENS_REGISTRY* = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"
const RESOLVER_SIGNATURE* = "0x0178b8bf"
const CONTENTHASH_SIGNATURE* = "0xbc1c58d1" # contenthash(bytes32)
const PUBKEY_SIGNATURE* = "0xc8690233" # pubkey(bytes32 node)
const ADDRESS_SIGNATURE* = "0x3b3b57de" # addr(bytes32 node)
const OWNER_SIGNATURE* = "0x02571be3" # owner(bytes32 node)

export STATUS_DOMAIN
export ENS_REGISTRY
export RESOLVER_SIGNATURE
export CONTENTHASH_SIGNATURE
export PUBKEY_SIGNATURE
export ADDRESS_SIGNATURE
export OWNER_SIGNATURE

type
  ENSType* {.pure.} = enum
    IPFS,
    SWARM,
    IPNS,
    UNKNOWN

proc addDomain*(username: string): string =
  if username.endsWith(ETH_DOMAIN) or
    username.endsWith(STATUS_DOMAIN):
    return username
  else:
    return username & STATUS_DOMAIN

proc publicKeyOf*(chainId: int, username: string): string =
  try:
    let res = status_ens.publicKeyOf(chainId, addDomain(username))
    return res.result.getStr
  except:
    return ""

proc addressOf*(chainId: int, username: string): string =
  try:
    let res = status_ens.addressOf(chainId, username.addDomain())
    return res.result.getStr
  except:
    return ""

proc ownerOf*(chainId: int, username: string): string =
  let res = status_ens.ownerOf(chainId, username)
  let address = res.result.getStr
  if address == ZERO_ADDRESS:
    return ""
  
  return address

proc buildTransaction*(
    source: Address,
    value: Uint256,
    gas = "",
    gasPrice = "",
    isEIP1559Enabled = false,
    maxPriorityFeePerGas = "",
    maxFeePerGas = "",
    data = ""
  ): TransactionDataDto =
  result = TransactionDataDto(
    source: source,
    value: value.some,
    gas: (if gas.isEmptyOrWhitespace: Quantity.none else: Quantity(cast[uint64](parseFloat(gas).toUInt64)).some),
    gasPrice: (if gasPrice.isEmptyOrWhitespace: int.none else: gwei2Wei(parseFloat(gasPrice)).truncate(int).some),
    data: data
  )
  if isEIP1559Enabled:
    result.txType = "0x02"
    result.maxPriorityFeePerGas = if maxFeePerGas.isEmptyOrWhitespace: Uint256.none else: gwei2Wei(parseFloat(maxPriorityFeePerGas)).some
    result.maxFeePerGas = (if maxFeePerGas.isEmptyOrWhitespace: Uint256.none else: gwei2Wei(parseFloat(maxFeePerGas)).some)
  else:
    result.txType = "0x00"

proc buildTransactionDataDto*(gasUnits: int, suggestedFees: SuggestedFeesDto, addressFrom: string, chainId: int, contractAddress: string): TransactionDataDto =
    if suggestedFees == nil:
      error "Can't find suggested fees for chainId", chainId=chainId
      return
    return buildTransaction(decodeHexAddress(addressFrom), 0.u256, $gasUnits,
      if suggestedFees.eip1559Enabled: "" else: $suggestedFees.gasPrice, suggestedFees.eip1559Enabled,
      if suggestedFees.eip1559Enabled: $suggestedFees.maxPriorityFeePerGas else: "",
      if suggestedFees.eip1559Enabled: $suggestedFees.maxFeePerGasM else: "")

proc buildTokenTransaction*(
  source, contractAddress: Address, gas = "", gasPrice = "", isEIP1559Enabled = false,
  maxPriorityFeePerGas = "", maxFeePerGas = ""
): TransactionDataDto =
  result = buildTransaction(source, 0.u256, gas, gasPrice, isEIP1559Enabled, maxPriorityFeePerGas, maxFeePerGas)
  result.to = contractAddress.some

proc label*(username:string): string =
  var node:array[32, byte] = nimcrypto.keccak256.digest(username.toLower()).data
  result = "0x" & node.toHex()

proc getExpirationTime*(chainId: int, username: string): int =
  let res = status_ens.expireAt(chainId, username)
  return fromHex[int](res.result.getStr)

proc hex2Token*(input: string, decimals: int): string =
  var value = fromHex(Stuint[256], input)

  if decimals == 0:
    return fmt"{value}"

  var p = u256(10).pow(decimals)
  var i = value.div(p)
  var r = value.mod(p)
  var leading_zeros = "0".repeat(decimals - ($r).len)
  var d = fmt"{leading_zeros}{$r}"
  result = $i
  if(r > 0): result = fmt"{result}.{d}"
