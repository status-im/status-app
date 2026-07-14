// SimpleSendModal-open benchmark scene. Models what the send token picker does
// when the modal opens: a sheet that animates in (the "open" window) while the
// handler synchronously creates + seeds the REAL Nim send picker model
// (TokenSelectorModel, Owned mode) the way SendModalHandler does at open
// (createTokenSelectorModel(0) -> buildOwnedSource -> setOwnedSource +
// updateSendSectionNames). A 16ms stall monitor turns any GUI-thread block during
// the open window into a dropped-frame tick delta.
//
// The token field's dropdown is a real ListView bound DIRECTLY to the send picker
// model (owned rows + a nested Repeater over the per-chain `balances` chips, the
// two levels the send token delegate renders). It is Loader-gated: CLOSED during
// the modal-open window (a real dropdown realizes no delegates until the user
// opens it) and opened as a separate interaction, so the two costs are measured
// apart: (1) the on-open model-seed burst, (2) the dropdown-open delegate churn.
//
// The Nim driver drives both regimes on the SAME real model + scene per owned-set
// size and records what the render loop actually experiences.

import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 556
    height: 900
    visible: true // realize the offscreen surface so the ListView creates delegates

    property bool paneOpen: false
    property bool dropdownOpen: false

    // Continuous activity so the render/event loop is genuinely busy during the
    // open window (the real modal animates its height while data lands).
    Rectangle {
        id: spinner
        width: 24; height: 24; radius: 12
        color: "#4360df"
        x: 8
        NumberAnimation on rotation {
            from: 0; to: 360; duration: 800
            loops: Animation.Infinite; running: true
        }
    }

    // The "modal" sheet: slides up when opened, matching StatusDialog's bottom sheet.
    Rectangle {
        id: pane
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.85
        color: "#101014"
        y: root.paneOpen ? parent.height - height : parent.height
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // The token field (always present at open); its dropdown list is lazy.
        Rectangle {
            id: tokenField
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            height: 56
            radius: 8
            color: "#1c1c22"
        }

        Loader {
            id: dropdownLoader
            anchors { left: parent.left; right: parent.right; margins: 12 }
            anchors.top: tokenField.bottom
            anchors.bottom: parent.bottom
            active: root.dropdownOpen
            sourceComponent: dropdownComponent
        }
    }

    Component {
        id: dropdownComponent
        ListView {
            id: listView
            model: sendPickerModel
            cacheBuffer: 0
            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                color: "transparent"
                // Roles the send token row binds.
                property string _k: model.key
                property string _n: model.name
                property string _s: model.symbol
                property string _l: model.logoUri
                property real _cb: model.currentBalance
                property real _fb: model.currencyBalance
                property string _sec: model.sectionName
                Component.onCompleted: bench.onDelegateCreated()
                Component.onDestruction: bench.onDelegateDestroyed()
                // The per-chain balance chips the delegate renders (nested submodel).
                Row {
                    Repeater {
                        model: _balances
                        delegate: Item {
                            width: 20; height: 20
                            property int _c: model.chainId
                            property string _i: model.iconUrl
                            property real _b: model.balance
                            Component.onCompleted: bench.onChipCreated()
                        }
                    }
                }
                property var _balances: model.balances
            }
        }
    }

    // 16ms stall monitor: each tick reports to the driver, which computes the
    // tick-to-tick delta. A synchronous GUI-thread block starves this timer.
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: bench.onStallTick()
    }

    Connections {
        target: sendPickerModel
        function onModelReset() { bench.onModelReset() }
        function onRowsInserted() { bench.onRowsInserted() }
        function onRowsRemoved() { bench.onRowsRemoved() }
        function onDataChanged(topLeft, bottomRight, roles) {
            bench.onDataChanged(topLeft.row, bottomRight.row)
        }
    }

    Connections {
        target: bench
        function onRequestOpen() { root.paneOpen = true }
        function onRequestDropdownOpen() { root.dropdownOpen = true }
        function onRequestDropdownClose() { root.dropdownOpen = false }
        function onRequestRelayout() {
            if (dropdownLoader.item)
                dropdownLoader.item.forceLayout()
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
