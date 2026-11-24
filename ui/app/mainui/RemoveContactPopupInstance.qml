import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

RemoveContactPopup {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        root.contactsStore.removeContact(publicKey)
        if (removeIDVerification)
            root.contactsStore.removeTrustStatus(publicKey)
        if (markAsUntrusted) {
            root.contactsStore.markUntrustworthy(publicKey)
            Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 removed from contacts and marked as untrusted").arg(mainDisplayName))
        }
        close()
    }
}
