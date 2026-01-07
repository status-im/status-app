import json, json_serialization, std/strformat
import hashes
import ./core, ./response_type
import app_service/service/saved_address/dto as saved_address_dto
import app_service/service/token/dto/token_preferences
from ./gen import rpc

export response_type

type
  Token* = ref object of RootObj
    name* {.serializedFieldName("name").}: string
    chainId* {.serializedFieldName("chainId").}: int
    address* {.serializedFieldName("address").}: string
    symbol* {.serializedFieldName("symbol").}: string
    decimals* {.serializedFieldName("decimals").}: int
    color* {.serializedFieldName("color").}: string

  Bookmark* = ref object of RootObj
    name* {.serializedFieldName("name").}: string
    url* {.serializedFieldName("url").}: string
    imageUrl* {.serializedFieldName("imageUrl").}: string
    removed* {.serializedFieldName("removed").}: bool
    deletedAt* {.serializedFieldName("deletedAt").}: int

  Permission* = ref object of RootObj
    dapp* {.serializedFieldName("dapp").}: string
    address* {.serializedFieldName("address").}: string
    permissions* {.serializedFieldName("permissions").}: seq[string]

  Network* = ref object of RootObj
    chainId* {.serializedFieldName("chainId").}: int
    nativeCurrencyDecimals* {.serializedFieldName("nativeCurrencyDecimals").}: int
    layer* {.serializedFieldName("layer").}: int
    chainName* {.serializedFieldName("chainName").}: string
    rpcURL* {.serializedFieldName("rpcUrl").}: string
    originalRpcURL* {.serializedFieldName("originalRpcUrl").}: string
    fallbackURL* {.serializedFieldName("fallbackUrl").}: string
    originalFallbackURL* {.serializedFieldName("originalFallbackURL").}: string
    blockExplorerURL* {.serializedFieldName("blockExplorerUrl").}: string
    iconURL* {.serializedFieldName("iconUrl").}: string
    nativeCurrencyName* {.serializedFieldName("nativeCurrencyName").}: string
    nativeCurrencySymbol* {.serializedFieldName("nativeCurrencySymbol").}: string
    isTest* {.serializedFieldName("isTest").}: bool
    enabled* {.serializedFieldName("enabled").}: bool
    chainColor* {.serializedFieldName("chainColor").}: string
    shortName* {.serializedFieldName("shortName").}: string
    relatedChainID* {.serializedFieldName("relatedChainID").}: int

  ActivityCenterNotificationsRequest* = ref object of RootObj
    cursor* {.serializedFieldName("cursor").}: string
    limit* {.serializedFieldName("limit").}: int
    activityTypes* {.serializedFieldName("activityTypes").}: seq[int]
    readType* {.serializedFieldName("readType").}: int

  ActivityCenterCountRequest* = ref object of RootObj
    activityTypes* {.serializedFieldName("activityTypes").}: seq[int]
    readType* {.serializedFieldName("readType").}: int

rpc(clientVersion, "web3"):
  discard

rpc(upsertSavedAddress, "wakuext"):
  savedAddress: SavedAddressDto

rpc(deleteSavedAddress, "wakuext"):
  address: string
  isTest: bool

rpc(getSavedAddresses, "wakuext"):
  discard

rpc(getSavedAddressesPerMode, "wakuext"):
  isTest: bool

rpc(remainingCapacityForSavedAddresses, "wakuext"):
  isTest: bool

rpc(checkConnected, "wallet"):
  discard

rpc(getPendingTransactions, "wallet"):
  discard

type
  TransactionIdentity* = ref object
    chainId*: int
    hash*: string
    address*: string

proc fromJson*(t: JsonNode, T: typedesc[TransactionIdentity]): T {.inline.} =
  result = TransactionIdentity(
    chainId: if t.hasKey("chainId"): t["chainId"].getInt() else: 0,
    hash: if t.hasKey("hash"): t["hash"].getStr() else: "",
    address: if t.hasKey("address"): t["address"].getStr() else: "",
  )

proc hash*(ti: TransactionIdentity): Hash =
  var h: Hash = 0
  h = h !& hash(ti.chainId)
  h = h !& hash(ti.hash)
  h = h !& hash(ti.address)
  result = !$h

proc `==`*(a, b: TransactionIdentity): bool =
  result = (a.chainId == b.chainId) and (a.hash == b.hash) and (a.address == b.address)

proc `$`*(self: TransactionIdentity): string =
  return fmt"""TransactionIdentity(
    chainId:{self.chainId},
    hash:{self.hash},
    address:{self.address},
  )"""

rpc(getWalletToken, "wallet"):
  accounts: seq[string]

rpc(fetchOrGetCachedWalletBalances, "wallet"):
  accounts: seq[string]
  forceRefresh: bool

rpc(fetchMarketValues, "wallet"):
  tokensKeys: seq[string]
  currency: string

rpc(startWallet, "wallet"):
  discard

rpc(getTransactionEstimatedTime, "wallet"):
  chainId: int
  maxFeePerGas: string

rpc(getTransactionEstimatedTimeV2, "wallet"):
  chainId: int
  gasPrice: string
  maxFeePerGas: string
  maxPriorityFeePerGas: string

rpc(fetchPrices, "wallet"):
  tokensKeys: seq[string]
  currencies: seq[string]

rpc(fetchDecodedTxData, "wallet"):
  data: string

rpc(activityCenterNotifications, "wakuext"):
  request: ActivityCenterNotificationsRequest

rpc(activityCenterNotificationsCount, "wakuext"):
  request: ActivityCenterCountRequest

rpc(markAllActivityCenterNotificationsRead, "wakuext"):
  discard

rpc(markActivityCenterNotificationsRead, "wakuext"):
  ids: seq[string]

rpc(markActivityCenterNotificationsUnread, "wakuext"):
  ids: seq[string]

rpc(acceptActivityCenterNotifications, "wakuext"):
  ids: seq[string]

rpc(dismissActivityCenterNotifications, "wakuext"):
  ids: seq[string]

rpc(deleteActivityCenterNotifications, "wakuext"):
  ids: seq[string]

rpc(hasUnseenActivityCenterNotifications, "wakuext"):
  discard

rpc(markAsSeenActivityCenterNotifications, "wakuext"):
  discard

rpc(getBookmarks, "browsers"):
  discard

rpc(storeBookmark, "browsers"):
  bookmark: Bookmark

rpc(updateBookmark, "browsers"):
  originalUrl: string
  bookmark: Bookmark

rpc(deleteBookmark, "browsers"):
  url: string

rpc(setTenorAPIKey, "gif"):
  key: string

rpc(fetchGifs, "gif"):
  path: string

rpc(updateRecentGifs, "gif"):
  recentGifs: JsonNode

rpc(updateFavoriteGifs, "gif"):
  favoriteGifs: JsonNode

rpc(getRecentGifs, "gif"):
  discard

rpc(getFavoriteGifs, "gif"):
  discard

rpc(getDappPermissions, "permissions"):
  discard

rpc(addDappPermissions, "permissions"):
  permission: Permission

rpc(deleteDappPermissionsByNameAndAddress, "permissions"):
  dapp: string
  address: string

rpc(fetchTokenDetails, "wallet"):
  tokenKeys: seq[string]

rpc(saveOrUpdateKeycard, "accounts"):
  keycard: JsonNode
  password: string

rpc(deleteKeycardAccounts, "accounts"):
  keycardUid: string
  accountsToRemove: seq[string]

rpc(getAllKnownKeycards, "accounts"):
  discard

rpc(getKeycardsWithSameKeyUID, "accounts"):
  keyUid: string

rpc(getKeycardByKeycardUID, "accounts"):
  keycardUid: string

rpc(setKeycardName, "accounts"):
  keycardUid: string
  keyPairName: string

rpc(keycardLocked, "accounts"):
  keycardUid: string

rpc(keycardUnlocked, "accounts"):
  keycardUid: string

rpc(updateKeycardUID, "accounts"):
  oldKeycardUID: string
  newKeycardUID: string

rpc(deleteKeycard, "accounts"):
  keycardUid: string

rpc(deleteAllKeycardsWithKeyUID, "accounts"):
  keyUid: string

rpc(moveWalletAccount, "accounts"):
  fromPosition: int
  toPosition: int

rpc(updateTokenPreferences, "accounts"):
  preferences: seq[TokenPreferencesDto]

rpc(getTokenPreferences, "accounts"):
  discard

rpc(updateKeypairName, "accounts"):
  keyUid: string
  name: string

rpc(getHourlyMarketValues, "wallet"):
  tokenKey: string
  currency: string
  limit: int
  aggregate: int

rpc(getDailyMarketValues, "wallet"):
  tokenKey: string
  currency: string
  limit: int
  allDate: bool
  aggregate: int

rpc(getName, "ens"):
  chainId: int
  address: string

rpc(getCachedCurrencyFormats, "wallet"):
  discard

rpc(fetchAllCurrencyFormats, "wallet"):
  discard

rpc(hasPairedDevices, "accounts"):
  discard

rpc(getBalancesByChain, "wallet"):
  chainIds: seq[int]
  addresses: seq[string]
  tokenAddresses: seq[string]

rpc(restartWalletReloadTimer, "wallet"):
  discard

rpc(isChecksumValidForAddress, "wallet"):
  address: string

rpc(fetchMarketTokenPageAsync, "wallet"):
  page: int
  pageSize: int
  sortOrder: int
  currency: string

rpc(unsubscribeFromLeaderboard, "wallet"):
  discard
