import QtQuick
import QtTest

import shared.panels

import Benchmark

/*
  RoundedImage (shared/panels), the round thumbnails of sticker packs
  (sticker market and details): 200 thumbnails of 64 px.

  Variant: stickers (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 200
        cellWidth: 64
        // the thumbnail's image, wherever it is in the tree
        isReady: item => {
            function find(i) {
                if (i instanceof Image && i.source.toString().startsWith(root.stillSource.toString()))
                    return i
                for (const c of i.children) {
                    const f = find(c)
                    if (f)
                        return f
                }
                return null
            }
            const image = find(item)
            return !!image && image.status === Image.Ready
        }

        delegate: Item {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight

            RoundedImage {
                anchors.fill: parent
                // a distinct pixmap per cell; the query only keys the pixmap
                // cache
                source: `${root.stillSource}?cell=${parent.index}`
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_stickers() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
