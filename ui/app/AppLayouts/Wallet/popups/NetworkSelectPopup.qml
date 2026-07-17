import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog

import SortFilterProxyModel

import utils

import "../controls"
import "../views"

StatusDropdown {
    id: root

    required property var flatNetworks

    property bool disableChainsWithNoCommunitiesSupport
    property bool showSelectionIndicator: true
    property bool selectionAllowed: true
    property bool multiSelection: false
    property bool showManageNetworksButton: false
    property var selection: []

    property bool showNewChainIcon: false
    property bool showManageNetworksNotificationIcon: false

    signal toggleNetwork(int chainId, int index)
    signal manageNetworksClicked()


    modal: false

    padding: 4
    implicitWidth: 300

    background: Rectangle {
        radius: Theme.radius
        color: Theme.palette.background
        border.color: Theme.palette.border
        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: "#22000000"
        }
    }

    contentItem: Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        active: root.visible
        sourceComponent: ColumnLayout {
            NetworkSelectorView {
                id: scrollView
                Layout.fillWidth: true

                model: root.flatNetworks
                selection: root.selection
                disableChainsWithNoCommunitiesSupport: root.disableChainsWithNoCommunitiesSupport
                interactive: root.selectionAllowed
                multiSelection: root.multiSelection
                showIndicator: root.showSelectionIndicator
                showNewChainIcon: root.showNewChainIcon

                onToggleNetwork: (chainId, index) => {
                    if (!root.multiSelection && root.closePolicy !== Popup.NoAutoClose)
                        root.close()
                    root.toggleNetwork(chainId, index)
                }
                onSelectionChanged: {
                    if (root.selection !== selection) {
                        root.selection = selection
                    }
                }
            }

            // down-sync for external writes while the popup is open
            Connections {
                target: root
                function onSelectionChanged() {
                    if (scrollView.selection !== root.selection)
                        scrollView.selection = root.selection
                }
            }

            StatusButton {
                id: manageNetworksButton
                visible: root.showManageNetworksButton
                Layout.fillWidth: true
                Layout.margins: 4

                icon.name: "settings"
                text: qsTr("Manage networks")
                isOutline: true
                onClicked: root.manageNetworksClicked()

                Loader {
                    active: root.showManageNetworksNotificationIcon
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -2
                    anchors.horizontalCenter: parent.right
                    sourceComponent: StatusRoundIcon {
                        objectName: "manageNetworksNotificationIcon"
                        asset.width: 10
                        asset.height: 10
                        asset.bgWidth: 15
                        asset.bgColor: Theme.palette.background
                        asset.bgHeight: 15
                        asset.isImage: true
                        asset.name: Assets.png("status-gradient-dot")
                        asset.color: StatusColors.transparent
                    }
                }
            }
        }
    }
}
