import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import utils

StatusDialog {
    id: root

    property int state: Constants.CommunityFetchState.Idle
    property int timeoutSeconds: 60

    signal cancelRequested()
    signal timeoutRequested()
    signal dismissFailedRequested()
    signal retryRequested()

    QtObject {
        id: d

        property int secondsLeft: root.timeoutSeconds
        readonly property bool fetching: root.state === Constants.CommunityFetchState.Fetching
        readonly property bool failed: root.state === Constants.CommunityFetchState.Failed
        readonly property bool loading: fetching && !failed
        readonly property int minDialogWidth: 316
        readonly property int maxDialogWidth: 360
        readonly property int desiredTopPadding: failed ? 90 : fetching ? 77 : Theme.bigPadding
        readonly property int desiredBottomPadding: failed ? 56 : fetching ? 77 : Theme.bigPadding
        // StatusDialog overrides bottomPadding on bottom sheets, so add content spacing to preserve the design margin.
        readonly property int bottomSheetBottomSpacerHeight: root.bottomSheet ? Math.max(0, desiredBottomPadding - root.bottomPadding) : 0

        function resetCountdown() {
            secondsLeft = root.timeoutSeconds
        }

        function closeOrCancel() {
            if (failed)
                root.dismissFailedRequested()
            else
                root.cancelRequested()
        }
    }

    width: Math.max(d.minDialogWidth, Math.min(d.maxDialogWidth,
                                               parent ? parent.width - 2 * Theme.padding : d.maxDialogWidth))
    padding: Theme.xlPadding
    focus: true
    closePolicy: Popup.NoAutoClose
    standardButtons: Dialog.NoButton
    topPadding: d.desiredTopPadding
    bottomPadding: d.desiredBottomPadding
    closeHandler: d.closeOrCancel

    header: Item {
        implicitHeight: Theme.xlPadding + closeButton.height

        StatusFlatRoundButton {
            id: closeButton

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.defaultPadding
            anchors.rightMargin: Theme.defaultPadding
            type: StatusFlatRoundButton.Type.Secondary
            icon.name: "close"
            icon.color: Theme.palette.directColor1
            icon.width: 24
            icon.height: 24
            onClicked: root.closeHandler()
        }
    }

    onStateChanged: {
        if (d.fetching)
            d.resetCountdown()
    }

    onTimeoutSecondsChanged: {
        if (d.fetching)
            d.resetCountdown()
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: d.loading
        onTriggered: {
            d.secondsLeft = Math.max(0, d.secondsLeft - 1)
            if (d.secondsLeft === 0) {
                stop()
                root.timeoutRequested()
            }
        }
    }

    Shortcut {
        enabled: root.opened
        sequences: [StandardKey.Cancel]
        onActivated: d.closeOrCancel()
    }

    contentItem: ColumnLayout {
        id: contentColumn

        width: root.availableWidth
        spacing: Theme.padding

        CountdownProgressIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: !d.failed
            running: d.loading
            timeoutSeconds: root.timeoutSeconds
            secondsLeft: d.secondsLeft
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: d.failed ? qsTr("Unable to fetch the community") :
                             qsTr("We're fetching community...")
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSize(19)
            font.weight: Font.Medium
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: d.failed ? qsTr("It may be offline, or Status couldn't reach it") : ""
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Light
            visible: d.failed
        }

        StatusButton {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
            visible: d.failed
            icon.name: "refresh"
            text: qsTr("Retry")
            type: StatusBaseButton.Type.Primary
            onClicked: root.retryRequested()
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: d.bottomSheetBottomSpacerHeight
            visible: d.bottomSheetBottomSpacerHeight > 0
        }
    }
}
