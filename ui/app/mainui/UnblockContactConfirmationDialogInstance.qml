import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

UnblockContactConfirmationDialog {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        root.contactsStore.unblockContact(publicKey)
        Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 unblocked").arg(mainDisplayName))
        close()
    }
}
