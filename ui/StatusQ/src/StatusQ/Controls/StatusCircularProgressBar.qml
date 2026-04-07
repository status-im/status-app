pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core.Theme

Item {
    id: root

    property int size: 16
    property real lineWidth: 1.5
    property real value: 1 // 0..1

    property color primaryColor: Theme.palette.primaryColor1
    property color secondaryColor: Theme.palette.primaryColor2

    property int animationDuration: 1000

    width: size
    height: size

    onValueChanged: canvas.degree = value * 360

    Canvas {
        id: canvas

        property real degree: 0

        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded

        onDegreeChanged: {
            requestPaint()
        }

        onPaint: {
            const ctx = getContext("2d")

            var x = root.width/2
            var y = root.height/2

            var radius = root.size/2 - root.lineWidth
            var startAngle = (Math.PI/180) * 270
            var fullAngle = (Math.PI/180) * (270 + 360)
            var progressAngle = (Math.PI/180) * (270 + degree)

            ctx.reset()

            ctx.lineCap = 'round'
            ctx.lineWidth = root.lineWidth

            ctx.beginPath()
            ctx.arc(x, y, radius, startAngle, fullAngle)
            ctx.strokeStyle = root.secondaryColor
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(x, y, radius, startAngle, progressAngle)
            ctx.strokeStyle = root.primaryColor
            ctx.stroke()
        }

        Behavior on degree {
            NumberAnimation {
                duration: root.animationDuration
            }
        }
    }
}
