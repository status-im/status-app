import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Utils as SQUtils

import shared.popups.walletconnect

StatusMouseArea {
    id: root
    implicitHeight: 50

    hoverEnabled: true

    required property string name
    required property url url
    required property url iconUrl
    required property url connectorBadge
    required property string topic
    property bool clickable: true

    signal disconnectDapp(string topic)
    signal dappClicked(string dappUrl)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TapHandler {
                id: dappTapHandler
                enabled: root.clickable
                onTapped: {
                    root.dappClicked(root.url)
                }
            }

            HoverHandler {
                id: dappHoverHandler
                enabled: root.clickable
                cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40

                    RoundImageWithBadge {
                        id: iconImage

                        anchors.fill: parent

                        imageUrl: root.iconUrl
                        badgeIcon: root.connectorBadge
                        badgeSize: 14
                        badgeMargin: 2
                    }
                }

                ColumnLayout {
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.fillWidth: true

                    StatusBaseText {
                        id: dAppCaption

                        text: root.name ? root.name : (root.url ? SQUtils.StringUtils.extractDomainFromLink(root.url) : "")

                        Layout.fillWidth: true

                        font.pixelSize: Theme.additionalTextSize
                        font.bold: true

                        elide: Text.ElideRight

                        clip: true
                    }
                    StatusBaseText {
                        text: root.url

                        Layout.fillWidth: true

                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.directColor5

                        elide: Text.ElideRight

                        clip: true
                    }
                }
            }
        }

        StatusFlatButton {
            objectName: "disconnectDappButton"
            size: StatusBaseButton.Size.Large

            asset.color: Theme.palette.directColor1
            icon.name: "disconnect"
            tooltip.text: qsTr("Disconnect dApp")

            onClicked: {
                root.disconnectDapp(root.topic)
        }
        }
    }
}
