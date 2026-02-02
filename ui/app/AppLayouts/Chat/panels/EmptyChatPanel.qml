import QtQuick
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Core.Theme

import utils

ColumnLayout {
    id: root

    signal shareChatKeyClicked()

    spacing: 0

    Image {
        id: placeholderImage

        objectName: "emptyChatPanelImage"

        fillMode: Image.PreserveAspectFit

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.maximumHeight: Math.min(width, implicitHeight)

        Layout.topMargin: {
            const remainingHeight = root.height - height

            return Math.max(0, remainingHeight / 2 -
                            Math.max(0, baseText.implicitHeight -
                                     remainingHeight / 2)) / 2
        }

        source: Assets.png("chat/chat@2x")
    }

    StatusBaseText {
        id: baseText

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: implicitHeight

        text: qsTr("%1 to connect with or<br>invite your friends to Status.")
          .arg(Utils.getStyledLink(qsTr("Share your profile"), "#share", hoveredLink,
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
        }

        HoverHandler {
            // Qt CSS doesn't support custom cursor shape
            cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
        }
    }
}
