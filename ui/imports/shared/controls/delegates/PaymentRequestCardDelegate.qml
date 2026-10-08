import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import StatusQ.Core

import QtQuick.Effects

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import shared.controls.chat

import utils

CalloutCard {
    id: root

    required property string amount
    required property string symbol
    required property string address
    required property string logoUri

    required property bool areTestNetworksEnabled

    property string senderName
    property string senderThumbnailImage
    property int senderColorId

    property bool highlight: false

    signal clicked(var mouse)

    implicitHeight: 187
    implicitWidth: 305 + 2 * borderWidth
    borderWidth: 2
    hoverEnabled: true
    dropShadow: d.highlight
    borderColor: d.highlight ? Theme.palette.background : Theme.palette.border

    padding: 12

    Behavior on borderColor {
        ColorAnimation { duration: 200 }
    }

    QtObject {
        id: d
        readonly property bool highlight: (root.highlight || root.hovered) && isAvailable
        readonly property bool isAvailable: !root.areTestNetworksEnabled
    }

    contentItem: ColumnLayout {
        spacing: 4
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            radius: 8
            color: Theme.palette.primaryColor3
            clip: true
            border.width: 1
            border.color: Theme.palette.primaryColor2

            StatusImage {
                anchors.fill: parent
                asynchronous: true
                source: Assets.png("chat/request_payment_banner")
            }

            Row {
                id: iconRow
                spacing: -8
                anchors.centerIn: parent
                StatusRoundedImage {
                    id: symbolImage
                    anchors.verticalCenter: parent.verticalCenter
                    image.source: root.logoUri || Constants.tokenIcon(root.symbol)
                    width: 44
                    height: width
                    image.layer.enabled: true
                    image.layer.effect: MultiEffect {
                        maskEnabled: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                        id: mask
                        maskInverted: true

                        maskSource: Item {
                            parent: root
                            layer.enabled: true
                            visible: false
                            width: mask.width + 2
                            height: mask.height + 2

                            Rectangle {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: symbolImage.width + iconRow.spacing - 2

                                width: parent.width
                                height: width
                                radius: width / 2
                            }
                        }
                    }
                }

                StatusSmartIdenticon {
                    width: symbolImage.width
                    height: symbolImage.height
                    asset.width: symbolImage.width
                    asset.height: symbolImage.height
                    asset.isImage: !!root.senderThumbnailImage
                    asset.name: root.senderThumbnailImage
                    asset.isLetterIdenticon: root.senderThumbnailImage === ""
                    asset.color: Theme.palette.userCustomizationColors[root.senderColorId]
                    asset.charactersLen: 2
                    name: root.senderName
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
        }

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            text: qsTr("Send %1 %2 to %3").arg(root.amount).arg(root.symbol).arg(Utils.compactAddress(root.address.toLowerCase(), 4))
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
        }
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Requested by %1").arg(root.senderName)
        }
    }

    StatusToolTip {
        text: qsTr("Not available in the testnet mode")
        visible: !d.isAvailable && root.hovered
        y: -height
    }

    StatusMouseArea {
        id: ma
        anchors.fill: root
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (!d.isAvailable)
                return
            root.clicked(mouse)
        }
    }
}
