import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.views.wallet

import Storybook

import Models

import StatusQ.Core.Utils

import utils

SplitView {
    Logs { id: logs }

    QtObject {
        id: d

        property var rpcProviders: ListModel {
            Component.onCompleted: append([
                {
                    chainId: NetworksModel.mainnetChainId,
                    name: "User Mainnet #1",
                    url: "https://mainnet.mynode.io/1/",
                    isEnabled: true,
                    providerType: Constants.rpcProviderTypes.user
                },
                {
                    chainId: NetworksModel.mainnetChainId,
                    name: "User Mainnet #2",
                    url: "https://mainnet.mynode.io/2/",
                    isEnabled: true,
                    providerType: Constants.rpcProviderTypes.user
                }
            ])
        }

        property var timer: Timer {
            interval: 400
            onTriggered: {
                networkModule.chainIdFetchedForUrl(
                    networkModule.url,
                    NetworksModel.mainnetChainId,
                    checkbox.checked,
                    networkModule.isMainUrl
                )
            }
        }
    }

    property var networkModule: QtObject {
        id: networkModule
        signal chainIdFetchedForUrl(string url, int chainId, bool success, bool isMainUrl)
        property string url
        property bool isMainUrl

        function evaluateRpcEndPoint(url, isMainUrl) {
            networkModule.url = url
            networkModule.isMainUrl = isMainUrl
            d.timer.restart()
        }
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        ScrollView {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            EditNetworkView {
                width: 560
                network: ModelUtils.getByKey(NetworksModel.flatNetworks, "chainId", NetworksModel.mainnetChainId)
                rpcProviders: d.rpcProviders
                networksModule: networkModule
                networkRPCChanged: ({})
                onEvaluateRpcEndPoint: networkModule.evaluateRpcEndPoint(url, isMainUrl)
                onUpdateNetworkValues: logs.logEvent("EditNetworkView::updateNetworkValues",
                                                     ["chainId", "mainRpc", "failoverRpc"],
                                                     [chainId, newMainRpcInput, newFailoverRpcUrl])
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: childrenRect.height

            logsView.logText: logs.logText

            CheckBox {
                id: checkbox
                text: "RPC fetch succeeds"
                checked: true
            }
        }
    }
}

// category: Views
