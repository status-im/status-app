import QtQuick
import QtQuick.Layouts

import StatusQ.Controls

import utils

import "../../views"

ColumnLayout {
    id: root

    required property var networksModule
    property var network
    property var rpcProviders
    property var networkRPCChanged
    property bool areTestNetworksEnabled: false

    signal evaluateRpcEndPoint(string url, bool isMainUrl)
    signal updateNetworkValues(int chainId, string newMainRpcInput, string newFailoverRpcUrl)
    signal reloginRequested()

    EditNetworkForm {
        Layout.fillWidth: true
        network: root.network
        rpcProviders: root.rpcProviders
        networksModule: root.networksModule
        networkRPCChanged: root.networkRPCChanged
        onEvaluateRpcEndPoint: root.evaluateRpcEndPoint(url, isMainUrl)
        onUpdateNetworkValues: root.updateNetworkValues(chainId, newMainRpcInput, newFailoverRpcUrl)
        onReloginRequested: root.reloginRequested()
    }
}
