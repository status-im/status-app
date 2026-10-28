import QtQuick
import QtTest

import Models
import AppLayouts.Wallet.controls

import Benchmark

/*
  NetworkFilter with several networks selected, their icons overlapping,
  each cut where the next one sits: 40 filters with 4 networks (one is shown
  per wallet header or send flow; 40 make its cost measurable).

  Variant: filters (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 40
        cellWidth: 160
        cellHeight: 44

        delegate: NetworkFilter {
            required property int index

            flatNetworks: NetworksModel.flatNetworks
            multiSelection: true
            selection: [NetworksModel.ethNet, NetworksModel.optimismNet,
                        NetworksModel.arbitrumNet, NetworksModel.baseNet]
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_filters() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
