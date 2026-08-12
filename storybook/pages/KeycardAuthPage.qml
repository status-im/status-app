import QtQuick
import QtQuick.Controls

import shared.popups.auth_sign_base.states

Item {
    id: root

    KeycardAuth {
        anchors.fill: parent
        anchors.bottomMargin: 40

        userProfilePublicKey: "0xpub"
        keycardState: ctrlState.currentText
        keycardInternalError: ctrlInternalError.checked
        wrongKeycardProfile: ctrlWrongProfile.checked
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 8

        CheckBox {
            id: ctrlWrongProfile
            text: "wrongKeycardProfile"
        }

        CheckBox {
            id: ctrlInternalError
            text: "keycardInternalError"
        }

        ComboBox {
            id: ctrlState
            width: 260
            model: ["waiting-for-card", "connecting-card", "ready", "empty-keycard",
                    "not-keycard", "blocked-pin", "blocked-puk", "pairing-error",
                    "no-available-pairing-slots", "authorized"]
        }
    }
}

// category: Popups
// status: good
