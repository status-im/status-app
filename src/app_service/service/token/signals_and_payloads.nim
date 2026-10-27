#################################################
# Signals emitted by token service
#################################################

const SIGNAL_TOKEN_HISTORICAL_DATA_LOADED* = "tokenHistoricalDataLoaded"
const SIGNAL_TOKENS_LIST_UPDATED* = "tokensListUpdated"
const SIGNAL_TOKENS_DETAILS_UPDATED* = "tokensDetailsUpdated"
const SIGNAL_TOKENS_MARKET_VALUES_ABOUT_TO_BE_UPDATED* = "tokensMarketValuesAboutToBeUpdated"
const SIGNAL_TOKENS_MARKET_VALUES_UPDATED* = "tokensMarketValuesUpdated"
const SIGNAL_TOKEN_PREFERENCES_UPDATED* = "tokenPreferencesUpdated"
# a held catalogue copy loaded or was dropped
const SIGNAL_TOKEN_CATALOGUE_CHANGED* = "tokenCatalogueChanged"
# a held catalogue copy started or stopped loading
const SIGNAL_TOKEN_CATALOGUE_LOADING_CHANGED* = "tokenCatalogueLoadingChanged"

#################################################
# Payload sent via above defined signals
#################################################

type
  ResultArgs* = ref object of Args
    success*: bool

type
  TokenHistoricalDataArgs* = ref object of Args
    result*: string

type
  TokenCatalogueChangedArgs* = ref object of Args
    kind*: TokenCatalogueKind
    chainId*: int # tckChainTokenGroups only
    # the copy was dropped, not loaded (SIGNAL_TOKEN_CATALOGUE_CHANGED only)
    dropped*: bool
