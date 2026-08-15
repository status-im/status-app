import QtQuick

// Required mock of: src/app/modules/main/wallet_section/send/view.nim
//
// Still the legacy send module: the swap flow routes through it, so the signals
// SwapStore connects to have to exist or every Connections binding warns.

Item {
    id: root

    readonly property string contextPropertyName: "walletSectionSend"

    readonly property ListModel accounts: ListModel {}
    readonly property QtObject selectedReceiveAccount: QtObject {}

    readonly property ListModel fromNetworksRouteModel: ListModel {}
    readonly property ListModel toNetworksRouteModel: ListModel {}

    property string selectedReceiveAccountAddress: ""
    property string selectedSenderAccountAddress: ""
    property string selectedAssetKey: ""
    property string selectedRecipient: ""
    property bool showUnPreferredChains: false
    property int sendType: 0

    signal suggestedRoutesReady(var txRoutes, string errCode, string errDescription)
    signal transactionSent(var uuid, var chainId, var approvalTx, var txHash, var error)
    signal transactionSendingComplete(var txHash, var success)
    signal signingRequested(string keyUid, string txHash, string path, string address)

    // Last call of each kind, so a page or test can assert what was requested.
    property var lastRouteRequest: null

    function fetchSuggestedRoutesWithParameters(uuid, accountFrom, accountTo, amountIn, amountOut,
                                                tokenFrom, tokenTo, fromChainID, toChainID,
                                                sendType, slippagePercentage) {
        root.lastRouteRequest = ({
            uuid: uuid, accountFrom: accountFrom, accountTo: accountTo, amountIn: amountIn,
            amountOut: amountOut, tokenFrom: tokenFrom, tokenTo: tokenTo,
            fromChainID: fromChainID, toChainID: toChainID, sendType: sendType,
            slippagePercentage: slippagePercentage
        })
    }

    function resetData() {}
    function authenticateAndTransfer(uuid) {}
    function reevaluateSwap(routerInputParamsUuid, chainId, isApprovalTx) {}
    function onSigningResult(signature) {}
    function setSendType(sendType) { root.sendType = sendType }
    function setSelectedRecipient(recipientAddress) { root.selectedRecipient = recipientAddress }
}
