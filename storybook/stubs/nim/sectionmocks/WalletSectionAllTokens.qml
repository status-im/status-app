// Mock of src/app/modules/main/wallet_section/all_tokens/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionAllTokens"

    property var tokenGroupsModel: emptyModel
    property var tokenGroupsForChainModel: emptyModel
    property var tokenGroupsForChainToModel: emptyModel
    property var tokenListsModel: emptyModel
    property var searchResultModel: emptyModel

    property double tokenListUpdatedAt: 0
    property bool marketHistoryIsLoading: false
    property bool tokenListsLoading: false
    property bool groupsForChainLoading: false
    property bool groupsForChainToLoading: false
    property bool showCommunityAssetWhenSendingTokens: true
    property bool displayAssetsBelowBalance: false
    property bool autoRefreshTokensLists: false
    property bool tokenGroupByCommunity: false

    property var displayAssetsBelowBalanceThreshold: ({
        amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false
    })

    property string tokenPreferencesJson: "[]"

    readonly property ListModel emptyModel: ListModel {}


    function loadTokenLists() {}
    function buildGroupsForChain(chainId, mandatoryGroupKeysString) {}
    function buildGroupsForChainTo(chainId, mandatoryGroupKeysString) {}
    function getTokenByKeyOrGroupKeyFromAllTokens(key) { return "{}" }
    function getHistoricalDataForToken(tokenKey, currency) {}
    function getHistoricalDataForTokenByRange(tokenKey, currency, range) {}
    function setDisplayAssetsBelowBalanceThreshold(threshold) {}
    function toggleShowCommunityAssetWhenSendingTokens() {
        root.showCommunityAssetWhenSendingTokens = !root.showCommunityAssetWhenSendingTokens
    }
    function toggleDisplayAssetsBelowBalance() {
        root.displayAssetsBelowBalance = !root.displayAssetsBelowBalance
    }
    function toggleAutoRefreshTokensLists() {
        root.autoRefreshTokensLists = !root.autoRefreshTokensLists
    }
    function toggleTokenGroupByCommunity() {
        root.tokenGroupByCommunity = !root.tokenGroupByCommunity
        return root.tokenGroupByCommunity
    }
    function updateTokenPreferences(tokenPreferencesJson) {
        root.tokenPreferencesJson = tokenPreferencesJson
    }
    function getTokenPreferencesJson() { return root.tokenPreferencesJson }
    function isChainSupportedForSwapViaParaswap(chainId) { return true }
    function isChainSupportedForSwapViaLiFi(chainId) { return true }
}
