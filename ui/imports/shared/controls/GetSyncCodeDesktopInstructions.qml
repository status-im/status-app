import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core

import shared.views

ColumnLayout {
    id: root

    property int purpose: SyncingCodeInstructions.Purpose.AppSync
    property int type: SyncingCodeInstructions.Type.QRCode

    QtObject {
        id: d

        function imageTag(icon) {
            return "<img src='%1' color='%2' align=top> ".arg(Assets.svg(icon)).arg(root.Theme.palette.directColor1)
        }

        function colorTag(text, color = root.Theme.palette.directColor1) {
            return "<font color='%1'>%2</font>".arg(color).arg(text)
        }

        readonly property var appSyncInstructions: [
            qsTr("Ensure both devices are on the same network"), // 1.
            qsTr("Open Status App on your device"), // 2.
            qsTr("Open %1", "(to) Open Settings").arg(imageTag("settings") + colorTag(qsTr("Settings"))), // 3.
            qsTr("Navigate to the %1", "Navigate to the Syncing tab").arg(imageTag("rotate") + colorTag(qsTr("Syncing tab"))), // 4.
            qsTr("Click %1", "Click Setup Syncing").arg(colorTag(qsTr("Setup Syncing"))), // 5.
            qsTr("%1 on this device", "Scan QR on this device").arg(colorTag(qsTr("Scan QR"))), // 6.
            qsTr("Scan or enter the code") // 7.
        ]

        readonly property var keypairSyncInstructions: [
            qsTr("Ensure both devices are on the same network"), // 1.
            qsTr("Open Status on the device you want to import from"), // 2.
            qsTr("Open %1", "(to) Open Settings / Wallet").arg(imageTag("settings") + colorTag(qsTr("Settings / Wallet"))), // 3.
            qsTr("Click %1 of key pairs on this device", "Click Show encrypted QR of key pairs on this device").arg(colorTag(qsTr("Show encrypted QR"))), // 4.
            root.type === SyncingCodeInstructions.Type.EncryptedKey ? qsTr("Copy the encrypted key pairs code") // 5.
                                                                    : qsTr("%1 on this device", "Scan QR on this device").arg(colorTag(qsTr("Scan QR"))),
            root.type === SyncingCodeInstructions.Type.EncryptedKey ? qsTr("Paste the encrypted key pairs code to this device") // 6.
                                                                    : qsTr("Scan or enter the encrypted QR with this device"),
            root.type === SyncingCodeInstructions.Type.EncryptedKey ? qsTr("For security, delete the code as soon as you are done") // 7.
                                                                    : ""
        ]
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: contentHeight
        model: root.purpose === SyncingCodeInstructions.Purpose.KeypairSync ? d.keypairSyncInstructions
                                                                            : d.appSyncInstructions
        interactive: false
        spacing: 6
        delegate: StatusBaseText {
            width: ListView.view.width
            wrapMode: Text.Wrap
            color: Theme.palette.baseColor1
            text: "%1. %2".arg(index + 1).arg(modelData)
            visible: !!modelData
        }
    }
}
