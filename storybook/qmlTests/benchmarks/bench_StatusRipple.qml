import QtQuick
import QtTest

import StatusQ.Controls

import Benchmark

/*
  StatusRipple, the press feedback of buttons, list items and menu items:
  200 ripples of 160 x 40, radius 8, pressed and released over and over so
  that one is always expanding or collapsing - the frames that cost
  something, as the ripple is hidden at rest.

  Variant: pressed (animated).
*/
Item {
    id: root

    width: 1000
    height: 800

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 200
        cellWidth: 160
        cellHeight: 40

        delegate: StatusRipple {
            id: ripple

            required property int index

            width: runner.cellWidth * runner.sizeFactor
            height: runner.cellHeight * runner.sizeFactor
            radius: 8
            color: "#4360df"

            Timer {
                interval: 400
                repeat: true
                running: true
                // spread the presses so frames keep coming
                triggeredOnStart: ripple.index % 2 === 0
                onTriggered: {
                    if (ripple.pressed)
                        ripple.release()
                    else
                        ripple.press(ripple.width / 4, ripple.height / 2)
                }
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_pressed() {
            runner.scenarios = ["animated"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
