import QtQuick
import QtTest

import Benchmark

import "../../../ui/imports/shared/popups/walletconnect"

/*
  RoundImageWithBadge, a dApp's icon with its badge cut out around it (the
  connected dApps list, the dApp cards and signing requests): 100 icons of
  40 px with a 16 px badge.

  Variant: icons (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url still: Qt.resolvedUrl("../../testData/image_example.png")
    readonly property url logo: Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/status-logo.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 100
        cellWidth: 40

        delegate: RoundImageWithBadge {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight
            // a distinct pixmap per icon; the query only keys the pixmap cache
            imageUrl: `${root.still}?cell=${index}`
            badgeIcon: root.logo
            badgeSize: 16
            badgeMargin: 2
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_icons() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
