import QtQuick
import QtTest

import StatusQ.Components.private

Rectangle {
    id: root

    width: 400
    height: 300
    color: "lime"

    // 320 x 180, 20 frames: red at (40, 40) in every frame, cyan at
    // (300, 170) in the first and red in the eleventh
    readonly property url gif: Qt.resolvedUrl("../../testData/image_example_animated.gif")

    Component {
        id: imageComponent

        RoundedAnimatedImage {
            width: 320
            height: 180
            source: root.gif
            asynchronous: false
            playing: false
            radius: 30
        }
    }

    TestCase {
        name: "RoundedAnimatedImage"
        when: windowShown

        readonly property bool software: root.GraphicsInfo.api === GraphicsInfo.Software

        function createImage(properties) {
            const image = createTemporaryObject(imageComponent, root, properties)
            verify(!!image)
            tryCompare(image, "status", Image.Ready)
            return image
        }

        function grab() {
            if (software)
                skip("the rounded node is not used by the software renderer")
            return grabImage(root)
        }

        function isLime(color) {
            return color.g > 0.9 && color.r < 0.1 && color.b < 0.1
        }

        function isRed(color) {
            return color.r > 0.9 && color.g < 0.2 && color.b < 0.1
        }

        function isCyan(color) {
            return color.g > 0.9 && color.b > 0.9 && color.r < 0.1
        }

        function test_cornersAreRoundedAndTheRestIsDrawn() {
            createImage({})
            const img = grab()

            verify(isLime(img.pixel(1, 1)), "the corner is cut")
            verify(isRed(img.pixel(40, 40)), "the image is drawn")
            verify(isCyan(img.pixel(300, 170)), "the first frame is drawn")
            verify(!isLime(img.pixel(160, 0)), "no border by default")
        }

        function test_eachFrameIsDrawnRounded() {
            const image = createImage({})
            image.currentFrame = 10

            tryVerify(() => isRed(grab().pixel(300, 170)), 5000, "the eleventh frame is drawn")
            verify(isLime(grab().pixel(1, 1)), "the corner is still cut")
        }

        function test_playingAdvancesTheFrames() {
            const image = createImage({})
            compare(image.currentFrame, 0)

            image.playing = true
            tryVerify(() => image.currentFrame > 0)
        }
    }
}
