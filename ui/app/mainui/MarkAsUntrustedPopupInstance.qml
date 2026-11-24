import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

MarkAsUntrustedPopup {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        root.contactsStore.markUntrustworthy(publicKey)
        if (removeContact) {
            root.contactsStore.removeContact(publicKey)
            Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 removed from contacts and marked as untrusted").arg(mainDisplayName))
        } else {
            Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 marked as untrusted").arg(mainDisplayName))
        }
        close()
    }
}
