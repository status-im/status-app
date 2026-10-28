import QtQuick
import QtTest

import Benchmark

import "../../../ui/app/AppLayouts/ActivityCenter/controls"

/*
  NotificationContentBlock with its banner (preImage), as activity center
  notifications show it: 50 blocks, 300 px wide, banner corners 12 px.

  Variant: banners (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 50
        cellWidth: 300
        cellHeight: 170

        delegate: Item {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight

            NotificationContentBlock {
                width: parent.width
                // a distinct pixmap per cell; the query only keys the pixmap
                // cache
                preImageSource: `${root.stillSource}?cell=${parent.index}`
                preImageRadius: 12
                contentText: "A notification"
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_banners() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
