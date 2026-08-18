import QtQuick
import QtQuick.Layouts
import QtTest

import StatusQ.Core.Theme

// Section switches hand panels between LayoutItemProxys; each handoff
// unparents the panel for a moment. The Theme attached node must NOT restyle
// the detached subtree through the engine-level Light fallback — in a dark
// app that double-fires every Theme.palette binding in the section on every
// switch (measured: 2.3s GUI-thread freeze per section switch on device).
Item {
    id: root

    width: 400
    height: 300

    Theme.style: Theme.Style.Dark

    property int evals: 0

    Item { id: holderA; anchors.fill: parent }

    Rectangle {
        id: payload
        parent: holderA
        width: 50; height: 50
        color: Theme.palette.baseColor4
        onColorChanged: root.evals++

        Text {
            text: "x"
            color: Theme.palette.directColor1
            onColorChanged: root.evals++
        }
    }

    Rectangle {
        id: proxyTarget
        width: 40; height: 40
        color: Theme.palette.baseColor4
        onColorChanged: root.evals++
    }
    ColumnLayout {
        id: pageA
        LayoutItemProxy { target: proxyTarget }
    }
    ColumnLayout {
        id: pageB
        visible: false
        LayoutItemProxy { target: proxyTarget }
    }

    TestCase {
        name: "ThemeDetachedReparent"
        when: windowShown

        function init() {
            waitForRendering(root)
            root.evals = 0
        }

        function test_nullReparentKeepsStyle() {
            payload.parent = null
            compare(payload.Theme.style, Theme.Style.Dark,
                    "detached subtree must keep its inherited style")
            payload.parent = holderA
            wait(20)
            compare(payload.Theme.style, Theme.Style.Dark)
            compare(root.evals, 0,
                    "no Theme.palette binding may re-fire on a same-style reparent")
        }

        function test_proxyHandoffIsFree() {
            pageA.visible = false; pageB.visible = true
            wait(20)
            pageB.visible = false; pageA.visible = true
            wait(20)
            compare(proxyTarget.Theme.style, Theme.Style.Dark)
            compare(root.evals, 0,
                    "a LayoutItemProxy handoff must not restyle the target")
        }
    }
}
