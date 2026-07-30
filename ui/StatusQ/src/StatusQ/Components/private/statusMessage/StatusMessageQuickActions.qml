import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core.Theme

Rectangle {
    id: root

    default property alias items: buttonRow.children

    QtObject {
        id: _internal
        readonly property int containerMargin: 2
    }

    implicitWidth: buttonRow.width > 0 ? buttonRow.width + (_internal.containerMargin * 2) : 0
    implicitHeight: 36
    radius: Theme.radius
    color: Theme.palette.statusSelect.menuItemBackgroundColor

    layer.enabled: true
    layer.effect: DropShadow {
        width: root.width
        height: root.height
        x: root.x
        y: root.y + 10
        horizontalOffset: 0
        verticalOffset: 2
        source: root
        radius: 10
        samples: 15
        color: Theme.palette.dropShadow
    }

    Row {
        id: buttonRow
        spacing: _internal.containerMargin
        anchors.left: parent.left
        anchors.leftMargin: _internal.containerMargin
        anchors.verticalCenter: root.verticalCenter
        height: parent.height - 2 * _internal.containerMargin
    }
}
