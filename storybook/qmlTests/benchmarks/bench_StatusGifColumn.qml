import QtQuick
import QtTest

import "../../../ui/imports/shared/status/StatusGifPopup"

import Benchmark

/*
  StatusGifColumn, a column of the GIF picker (StatusGifPopup): 6 columns
  of 10 animated GIFs, 150 px wide, all playing.

  Variant: picker (animated, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url animatedSource: Qt.resolvedUrl("../../testData/image_example_animated.gif")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 6
        cellWidth: 150
        isReady: item => {
            for (let i = 0; i < item.gifList.count; ++i) {
                const thumb = item.gifList.itemAt(i)
                if (!thumb || thumb.height === 100) // the loading placeholder's height
                    return false
            }
            return true
        }

        delegate: StatusGifColumn {
            id: column

            required property int index

            gifWidth: runner.cellWidth

            gifList.model: ListModel {
                Component.onCompleted: {
                    for (let i = 0; i < 10; ++i) {
                        // a distinct pixmap per GIF; the query only keys the
                        // pixmap cache
                        const url = `${root.animatedSource}?cell=${column.index * 10 + i}`
                        append({ id: url, tinyUrl: url, url })
                    }
                }
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_picker() {
            runner.scenarios = ["animated", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
