import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Core.Theme
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
    property alias selection: scrollView.selection

    property bool showNewChainIcon: false

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

    contentItem: ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4

        NetworkSelectorView {
            id: scrollView
            Layout.fillWidth: true

            model: root.flatNetworks
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
        }
    }
}
