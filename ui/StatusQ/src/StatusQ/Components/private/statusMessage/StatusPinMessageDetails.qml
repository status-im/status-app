import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

Loader {
    id: root
    objectName: "statusPinMessageDetails"

    property string pinnedMsgInfoText: ""
    property string pinnedBy: ""

    Accessible.role: Accessible.StaticText
    Accessible.name: root.active ? root.pinnedMsgInfoText + " " + root.pinnedBy : ""

    sourceComponent: Control {
        verticalPadding: 3
        leftPadding: 2
        rightPadding: 6

        background: Rectangle {
            readonly property color translucentColor: Theme.palette.pinColor2

            implicitWidth: 24
            implicitHeight: 24
            color: Qt.rgba(translucentColor.r,
                           translucentColor.g,
                           translucentColor.b, 1)
            opacity: translucentColor.a
            layer.enabled: true
            radius: 12

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width / 2
                height: parent.height / 2
                color: parent.color
                radius: 4
            }
        }

        contentItem: RowLayout {
            spacing: 4
            StatusIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                color: Theme.palette.pinColor1
                icon: "tiny/pin"
            }
            StatusBaseText {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -4
                color: Theme.palette.directColor1
                font.pixelSize: Theme.secondaryTextFontSize
                text: pinnedMsgInfoText
            }
            StatusBaseText {
                Layout.alignment: Qt.AlignVCenter
                color: Theme.palette.directColor1
                font.pixelSize: Theme.secondaryTextFontSize
                font.weight: Font.Medium
                text: pinnedBy
            }
        }
    }
}
