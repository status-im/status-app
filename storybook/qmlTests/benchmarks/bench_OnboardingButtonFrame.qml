import QtQuick
import QtQuick.Controls
import QtTest

import Benchmark

import "../../../ui/app/AppLayouts/Onboarding/controls"

/*
  OnboardingButtonFrame, the rounded frame of the onboarding pages'
  option buttons: 20 frames of 320 x 72, each holding a label.

  Variant: frames (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 20
        cellWidth: 320
        cellHeight: 72

        delegate: OnboardingButtonFrame {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight

            contentItem: Label {
                text: "Option " + parent.index
                verticalAlignment: Text.AlignVCenter
                leftPadding: 16
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_frames() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
