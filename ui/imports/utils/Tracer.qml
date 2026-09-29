import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property bool randomColor

    z: 1000
    border.color: randomColor ? Qt.rgba(Math.random(), Math.random(), Math.random(), 1) : 'red'
    color: 'transparent'

    QtObject {
        id: d

        property Item originalParent
    }

    Timer {
        id: positionUpdateTimer

        interval: 500
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const overlay = d.originalParent.Overlay.overlay

            if (!overlay)
                return

            root.parent = overlay
            root.visible = d.originalParent.visible
            const rect = d.originalParent.mapToItem(overlay, 0, 0,
                                                    d.originalParent.width,
                                                    d.originalParent.height)
            root.x = rect.x
            root.y = rect.y
            root.width = rect.width
            root.height = rect.height
        }
    }

    Component.onCompleted: {
        if (parent instanceof ColumnLayout
                || parent instanceof RowLayout
                || parent instanceof GridLayout
                || parent instanceof StackLayout
                || parent instanceof Column
                || parent instanceof Row
                || parent instanceof Grid
                || parent instanceof Flow) {
            d.originalParent = parent
            positionUpdateTimer.running = true
        } else {
            if (!anchors.fill)
                anchors.fill = parent
        }
    }
}
