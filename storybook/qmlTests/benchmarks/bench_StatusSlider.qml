import QtQuick
import QtTest

import StatusQ.Controls

import Benchmark

/*
  StatusSlider, whose handle casts a shadow: 100 sliders of 200 px (the
  settings and send pages show several).

  Variant: sliders (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 100
        cellWidth: 200
        cellHeight: 40

        delegate: StatusSlider {
            required property int index

            width: runner.cellWidth
            value: (index % 10) / 10
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_sliders() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
