import QtQuick

import StatusQ.Core.Utils

QObject {
    id: root

    /// An WalletConnect.session_request event data looks like this:
    /// {
    ///     topic,
    ///     params: {
    ///         request: [requestParamsMessage]
    ///     },
    ///     id
    /// }
    required property var event

    /// dApp request data
    required property string topic
    required property string requestId
    required property string method
    required property string accountAddress
    required property string chainId
    // optional expiry date in ms
    property var expirationTimestamp
    property bool active: false

    // Maps to Constants.DAppConnectors values
    required property int sourceId

    required property var data
    // Data prepared for display in a human readable format
    required property var preparedData

    required property string dappName
    required property string dappUrl
    required property string dappIcon

    /// extra data resolved from wallet
    property bool haveEnoughFunds: false
    property bool haveEnoughFees: false

    property var /* Big */ fiatMaxFees
    property string fiatSymbol
    property var /* Big */ nativeTokenMaxFees
    property string nativeTokenGroupKey
    property var feesInfo
    // hex gas the fees are shown for and the tx is signed with
    property string gasLimit
    property var /* Big */ value

    /// maps to Constants.TransactionEstimatedTime values
    property int estimatedTimeCategory: 0
    signal expired()

    function isExpired() {
        return !!expirationTimestamp && expirationTimestamp > 0 && Math.floor(Date.now() / 1000) >= expirationTimestamp
    }

    function setExpired() {
        expirationTimestamp = Math.floor(Date.now() / 1000)
        expired()
    }

    function setActive() {
        active = true
    }
}
