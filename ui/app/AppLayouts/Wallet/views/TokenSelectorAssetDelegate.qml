import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils

ItemDelegate {
    id: root

    objectName: "tokenSelectorAssetDelegate_" + name

    required property string name
    required property string symbol
    required property string currencyBalanceAsString
    required property string iconSource
    required property bool isAutoHovered

    // expected structure: [iconUrl: string, balance: double]
    property alias balancesModel: balancesListView.model

    property alias balancesListInteractive: balancesListView.interactive

    spacing: Theme.halfPadding
    horizontalPadding: Theme.padding
    verticalPadding: 4

    opacity: enabled ? 1 : 0.3
    implicitHeight: 60

    icon.width: 32
    icon.height: 32
    icon.source: iconSource

    background: Rectangle {
        radius: Theme.radius
        color: root.hovered || root.isAutoHovered
               ? Theme.palette.baseColor2
               : root.highlighted
                 ? Theme.palette.statusListItem.highlightColor
                 : "transparent"

        HoverHandler {
            cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        spacing: root.spacing

        // asset icon
        StatusRoundedImage {
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
            image.source: root.icon.source
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            // name, symbol, total balance
            RowLayout {
                Layout.fillWidth: true
                spacing: root.spacing

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: childrenRect.height

                    StatusBaseText {
                        id: nameText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - symbolText.width
                                        - symbolText.anchors.leftMargin)
                        text: root.name
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StatusBaseText {
                        id: symbolText
                        anchors.left: nameText.right
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.symbol
                        color: Theme.palette.baseColor1
                    }
                }

                StatusBaseText {
                    font.weight: Font.Medium
                    text: root.currencyBalanceAsString
                }
            }

            // balances per chain
            StatusListView {
                id: balancesListView

                objectName: "balancesListView"

                Layout.maximumWidth: parent.width
                Layout.preferredWidth: contentWidth
                Layout.preferredHeight: 22

                ScrollBar.horizontal: null

                orientation: ListView.Horizontal
                spacing: root.spacing
                visible: count
                interactive: root.balancesListInteractive

                delegate: RowLayout {
                    height: ListView.view.height
                    spacing: 4

                    StatusRoundedImage {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        image.source: Assets.svg(model.iconUrl)
                    }
                    StatusBaseText {
                        font.pixelSize: Theme.tertiaryTextFontSize
                        // numeric balance formatted at the UI layer (no currency symbol)
                        text: LocaleUtils.currencyAmountToLocaleString(
                                  {amount: model.balance, displayDecimals: 2}, {noSymbol: true})
                    }
                }

                // let the root handle the click
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.clicked()
                }
            }
        }
    }
}
