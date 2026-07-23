import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import mainui

Item {
    id: root

    readonly property int stateIdle: 0
    readonly property int stateFetching: 1
    readonly property int stateFailed: 2
    property int popupState: stateIdle
    property int scenario: 0

    readonly property string idleText: "Choose a scenario"
    readonly property string stateText: popupState === stateFailed ? "Failed" :
                                        popupState === stateFetching ? "Fetching" :
                                                                       idleText

    function reset() {
        popupState = stateIdle
        scenario = 0
        scenarioTimer.stop()
    }

    function start(newScenario) {
        reset()
        scenario = newScenario
        popupState = stateFetching
        if (scenario === 1 || scenario === 2)
            scenarioTimer.start()
    }

    function fail() {
        popupState = stateFailed
        scenarioTimer.stop()
    }

    Rectangle {
        anchors.fill: parent
        color: "#e5e5e5"
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 420
        spacing: 20

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Community -> Fetching"
            color: "#2A8AF6"
            font.pixelSize: 20
            font.weight: Font.Medium
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            Layout.alignment: Qt.AlignHCenter
            radius: 8
            color: "#ffffff"

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Previous screen"
                    color: "#697386"
                    font.pixelSize: 16
                }

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Popup state: " + root.stateText
                    color: "#111827"
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Button {
                text: "Success after 10s"
                onClicked: root.start(1)
            }

            Button {
                text: "Fail after 10s"
                onClicked: root.start(2)
            }

            Button {
                text: "Fail after 60s"
                onClicked: root.start(3)
            }
        }
    }

    Timer {
        id: scenarioTimer

        interval: 10000
        repeat: false
        onTriggered: {
            if (root.scenario === 1)
                root.reset()
            else if (root.scenario === 2)
                root.fail()
        }
    }

    CommunityFetchPopup {
        id: popup

        state: root.popupState
        timeoutSeconds: 60
        errorMessage: "It may be offline, or Status couldn't reach it"

        onCancelRequested: root.reset()
        onDismissFailedRequested: root.reset()
        onRetryRequested: root.start(root.scenario || 3)
        onTimeoutRequested: root.fail()
    }
}

// category: Communities
