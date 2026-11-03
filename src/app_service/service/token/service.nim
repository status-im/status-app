import nimqml, tables, sets, json, std/sequtils, chronicles, strutils, sugar, algorithm, std/times

import web3/eth_api_types
import backend/backend as backend

import app_service/common/utils as common_utils
import app_service/common/wallet_constants as common_wallet_constants
import app_service/service/general/debouncer as debouncer_service
import app_service/service/network/service as network_service
import app_service/service/settings/service as settings_service

import app/core/eventemitter
import app/core/held_resource_qtimer
import app/core/tasks/[qt, threadpool]
import app/core/signals/types
import app/global/feature_flags
import constants as main_constants
when main_constants.IS_MOBILE:
  import app/global/app_signals
import app_service/common/cache

import json_serialization
import nimqml, json, chronicles
import backend/tokens as status_go_tokens

import dto/types as dto_types
import items/types as items_types
import token_lookup_cache
import token_group_lookup
import token_missing_fetch
import token_pending_fetch
import token_refresh_generation
import token_apply_builder
import token_market_values_apply
import token_price_requests
import held_token_catalogue

export held_token_catalogue

export dto_types, items_types


logScope:
  topics = "token-service"


include signals_and_payloads
include app_service/common/json_utils
include async_tasks

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    networkService: network_service.Service
    settingsService: settings_service.Service
    rebuildMarketDataDebouncer: debouncer_service.Debouncer

    # local storage, fulfilled by need, empty at the start
    chainsSupportedForSwap: Table[int, bool] # [chainId, bool], refers to the active swap provider
    swapSupportChainIdsInFlight: HashSet[int] # chains used for a prefetch check
    # local storage
    tokensOfInterestByKey: Table[string, TokenItem] # [tokenKey, TokenItem]
    tokensOfInterestReadiness: TokenMapReadiness
    knownMissingKeys: HashSet[string] # keys the backend confirmed as "not found"; skip re-fetching until a refresh applies
    pendingTokenFetch: PendingTokenFetch # missing keys awaiting an async batch fetch (replaces the sync GUI-thread RPC)
    missingTokenKeysFetchDebouncer: debouncer_service.Debouncer # coalesces a burst of misses into one batch
    onDemandPrices: OnDemandPriceRequests # prices asked for by key (catalog tokens the periodic refresh doesn't cover)
    onDemandPricesDebouncer: debouncer_service.Debouncer # coalesces a burst of by-key price requests into one fetch
    groupsOfInterestByKey: Table[string, TokenGroupItem] # [tokenGroupKey, TokenGroupItem]
    groupsOfInterest: seq[TokenGroupItem] # refers to groups for tokens of interest
    groupTokensLookups: GroupTokensCache # groups outside the tokens of interest, fetched on demand; cleared on refresh
    # token lists, all token groups and groups per chain, loaded only while held
    catalogue: HeldTokenCatalogue
    tokenDetailsTable: Table[string, TokenDetailsItem] # [tokenKey, TokenDetailsItem]
    tokenMarketValuesTable: Table[string, TokenMarketValuesItem] # [tokenKey, TokenMarketValuesItem]
    tokenPriceTable: Table[string, float64] # [tokenKey, price]
    tokenPreferencesTable: Table[string, TokenPreferencesItem] # [crossChainId-or-tokenKey, TokenPreferencesItem]

    tokenPreferencesJson: string
    tokensDetailsLoading: bool
    tokensPricesLoading: bool
    tokensMarketDetailsLoading: bool
    hasMarketDetailsCache: bool
    hasPriceValuesCache: bool
    tokenListUpdatedAt: int64
    # Generation coalescing for the tokens refresh: N queued triggers -> one apply
    # of the newest data, no piling-up in-flight tasks.
    refreshTokensGen: RefreshGenerationState

  # Forward declaration
  proc getCurrency*(self: Service): string
  proc rebuildMarketData*(self: Service)
  proc fetchTokenPreferences(self: Service)
  proc scheduleMissingTokenKeysFetch(self: Service)
  proc fetchPendingMissingTokenKeys(self: Service)
  proc fetchPendingOnDemandPrices(self: Service)
  proc startRefreshTokensTask(self: Service, generation: int)
  proc startFetchAllTokenListsTask(self: Service, generation: int)
  proc startFetchAllTokenGroupsTask(self: Service, generation: int)
  proc startFetchChainTokenGroupsTask(self: Service, chainId: int, generation: int)

  # All slots defined in included files have to be forward declared
  proc tokensMarketValuesRetrieved(self: Service, response: string) {.slot.}
  proc tokensDetailsRetrieved(self: Service, response: string) {.slot.}
  proc tokensPricesRetrieved(self: Service, response: string) {.slot.}
  proc onDemandTokensPricesRetrieved(self: Service, response: string) {.slot.}
  proc tokenHistoricalDataResolved*(self: Service, response: string) {.slot.}
  proc onAsyncRefreshTokensDone(self: Service, response: string) {.slot.}
  proc onAsyncFetchAllTokenListsDone(self: Service, response: string) {.slot.}
  proc onAsyncFetchMissingTokensDone(self: Service, response: string) {.slot.}
  proc onAsyncBuildGroupsForChainDone(self: Service, response: string) {.slot.}
  proc onAsyncFetchAllTokenGroupsDone(self: Service, response: string) {.slot.}
  proc prefetchSwapSupportRetrieved(self: Service, response: string) {.slot.}


  proc delete*(self: Service)

  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    networkService: network_service.Service,
    settingsService: settings_service.Service
  ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.networkService = networkService
    result.settingsService = settingsService

    result.tokensOfInterestByKey = initTable[string, TokenItem]()
    result.knownMissingKeys = initHashSet[string]()
    result.pendingTokenFetch = initPendingTokenFetch()
    result.onDemandPrices = initOnDemandPriceRequests()
    result.refreshTokensGen = initRefreshGenerationState()
    let service = result
    result.catalogue = newHeldTokenCatalogue(
      makeResource = proc(name: string, onLoad: proc(generation: int), onDrop: proc()): HeldResource =
        newHeldResourceWithQTimers(name, onLoad, onDrop),
      makeKeyedResources = proc(name: string, onLoad: proc(key: int, generation: int),
          onDrop: proc(key: int)): HeldResources[int] =
        newHeldResourcesWithQTimers[int](name, onLoad, onDrop),
      fetches = TokenCatalogueFetches(
        tokenLists: proc(generation: int) = service.startFetchAllTokenListsTask(generation),
        allTokenGroups: proc(generation: int) = service.startFetchAllTokenGroupsTask(generation),
        chainTokenGroups: proc(chainId: int, generation: int) =
          service.startFetchChainTokenGroupsTask(chainId, generation),
      ),
      changed = proc(kind: TokenCatalogueKind, chainId: int, dropped: bool) =
        service.events.emit(SIGNAL_TOKEN_CATALOGUE_CHANGED,
          TokenCatalogueChangedArgs(kind: kind, chainId: chainId, dropped: dropped)),
      loadingChanged = proc(kind: TokenCatalogueKind, chainId: int) =
        service.events.emit(SIGNAL_TOKEN_CATALOGUE_LOADING_CHANGED,
          TokenCatalogueChangedArgs(kind: kind, chainId: chainId)),
    )
    result.groupsOfInterestByKey = initTable[string, TokenGroupItem]()
    result.groupTokensLookups = initGroupTokensCache()
    result.tokenDetailsTable = initTable[string, TokenDetailsItem]()
    result.tokenMarketValuesTable = initTable[string, TokenMarketValuesItem]()
    result.tokenPriceTable = initTable[string, float64]()
    result.tokenPreferencesTable = initTable[string, TokenPreferencesItem]()
    result.tokensDetailsLoading = true
    result.tokensPricesLoading = true
    result.tokensMarketDetailsLoading = true
    result.hasMarketDetailsCache = false
    result.hasPriceValuesCache = false


  include service_tokens
  include service_tokens_details
  include service_tokens_preferences
  include service_main

  proc delete*(self: Service) =
    if not self.catalogue.isNil:
      self.catalogue.dispose()
    self.QObject.delete
