import QtQuick

import Storybook
import shared.popups
import shared.stores as SharedStores

ContactAdaptiveDialogStoryFrame {
    id: root

    localNickname: "Ada"
    showRequestControls: false

    SharedStores.UtilsStore {
        id: utilsStoreMock

        function isAlias(name) {
            return false
        }
    }

    dialogComponent: Component {
        NicknamePopup {
            id: dialog

            modal: false
            publicKey: root.publicKey
            compressedPublicKey: root.compressedPublicKey
            emojiHash: root.emojiHash
            contactDetails: root.contactDetails
            utilsStore: utilsStoreMock
            onEditDone: newNickname => {
                root.logs.logEvent("editDone newNickname=" + newNickname)
                dialog.close()
            }
            onRemoveNicknameRequested: {
                root.logs.logEvent("removeNicknameRequested")
                dialog.close()
            }
            onClosed: root.logs.logEvent("closed")
        }
    }
}

// category: Popups
