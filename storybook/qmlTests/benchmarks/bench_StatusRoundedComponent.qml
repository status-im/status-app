import QtQuick
import QtTest

import StatusQ.Components

import Benchmark

/*
  StatusRoundedComponent clipping a StatusImage, as NetworkIcon and
  StatusRoundedMedia build it: 500 circles of 40 px. Variant: avatar.
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url source: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent

        delegate: StatusRoundedComponent {
            id: component

            required property int index
            readonly property int status: image.status

            width: runner.cellWidth * runner.sizeFactor
            height: runner.cellHeight * runner.sizeFactor
            radius: width / 2

            StatusImage {
                id: image

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // decoded for the unresized cell: resizing must not re-decode
                sourceSize: Qt.size(runner.cellWidth, runner.cellHeight)
                // a distinct pixmap per cell; the query only keys the pixmap cache
                source: `${root.source}?cell=${component.index}`
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_avatar() {
            runner.count = 500
            runner.cellWidth = 40
            runner.scenarios = ["static", "scroll", "resize"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
