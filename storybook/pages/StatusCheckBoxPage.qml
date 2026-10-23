import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical
    Logs { id: logs }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            width: switchControl.width
            height: switchControl.height
            anchors.centerIn: parent
            color: "transparent"
            border.width: 1
            border.color: "pink"

            StatusCheckBox {
                id: switchControl
                anchors.centerIn: parent
                text: ctrlWithText.checked ? "Check me out" : ""
                leftSide: !ctrlInverted.checked
                changeCursor: ctrlCursor.checked
                checked: true
                enabled: ctrlEnabled.checked
                tristate: ctrlTristate.checked
                size: ctrlSmall.checked ? StatusCheckBox.Size.Small : StatusCheckBox.Size.Regular
                onClicked: logs.logEvent("clicked()")
                onToggled: logs.logEvent("toggled()")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 320
        SplitView.preferredHeight: 320

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true

            Label {
                text: "State: %1".arg(switchControl.checkState)
            }

            Switch {
                id: ctrlEnabled
                text: "Enabled"
                checked: true
            }
            Switch {
                id: ctrlCursor
                text: "Change cursor"
                checked: true
            }
            Switch {
                id: ctrlInverted
                text: "Inverted"
            }
            Switch {
                id: ctrlSmall
                text: "Small size"
            }
            Switch {
                id: ctrlTristate
                text: "Tristate"
            }
            Switch {
                id: ctrlWithText
                text: "With text"
                checked: true
            }
        }
    }
}

// category: Controls
// status: good
// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=17726-60222&m=dev
