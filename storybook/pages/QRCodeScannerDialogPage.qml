import QtQuick
import QtQuick.Controls

import shared.popups
import StatusQ.Core.Theme

Item {
    id: root

    QRCodeScannerDialog {
        id: qrCodeScannerDialog
        // workaround for QTBUG-142248
        Theme.style: root.Theme.style
        Theme.padding: root.Theme.padding
        Theme.fontSizeOffset: root.Theme.fontSizeOffset
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
