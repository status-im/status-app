import QtQuick
import QtQuick.Controls

import shared.popups

Item {
    id: root

    QRCodeScannerDialog {
        id: qrCodeScannerDialog
        visible: true
    }

    Button {
        anchors.centerIn: parent
        text: "Reopen"

        onClicked: qrCodeScannerDialog.open()
    }
}

// category: Components
// status: good
