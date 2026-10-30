import QtQuick
import QtTest

import StatusQ.Components
import "../../../ui/StatusQ/src/StatusQ/Components/private/statusMessage"

import Benchmark

/*
  StatusTextMessage, the text of a chat message, collapsed: 50 long
  messages, 300 px wide, each cut at 200 px with its "show more" fade.

  Variant: collapsed (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property string longText: Array.from({ length: 30 },
        (_, i) => `Line ${i + 1} of a long message that wraps over a few lines in a narrow bubble.`).join("\n\n")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 50
        cellWidth: 300
        cellHeight: 230

        delegate: Item {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight

            StatusTextMessage {
                width: parent.width
                messageDetails: StatusMessageDetails {
                    unparsedText: root.longText
                }
            }
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
