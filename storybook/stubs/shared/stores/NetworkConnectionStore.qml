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

    function getBlockchainNetworkDownText(chains) { return "" }
    function getBlockchainNetworkDownTextForToken(balances) { return "" }
    function getMarketNetworkDownText() { return "" }
}
