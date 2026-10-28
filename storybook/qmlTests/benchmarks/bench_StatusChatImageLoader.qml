import QtQuick
import QtTest

import shared.status

import Benchmark

/*
  StatusChatImageLoader as GIF link previews (LinkPreviewGifDelegate) use
  it: 100 animated GIFs, 300 px wide, playing, cache on.

  Variant: gif (animated, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url animatedSource: Qt.resolvedUrl("../../testData/image_example_animated.gif")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 100
        cellWidth: 300
        isReady: item => item.imageLoaded

        delegate: StatusChatImageLoader {
            required property int index

            imageWidth: runner.cellWidth
            isAnimated: true
            playing: true
            asynchronous: true
            cacheImage: true
            // a distinct pixmap per cell; the query only keys the pixmap cache
            source: `${root.animatedSource}?cell=${index}`
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_gif() {
            runner.scenarios = ["animated", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
