import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

BlockContactConfirmationDialog {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        root.contactsStore.blockContact(publicKey)
        if (removeIDVerification)
            root.contactsStore.removeTrustStatus(publicKey)
        if (removeContact)
            root.contactsStore.removeContact(publicKey)
        Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 blocked").arg(mainDisplayName))
        close()
    }
}
