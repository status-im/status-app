import QtQuick

import SortFilterProxyModel

import StatusQ.Core
import StatusQ.Core.Utils

import utils

QtObject {
    id: root

    property var networksModuleInst: networksModule

    readonly property bool areTestNetworksEnabled: networksModuleInst?.areTestNetworksEnabled ?? false

    // Full list of networks.
    // All list representations should have L1 at the top, then grouped Active and Inactive
    // chains, sorted by chainName.
    // For use when extracting properties from a given network or in the network settings screen.
    readonly property SortFilterProxyModel allNetworks: SortFilterProxyModel {
        sourceModel: networksModuleInst?.flatNetworks ?? null
        sorters: [
            RoleSorter {
                roleName: "isDeactivatable"
                sortOrder: Qt.AscendingOrder
            },
            RoleSorter {
                roleName: "isActive"
                sortOrder: Qt.DescendingOrder
            },
            RoleSorter {
                roleName: "chainName"
                sortOrder: Qt.AscendingOrder
            }
        ]
    }

    // Networks that are currently active (that is, individually active and matching
    // the current mainnet/testnet mode).
    // For use when presenting a list of networks to the user anywhere other than the
    // networks settings screen.
    readonly property SortFilterProxyModel activeNetworks: SortFilterProxyModel {
        sourceModel: root.allNetworks
        filters: [
            ValueFilter { roleName: "isTest"; value: root.areTestNetworksEnabled },
            ValueFilter { roleName: "isActive"; value: true }
        ]
    }

    /* This property holds networks currently selected in the Wallet Main layout  */
    readonly property var networkFilters: networksModuleInst?.enabledChainIds ?? null

    readonly property var rpcProviders: networksModuleInst?.rpcProviders ?? null

    property var networkRPCChanged: ({}) // add network id to the object if changed

    function toggleTestNetworksEnabled(){
        networksModuleInst.toggleTestNetworksEnabled()
    }

    function evaluateRpcEndPoint(url, isMainUrl) {
        return networksModuleInst.fetchChainIdForUrl(url, isMainUrl)
    }

    function updateNetworkEndPointValues(chainId, newMainRpcInput, newFailoverRpcUrl) {
        networksModuleInst.updateNetworkEndPointValues(chainId, newMainRpcInput, newFailoverRpcUrl)
    }

    function setNetworkActive(chainId, active) {
        networksModuleInst.setNetworkActive(chainId, active)
    }

    function toggleNetworkEnabled(chainId) {
        networksModuleInst.toggleNetwork(chainId)
    }

    function enableNetwork(chainId) {
        networksModuleInst.enableNetwork(chainId)
    }
}
