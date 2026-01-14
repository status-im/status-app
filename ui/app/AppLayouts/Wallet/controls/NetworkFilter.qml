import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Components.private as SQP
import StatusQ.Controls

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.Wallet.helpers
import AppLayouts.Wallet.popups

import utils

import "../views"

StatusComboBox {
    id: root

    required property var flatNetworks
    readonly property alias singleSelectionItemData: d.singleSelectionItem.item

    property bool disableChainsWithNoCommunitiesSupport: false
    property bool multiSelection: true
    property bool showSelectionIndicator: true
    property bool showTitle: true
    property bool selectionAllowed: true
    property bool showManageNetworksButton: false
    property alias selection: networkSelectorView.selection

    property bool showNewChainIcon: false
    property bool showNotificationIcon: false

    signal toggleNetwork(int chainId, int index)
    signal manageNetworksClicked()

    control.padding: 12
    control.spacing: 0
    control.rightPadding: 36
    control.topPadding: 7

    control.popup.horizontalPadding: 4
    control.popup.verticalPadding: 4

    size: StatusComboBox.Size.Small

    control.background: SQP.StatusComboboxBackground {
        height: 38
        opacity: root.interactive ? 1 : 0.5
        active: root.control.down || root.control.hovered

        Loader {
            active: root.showNotificationIcon
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 2
            anchors.horizontalCenterOffset: -2
            anchors.horizontalCenter: parent.right
            sourceComponent: StatusRoundIcon {
                objectName: "notificationIcon"
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

    control.indicator: SQP.StatusComboboxIndicator {
        x: root.control.mirrored ? root.control.horizontalPadding : root.width - width - root.control.horizontalPadding
        y: root.control.topPadding + (root.control.availableHeight - height) / 2
        opacity: root.interactive ? 1 : 0.5
        visible: !d.selectionUnavailable && root.selectionAllowed
    }

    control.contentItem: RowLayout {
        spacing: Theme.halfPadding
        StatusSmartIdenticon {
            objectName: "contentItemIcon"
            Layout.alignment: Qt.AlignVCenter
            asset.height: 24
            asset.width: 24
            asset.isImage: !root.multiSelection
            asset.name: !root.multiSelection ? Assets.svg(d.singleSelectionIconUrl) : ""
            active: !root.multiSelection
            visible: active
        }
        Row {
            id: row
            spacing: -4
            visible: chainRepeater.count > 0
            Repeater {
                id: chainRepeater
                model: SortFilterProxyModel {
                    sourceModel: root.multiSelection ? root.flatNetworks : null
                    filters: OneOfFilter {
                        roleName: "chainId"
                        array: root.selection
                    }
                }
                delegate: StatusRoundedImage {
                    id: delegateItem
                    required property var model
                    required property int index

                    width: 24
                    height: 24
                    image.source: Assets.svg(model.iconUrl)
                    z: index + 1

                    image.layer.enabled: index < chainRepeater.count - 1 && row.spacing < 0
                    image.layer.effect: OpacityMask {
                        id: mask
                        invert: true

                        maskSource: Item {
                            width: mask.width + 2
                            height: mask.height + 2

                            Rectangle {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: delegateItem.width + row.spacing

                                width: parent.width
                                height: width
                                radius: width / 2
                            }
                        }
                    }
                }
            }
        }

        StatusBaseText {
            objectName: "contentItemText"
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
            elide: Text.ElideRight
            lineHeight: 24
            lineHeightMode: Text.FixedHeight
            verticalAlignment: Text.AlignVCenter
            text: d.titleText
            visible: !!text
        }
    }

    popup: NetworkSelectPopup {
        id: networkSelectorView

        directParent: root
        relativeX: parent.width - width
        relativeY: parent.height + 4

        padding: 1
        topPadding: 8
        bottomPadding: !!d.window.window ? d.window.window.SafeArea.margins.bottom: 0

        flatNetworks: root.flatNetworks
        disableChainsWithNoCommunitiesSupport: root.disableChainsWithNoCommunitiesSupport
        selectionAllowed: root.selectionAllowed
        multiSelection: root.multiSelection
        showSelectionIndicator: root.showSelectionIndicator
        showManageNetworksButton: root.showManageNetworksButton
        showNewChainIcon: root.showNewChainIcon

        onToggleNetwork: (chainId, index) => root.toggleNetwork(chainId, index)

        onManageNetworksClicked: {
            control.popup.close()
            root.manageNetworksClicked()
        }
    }

    Connections {
        target: control.popup
        enabled: !root.multiSelection
        function onOpened() {
            if (d.selectionUnavailable)
                control.popup.close()
        }
    }

    QtObject {
        id: d
        readonly property int networksCount: root.flatNetworks.ModelCount.count
        readonly property bool noneSelected: root.selection.length === 0
        readonly property bool oneSelected: root.selection.length === 1
        readonly property bool selectionUnavailable: d.networksCount <= 1 && d.oneSelected

        readonly property ModelEntry singleSelectionItem: ModelEntry {
            sourceModel: d.oneSelected ? root.flatNetworks : null
            key: "chainId"
            value: root.selection[0] ?? -1
        }

        readonly property string singleSelectionIconUrl: singleSelectionItem.item.iconUrl ?? ""
        readonly property string singleCelectionChainName: singleSelectionItem.item.chainName ?? ""

        readonly property string titleText: {
            if (d.oneSelected && root.showTitle) {
                return d.singleCelectionChainName
            }

            if (root.multiSelection) {
                if (d.noneSelected) {
                    return  qsTr("Select networks")
                }
            }

            return ""
        }
        property var window: root.control.Window
        property int windowWidth: window ? window.width: Screen.width
        property int windowHeight: window ? window.height: Screen.height
    }
}
