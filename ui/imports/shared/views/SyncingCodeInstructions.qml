import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme

import utils
import shared.controls

ColumnLayout {
    id: root

    enum Purpose {
        AppSync,
        KeypairSync
    }

    enum Type {
        QRCode,
        EncryptedKey
    }

    property int purpose: SyncingCodeInstructions.Purpose.AppSync
    property int type: SyncingCodeInstructions.Type.QRCode

    GetSyncCodeDesktopInstructions {
        Layout.fillWidth: true

        purpose: root.purpose
        type: root.type
    }
}
