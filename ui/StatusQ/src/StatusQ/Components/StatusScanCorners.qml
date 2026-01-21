import QtQuick

Item {
    id: root
    property real stroke: 8
    property real radius: 16
    property real margin: 18
    property real leg: 34
    property color color: "white"
    property real overlayOpacity: 1.0

    Canvas {
        id: c
        anchors.fill: parent
        opacity: root.overlayOpacity
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            ctx.strokeStyle = root.color
            ctx.lineWidth = root.stroke
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            const m = root.margin
            const r = root.radius
            const L = root.leg

            function cornerTL() {
                ctx.beginPath()
                ctx.moveTo(m, m + r + L)
                ctx.lineTo(m, m + r)
                ctx.arcTo(m, m, m + r, m, r)
                ctx.lineTo(m + r + L, m)
                ctx.stroke()
            }

            function cornerTR() {
                ctx.beginPath()
                ctx.moveTo(width - m - r - L, m)
                ctx.lineTo(width - m - r, m)
                ctx.arcTo(width - m, m, width - m, m + r, r)
                ctx.lineTo(width - m, m + r + L)
                ctx.stroke()
            }

            function cornerBL() {
                ctx.beginPath()
                ctx.moveTo(m, height - m - r - L)
                ctx.lineTo(m, height - m - r)
                ctx.arcTo(m, height - m, m + r, height - m, r)
                ctx.lineTo(m + r + L, height - m)
                ctx.stroke()
            }

            function cornerBR() {
                ctx.beginPath()
                ctx.moveTo(width - m - r - L, height - m)
                ctx.lineTo(width - m - r, height - m)
                ctx.arcTo(width - m, height - m, width - m, height - m - r, r)
                ctx.lineTo(width - m, height - m - r - L)
                ctx.stroke()
            }

            cornerTL()
            cornerTR()
            cornerBL()
            cornerBR()
        }

        // repaint when properties change
        Connections {
            target: root
            function onStrokeChanged() { c.requestPaint() }
            function onRadiusChanged() { c.requestPaint() }
            function onMarginChanged() { c.requestPaint() }
            function onLegChanged() { c.requestPaint() }
            function onColorChanged() { c.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
