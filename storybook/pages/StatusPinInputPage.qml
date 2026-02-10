import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core.Theme

Item {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        StatusBaseText {
            Layout.alignment: Qt.AlignHCenter
            text: "ENTER NUMERIC PIN, EXPECTED LENGTH: %1".arg(pinInput.pinLen)
        }
        StatusPinInput {
            Layout.alignment: Qt.AlignHCenter
            id: pinInput
            validator: StatusIntValidator { bottom: 0; top: 999999 }
            Component.onCompleted: {
                statesInitialization()
            }
        }
        StatusBaseText {
            Layout.alignment: Qt.AlignHCenter
            text: "ENTERED PIN: %1".arg(pinInput.pinInput || "[empty]")
        }
        StatusBaseText {
            Layout.alignment: Qt.AlignHCenter
            text: "VALID: %1".arg(pinInput.valid ? "true" : "false")
        }
    }
}

// category: Controls
// status: good
