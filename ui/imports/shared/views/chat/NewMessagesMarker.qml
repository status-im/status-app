import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    property double timestamp
    property int count

    implicitHeight: Math.max(28, txt.implicitHeight + 8)

    QtObject {
        id: d

        readonly property int horizontalPadding: 16
        readonly property int minimumLineWidth: 16
        readonly property int internalPadding: 8
    }

    Rectangle {
        height: 1
        anchors.left: parent.left
        anchors.leftMargin: d.horizontalPadding

        anchors.right: txt.left
        anchors.rightMargin: -(txt.width - txt.contentWidth) / 2 + d.internalPadding

        anchors.verticalCenter: parent.verticalCenter
        color: Theme.palette.primaryColor1
    }

    Rectangle {
        height: 1
        anchors.left: txt.right
        anchors.right: newBadge.left
        anchors.verticalCenter: parent.verticalCenter

        anchors.leftMargin: -(txt.width - txt.contentWidth) / 2 + d.internalPadding
        color: Theme.palette.primaryColor1
    }

    Rectangle {
        id: newBadge
        height: 16
        width: newLabel.width + 8

        anchors.right: parent.right
        anchors.rightMargin: d.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter

        radius: 4
        color: Theme.palette.primaryColor1

        StatusBaseText {
            id: newLabel
            anchors.centerIn: parent
            text: qsTr("NEW", "new message(s)")
            color: Theme.palette.indirectColor1
            font.weight: Font.DemiBold
            font.pixelSize: Theme.fontSize(11)
        }
    }

    StatusBaseText {
        id: txt

        anchors.left: parent.left
        anchors.right: newBadge.left
        anchors.verticalCenter: parent.verticalCenter

        anchors.leftMargin: d.horizontalPadding + d.minimumLineWidth + d.internalPadding
        anchors.rightMargin: d.minimumLineWidth + d.internalPadding

        text: qsTr("%n missed message(s) since %1", "", count).arg(
                  LocaleUtils.formatDate(timestamp))
        color: Theme.palette.primaryColor1
        font.weight: Font.Bold
        font.pixelSize: Theme.additionalTextSize
        maximumLineCount: 2
        elide: Text.ElideRight

        horizontalAlignment: Text.AlignHCenter

        wrapMode: Text.Wrap
    }
}
