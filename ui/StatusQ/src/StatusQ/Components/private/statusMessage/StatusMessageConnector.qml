import QtQuick
import QtQuick.Shapes

import StatusQ.Core.Theme

Shape {
    id: root

    enum Direction {
        Up,
        Down
    }

    property int direction: StatusMessageConnector.Direction.Up
    property color strokeColor: Theme.palette.baseColor1
    property real strokeWidth: 2
    property real cornerRadius: Theme.padding
    property real pathHeight: height

    // The corner can't be larger than the room it has to turn in.
    readonly property real effectiveRadius: Math.max(0, Math.min(cornerRadius, pathHeight, width))

    asynchronous: true
    antialiasing: true
    opacity: 0.4

    ShapePath {
        strokeColor: root.strokeColor
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.direction === StatusMessageConnector.Direction.Up ? root.width : 0
        startY: 0

        PathLine {
            x: root.direction === StatusMessageConnector.Direction.Up ? root.effectiveRadius : 0
            y: root.direction === StatusMessageConnector.Direction.Up ? 0 : root.pathHeight - root.effectiveRadius
        }
        PathArc {
            x: root.direction === StatusMessageConnector.Direction.Up ? 0 : root.effectiveRadius
            y: root.direction === StatusMessageConnector.Direction.Up ? root.effectiveRadius : root.pathHeight
            radiusX: root.effectiveRadius
            radiusY: root.effectiveRadius
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: root.direction === StatusMessageConnector.Direction.Up ? 0 : root.width
            y: root.pathHeight
        }
    }
}
