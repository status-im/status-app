import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils

/// Whether the browser offers to open files other apps send to Status, and the
/// types Status opens by default, with the way to stop that (Android).
ColumnLayout {
    id: root

    /// Whether the offer shows; the host keeps it.
    property bool suggested: true

    property var typesFn: () => SystemUtils.defaultViewerTypes()
    property var resetFn: () => SystemUtils.resetDefaultViewer()

    /// The types Status opens by default, as the platform last said.
    property var types: []

    signal suggestedToggled(bool suggested)

    function refresh() {
        types = typesFn() ?? []
    }

    function reset() {
        resetFn()
        refresh()
        d.awaitingReturn = true
    }

    /// The app is active again; only a return from Stop's system screen can
    /// have changed the types.
    function applicationActivated() {
        if (!d.awaitingReturn)
            return
        d.awaitingReturn = false
        refresh()
    }

    spacing: 0

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

    QtObject {
        id: d
        property bool awaitingReturn: false
    }

    readonly property Connections appState: Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                root.applicationActivated()
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        leftPadding: 0
        bgColor: StatusColors.transparent
        title: qsTr("Suggest opening files in Status")
        components: [
            StatusSwitch {
                id: suggestSwitch
                objectName: "suggestDefaultViewerSwitch"
                checked: root.suggested
                onToggled: root.suggestedToggled(checked)
            }
        ]
        onClicked: suggestSwitch.click()
    }

    StatusListItem {
        objectName: "defaultViewerTypesItem"
        Layout.fillWidth: true
        visible: root.types.length > 0
        leftPadding: 0
        bgColor: StatusColors.transparent
        title: qsTr("Opened in Status")
        subTitle: DefaultViewerTypes.names(root.types)
        statusListItemSubTitle.font.pixelSize: Theme.fontSize(13)
        components: [
            StatusButton {
                objectName: "resetDefaultViewerButton"
                size: StatusBaseButton.Size.Small
                type: StatusBaseButton.Type.Danger
                text: qsTr("Stop")
                onClicked: root.reset()
            }
        ]
    }
}
