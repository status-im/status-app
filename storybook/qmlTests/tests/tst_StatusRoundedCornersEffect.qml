import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root

    width: 200
    height: 200

    Component {
        id: contentComponent

        // arbitrary content: a frame with a child in its top-left corner
        Rectangle {
            id: content

            property real effectRadius
            property real effectBottomRightRadius: effectRadius
            property point effectCutoutCenter
            property real effectCutoutRadius

            width: 64
            height: 64
            color: "red"

            layer.enabled: true
            layer.effect: StatusRoundedCornersEffect {
                radius: content.effectRadius
                bottomRightRadius: content.effectBottomRightRadius
                cutoutCenter: content.effectCutoutCenter
                cutoutRadius: content.effectCutoutRadius
            }

            Rectangle {
                width: 20
                height: 20
                color: "blue"
            }
        }
    }

    TestCase {
        name: "StatusRoundedCornersEffect"
        when: windowShown

        function grab(properties) {
            if (root.GraphicsInfo.api === GraphicsInfo.Software)
                skip("ShaderEffect does not run under the software renderer")

            const content = createTemporaryObject(contentComponent, root, properties)
            verify(!!content)
            return grabImage(content)
        }

        function isRed(color) {
            return color.r > 0.9 && color.g < 0.1 && color.b < 0.1
        }

        function isBlue(color) {
            return color.b > 0.9 && color.r < 0.1 && color.g < 0.1
        }

        function isEmpty(color) {
            return !isRed(color) && !isBlue(color)
        }

        function test_cornersAreRoundedAndTheContentIsDrawn() {
            const img = grab({ effectRadius: 16 })

            verify(isEmpty(img.pixel(1, 1)), "top-left corner is cut, child included")
            verify(isEmpty(img.pixel(62, 1)), "top-right corner is cut")
            verify(isEmpty(img.pixel(1, 62)), "bottom-left corner is cut")
            verify(isEmpty(img.pixel(62, 62)), "bottom-right corner is cut")
            verify(isBlue(img.pixel(15, 15)), "child is drawn inside the corner")
            verify(isRed(img.pixel(32, 32)), "content is drawn")
            verify(isRed(img.pixel(32, 63)), "straight edge is drawn")
        }

        function test_eachCornerHasItsOwnRadius() {
            const img = grab({ effectRadius: 16, effectBottomRightRadius: 0 })

            verify(isRed(img.pixel(62, 62)), "square bottom-right corner is drawn")
            verify(isEmpty(img.pixel(1, 62)), "bottom-left corner is still cut")
        }

        function test_cutoutCutsACircle() {
            const img = grab({ effectCutoutCenter: Qt.point(64, 32), effectCutoutRadius: 20 })

            verify(isEmpty(img.pixel(60, 32)), "inside the circle is cut")
            verify(isEmpty(img.pixel(50, 32)), "inside the circle is cut")
            verify(isRed(img.pixel(40, 32)), "outside the circle is drawn")
            verify(isBlue(img.pixel(10, 10)), "the rest is untouched")
        }

        function test_radiusIsClampedToHalfTheShorterSide() {
            const img = grab({ effectRadius: 1000 })

            // a circle: the middle of each side is drawn, the corners are not
            verify(isRed(img.pixel(32, 1)))
            verify(isRed(img.pixel(1, 32)))
            verify(isEmpty(img.pixel(8, 8)))
        }
    }
}
