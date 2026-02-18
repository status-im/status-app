import QtQml

import utils
QtObject {
    id: root

    property string selectedWalletAddress: ""
    property int selectedNetworkChainId: -1
    property string selectedTokenGroupKey: defaultTokenGroupKey
    property string selectedProviderId: ""

    readonly property bool filledCorrectly: !!selectedWalletAddress && !!selectedTokenGroupKey && selectedNetworkChainId !== -1

    readonly property string defaultTokenGroupKey: Utils.getNativeTokenGroupKey(root.selectedNetworkChainId)

    function resetFormData() {
        selectedWalletAddress = ""
        selectedNetworkChainId = -1
        selectedTokenGroupKey = defaultTokenGroupKey
        selectedProviderId = ""
    }
}
