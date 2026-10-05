import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core

import utils

CalloutCard {
    id: root

    objectName: "paymentRequestMiniCard"

    required property string amount
    required property string symbol
    required property string logoUri

    readonly property bool containsMouse: mouseArea.hovered || closeButton.hovered

    signal close()

    implicitWidth:260
    implicitHeight: 64
    verticalPadding: 15
    horizontalPadding: 12
    borderColor: Theme.palette.directColor7
    backgroundColor: root.containsMouse ? Theme.palette.directColor7 : Theme.palette.background

    contentItem: Item {
        implicitHeight: layout.implicitHeight
        implicitWidth: layout.implicitWidth

        RowLayout {
            id: layout
            anchors.fill: parent
            spacing: 16

            StatusRoundIcon {
                id: favIcon
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                asset.width: 24
                asset.height: 24
                asset.bgColor: Theme.palette.directColor7
                asset.bgHeight: 36
                asset.bgWidth: 36
                asset.color: Theme.palette.primaryColor1
                asset.name: Assets.svg("send")

                StatusSmartIdenticon {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.right
                    asset.width: 16
                    asset.height: 16
                    asset.bgColor: root.containsMouse ? StatusColors.transparent : Theme.palette.background
                    asset.bgHeight: 20
                    asset.bgWidth: 20
                    asset.isImage: true
                    asset.name: root.logoUri || Constants.tokenIcon(root.symbol)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Payment request")
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StatusBaseText {
                        id: amountText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.rightMargin: symbolText.paintedWidth
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: root.amount
                    }
                    StatusBaseText {
                        id: symbolText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: amountText.paintedWidth + Theme.halfPadding
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                        verticalAlignment: Text.AlignVCenter
                        text: root.symbol
                    }
                }
            }

            StatusFlatButton {
                id: closeButton
                icon.name: "close"
                size: StatusBaseButton.Size.Small
                hoverColor: Theme.palette.directColor8
                textColor: Theme.palette.directColor1
                onClicked: root.close()
            }
        }
    }

    HoverHandler {
        id: mouseArea
        target: background
        cursorShape: Qt.PointingHandCursor
    }
}
