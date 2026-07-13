// Handler-lookup scene. SendModalHandler / SimpleSendModal run a set of
// SQUtils.ModelUtils lookups over the wallet's tokenGroups / collectibles models
// around open (SendModalHandler.qml sendToken :263, openTokenPaymentRequest :307,
// marketDataNotAvailable :487; SimpleSendModal isSelectedAssetAvailableInSelected
// Network :283). This scene drives the REAL ModelUtils / ModelQuery against an
// injected tokenGroups-shaped model in the distinct fetch regimes, so their cost
// is attributed against the model size:
//   getByKey_norole      = getByKey(m,"key",v)        -> all-roles get of 1 matched row
//   getByKey_role        = getByKey(m,"key",v,"symbol") -> single-role get of 1 row
//   get_loop_allroles    = openTokenPaymentRequest's for-loop of get(m,i) (all roles)
//   getFirstModelEntryIf = full scan, all-roles get + predicate per row (worst case)
//   modelToFlatArray     = modelToFlatArray(m,"chainId") (role-restricted, fixed)
// Timing is taken via the native bench clock (excludes model construction).

import QtQuick
import QtQuick.Window
import StatusQ.Core.Utils 0.1 as SQUtils
import QtModelsToolkit as QtMT

Window {
    id: root
    width: 320
    height: 480
    visible: true

    property int reps: 5

    // The key of the LAST row, so index-based scans (indexOf / get-loop / predicate)
    // pay the full O(N) walk -- the worst case the handler hits on a miss/last hit.
    function lastKey() { return "grp_" + (lookupModel.rowCount() - 1) }

    function do_getByKey_norole() {
        return SQUtils.ModelUtils.getByKey(lookupModel, "key", root.lastKey())
    }
    function do_getByKey_role() {
        return SQUtils.ModelUtils.getByKey(lookupModel, "key", root.lastKey(), "symbol")
    }
    function do_get_loop_allroles() {
        // openTokenPaymentRequest: for i { get(model, i); read fields } until match.
        const target = root.lastKey()
        const count = lookupModel.rowCount()
        let hit = null
        for (let i = 0; i < count; i++) {
            const g = QtMT.ModelQuery.get(lookupModel, i)  // all roles per row
            if (g["key"] === target) { hit = g; break }
        }
        return hit
    }
    function do_getFirstModelEntryIf() {
        return SQUtils.ModelUtils.getFirstModelEntryIf(lookupModel, (g) => g.key === "__none__")
    }
    function do_modelToFlatArray() {
        return SQUtils.ModelUtils.modelToFlatArray(lookupModel, "chainId")
    }

    function runOne(name, fn) {
        let best = Number.MAX_VALUE
        for (let r = 0; r < root.reps; r++) {
            const t0 = bench.nowMs()
            fn()
            const t1 = bench.nowMs()
            if (t1 - t0 < best) best = t1 - t0
        }
        bench.reportLookup(name, best)
    }

    Connections {
        target: bench
        function onRequestLookups() {
            runOne("getByKey_norole", root.do_getByKey_norole)
            runOne("getByKey_role", root.do_getByKey_role)
            runOne("get_loop_allroles", root.do_get_loop_allroles)
            runOne("getFirstModelEntryIf", root.do_getFirstModelEntryIf)
            runOne("modelToFlatArray", root.do_modelToFlatArray)
            bench.lookupsDone()
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
