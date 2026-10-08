import QtQuick
import QtQuick.Effects

import StatusQ.Platform
import StatusQ.Core.Theme

Item {
    property string name
    property string message

    height: statusNotification.height

    implicitWidth: statusNotification.implicitWidth
    implicitHeight: statusNotification.implicitHeight

    StatusMacNotification {
        id: statusNotification

        width: parent.width
        name: parent.name
        message: parent.message

        RectangularShadow {
            parent: statusNotification.background
            anchors.fill: parent
            z: -1
            radius: Theme.radius
            offset.y: 2
            color: Theme.palette.dropShadow3
        }
    }
}
