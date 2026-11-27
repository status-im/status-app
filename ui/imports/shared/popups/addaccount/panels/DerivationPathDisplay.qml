import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls

import utils
import shared.controls

import "../stores"

GridLayout {
    id: root

    property AddAccountStore store

    columns: 2
    columnSpacing: Theme.padding
    rowSpacing: Theme.halfPadding

    QtObject {
        id: d

        readonly property int oneHalfWidth: (root.width - root.columnSpacing) * 0.5
    }

    component ReadonlyInputWithCopyButton: StatusInput {
        id: comp
        required property string textToCopy
        property bool revealNeedsPassword: false

        input.edit.enabled: false
        input.edit.color: Theme.palette.baseColor1
        input.background.color: "transparent"
        input.background.border.color: Theme.palette.baseColor2
        input.rightComponent: CopyButton {
            textToCopy: comp.textToCopy
            revealNeedsPassword: comp.revealNeedsPassword
        }
    }

    StatusBaseText {
        Layout.fillWidth: true
        text: qsTr("Derivation Path")
    }

    StatusBaseText {
        Layout.preferredWidth: d.oneHalfWidth
        text: qsTr("Account")
    }

    ReadonlyInputWithCopyButton {
        Layout.preferredWidth: d.oneHalfWidth
        text: root.store.addAccountModule.derivationPath
        textToCopy: root.store.addAccountModule.derivationPath
    }

    ReadonlyInputWithCopyButton {
        Layout.preferredWidth: d.oneHalfWidth
        text: StatusQUtils.Utils.elideText(root.store.selectedDerivedAddress.address, 6, 8)
        textToCopy: root.store.selectedDerivedAddress.address
        revealNeedsPassword: root.store.addressRevealNeedsPassword && !root.store.selectedOrigin.migratedToColdWallet
    }

    StatusBaseText {
        Layout.preferredWidth: d.oneHalfWidth
        font.pixelSize: Theme.additionalTextSize
        color: Theme.palette.baseColor1
        text: {
            if (root.store.addAccountModule.derivationPath.startsWith(Constants.addAccountPopup.predefinedPaths.ethereum)) {
                root.store.selectedRootPath = Constants.addAccountPopup.predefinedPaths.ethereum
            }
            else if (root.store.addAccountModule.derivationPath.startsWith(Constants.addAccountPopup.predefinedPaths.ethereumLedger)) {
                root.store.selectedRootPath = Constants.addAccountPopup.predefinedPaths.ethereumLedger
            }
            else if (root.store.addAccountModule.derivationPath.startsWith(Constants.addAccountPopup.predefinedPaths.ethereumLedgerLive)) {
                root.store.selectedRootPath = Constants.addAccountPopup.predefinedPaths.ethereumLedgerLive
            }
            else {
                root.store.selectedRootPath = Constants.addAccountPopup.predefinedPaths.custom
            }

            return root.store.translation(root.store.selectedRootPath, true)
        }
    }
}
