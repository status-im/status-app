import QtQuick

import Storybook
import shared.popups

ContactAdaptiveDialogStoryFrame {
    id: root

    isContact: true
    isTrusted: true

    dialogComponent: Component {
        BlockContactConfirmationDialog {
            id: dialog

            modal: false
            publicKey: root.publicKey
            compressedPublicKey: root.compressedPublicKey
            emojiHash: root.emojiHash
            contactDetails: root.contactDetails
            onAccepted: {
                root.logs.logEvent("accepted removeContact=" + dialog.removeContact + " removeIDVerification=" + dialog.removeIDVerification)
                dialog.close()
            }
            onClosed: root.logs.logEvent("closed")
        }
    }
}

// category: Popups
