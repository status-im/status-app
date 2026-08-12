import strutils, tables, json, options

import app_service/common/wallet_constants as common_wallet_constants
import app_service/common/utils as common_utils
import app_service/common/types as common_types

import ../dto/token

export token


type CommunityDataItem* = CommunityDataDto

type TokenDetailsItem* = TokenDetailsDto

const
  PrivilegesLevelOwner* = 0
  PrivilegesLevelTMaster* = 1
  PrivilegesLevelCommunity* = 2

# {.acyclic.}: TokenItem is tree-shaped (only value fields + a value CommunityDataItem,
# no ref back-edges), so ORC must never treat it as a cycle candidate. Without this,
# copying/destroying a TokenItem calls system.rememberCycle — which crashed (SIGSEGV)
# on Android arm64 when the graph was built on a worker thread and touched on the GUI
# thread. Acyclic types skip the cycle collector entirely.
type TokenItemObj {.acyclic.} = object of RootObj
  key: string
  groupKey: string
  crossChainId: string
  address: string
  name: string
  symbol: string
  decimals: int
  chainId: int
  logoUri: string
  customToken: bool
  communityData: CommunityDataItem
  soulbound: bool
  privilegesLevel: int
  `type`: common_types.TokenType

# TokenItem creation is enforced using `createTokenItem`
type TokenItem* = ref TokenItemObj

proc key*(t: TokenItem): string = t.key
proc groupKey*(t: TokenItem): string = t.groupKey
proc crossChainId*(t: TokenItem): string = t.crossChainId
proc address*(t: TokenItem): string = t.address
proc name*(t: TokenItem): string = t.name
proc symbol*(t: TokenItem): string = t.symbol
proc decimals*(t: TokenItem): int = t.decimals
proc chainId*(t: TokenItem): int = t.chainId
proc logoUri*(t: TokenItem): string = t.logoUri
proc customToken*(t: TokenItem): bool = t.customToken
proc communityData*(t: TokenItem): CommunityDataItem = t.communityData
proc soulbound*(t: TokenItem): bool = t.soulbound
proc privilegesLevel*(t: TokenItem): int = t.privilegesLevel
proc `type`*(t: TokenItem): common_types.TokenType = t.`type`

proc isOwnerToken*(t: TokenItem): bool =
  t.privilegesLevel == PrivilegesLevelOwner

proc isNative(address: string): bool =
  return address == common_wallet_constants.ZERO_ADDRESS

proc isNative*(self: TokenItem): bool =
  return isNative(self.address)

# If `type` is not provided, it will be determined based on the address (native token for zero address or ERC20 token for other addresses)
proc createTokenItem*(dto: TokenDto, `type`: common_types.TokenType = common_types.TokenType.ERC20): TokenItem =
  if dto.chainId <= 0 or dto.address.isEmptyOrWhitespace:
    raise newException(ValueError, "invalid token dto")

  var tokenType = `type`
  if isNative(dto.address):
    tokenType = common_types.TokenType.Native

  let key = common_utils.createTokenKey(dto.chainId, dto.address)
  let groupKey = if dto.crossChainId.isEmptyOrWhitespace: key else: dto.crossChainId
  return TokenItem(
    key: key,
    groupKey: groupKey,
    crossChainId: dto.crossChainId,
    address: dto.address,
    name: dto.name,
    symbol: dto.symbol,
    decimals: dto.decimals,
    chainId: dto.chainId,
    logoUri: common_utils.resolveUri(dto.logoUri),
    customToken: dto.customToken,
    communityData: CommunityDataItem(
      id: dto.communityData.id,
      name: dto.communityData.name,
      color: dto.communityData.color,
      image: dto.communityData.image
    ),
    soulbound: dto.soulbound,
    privilegesLevel: dto.privilegesLevel.get(PrivilegesLevelCommunity),
    `type`: tokenType,
  )

proc createNativeTokenItem*(chainId: int): TokenItem =
  var tokenDto = TokenDto(
    crossChainId: common_wallet_constants.ETH_GROUP_KEY,
    chainId: chainId,
    address: common_wallet_constants.ZERO_ADDRESS,
    symbol: common_wallet_constants.ETH_SYMBOL,
    decimals: common_wallet_constants.ETH_DECIMALS,
  )

  if chainId == common_wallet_constants.BSC_MAINNET or chainId == common_wallet_constants.BSC_TESTNET:
    tokenDto.crossChainId = common_wallet_constants.BNB_GROUP_KEY
    tokenDto.symbol = common_wallet_constants.BNB_SYMBOL
    tokenDto.decimals = common_wallet_constants.BNB_DECIMALS

  return createTokenItem(tokenDto, common_types.TokenType.Native)

proc createStatusTokenItem*(chainId: int): TokenItem =
  if not common_wallet_constants.STATUS_TOKEN_ADDRESSES.hasKey(chainId):
    return nil

  var tokenDto = TokenDto(
    crossChainId: common_wallet_constants.STATUS_GROUP_KEY,
    chainId: chainId,
    address: common_wallet_constants.STATUS_TOKEN_ADDRESSES[chainId],
    symbol: common_wallet_constants.STATUS_SYMBOL,
    decimals: common_wallet_constants.STATUS_DECIMALS,
  )

  if common_wallet_constants.SUPPORTED_TEST_NETWORKS.hasKey(chainId):
    tokenDto.crossChainId = common_wallet_constants.STATUS_TEST_TOKEN_GROUP_KEY
    tokenDto.symbol = common_wallet_constants.STATUS_SYMBOL_TESTNET
    tokenDto.decimals = common_wallet_constants.STATUS_DECIMALS_TESTNET

  return createTokenItem(tokenDto, common_types.TokenType.ERC20)

proc `%`*(self: TokenItem): JsonNode =
  return %*{
    "key": self.key,
    "groupKey": self.groupKey,
    "crossChainId": self.crossChainId,
    "address": self.address,
    "name": self.name,
    "symbol": self.symbol,
    "decimals": self.decimals,
    "chainId": self.chainId,
    "logoUri": self.logoUri,
    "customToken": self.customToken,
    "communityId": self.communityData.id,
    "type": self.`type`
  }
