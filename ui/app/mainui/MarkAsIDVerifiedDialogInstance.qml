import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

MarkAsIDVerifiedDialog {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        root.contactsStore.markAsTrusted(publicKey)
        Global.displaySuccessToastMessage(qsTranslate("Popups", "%1 marked as trusted").arg(mainDisplayName))
        close()
    }
}
