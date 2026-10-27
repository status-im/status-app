import QtQuick
import QtQuick.Controls

import AppLayouts.Onboarding.pages

Item {
    id: root

    ListModel {
        id: loginAccounts

        ListElement {
            keyUid: "profile-key-uid-1"
            username: "Alice"
            colorId: 0
            thumbnailImage: ""
        }
    }

    ListModel {
        id: emptyLoginAccounts
    }

    KeycardDetailsPage {
        anchors.fill: parent
        anchors.bottomMargin: 80

        keycardState: ctrlState.currentText
        keycardUid: "keycard-uid-1"
        keyUid: ctrlOnlyPin.checked ? "" : "profile-key-uid-1"
        keycardStatusAvailable: true
        remainingPinAttempts: ctrlBlocked.checked ? 0 : 3
        remainingPukAttempts: 5
        availableSlots: ctrlNoSlots.checked || ctrlApplet4.checked ? 0 : 5
        pairingSupported: !ctrlApplet4.checked
        cardMetadataName: "My Keycard"
        cardMetadataWalletAccountsJson: "[]"
        loginAccountsModel: ctrlProfileExists.checked ? loginAccounts : emptyLoginAccounts
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 4

        CheckBox {
            id: ctrlProfileExists
            text: "profile already exists"
            checked: true
        }
        CheckBox {
            id: ctrlOnlyPin
            text: "only PIN set"
        }
        CheckBox {
            id: ctrlNoSlots
            text: "no free slots"
        }
        CheckBox {
            id: ctrlApplet4
            text: "applet 4.x (no pairing)"
        }
        CheckBox {
            id: ctrlBlocked
            text: "blocked (0 PIN attempts)"
        }
        ComboBox {
            id: ctrlState
            width: 260
            model: ["ready", "empty-keycard", "blocked-pin", "blocked-puk",
                    "no-available-pairing-slots", "untrusted-keycard"]
        }
    }
}

// category: Onboarding
// status: good
