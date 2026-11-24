import shared.popups.walletconnect

DAppConfirmDisconnectPopup {
    id: root

    required property string topic
    required property int connectorId
    required property string clientId

    signal disconnectRequested(string topic, string url, int connectorId, string clientId)

    onAccepted: root.disconnectRequested(root.topic, root.dappUrl, root.connectorId, root.clientId)
}
