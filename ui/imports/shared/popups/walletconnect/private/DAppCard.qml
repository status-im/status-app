import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import shared.popups.walletconnect
import utils

ColumnLayout {
    id: root
    property alias name: appNameText.text
    property url dAppUrl: ""
    property url iconUrl: ""
    // Property specifing the icon for the connector badge
    property alias connectorBadge: dappIcon.badgeIcon
    property bool connectionSuccessful
    property bool connectionAttempted

    spacing: Theme.padding

    RoundImageWithBadge {
        id: dappIcon
        objectName: "dappIcon"
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 72
        Layout.preferredHeight: Layout.preferredWidth
        badgeSize: 20
        badgeMargin: 1

        imageUrl: iconUrl
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        StatusBaseText {
            id: appNameText
            objectName: "appNameText"
            Layout.fillWidth: true
            Layout.maximumWidth: root.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.bold: true
            font.pixelSize: Theme.secondaryAdditionalTextSize
            textFormat: Text.PlainText
        }

        StatusFlatButton {
            id: appUrlText
            objectName: "appUrlControl"
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width
            icon.name: "external-link"
            icon.color: hovered ? Theme.palette.baseColor1 : Theme.palette.directColor1
            textPosition: StatusBaseButton.TextPosition.Left
            size: StatusBaseButton.Size.Tiny
            textColor: Theme.palette.directColor1
            hoverColor: "transparent"
            spacing: 0
            font.pixelSize: Theme.primaryTextFontSize
            font.weight: Font.Normal
            horizontalPadding: 0
            verticalPadding: 0
            text: StringUtils.extractDomainFromLink(dAppUrl)
            onClicked: Global.requestOpenLink(dAppUrl)
        }
        ConnectionStatusTag {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width
            objectName: "connectionStatusTag"
            success: root.connectionSuccessful
            visible: root.connectionAttempted
        }
    }
}
