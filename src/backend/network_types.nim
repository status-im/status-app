import json, json_serialization, std/strformat

type RpcProviderType* {.pure.} = enum
  EmbeddedProxy = "embedded-proxy"
  EmbeddedEthRpcProxy = "embedded-eth-rpc-proxy"
  EmbeddedDirect = "embedded-direct"
  User = "user"

type RpcProviderAuthType* {.pure.} = enum
  NoAuth = "no-auth"
  BasicAuth = "basic-auth"
  TokenAuth = "token-auth"

type RpcProviderDto* = object
  id* {.serializedFieldName("id").}: int
  chainId* {.serializedFieldName("chainId").}: int
  name* {.serializedFieldName("name").}: string
  url* {.serializedFieldName("url").}: string
  isRpsLimiterEnabled* {.serializedFieldName("enableRpsLimiter").}: bool
  providerType* {.serializedFieldName("type").}: RpcProviderType
  isEnabled* {.serializedFieldName("enabled").}: bool
  authType* {.serializedFieldName("authType").}: RpcProviderAuthType
  authLogin* {.serializedFieldName("authLogin").}: string
  authPassword* {.serializedFieldName("authPassword").}: string
  authToken* {.serializedFieldName("authToken").}: string

proc `$`*(self: RpcProviderDto): string =
  return fmt"""RpcProviderDto(
    id:{self.id},
    chainId:{self.chainId},
    name:{self.name},
    url:{self.url},
    isRpsLimiterEnabled:{self.isRpsLimiterEnabled},
    providerType:{self.providerType},
    isEnabled:{self.isEnabled},
    authType:{self.authType},
    authLogin:{self.authLogin},
    authPassword:{self.authPassword},
    authToken:{self.authToken}
  )"""

proc `%`*(t: RpcProviderDto): JsonNode {.inline.} =
  result = parseJson(t.toJson)

type NetworkDto* = object
  chainId* {.serializedFieldName("chainId").}: int
  nativeCurrencyDecimals* {.serializedFieldName("nativeCurrencyDecimals").}: int
  layer* {.serializedFieldName("layer").}: int
  chainName* {.serializedFieldName("chainName").}: string
  rpcProviders* {.serializedFieldName("rpcProviders").}: seq[RpcProviderDto]
  blockExplorerUrl* {.serializedFieldName("blockExplorerUrl").}: string
  iconUrl* {.serializedFieldName("iconUrl").}: string
  nativeCurrencyName* {.serializedFieldName("nativeCurrencyName").}: string
  nativeCurrencySymbol* {.serializedFieldName("nativeCurrencySymbol").}: string
  isTest* {.serializedFieldName("isTest").}: bool
  isEnabled* {.serializedFieldName("enabled").}: bool
  chainColor* {.serializedFieldName("chainColor").}: string
  shortName* {.serializedFieldName("shortName").}: string
  relatedChainID* {.serializedFieldName("relatedChainID").}: int
  isActive* {.serializedFieldName("isActive").}: bool
  isDeactivatable* {.serializedFieldName("isDeactivatable").}: bool
  eip1559Enabled* {.serializedFieldName("eip1559Enabled").}: bool
  noBaseFee* {.serializedFieldName("noBaseFee").}: bool
  noPriorityFee* {.serializedFieldName("noPriorityFee").}: bool
  communitiesSupported* {.serializedFieldName("communitiesSupported").}: bool

type NetworkDtoSafe* = NetworkDto


proc `$`*(self: NetworkDto): string =
  return fmt"""NetworkDto(
    chainId:{self.chainId},
    nativeCurrencyDecimals:{self.nativeCurrencyDecimals},
    layer:{self.layer},
    chainName:{self.chainName},
    name:{self.chainName},
    rpcProviders:{self.rpcProviders},
    blockExplorerUrl:{self.blockExplorerUrl},
    iconUrl:{self.iconUrl},
    nativeCurrencyName:{self.nativeCurrencyName},
    nativeCurrencySymbol:{self.nativeCurrencySymbol},
    isTest:{self.isTest},
    isEnabled:{self.isEnabled},
    chainColor:{self.chainColor},
    shortName:{self.shortName},
    relatedChainId:{self.relatedChainId},
    isActive:{self.isActive},
    isDeactivatable:{self.isDeactivatable},
    eip1559Enabled:{self.eip1559Enabled},
    noBaseFee:{self.noBaseFee},
    noPriorityFee:{self.noPriorityFee},
    communitiesSupported:{self.communitiesSupported}
  )"""

proc `%`*(t: NetworkDto): JsonNode {.inline.} =
  result = parseJson(t.toJson)
