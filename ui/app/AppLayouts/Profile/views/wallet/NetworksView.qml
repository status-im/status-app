import QtQml
import QtQuick

import shared.status
import shared.popups
import shared.panels

import AppLayouts.Profile.popups.networkSettings

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Popups.Dialog

import utils

import QtModelsToolkit
import SortFilterProxyModel

import "../../stores"
import "../../controls"

Item {
    id: root

    implicitHeight: column.implicitHeight

    signal goBack

    readonly property int mainnetTabIndex: 0
    readonly property int testnetTabIndex: 1

    required property var flatNetworks
    required property bool areTestNetworksEnabled

    signal editNetwork(int chainId)
    signal setNetworkActive(int chainId, bool active)

    function overrideInitialTabIndex(index) {
        d.overrideInitialTabIndex = index
    }

    onAreTestNetworksEnabledChanged: d.checkTestModeTab()

    QtObject {
        id: d

        Component.onCompleted: d.checkTestModeTab()

        property int overrideInitialTabIndex: -1

        function checkTestModeTab() {
            if (d.overrideInitialTabIndex >= 0) {
                testModeViewTabBar.currentIndex = d.overrideInitialTabIndex
                d.overrideInitialTabIndex = -1
                return
            }
            testModeViewTabBar.currentIndex = root.areTestNetworksEnabled ? root.testnetTabIndex : root.mainnetTabIndex
        }

        property var currentTestModeNetworks: SortFilterProxyModel {
            sourceModel: root.flatNetworks
            filters: ValueFilter {
                roleName: "isTest"
                value: testModeViewTabBar.currentIndex === root.testnetTabIndex
            }
        }

        property var currentActiveNetworks: SortFilterProxyModel {
            sourceModel: d.currentTestModeNetworks
            filters: ValueFilter {
                roleName: "isActive"
                value: true
            }
        }

        readonly property int currentActiveNetworksCount: d.currentActiveNetworks.ModelCount.count
    }

    Column {
        id: column
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width
        spacing: 0

        StatusTabBar {
            id: testModeViewTabBar
            objectName: "testModeViewTabBar"
            StatusTabButton {
                text: qsTr("Mainnet")
                objectName: "testModeViewMainButton"
                width: implicitWidth
            }
            StatusTabButton {
                text: qsTr("Testnet")
                objectName: "testModeViewTestButton"
                width: implicitWidth
            }
        }

        Repeater {
            id: networkList
            model: d.currentTestModeNetworks
            delegate: WalletNetworkDelegate {
                objectName: "walletNetworkDelegate_" + model.chainName + '_' + model.chainId
                chainName: model.chainName
                iconUrl: model.iconUrl
                isActive: model.isActive
                isDeactivatable: model.isDeactivatable
                showNewIcon: Constants.chains.newChains.indexOf(model.chainId) >= 0

                onSetNetworkActive: function (active) {
                    if (!active) {
                        // Launch confirmation popup
                        Global.openPopup(deactivateNetworkPopupComponent, {chainId: model.chainId, iconUrl: model.iconUrl, chainName: model.chainName})
                        return
                    }
                    if (d.currentActiveNetworksCount >= Constants.maxActiveNetworks && active) {
                        Global.openPopup(activeNetworkLimitPopupComponent)
                        return
                    }
                    // Set network active
                    root.setNetworkActive(model.chainId, active)
                }

                onEditNetwork: root.editNetwork(model.chainId)
            }
        }
    }

    Component {
        id: deactivateNetworkPopupComponent
        DeactivateNetworkPopup {
            width: 556
            onAccepted: {
                root.setNetworkActive(chainId, false)
            }
        }
    }

    Component {
        id: activeNetworkLimitPopupComponent
        ActiveNetworkLimitPopup {
            width: 521
        }
    }
}
