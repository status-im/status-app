import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

Item {
    id: root

    /** token icon; sized to fill this item **/
    property alias image: tokenImage.image

    /** network badge icon; the badge is hidden while this is empty **/
    property url networkIcon

    /** ring colour, matched to whatever the badge sits on **/
    property color badgeColor: Theme.palette.background

    property int badgeSize: 18
    property int badgeRadius: 5
    property int badgeIconSize: 14
    property int badgeIconRadius: 4

    StatusRoundedImage {
        id: tokenImage
        anchors.fill: parent
    }

    Rectangle {
        width: root.badgeSize
        height: root.badgeSize
        radius: root.badgeRadius
        color: root.badgeColor

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -3
        anchors.bottomMargin: -3

        visible: !!root.networkIcon.toString()

        StatusRoundedImage {
            anchors.centerIn: parent
            width: root.badgeIconSize
            height: root.badgeIconSize
            radius: root.badgeIconRadius
            image.source: root.networkIcon
        }
    }
}
