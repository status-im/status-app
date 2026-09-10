import QtQuick

import Storybook
import shared.popups

ContactAdaptiveDialogStoryFrame {
    id: root

    isTrusted: false

    dialogComponent: Component {
        MarkAsIDVerifiedDialog {
            id: dialog

            modal: false
            publicKey: root.publicKey
            compressedPublicKey: root.compressedPublicKey
            emojiHash: root.emojiHash
            contactDetails: root.contactDetails
            onAccepted: {
                root.logs.logEvent("accepted")
                dialog.close()
            }
            onClosed: root.logs.logEvent("closed")
        }
    }
}

// category: Popups
