import QtQuick
import QtTest

import Benchmark

import "../../../ui/app/AppLayouts/Wallet/views"

/*
  LoadingGraphView, the shimmering outline of a price chart while its
  history loads (AssetsDetailView): 6 charts of 480 x 240.

  Variant: charts (static: the cost of a frame with the charts shown).
*/
Item {
    id: root

    width: 1000
    height: 800

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 6
        cellWidth: 480
        cellHeight: 240

        delegate: LoadingGraphView {
            required property int index

            width: runner.cellWidth * runner.sizeFactor
            height: runner.cellHeight * runner.sizeFactor
            active: true
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_charts() {
            runner.scenarios = ["static"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
