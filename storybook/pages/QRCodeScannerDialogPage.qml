import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import shared.popups
import StatusQ.Core.Theme

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }


    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        QRCodeScannerDialog {
            id: qrCodeScannerDialog
            // workaround for QTBUG-142248
            Theme.style: root.Theme.style
            Theme.padding: root.Theme.padding
            Theme.fontSizeOffset: root.Theme.fontSizeOffset
            visible: true
            cameraPermissionDenied: !ctrlCameraEnabled.checked
        }

        Button {
            anchors.centerIn: parent
            text: "Reopen"

            onClicked: qrCodeScannerDialog.open()
        }
    }



    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        RowLayout {
            Layout.fillWidth: true


            Switch {
                id: ctrlCameraEnabled
                text: "Camera access allowed"
                checked: true
            }
        }
    }
}

// category: Popups
// status: good

// "https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=5367-32317&p=f&t=NNyEnbxSaAbXYwYe-0"
