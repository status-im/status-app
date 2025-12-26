import QtQuick

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ

import utils

import shared.stores as SharedStores

QtObject {
    id: root

    required property SharedStores.NetworksStore networksStore

    /* PRIVATE: Modules used to get data from backend */
    readonly property var _allTokensModule: !!walletSectionAllTokens ? walletSectionAllTokens : null
    readonly property var _networksModule: !!networksModule ? networksModule : null

    readonly property double tokenListUpdatedAt: root._allTokensModule.tokenListUpdatedAt

    readonly property bool marketHistoryIsLoading: Global.appIsReady ? walletSectionAllTokens.marketHistoryIsLoading : false


    /* This contains all token lists, except native, custom and community, if you need them, refer to `root._allTokensModule.tokenListsModel` */
    readonly property var tokenListsModel: SortFilterProxyModel {
        sourceModel: !!root._allTokensModule ? root._allTokensModule.tokenListsModel : null

        filters: FastExpressionFilter {
            function shouldDisplayList(listId) {
                return listId !== Constants.hiddenTokenLists.nativeList &&
                        listId !== Constants.hiddenTokenLists.custom &&
                        listId !== Constants.hiddenTokenLists.community
            }

            expression: {
                return shouldDisplayList(model.id)
            }

            expectedRoles: ["id"]
        }
    }


    /*
        This list contains all token groups (key is a group key (which is crossChainId if set, otherwise token key)

        Exposed fields:
        key                         [string]    - refers to token group key
        name                        [string]    - token's name
        symbol                      [string]    - token's symbol
        decimals                    [int]       - token's decimals
        logoUri                     [string]    - token's image
        tokens                      [model]     - contains tokens that belong to the same token group (a single token per chain), has at least a single token
            key                     [string]    - token key
            groupKey                [string]    - token group key
            crossChainId            [string]    - cross chain id
            address                 [string]    - token's address
            name:                   [string]    - token's name
            symbol:                 [string]    - token's symbol
            decimals:               [int]       - token's decimals
            chainId:                [int]       - token's chain id
            image:                  [string]    - token's image
            customToken             [bool]      - `true` if the it's a custom token
            communityId             [string]    - contains community id if the token is a community token
        communityId                 [string]    - contains community id if the token is a community token
        websiteUrl                  [string]    - token's website
        description                 [string]    - token's description
        marketDetails               [object]    - contains market data
            changePctHour           [double]    - percentage change hour
            changePctDay            [double]    - percentage change day
            changePct24hour         [double]    - percentage change 24 hrs
            change24hour            [double]    - change 24 hrs
            marketCap               [object]
                amount              [double]    - market capitalization value
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
            highDay                 [object]
                amount              [double]    - the highest value for day
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
            lowDay                  [object]
                amount              [double]    - the lowest value for day
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
            currencyPrice           [object]
                amount              [double]    - token's price
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
        detailsLoading              [bool]      - `true` if details are still being loaded
        marketDetailsLoading        [bool]      - `true` if market details are still being loaded
        visible                     [bool]      - determines if token is displayed or not
        position                    [int]       - token's position
    */
    readonly property var tokenGroupsModel: !!root._allTokensModule ? root._allTokensModule.tokenGroupsModel : null
    readonly property var tokenGroupsForChainModel: !!root._allTokensModule ? root._allTokensModule.tokenGroupsForChainModel : null
    readonly property var searchResultModel: !!root._allTokensModule ? root._allTokensModule.searchResultModel : null

    // Property and methods below are used to apply advanced token management settings to the SendModal

    // Temporarily disabled, refer to https://github.com/status-im/status-app/issues/15955 for details.
    readonly property bool showCommunityAssetsInSend: true //root._allTokensModule.showCommunityAssetWhenSendingTokens
    readonly property bool displayAssetsBelowBalance: root._allTokensModule.displayAssetsBelowBalance
    readonly property bool autoRefreshTokensLists: root._allTokensModule.autoRefreshTokensLists

    signal displayAssetsBelowBalanceThresholdChanged()

    function buildGroupsForChain(chainId, mandatoryKeys) {
        root._allTokensModule.buildGroupsForChain(chainId, mandatoryKeys)
    }

    // Due to performance reasons, use this function as the last option, when you're sure the token is not present in the models.
    function getTokenByKeyOrGroupKeyFromAllTokens(key) {

        const defaultValue = {
            key: "",
            groupKey: "",
            crossChainId: "",
            address: "",
            name: "",
            symbol: "",
            decimals: 0,
            hainId: 0,
            logoUri: "",
            customToken:false,
            communityId: "",
            type: ""
        }

        const jsonToken = root._allTokensModule.getTokenByKeyOrGroupKeyFromAllTokens(key)

        try {
            return JSON.parse(jsonToken)
        }
        catch (e) {
            console.warn("error parsing token for the key: ", key)
            return defaultValue
        }
    }

    function getHistoricalDataForToken(tokenKey, currency) {
        root._allTokensModule.getHistoricalDataForToken(tokenKey, currency)
    }

    function getDisplayAssetsBelowBalanceThresholdCurrency() {
        return root._allTokensModule.displayAssetsBelowBalanceThreshold
    }

    function getDisplayAssetsBelowBalanceThresholdDisplayAmount() {
        const thresholdCurrency = getDisplayAssetsBelowBalanceThresholdCurrency()
        return thresholdCurrency.amount / Math.pow(10, thresholdCurrency.displayDecimals)
    }

    function setDisplayAssetsBelowBalanceThreshold(rawValue) {
        // rawValue - raw amount (multiplied by displayDecimals)`
        root._allTokensModule.setDisplayAssetsBelowBalanceThreshold(rawValue)
    }

    function toggleShowCommunityAssetsInSend() {
        root._allTokensModule.toggleShowCommunityAssetWhenSendingTokens()
    }

    function toggleDisplayAssetsBelowBalance() {
        root._allTokensModule.toggleDisplayAssetsBelowBalance()
    }

    function toggleAutoRefreshTokensLists() {
        root._allTokensModule.toggleAutoRefreshTokensLists()
    }

    readonly property Connections allTokensConnections: Connections {
        target: root._allTokensModule

        function onDisplayAssetsBelowBalanceThresholdChanged() {
            root.displayAssetsBelowBalanceThresholdChanged()
        }
    }

    function updateTokenPreferences(jsonData) {
        root._allTokensModule.updateTokenPreferences(jsonData)
    }

    function getTokenPreferencesJson(jsonData) {
        return root._allTokensModule.getTokenPreferencesJson(jsonData)
    }

    function tokenAvailableForBridgingViaHop(tokenChainId, tokenAddress) {
        return root._allTokensModule.tokenAvailableForBridgingViaHop(tokenChainId, tokenAddress)
    }

    function getListOfTokenKeysAvailableForSwapViaParaswap(chainId) {
        const jsonListAsString = root._allTokensModule.getListOfTokenKeysAvailableForSwapViaParaswap(chainId)

        try {
            return JSON.parse(jsonListAsString)
        }
        catch (e) {
            console.warn("unable to parse the list of available tokens", e)
            return []
        }
    }
}
