import QtQuick
import QtTest

import StatusQ.Components.private

import Benchmark

/*
  StatusImageMessage, the image of a chat message, as albums and attachments
  show it: 200 images, square crop, 240 px, the bubble's tail corner.
  240 px keeps the 85% resize within one of its 128 px decode steps at 1x
  and 2x, so resizing measures the drawing, not re-decoding.

  Variants: still (static, scroll, resize), gif (animated, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    property bool animated: false

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")
    readonly property url animatedSource: Qt.resolvedUrl("../../testData/image_example_animated.gif")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 200
        cellWidth: 240
        isReady: item => !!item.imageAlias && item.imageAlias.status === Image.Ready

        delegate: StatusImageMessage {
            required property int index

            imageWidth: runner.cellWidth * runner.sizeFactor
            isFillCropMode: true
            isAppWindowActive: true
            shapeType: StatusImageMessage.ShapeType.LEFT_ROUNDED
            // a distinct pixmap per cell even for one source: the component
            // loads without the pixmap cache (and tells GIFs by the suffix)
            source: root.animated ? root.animatedSource : root.stillSource
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function bench(animated) {
            root.animated = animated
            runner.scenarios = animated ? ["animated", "scroll"] : ["static", "scroll", "resize"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }

        function test_still() { bench(false) }
        function test_gif() { bench(true) }
    }
}
