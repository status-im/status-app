#################################################
# Signals emitted by token service
#################################################

const SIGNAL_TOKEN_HISTORICAL_DATA_LOADED* = "tokenHistoricalDataLoaded"
const SIGNAL_TOKENS_LIST_UPDATED* = "tokensListUpdated"
const SIGNAL_TOKENS_DETAILS_UPDATED* = "tokensDetailsUpdated"
const SIGNAL_TOKENS_MARKET_VALUES_ABOUT_TO_BE_UPDATED* = "tokensMarketValuesAboutToBeUpdated"
const SIGNAL_TOKENS_MARKET_VALUES_UPDATED* = "tokensMarketValuesUpdated"
const SIGNAL_TOKEN_PREFERENCES_UPDATED* = "tokenPreferencesUpdated"
const SIGNAL_TOKEN_LISTS_LOADED* = "tokenListsLoaded"
const SIGNAL_GROUPS_FOR_CHAIN_LOADED* = "groupsForChainLoaded"
const SIGNAL_ALL_TOKEN_GROUPS_LOADED* = "allTokenGroupsLoaded"

#################################################
# Payload sent via above defined signals
#################################################

type
  ResultArgs* = ref object of Args
    success*: bool

type
  TokenHistoricalDataArgs* = ref object of Args
    result*: string
