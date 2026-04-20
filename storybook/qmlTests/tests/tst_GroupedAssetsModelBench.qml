// A/B benchmark for grouped_account_assets_model: OLD reset-based
// (`beginResetModel`/`endResetModel` + ref-object DTOs) vs NEW CoW + diff
// (`setItemsWithSync` + value-type DTOs).
//
// Driven by the `benchHarness` context property exposed from C++ (which
// owns both model variants via the bench Nim static lib).
//
// Two measurement axes:
//   1. Pure-model: harness slot returns elapsed seconds for the model
//      operation alone (populate / repopulate / single-row balance tick).
//   2. End-to-end: Qt Quick Test reruns the body N times measuring wall
//      clock for the operation + signal propagation through a real proxy
//      chain (BenchProxyChain.qml) up to a ListView consumer.

import QtQuick
import QtTest

Item {
    id: root
    width: 100; height: 100  // headless

    // Two clones of the proxy chain - one per model variant.
    BenchProxyChain {
        id: oldChain
        sourceModel: benchHarness ? benchHarness.oldModel : null
    }
    BenchProxyChain {
        id: newChain
        sourceModel: benchHarness ? benchHarness.newModel : null
    }

    // Real ListView consumers so dataChanged signals propagate end-to-end.
    ListView {
        id: oldView
        anchors.fill: parent
        visible: false
        model: oldChain.outputModel
        delegate: Item { width: 1; height: 1 }
    }
    ListView {
        id: newView
        anchors.fill: parent
        visible: false
        model: newChain.outputModel
        delegate: Item { width: 1; height: 1 }
    }

    TestCase {
        name: "GroupedAssetsModelBench"
        when: windowShown

        // Helper - reports OLD vs NEW comparison so the user can see the
        // ratio without grepping multiple lines.
        function _report(label, oldT, newT) {
            const ratio = (oldT > 0 && newT > 0) ? (oldT / newT).toFixed(2) : "n/a"
            console.log("[BENCH]", label, "OLD=", oldT.toFixed(6), "s",
                        "NEW=", newT.toFixed(6), "s",
                        "speedup=", ratio + "x")
        }

        // ---- pure-model timings (Nim slots return elapsed seconds) ----

        function test_pure_load_50() {
            const oldT = benchHarness.pureLoadOld(50, 5, 3)
            const newT = benchHarness.pureLoadNew(50, 5, 3)
            _report("pure load 50x5x3", oldT, newT)
        }

        function test_pure_load_200() {
            const oldT = benchHarness.pureLoadOld(200, 10, 5)
            const newT = benchHarness.pureLoadNew(200, 10, 5)
            _report("pure load 200x10x5", oldT, newT)
        }

        function test_pure_load_500() {
            const oldT = benchHarness.pureLoadOld(500, 10, 5)
            const newT = benchHarness.pureLoadNew(500, 10, 5)
            _report("pure load 500x10x5", oldT, newT)
        }

        function test_pure_balance_tick_200() {
            benchHarness.populate(200, 10, 5)
            const oldT = benchHarness.simulateBalanceTickOld()
            const newT = benchHarness.simulateBalanceTickNew()
            _report("pure balance tick 200x10x5", oldT, newT)
        }

        function test_pure_balance_tick_500() {
            benchHarness.populate(500, 10, 5)
            const oldT = benchHarness.simulateBalanceTickOld()
            const newT = benchHarness.simulateBalanceTickNew()
            _report("pure balance tick 500x10x5", oldT, newT)
        }

        // ---- end-to-end timings (Qt Quick Test wraps the body) ----

        function benchmark_e2e_load_200_old() {
            benchHarness.populate(200, 10, 5)
            // The benchmark function reruns the body multiple times.
            // populate() is idempotent so the input is identical every run.
            tryCompare(oldView, "count", oldChain.expectedCount(), 5000)
        }
        function benchmark_e2e_load_200_new() {
            benchHarness.populate(200, 10, 5)
            tryCompare(newView, "count", newChain.expectedCount(), 5000)
        }

        function benchmark_e2e_balance_tick_200_old() {
            benchHarness.populate(200, 10, 5)
            benchHarness.simulateBalanceTickOld()
        }
        function benchmark_e2e_balance_tick_200_new() {
            benchHarness.populate(200, 10, 5)
            benchHarness.simulateBalanceTickNew()
        }
    }
}
