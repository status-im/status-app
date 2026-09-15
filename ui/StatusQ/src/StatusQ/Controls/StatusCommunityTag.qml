import QtQuick

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Rectangle {
    id: root

    property string emoji
    property string name
    property bool removable: false
    property bool highlighted: false
    property bool interactive: enabled

    signal clicked()

    implicitHeight: 32
    implicitWidth: row.width + 20
    radius: height / 2
    border.color: Theme.palette.directColor8
    border.width: 1
    color: root.highlighted ? Theme.palette.primaryColor2
                            : hoverHandler.hovered ? Theme.palette.primaryColor3
                                                   : "transparent"

    TapHandler {
        enabled: root.interactive
        onTapped: root.clicked()
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }

    Row {
        id: row
        anchors.centerIn: parent

        StatusEmoji {
            width: 18
            height: 18
            emojiId: root.emoji != "" ? Emoji.iconHex(root.emoji) : ""
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: 5
            height: width
        }

        StatusBaseText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.primaryTextFontSize
            font.weight: root.interactive ? Font.Medium : Font.Normal
            font.capitalization: Font.AllLowercase
            color: !root.interactive ? Theme.palette.directColor1
                                     : root.enabled ? Theme.palette.primaryColor1
                                                    : Theme.palette.baseColor1
            text: root.name
        }

        Loader {
            active: root.removable

            sourceComponent: StatusIcon {
                color: root.enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                icon: "close"
            }
        }
    }
}
