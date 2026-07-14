// Real-instantiation scene for the send modal. Unlike send_modal_open_scene (which
// drives the Nim picker model in a synthetic sheet), this loads the ACTUAL
// SimpleSendModal QML tree (and its major subtrees) under an offscreen engine with
// StatusQ linked + the app import paths (ui/StatusQ/src, ui/imports, ui/app), and
// times Component.createObject (the structural instantiation cost) + time-to-opened
// + the GUI-thread block via a 16ms stall monitor.
//
// The dominant hypothesis for the ~1s device-side open is QML component
// instantiation of this tree; this scene measures it directly and bisects it by
// timing each major subtree's createObject standalone.

import QtQuick
import QtQuick.Window
import QtQml.Models

import StatusQ.Core.Theme

import AppLayouts.Wallet.popups.simpleSend
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.views
import shared.popups.send.views as SendViews

Window {
    id: root
    width: 800
    height: 1000
    visible: true

    // Empty stand-in models: instantiation of a list is structural (delegates are
    // realized lazily on show), so model SIZE does not change the createObject cost
    // measured here; the data-dependent handler-JS cost is measured separately in
    // send_handler_lookup_bench.
    ListModel { id: emptyModel }

    function fnFmt(a, s, o) { return "" }

    // --- component catalog: the full modal + its major subtrees ---------------
    Component {
        id: fullModalComp
        SimpleSendModal {
            accountsModel: emptyModel
            assetsModel: emptyModel
            groupedAccountAssetsModel: emptyModel
            flatCollectiblesModel: emptyModel
            collectiblesModel: emptyModel
            networksModel: emptyModel
            recipientsModel: emptyModel
            recipientsFilterModel: emptyModel
            currentCurrency: "USD"
            fnFormatCurrencyAmount: root.fnFmt
            fnResolveENS: function() {}
        }
    }

    Component {
        id: sendHeaderComp
        SendModalHeader {
            networksModel: emptyModel
            assetsModel: emptyModel
            collectiblesModel: emptyModel
            formatCurrencyBalance: root.fnFmt
        }
    }

    Component {
        id: stickyHeaderComp
        StickySendModalHeader {
            networksModel: emptyModel
            assetsModel: emptyModel
            collectiblesModel: emptyModel
            formatCurrencyBalance: root.fnFmt
        }
    }

    Component {
        id: amountComp
        SendViews.AmountToSend {}
    }

    Component {
        id: footerComp
        SendModalFooter {}
    }

    function compFor(kind) {
        switch (kind) {
        case 0: return fullModalComp
        case 1: return sendHeaderComp
        case 2: return stickyHeaderComp
        case 3: return amountComp
        case 4: return footerComp
        }
        return null
    }

    property var _held: []   // keep created objects alive so GC doesn't skew timings

    // Create `kind`, timing createObject (the structural instantiation cost the
    // synchronous open pays). `opened` is not driven: offscreen the Popup enter
    // transition never completes, so create time is the measurable term.
    function runKind(kind) {
        const comp = compFor(kind)
        if (!comp) { bench.reportInstantiation(kind, -1, "no-comp"); return }

        const t0 = bench.nowMs()
        const obj = comp.createObject(root)
        const t1 = bench.nowMs()

        if (!obj) {
            bench.reportInstantiation(kind, -1, comp.errorString())
            return
        }
        _held.push(obj)
        bench.reportInstantiation(kind, t1 - t0, "")
    }

    Connections {
        target: bench
        function onRequestKind(kind) { root.runKind(kind) }
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: bench.onStallTick()
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
