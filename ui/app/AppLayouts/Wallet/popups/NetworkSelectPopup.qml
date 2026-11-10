import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

import QtModelsToolkit

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

    padding: Theme.defaultHalfPadding
    implicitWidth: 300

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
            // an empty model (still loading or resetting) cannot validate the
            // selection; keep it untouched until rows are available again
            if (d.networksCount === 0)
                return

            let selection = root.selection

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

        function selectAll() {
            const chainIds = ModelUtils.modelToFlatArray(root.flatNetworks, "chainId")
            const initialSelection = [...root.selection]
            for (let index = 0; index < chainIds.length; index++) {
                const chainId = chainIds[index]
                if (initialSelection.includes(chainId))
                    continue

                d.commitSelection(chainIds.filter(id => id === chainId || root.selection.includes(id)))
                root.toggleNetwork(chainId, index)
            }
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
        anchors.margins: Theme.defaultHalfPadding
        active: root.visible
        onLoaded: active = true // latch: keep content alive across close/reopen
        sourceComponent: ColumnLayout {
            spacing: Theme.defaultHalfPadding
            NetworkSelectItemDelegate {
                Layout.fillWidth: true
                objectName: "selectAllButton"
                visible: root.multiSelection
                interactive: root.selectionAllowed && d.networksCount > 0
                text: qsTr("All networks")
                icon.source: Assets.svg("network")
                icon.color: Theme.palette.primaryColor1
                showIndicator: root.showSelectionIndicator
                checked: d.networksCount > 0 && root.selection.length === d.networksCount
                checkable: false // not user-checkable
                onClicked: d.selectAll()
            }
            Separator {
                visible: root.multiSelection
            }
            NetworkSelectorView {
                Layout.fillWidth: true
                // shrinks and scrolls when the window cuts the popup short
                Layout.fillHeight: true

                model: root.flatNetworks
                // copy: the view mutates its selection array in place, so it
                // must own a distinct instance; this binding survives those
                // mutations and keeps the popup -> view direction live
                selection: [...root.selection]
                disableChainsWithNoCommunitiesSupport: root.disableChainsWithNoCommunitiesSupport
                selectionAllowed: root.selectionAllowed
                multiSelection: root.multiSelection
                showIndicator: root.showSelectionIndicator
                showNewChainIcon: root.showNewChainIcon
                spacing: parent.spacing

                onItemClicked: {
                    if (!root.multiSelection && root.closePolicy !== Popup.NoAutoClose)
                        root.close()
                }
                onToggleNetwork: (chainId, index) => root.toggleNetwork(chainId, index)
                onSelectionChanged: d.commitSelection(selection)
            }
            Separator {
                visible: root.showManageNetworksButton
            }
            StatusButton {
                objectName: "manageNetworksButton"
                visible: root.showManageNetworksButton
                Layout.fillWidth: true

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

    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.palette.separator
    }
}
