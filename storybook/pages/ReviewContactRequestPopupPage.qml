import QtQuick

import Storybook
import shared.popups

ContactAdaptiveDialogStoryFrame {
    id: root

    showRequestControls: true

    dialogComponent: Component {
        ReviewContactRequestPopup {
            id: dialog

            modal: false
            publicKey: root.publicKey
            compressedPublicKey: root.compressedPublicKey
            emojiHash: root.emojiHash
            contactDetails: root.contactDetails
            crDetails: root.contactRequestDetails
            onAccepted: {
                root.logs.logEvent("accepted contactRequestId=" + contactRequestId)
                dialog.close()
            }
            onRejected: {
                root.logs.logEvent("ignored contactRequestId=" + contactRequestId)
                dialog.close()
            }
            onClosed: root.logs.logEvent("closed")
        }
    }
}

// category: Popups
