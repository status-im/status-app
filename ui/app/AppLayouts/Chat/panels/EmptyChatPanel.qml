import QtQuick
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Core.Theme

import utils

ColumnLayout {
    id: root

    signal shareChatKeyClicked()
    signal supportBotChatRequested()

    spacing: 0

    Item {
        Layout.fillHeight: true
        Layout.verticalStretchFactor: 1
    }

    Image {
        id: placeholderImage

        objectName: "emptyChatPanelImage"

        fillMode: Image.PreserveAspectFit

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.maximumHeight: Math.min(width, implicitHeight)

        source: Assets.png("chat/chat@2x")
    }

    StatusBaseText {
        id: baseText

        Layout.fillWidth: true

        text: qsTr("%1 to connect with or<br>invite your friends to Status.<br><br><br>%2<br>for welcome messages, how-to tips, or just to share feedback or issues.")
          .arg(Utils.getStyledLink(qsTr("Share your profile"), "#share", hoveredLink,
                Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))
          .arg(Utils.getStyledLink(qsTr("Chat with the Status Team peer-to-peer bot"), "#supportBot", hoveredLink,
                Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))

        horizontalAlignment: Text.AlignHCenter

        color: Theme.palette.secondaryText
        font.pixelSize: Theme.primaryTextFontSize
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: 3
        textFormat: Text.RichText

        onLinkActivated: link => {
            if (link === "#share")
                root.shareChatKeyClicked()
            else if (link === "#supportBot")
                root.supportBotChatRequested()
        }

        HoverHandler {
            // Qt CSS doesn't support custom cursor shape
            cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
        }
    }

    Item {
        Layout.fillHeight: true
        Layout.verticalStretchFactor: 2
    }
}
