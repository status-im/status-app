import QtQuick
import QtTest

import shared.status

import Benchmark

/*
  StatusChatInputToolBar, the action row under the chat input: 40 toolbars
  (one is shown per chat input; 40 make its cost measurable), 500 px wide -
  the actions fit - or 120 px - they overflow and the edges fade.

  Variants: wide, narrow (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 40
        cellWidth: 500
        cellHeight: 48

        delegate: StatusChatInputToolBar {
            required property int index

            width: runner.cellWidth
            sendButtonVisible: true
            editActionsVisible: false
            editAcceptButtonEnabled: true
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function bench(width) {
            runner.cellWidth = width
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }

        function test_wide() { bench(500) }
        function test_narrow() { bench(120) }
    }
}
