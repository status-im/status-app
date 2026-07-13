// Request-side harvest scene. SwapModal.rebuildGroupsForChain harvests the owned
// groups' keys via SQUtils.ModelUtils.joinModelEntries(groupedAccountAssetsModel,
// "key") -> modelToArray(model, ["key"]) -> QtMT.ModelQuery.get(model, i). The
// all-roles get fetches EVERY role per row (incl. the "balances" submodel) and
// marshals it to JS, even though only "key" is read. This scene measures that hot
// loop in both regimes on the real ModelQuery against the injected owned model:
//   mode 0 (all-roles)   = the old modelToArray
//   mode 1 (single-role) = the fixed modelToArray (get(model, i, "key"))
// Timing is taken via the native bench clock so it excludes model construction.

import QtQuick
import QtQuick.Window
import QtModelsToolkit as QtMT

Window {
    id: root
    width: 320
    height: 480
    visible: true

    // reps harvests per invocation, so the Nim driver needs only one signal emit per
    // mode (the offscreen engine is fragile under many signal round-trips); the
    // reported time is the best single-pass wall time.
    property int reps: 5

    function harvestAllRoles() {
        const count = ownedModel.rowCount()
        const out = []
        for (let i = 0; i < count; i++) {
            const item = QtMT.ModelQuery.get(ownedModel, i)  // fetches EVERY role per row
            if (item["key"] !== undefined)
                out.push(item["key"])
        }
        return out.join("$$")
    }

    function harvestSingleRole() {
        const count = ownedModel.rowCount()
        const out = []
        for (let i = 0; i < count; i++) {
            const entry = QtMT.ModelQuery.get(ownedModel, i, "key")  // fetches only key
            if (entry !== undefined)
                out.push(entry)
        }
        return out.join("$$")
    }

    function measureMode(mode) {
        let best = Number.MAX_VALUE
        let joined = ""
        for (let r = 0; r < root.reps; r++) {
            const t0 = bench.nowMs()
            joined = (mode === 0) ? root.harvestAllRoles() : root.harvestSingleRole()
            const t1 = bench.nowMs()
            if (t1 - t0 < best)
                best = t1 - t0
        }
        bench.reportResult(mode, best, joined.length)
    }

    // One regime per process (harvestMode injected from the environment): the
    // offscreen engine corrupts under an in-process all-roles -> single-role
    // transition, so the parent runs this bench once per mode as a child process.
    Connections {
        target: bench
        function onRequestHarvest() {
            root.measureMode(harvestMode)
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
