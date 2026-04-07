pragma ComponentBehavior: Bound

import QtQuick
import QtQml

Flickable {
    id: root

    boundsBehavior: Flickable.StopAtBounds
    maximumFlickVelocity: 2000
    synchronousDrag: true

    property Flickable flickable1: Flickable {}
    property Flickable flickable2: Flickable {}

    readonly property real flickable1ContentHeight: flickable1.contentHeight
    readonly property real flickable2ContentHeight: flickable2.contentHeight

    onWidthChanged: returnToBounds()
    onHeightChanged: returnToBounds()

    contentWidth: root.width
    contentHeight: flickable1ContentHeight + flickable2ContentHeight

    QtObject {
        id: d

        property real offsetY1
        property real offsetY2

        Binding on offsetY1 {
            value: flickable1.originY
            delayed: true
        }

        Binding on offsetY2 {
            value: flickable2.originY
            delayed: true
        }
    }

    // First flickable

    Binding {
        target: flickable1
        property: "parent"
        value: contentItem
    }

    Binding {
        target: flickable1
        property: "interactive"
        value: false
    }

    Binding {
        target: flickable1
        property: "height"
        value: Math.min(root.height, flickable1ContentHeight)
        delayed: true
    }

    Binding {
        target: flickable1
        property: "y"
        value: Math.min(Math.max(0, root.contentY),
                        flickable1ContentHeight - flickable1.height)
    }

    Binding {
        target: flickable1
        property: "contentY"
        value: Math.min(Math.max(root.contentY, 0),
                        flickable1ContentHeight - flickable1.height) + d.offsetY1

        delayed: true
    }

    // Second flickable

    Binding {
        target: flickable2
        property: "parent"
        value: contentItem
    }

    Binding {
        target: flickable2
        property: "interactive"
        value: false
    }

    Binding {
        target: flickable2
        property: "height"
        value: Math.min(root.height, flickable2ContentHeight)

        delayed: true
    }

    Binding {
        target: flickable2
        property: "y"
        value: Math.min(Math.max(flickable1ContentHeight, root.contentY),
                        root.contentHeight - flickable2.height)
    }

    Binding {
        target: flickable2
        property: "contentY"
        value: Math.min(Math.max(0, root.contentY - flickable1ContentHeight),
                        flickable2ContentHeight - flickable2.height) + d.offsetY2

        delayed: true
    }
}
