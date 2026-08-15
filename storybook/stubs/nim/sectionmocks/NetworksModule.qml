// Mock of src/app/modules/main/wallet_section/networks/view.nim
import QtQuick

import Models

QtObject {
    id: root

    readonly property string contextPropertyName: "networksModule"

    // Sourced from the storybook networks model rather than left empty: the real
    // shared NetworksStore is now used everywhere, and a page with no networks
    // renders nothing at all.
    readonly property var flatNetworks: NetworksModel.flatNetworks

    property bool areTestNetworksEnabled: false
    // ":"-separated chain ids, like networks/view.nim; consumers split on it
    property string enabledChainIds: ""
    property var rpcProviders: emptyProviders

    readonly property ListModel emptyProviders: ListModel {}

    function toggleTestNetworksEnabled() {
        root.areTestNetworksEnabled = !root.areTestNetworksEnabled
    }

    function _chainIds() {
        return root.enabledChainIds === "" ? [] : root.enabledChainIds.split(":")
    }

    function toggleNetwork(chainId) {
        const ids = _chainIds()
        const index = ids.indexOf(String(chainId))
        if (index === -1)
            ids.push(String(chainId))
        else
            ids.splice(index, 1)
        root.enabledChainIds = ids.join(":")
    }

    function enableNetwork(chainId) {
        const ids = _chainIds()
        if (ids.indexOf(String(chainId)) === -1) {
            ids.push(String(chainId))
            root.enabledChainIds = ids.join(":")
        }
    }

    function setNetworkActive(chainId, active) {}
    function fetchChainIdForUrl(url, isMainUrl) { return 0 }
    function updateNetworkEndPointValues(chainId, newMainRpcInput, newFailoverRpcUrl) {}
}
