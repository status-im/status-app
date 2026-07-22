import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog

import QtModelsToolkit
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

    // Keeps the single-selection invariant (exactly one selected network,
    // defaulting to the first one) while the view below is not instantiated.
    QtObject {
        id: d

        readonly property int networksCount: root.flatNetworks.ModelCount.count
        onNetworksCountChanged: d.scheduleNormalize()

        // always deferred (callLater dedupes) so in-progress consumer writes —
        // e.g. a Binding element applying its initial selection — land first;
        // normalizing synchronously would auto-default over them
        function scheduleNormalize() {
            Qt.callLater(d.normalizeSelection)
        }

        function normalizeSelection() {
            let selection = root.selection

            // an empty model (still loading or resetting) cannot validate the
            // selection; keep it untouched until rows are available again
            if (d.networksCount === 0)
                return

            if (!root.multiSelection) {
                if (selection.length === 0)
                    selection = [ModelUtils.get(root.flatNetworks, 0, "chainId")]
                else if (selection.length > 1)
                    selection = [selection[0]]
            }

            d.commitSelection(selection)
        }

        // in-place commit: swapping the array pointer would detach literal
        // bindings installed on `selection` by the owner of this popup
        function commitSelection(newSelection) {
            if (JSON.stringify(root.selection) === JSON.stringify(newSelection))
                return
            root.selection.splice(0, root.selection.length, ...newSelection)
            root.selectionChanged()
        }
    }

    Connections {
        target: root
        function onSelectionChanged() { d.scheduleNormalize() }
        function onMultiSelectionChanged() { d.scheduleNormalize() }
    }

    Component.onCompleted: d.scheduleNormalize()

    contentItem: Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        active: root.visible
        onLoaded: active = true // latch: keep content alive across close/reopen
        sourceComponent: ColumnLayout {
            NetworkSelectorView {
                id: scrollView
                Layout.fillWidth: true

                model: root.flatNetworks
                // copy: the view mutates its selection array in place, so it
                // must own a distinct instance; this binding survives those
                // mutations and keeps the popup -> view direction live
                selection: [...root.selection]
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
                onSelectionChanged: d.commitSelection(selection)
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
