import QtQuick
import QtTest

import shared.controls.delegates

import Benchmark

/*
  PaymentRequestCardDelegate, a payment request in chat: 50 cards, the
  token icon cut where the recipient's overlaps it.

  Variant: cards (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url icon: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 50
        cellWidth: 270
        cellHeight: 180

        delegate: PaymentRequestCardDelegate {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight
            amount: "100"
            symbol: "ETH"
            address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"
            // a distinct pixmap per card; the query only keys the pixmap cache
            logoUri: `${root.icon}?cell=${index}`
            areTestNetworksEnabled: false
            senderName: "Alice"
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_cards() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
