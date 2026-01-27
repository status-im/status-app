import QtQuick
import QtQuick.Controls

import shared.popups
import StatusQ.Core.Theme

Item {
    id: root

    QRCodeScannerDialog {
        id: qrCodeScannerDialog
        visible: true
        modal: false
        closePolicy: Dialog.CloseOnEscape
    }

    Button {
        anchors.centerIn: parent
        text: "Reopen"

        onClicked: qrCodeScannerDialog.open()
    }
}

// category: Components
// status: good
