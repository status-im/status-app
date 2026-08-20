import QtQuick

QtObject {
    property bool isOnline: true
    property var blockchainNetworksDown: []
    property bool walletReadyForTransactionsEnabled: true
    property string walletReadyForTransactionsToolTipText: ""

    // Consumed by the real wallet views now that they run on this stub
    property bool accountBalanceNotAvailable: false
    property string accountBalanceNotAvailableText: ""
    property bool collectiblesNetworkUnavailable: false

    // Real store parses this out of networkConnectionModule's JSON, so it is
    // always an array; leaving it unset made CollectiblesView's filter throw.
    property var unsupportedCollectibleChains: []

    function getBlockchainNetworkDownText(chains) { return "" }
    function getBlockchainNetworkDownTextForToken(balances) { return "" }
    function getMarketNetworkDownText() { return "" }
}
