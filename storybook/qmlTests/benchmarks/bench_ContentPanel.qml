import QtQuick
import QtTest

import Benchmark

import "../../../ui/imports/shared/popups/walletconnect/panels"

/*
  ContentPanel, the payload of a wallet connect signing request, collapsed:
  8 panels of 300 px showing a long payload, cut at 350 px with the bottom
  fading out (one is shown per request; 8 make its cost measurable).

  Variant: collapsed (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property string payload: JSON.stringify(Array.from({ length: 60 },
        (_, i) => ({ index: i, address: "0x" + "ab".repeat(20), value: i * 1000 })), null, 2)

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 8
        cellWidth: 300
        cellHeight: 352

        delegate: ContentPanel {
            required property int index

            width: runner.cellWidth
            payloadToDisplay: root.payload
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_collapsed() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
