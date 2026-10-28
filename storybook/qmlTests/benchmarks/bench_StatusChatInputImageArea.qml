import QtQuick
import QtTest

import shared.status

import Benchmark

/*
  StatusChatInputImageArea, the images attached in the chat input: 100
  64 x 64 thumbnails of a 320 x 180 source.

  Variant: thumbnails (static, scroll). The thumbnails have a fixed size,
  so there is no resize scenario.
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 100
        cellWidth: 64
        cellHeight: 64
        // the thumbnail image, wherever it is in the area
        isReady: item => {
            function find(i) {
                if (i instanceof Image && i.source.toString() === item.imageSource[0])
                    return i
                for (const c of i.children) {
                    const f = find(c)
                    if (f)
                        return f
                }
                return null
            }
            const thumbnail = find(item)
            return !!thumbnail && thumbnail.status === Image.Ready
        }

        delegate: StatusChatInputImageArea {
            required property int index

            // a distinct pixmap per cell; the query only keys the pixmap
            // cache
            imageSource: [`${root.stillSource}?cell=${index}`]
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_thumbnails() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
