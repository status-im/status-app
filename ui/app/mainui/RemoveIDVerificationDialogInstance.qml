import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

RemoveIDVerificationDialog {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        if (markAsUntrusted && removeContact) {
            root.contactsStore.markUntrustworthy(publicKey)
            root.contactsStore.removeContact(publicKey)
            Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 trust mark removed, removed from contacts and marked as untrusted").arg(mainDisplayName))
        } else if (markAsUntrusted) {
            root.contactsStore.markUntrustworthy(publicKey)
            Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 trust mark removed and marked as untrusted").arg(mainDisplayName))
        } else if (removeContact) {
            root.contactsStore.removeContact(publicKey)
            Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 trust mark removed and removed from contacts").arg(mainDisplayName))
        } else {
            root.contactsStore.removeTrustStatus(publicKey)
        }
        close()
    }
}
